
;; Decentralized Insurance Protocol
;; Features: Policy creation, premium calculation, claims processing, risk pooling

;; Constants and Settings
(define-constant CONTRACT-OWNER tx-sender)
(define-constant MIN-COVERAGE-AMOUNT u1000000) ;; 1 STX
(define-constant MAX-COVERAGE-AMOUNT u1000000000) ;; 1000 STX
(define-constant CLAIM-THRESHOLD u500000) ;; Minimum claim amount
(define-constant PREMIUM-BASE-RATE u100) ;; 1% base rate
(define-constant RISK-MULTIPLIER u200) ;; 2x multiplier for high-risk policies
(define-constant VOTING-PERIOD u144) ;; ~24 hours in blocks
(define-constant CLAIMS-RESERVE-RATIO u300) ;; 30% of premiums go to reserves

;; Error codes
(define-constant ERR-UNAUTHORIZED (err u100))
(define-constant ERR-INVALID-AMOUNT (err u101))
(define-constant ERR-POLICY-NOT-FOUND (err u102))
(define-constant ERR-POLICY-EXPIRED (err u103))
(define-constant ERR-CLAIM-IN-PROGRESS (err u104))
(define-constant ERR-INSUFFICIENT-COVERAGE (err u105))
(define-constant ERR-INVALID-RISK-SCORE (err u106))


;; Data Maps
(define-map policies
    principal
    {
        coverage-amount: uint,
        premium-amount: uint,
        risk-score: uint,
        start-block: uint,
        end-block: uint,
        claims-filed: uint,
        active: bool
    }
)


(define-map claims
    uint
    {
        policyholder: principal,
        amount: uint,
        evidence-hash: (buff 32),
        votes-for: uint,
        votes-against: uint,
        status: (string-ascii 20),
        created-at: uint
    }
)

(define-map risk-scores
    principal
    {
        score: uint,
        last-updated: uint,
        total-claims: uint
    }
)

(define-map pool-stats
    bool
    {
        total-premiums: uint,
        total-claims-paid: uint,
        available-liquidity: uint,
        total-policies: uint
    }
)

;; Private Functions
(define-private (calculate-premium 
    (coverage-amount uint) 
    (risk-score uint))
    (let
        (
            (base-premium (/ (* coverage-amount PREMIUM-BASE-RATE) u10000))
            (risk-adjusted-premium (/ (* base-premium (+ u1000 (* risk-score RISK-MULTIPLIER))) u1000))
        )
        risk-adjusted-premium
    )
)

(define-private (update-risk-score (user principal) (claim-amount uint))
    (let
        (
            (current-score (default-to 
                {score: u500, last-updated: u0, total-claims: u0}
                (map-get? risk-scores user)))
            (new-score (+ 
                (get score current-score)
                (/ (* claim-amount u100) (get total-claims current-score))))
        )
        (map-set risk-scores
            user
            (merge current-score {
                score: new-score,
                last-updated: block-height,
                total-claims: (+ u1 (get total-claims current-score))
            })
        )
        new-score
    )
)

;; Public Functions
(define-public (create-policy (coverage-amount uint) (duration uint))
    (let
        (
            (sender tx-sender)
            (risk-data (default-to 
                {score: u500, last-updated: u0, total-claims: u0}
                (map-get? risk-scores sender)))
            (premium-amount (calculate-premium coverage-amount (get score risk-data)))
        )
        (asserts! (and 
            (>= coverage-amount MIN-COVERAGE-AMOUNT)
            (<= coverage-amount MAX-COVERAGE-AMOUNT)) 
            ERR-INVALID-AMOUNT)
        (try! (stx-transfer? premium-amount sender (as-contract tx-sender)))
        (ok (map-set policies
            sender
            {
                coverage-amount: coverage-amount,
                premium-amount: premium-amount,
                risk-score: (get score risk-data),
                start-block: block-height,
                end-block: (+ block-height duration),
                claims-filed: u0,
                active: true
            }))
    )
)


(define-public (file-claim (amount uint) (evidence-hash (buff 32)))
    (let
        (
            (sender tx-sender)
            (policy (unwrap! (map-get? policies sender) ERR-POLICY-NOT-FOUND))
            (claim-id (+ (var-get next-claim-id) u1))
        )
        (asserts! (get active policy) ERR-POLICY-EXPIRED)
        (asserts! (>= amount CLAIM-THRESHOLD) ERR-INVALID-AMOUNT)
        (asserts! (<= amount (get coverage-amount policy)) ERR-INSUFFICIENT-COVERAGE)
        (var-set next-claim-id claim-id)
        (ok (map-set claims
            claim-id
            {
                policyholder: sender,
                amount: amount,
                evidence-hash: evidence-hash,
                votes-for: u0,
                votes-against: u0,
                status: "PENDING",
                created-at: block-height
            }))
    )
)


(define-public (vote-on-claim (claim-id uint) (vote bool))
    (let
        (
            (sender tx-sender)
            (claim (unwrap! (map-get? claims claim-id) ERR-CLAIM-IN-PROGRESS))
        )
        (asserts! (is-eq (get status claim) "PENDING") ERR-UNAUTHORIZED)
        (if vote
            (map-set claims claim-id (merge claim {votes-for: (+ (get votes-for claim) u1)}))
            (map-set claims claim-id (merge claim {votes-against: (+ (get votes-against claim) u1)}))
        )
        (ok true)
    )
)

(define-public (process-claim (claim-id uint))
    (let
        (
            (claim (unwrap! (map-get? claims claim-id) ERR-CLAIM-IN-PROGRESS))
            (total-votes (+ (get votes-for claim) (get votes-against claim)))
        )
        (asserts! (>= (- block-height (get created-at claim)) VOTING-PERIOD) ERR-UNAUTHORIZED)
        (if (> (get votes-for claim) (get votes-against claim))
            (begin
                (try! (as-contract (stx-transfer? 
                    (get amount claim)
                    (as-contract tx-sender)
                    (get policyholder claim))))
                (map-set claims claim-id (merge claim {status: "APPROVED"}))
                (ok true))
            (begin
                (map-set claims claim-id (merge claim {status: "REJECTED"}))
                (ok true))
        )
    )
)

;; Read-only functions
(define-read-only (get-policy (user principal))
    (map-get? policies user)
)

(define-read-only (get-claim (claim-id uint))
    (map-get? claims claim-id)
)

(define-read-only (get-pool-stats)
    (map-get? pool-stats true)
)



