# Canonical Facts Ledger

Generated: 2026-07-26
Status: CLOSED

## Population

| ID | Quantity | Value | Producer |
|----|----------|-------|----------|
| N | Sample size | 4182 | code/S6R_population.R -> data/S6R_population.rds (census: output/TD1R_population_census.csv) |

## Effect Distribution

| ID | Quantity | Value | SE | Producer |
|----|----------|-------|-----|----------|
| MEAN_THETA_D | Mean theta_D | 0.2473 | 0.0241 | data/S5R_bhat.rds$baseline (n=4182) |
| SD_THETA_TRUE | SD(theta_true) | [0.74, 1.48] | - | INV-027 |
| RAW_SHARE | Share theta_D <= 0 | 0.4211 | - | data/S5R_bhat.rds$baseline (n=4182) |

## P(theta <= 0) Bracket

| ID | Quantity | Value | Producer |
|----|----------|-------|----------|
| P_THETA_LEQ_0 | P(theta_true <= 0) | [0.369, 0.421] | code/S22_ladder_closed_form.R -> output/T19_pleq0_bracket.csv |
| P_LO | C_hardened | 0.369 | Phi(-0.2473/0.74), normal form |
| P_HI | A_noise_only | 0.421 | Capped at RAW_SHARE (normal form 0.433 exceeds empirical share) |

## GE Propagation (Arm-Indexed)

| Arm | SD_true | q50 | RANGE_1090 | Producer |
|-----|---------|-----|------------|----------|
| C_hardened | 0.740 | 28.2% | 6.64 | code/S23_ge_bracket.R -> output/T20_ge_bracket.csv |
| A_noise_only | 1.475 | 23.5% | 44.44 | code/S23_ge_bracket.R -> output/T20_ge_bracket.csv |

## Gradient

| ID | Quantity | Value | SE | Producer |
|----|----------|-------|-----|----------|
| GRADIENT | Cohort gradient | 0.9137 | 0.0809 | gates/X5_size_cohort.R -> gates/T3_gradient_cohorts.csv |

## Superseded Entries

| Old Entry | Old Value | Cause | INV |
|-----------|-----------|-------|-----|
| "41% share theta_D <= 0" | 0.41 | wrong-object | INV-028 |
| "12.5x GE range" | 12.5 | un-indexed by arm | INV-028 |
| "27.25x GE range" | 27.25 | un-indexed by arm | INV-028 |
| P_HI = 0.433 | 0.433 | normal form exceeds raw share | INV-029 |

## QUARANTINED (INV-029)

T14, T15, T16, T17, T18 outputs.

## RETIRED (INV-021)

- W1_pop_canon.rds
- S6_population.rds (use S6R_population.rds)

## Investigation Log

### INV-029: Shape unidentified (CLOSED)
K=3 mixture returned duplicate components at the SD floor (k=2 mean 0.190 sd 0.100; k=3 mean 0.213 sd 0.100). Shape is not identified at the canonical signal share of 0.37. No mixture-based P(theta<=0) is reported.

Resolution: P_HI capped at empirical share of non-positive estimates (0.421), which requires no distributional assumption. Normal form at noise-only arm (0.433) exceeds that share and is not used as an endpoint.

### INV-030: theta_D location error (CLOSED)
Cause: theta_D does not exist in data/S6R_population.rds; raw-share computations pointed there were reading a stray W1 copy. Canonical raw share is 0.4211 from S5R_bhat.rds$baseline (n=4182).

Reconciliation with N4: N4 reported 0.421, which matches RAW_SHARE = 0.4211. RECONCILED.

Status: CLOSED.

### INV-032: Wrong-object class instance 7 (CLOSED)
During a provenance fix, the retired pack value 0.2138 was written over the R-chain value 0.2473. Cause: a stray W1 copy carrying the S6R filename was read in place of the committed artifact. The SE moved 0.0235 -> 0.0092, a factor of 2.6, which no re-sourcing of the same 4,182 pairs can produce.

Stray file renamed: data/STRAY_W1_COPY_DO_NOT_USE.rds

Status: CLOSED.

### INV-033: Pseudo-population definition unreconciled (OPEN)
Three pseudo-population counts exist: 5,169 / 4,244 / 3,387. Arm C null variance depends on which definition is used. Non-blocking: SD_true is reported as an interval [0.74, 1.48].

Status: OPEN.
