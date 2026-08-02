# Replication Package: Heterogeneity in RTA Trade Effects

## Overview

Code and data for the estimation of heterogeneous regional trade agreement
effects across country pairs. The live pipeline is the R-chain (`S*`, `N*`,
`V*` scripts). An earlier exhibit pack was retired under INV-021 and is
preserved unmodified under `archive/retired_pack/` for referee verification;
nothing in it should be cited.

## Directory Structure

| Path | Contents |
|------|----------|
| `code/` | R scripts, live pipeline |
| `code/validation/` | V1-V4 validation scripts |
| `data/` | Input and intermediate `.rds` artifacts |
| `output/` | Committed tables (T*) |
| `meta/` | Sidecars, `FILE_REGISTRY.csv`, `canonical_facts.md`, `SUPERSEDED.md` |
| `article/` | LaTeX source, bibliography, generated constants |
| `audit/` | Scripts and outputs under review, not cited |
| `archive/retired_pack/` | Retired exhibit pack (INV-021), frozen |
| `archive/retired_2026-07-29/` | Files outside the paper's dependency closure |

`meta/canonical_facts.md` is the **sole authority** for every reported number.
Where it disagrees with anything in `output/`, the ledger governs and the
disagreement is logged in its Investigation Log.

## Pipeline

Stage 1 -- counterfactual and pair-level effects

```bash
Rscript code/S1R_ppml_untreated.R    # PPML fit on untreated cells only
Rscript code/S3R_theta.R             # pair-level log gaps
Rscript code/S4_placebo.R            # never-treated pseudo-adoption set
Rscript code/S5R_bhat_split.R        # 50/50 placebo split, b_hat, theta_D
Rscript code/S6R_population.R        # canonical population, n = 4182
```

Stage 2 -- nulls, arms, and the identified set

```bash
Rscript code/N1_oos_null.R           # out-of-sample noise null (Arm A)
Rscript code/N2_placebo_benchmark.R  # in-sample placebo null (Arm B)
Rscript code/S18_null_stack.R        # in-sample pseudo null, NOT Arm C
Rscript code/S24_arms_canonical.R    # Arm C and TW_MEAN -> T21_arms.csv
Rscript code/S22_ladder_closed_form.R # P(theta <= 0) bracket -> T19
Rscript code/S23_ge_bracket.R        # GE propagation by arm -> T20
```

Stage 3 -- distribution, gradient, reliability

```bash
Rscript code/N4_distribution.R       # effect distribution and size quintiles
Rscript code/S28_gradient_B.R        # Definition-B gradient -> T27
Rscript code/S24_reliability.R       # split-half, per-pair theta_A -> T22
Rscript code/S24b_anchor_table.R     # anchor table -> T23
Rscript code/S25_placebo_uncorrected.R # uncorrected placebo -> T24
Rscript code/S9R_spec_spread.R       # specification spread -> T1R
```

Stage 4 -- proposition verification

```bash
Rscript code/S29_v1c_pairlevel.R     # pair-level V1c arms -> T28 (diagnostic)
Rscript code/S29b_v1c_arm1p.R        # Arm 1' (canonical V1c) -> T28b
Rscript code/S26_prop_verification.R # T25 + article/prop_constants.tex
```

Stage 5 -- enforcement

```bash
Rscript code/enforce.R
```

`enforce.R` halts on any violation. **The pass condition is zero.** There is no
expected-violation list; an earlier version of this file published one that had
never been measured against the repository (see INV-038). All ten checks carry a
known-pass and known-fail fixture and provably discriminate. As last measured at
commit `b2d0edf`, 2 violations remain under check (f): appendix numeric literals
on main.tex lines 2017 and 2021 without resolving ledger IDs. The pass condition
is unmet. That figure is a measured residual and not a tolerated exception; it is
recorded identically in `MANIFEST.txt`, and both statements are removed together
once the count reaches zero.

Check coverage has its own open gap. `archive/retired_pack/` is absent from
`meta/FILE_REGISTRY.csv`, and check (d) builds its forbidden-input set from
registry rows, so nothing in that directory is currently forbidden as a
dependency even though this file states it must not be cited. See INV-039 in
`meta/canonical_facts.md`, and CAV-005 in `meta/SUPERSEDED.md` for the related
register-hygiene items.

## Validation Gates

Current values. All are ledgered in `meta/canonical_facts.md`; cite the
ledger, not this table.

| Gate | Criterion | Expected |
|------|-----------|----------|
| Population | n pairs | 4182 |
| Anchor | mean(theta_D) | 0.2473 +/- 0.002 (SE 0.0241) |
| Anchor | SD(theta_D), observed | 1.5614 +/- 0.005 |
| Anchor | SD(theta_true), identified set | [0.74, 1.48] |
| Anchor | share theta_D <= 0 | 0.4211 |
| Anchor | trade-weighted mean (pre_trade) | 0.0898 |
| Bracket | P(theta_true <= 0) | [0.370, 0.421] |
| Spec | published four | [1.402, 0.922, 0.411, 0.095] +/- 0.005 |
| Gradient | Q1 - Q5, Definition D | 0.9137 +/- 0.08 |
| Gradient | Q1 - Q5, Definition B | 0.6827 +/- 0.09 |
| Reliability | split-half r, treated vs placebo | 0.9243 vs 0.7463 |
| V1c | \|R_GAP\| for Arm 1' | < 0.05 (realized 0.0076) |

The gradient profile is not monotone: Q4 lies below Q5 and the difference is
not significant. See the shape note in the ledger's Gradient section before
writing about it.

The retired gate table previously published here (mean 0.2138, SD 0.5950,
naive mean -0.52) was a chimera with no R-chain provenance; see INV-010 in
`meta/SUPERSEDED.md`.

## Requirements

- R >= 4.4.0 (tested with R 4.4.1)
- `data.table`, `fixest` (0.13.2+), `dplyr`, `MASS`
- Heavy stages are written for SLURM compute nodes; several scripts assert
  they are not running on a login node.

## Verification

Every committed artifact carries a sidecar in `meta/` recording its producer,
inputs, seed, gates, and SHA256, and a row in `meta/FILE_REGISTRY.csv` with one
of three statuses: `BUILT` (live and citable as a source), `ANCHOR` (live
dependency, not citable), `ARCHIVED` (dead, moved under `archive/`). Registry
coverage is not yet complete; see INV-039.

```bash
Rscript code/enforce.R
```

## Contact

For questions about this replication package, contact the authors.
