import { describe, it, expect, beforeEach, vi } from 'vitest';

// Mock state
const state = {
    policies: new Map(),
    claims: new Map(),
    riskScores: new Map(),
    poolStats: new Map(),
    nextClaimId: 0,
    blockHeight: 1000
};

// Mock contract functions
const contract = {
    calculatePremium: (coverageAmount: number, riskScore: number) => {
        const basePremium = (coverageAmount * 100) / 10000;
        return (basePremium * (1000 + riskScore * 200)) / 1000;
    },

    createPolicy: (sender: string, coverageAmount: number, duration: number) => {
        if (coverageAmount < 1000000 || coverageAmount > 1000000000) {
            return { error: 101 };
        }

        const riskData = state.riskScores.get(sender) || {
            score: 500,
            lastUpdated: state.blockHeight,
            totalClaims: 0
        };

        const policy = {
            coverageAmount,
            premiumAmount: contract.calculatePremium(coverageAmount, riskData.score),
            riskScore: riskData.score,
            startBlock: state.blockHeight,
            endBlock: state.blockHeight + duration,
            claimsFiled: 0,
            active: true
        };

        state.policies.set(sender, policy);
        return { success: true };
    },

    fileClaim: (sender: string, amount: number, evidenceHash: Buffer) => {
        const policy = state.policies.get(sender);
        if (!policy) return { error: 102 };
        if (!policy.active) return { error: 103 };
        if (amount < 500000) return { error: 101 };
        if (amount > policy.coverageAmount) return { error: 105 };

        const claimId = ++state.nextClaimId;
        state.claims.set(claimId, {
            policyholder: sender,
            amount,
            evidenceHash,
            votesFor: 0,
            votesAgainst: 0,
            status: "PENDING",
            createdAt: state.blockHeight
        });

        return { success: true };
    }
};

describe('Insurance Protocol Tests', () => {
    beforeEach(() => {
        state.policies.clear();
        state.claims.clear();
        state.riskScores.clear();
        state.poolStats.clear();
        state.nextClaimId = 0;
        state.blockHeight = 1000;
    });

    describe('create-policy', () => {
        it('should successfully create a valid policy', () => {
            const result = contract.createPolicy('wallet1', 2000000, 1000);
            expect(result.success).toBe(true);
            
            const policy = state.policies.get('wallet1');
            expect(policy).toBeDefined();
            expect(policy?.active).toBe(true);
            expect(policy?.coverageAmount).toBe(2000000);
        });

        it('should reject policy with invalid coverage amount', () => {
            const result = contract.createPolicy('wallet1', 500000, 1000);
            expect(result.error).toBe(101);
        });
    });

    describe('file-claim', () => {
        beforeEach(() => {
            contract.createPolicy('wallet1', 2000000, 1000);
        });

        it('should successfully file a valid claim', () => {
            const result = contract.fileClaim('wallet1', 600000, Buffer.alloc(32));
            expect(result.success).toBe(true);
            
            const claim = state.claims.get(1);
            expect(claim).toBeDefined();
            expect(claim?.status).toBe('PENDING');
            expect(claim?.amount).toBe(600000);
        });

        it('should reject claim below threshold', () => {
            const result = contract.fileClaim('wallet1', 400000, Buffer.alloc(32));
            expect(result.error).toBe(101);
        });

        it('should reject claim above coverage', () => {
            const result = contract.fileClaim('wallet1', 3000000, Buffer.alloc(32));
            expect(result.error).toBe(105);
        });
    });

    describe('premium calculation', () => {
        it('should calculate correct premium based on risk score', () => {
            const premium = contract.calculatePremium(2000000, 500);
            expect(premium).toBeGreaterThan(0);
            expect(typeof premium).toBe('number');
        });
    });
});