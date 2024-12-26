
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


