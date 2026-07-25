# SUPERSEDED Files Registry

Generated: 2026-07-25
Pipeline: REBUILD_V2 (manifest-first rebuild + PATCH)

Files marked SUPERSEDED are retained per R9 for audit trail but should not be used
for analysis. Each entry documents what was wrong and what supersedes it.

## Superseded Exhibits

### T5_theta_summary.csv
- **Superseded by:** T5b_theta_summary.csv
- **Producer:** code/S10_exhibits.R
- **Issue:** Used n=4,875 population instead of BASELINE n=4,639 (anticipation exclusion not applied)
- **Date superseded:** 2026-07-25
- **Stage:** 7 → 8

### T3_size_gradient.csv
- **Superseded by:** T3b_size_gradient_fixed.csv
- **Producer:** code/S10_exhibits.R
- **Issue:** Used fake quintiles created by `ceiling(size_decile/2)` which produced bins of 34, 284, 844, 1406, 2071 instead of equal bins
- **Date superseded:** 2026-07-25
- **Stage:** 7 → 8

### T6_matching_sensitivity.csv
- **Superseded by:** T6b_matching_sensitivity.csv
- **Producer:** code/S13_matching_sensitivity.R
- **Issue:** Used same wrong quintile construction as T3. Quintiles were not equal bins within BASELINE.
- **Gate verification failed:** Did not reproduce T3b (which uses correct quintiles)
- **Date superseded:** 2026-07-25
- **Stage:** 8

## Sidecar Files

The following sidecar files correspond to superseded exhibits:
- meta/T5_theta_summary.csv.sidecar
- meta/T3_size_gradient.csv.sidecar
- meta/T6_matching_sensitivity.csv.sidecar

## Impact Assessment

The superseded files affected:
1. **Mean θ_D calculation:** Wrong population size (P1 fix)
2. **Size gradient direction:** Appeared reversed due to fake quintiles (P2 fix)
3. **Matching sensitivity:** Inherited wrong quintiles (F2 fix)

All corrected versions (T5b, T3b, T6b) have passed their respective gates.
