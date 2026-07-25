# Invalidation Register

| ID | Original Value | Result | Cause | Authority | Date | Superseding Value |
|-----|----------------|--------|-------|-----------|------|-------------------|
| INV-001 | Table 6 ratio 5-7x | VERIFIED | Reinterpreted via U2 decomposition | T7_pearson_loggap.R | 2026 (undated) | Pearson 6.25 / log-gap 0.99 |
| INV-002 | Full-rho correction (rho=1) | RETIRED | P4-(iv) rejects boundary | P4_volatility.R | 2026 (undated) | Capped-rho = 0.83 |
| INV-003 | sigma_theta = 0.15 | CLOSED | Deconvolution refinement | O5_deconvolution.R | 2026 (undated) | SD_THETA_IDSET = [0.39, 0.46] |
| INV-004 | R2 false invalidation | REVERSED | Reanalysis confirmed original | Review_v2.R | 2026 (undated) | Original estimate valid |
| INV-005 | Exponentiation error | RELABELED | exp(theta) vs theta interpretation | Clarification | 2026 (undated) | Values are log-changes, not levels |
| INV-006 | M-era mean_A | CLOSED | Population redefinition | M_reconciliation.R | 2026 (undated) | MEAN_THETA = 0.2138 |
| INV-007 | M-era mean_B | CLOSED | Population redefinition | M_reconciliation.R | 2026 (undated) | Merged into canonical W1 |
| INV-008 | QSKEW = -2.6066 | RELABELED | Moment vs quantile skewness | Skewness_decomp.R | 2026 (undated) | MSKEW_RAW_OBSERVED = -2.6066; QSKEW = 2.9867 |
| INV-009 | SPLITHALF r=0.9244 | SUPERSEDED | Fresh recomputation canonical | NAIVE_GROUND_TRUTH.R | 2026-07-24 | SPLITHALF_A_FRESH = 0.9720 |
| INV-010 | O1 theta_A (mean=-0.52) | REGISTER | Unidentified computation lineage | NAIVE_GROUND_TRUTH.R | 2026-07-24 | r=0.667 vs fresh; canonical is G2a (mean=-0.27, SD=1.66) |
| INV-011 | O1 theta_B | REGISTER | Unidentified computation lineage | NAIVE_GROUND_TRUTH.R | 2026-07-24 | r=0.677 vs fresh; M1 theta_hat_B (r=0.976) pending CHECK |

## Notes
- INV-001: Table 6 verified from original code; reinterpreted via U2 decomposition (Pearson 6.25 / log-gap 0.99)
- INV-002: Full-rho correction (rho=1) rejected by P4 proposition verification; capped at 0.83
- INV-003: Deconvolved SD bounds updated; identified set [0.39, 0.46] per Prop 3
- INV-004: R2 false invalidation reversed after reanalysis confirmed original estimate
- INV-005: Values are log-changes (theta), not levels (exp(theta)); relabeled for clarity
- INV-006: M-era mean_A superseded by canonical population mean 0.2138
- INV-007: M-era mean_B merged into canonical W1 population
- INV-008: Moment skewness (-2.6066) relabeled as MSKEW_RAW_OBSERVED; quantile skewness (2.9867) is QSKEW
- INV-009: G2c r=0.9244 superseded by fresh ledgered computation r=0.9720. Note: r=0.9364 reported elsewhere is decile-split reliability of theta_D, a different statistic (not superseded).
- INV-010: O1 theta_A had mean=-0.5168 but r=0.667 vs fresh recomputation; canonical Definition A is G2a theta_hat (mean=-0.2738, SD=1.6641, r=1.0 vs fresh)
- INV-011: O1 theta_B had r=0.677 vs fresh; M1 theta_hat_B has r=0.976 (between 0.9 and 0.99, requires CHECK)

## Cross-Check Verification
Verified via cross_check_register.R: No superseded value appears as canonical.
All superseding values match canonical_facts.md.
T1 cells verified against canonical_facts (facts-vs-CSV check).

## F2 Figure Errata

| Version | Description | Status | Date |
|---------|-------------|--------|------|
| F2_v1 | Plain 2-component GMM on observed theta_D | SUPERSEDED | 2026-07-24 |
| F2_v2 | Ledgered deconvolution K=2/K=3 mixture | CURRENT | 2026-07-24 |

**Resolution:** F2 regenerated from ledgered deconvolution mixtures. Current F2 displays:
- Observed theta_D histogram (n=4182)
- DECONV_K2 overlay: w=[0.135,0.865], m=[0.131,0.220], s=[0.858,0.071]
- DECONV_K3 overlay: w=[0.204,0.031,0.765], m=[0.451,-1.095,0.199], s=[0.369,0.989,0.049]
- K=3 mode density = 6.38 (> 4.0 required)
Source: W2_results.rds (SHA K2: 72e405aa..., SHA K3: f9fe84cd...)

## NAIVE-GROUND-TRUTH Adjudication (2026-07-24)

Fresh recomputation from G1 predictions with ledgered windows:
- theta_A (canonical): n=4182, mean=-0.2738, SD=1.6641 (= G2a, r=1.0)
- theta_B (canonical): n=4182, mean=0.0854, SD=1.5819
- placebo_A: n=18055, mean=-0.7121, SD=1.1165 (anchors Prop 1)
- Split-half r (fresh): 0.9720

Lineage adjudication:
- G2a theta_hat: CANONICAL (r=1.0 vs fresh)
- O1 theta_A: REGISTER (r=0.667, unidentified lineage)
- O1 theta_B: REGISTER (r=0.677, unidentified lineage)
- M1 theta_hat_B: CHECK (r=0.976, between 0.9 and 0.99)
