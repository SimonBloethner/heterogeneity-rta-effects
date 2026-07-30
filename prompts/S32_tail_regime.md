# PROMPT S32 — Scale-free or lognormal: the comparative tail test

ROLE: Execution agent on Festus (R/4.4.1). One task, fresh session, halt where
instructed.

Supersedes the tail portion of S31. S31a and S31c are withdrawn: the anchor-table
and per-year-ratio machinery belongs to a superseded version of the article and is
not wanted, reproducing or not. Do not run them and do not promote their outputs.

## 1. Objective

Determine whether the right tail of the trade distribution is better described by
a scale-free law or by a lognormal, year by year and threshold by threshold, and
establish whether the procedure that answers this question can be trusted to
answer it. Both halves are required. A verdict from an unvalidated procedure is
not a result.

## 2. Object of study

Bilateral trade flows from `ITPDE_total.rds`, in levels, positive values only.
One set of exceedances per (year, threshold) cell. Do not use residuals, do not
use effect estimates, and do not use any object downstream of a PPML fit. If you
believe residuals would be more informative, say so under residual ambiguities
and run flows anyway.

## 3. Cells

Every year present in the panel, crossed with four thresholds set as within-year
quantiles of positive flows: p90, p95, p97.5, p99. Report the realised threshold
value and the exceedance count for every cell. Cells with fewer than 50
exceedances are computed and reported but flagged `THIN`; do not drop them.

## 4. The comparison

For each cell, fit two models to the exceedances:

- **Lognormal**, by maximum likelihood, left-truncated at the threshold.
- **Generalised Pareto**, by maximum likelihood on the excesses over the
  threshold.

Both are fitted to the same exceedance set over the same support, so the
likelihoods are comparable. Compare them with a Vuong test for non-nested models.

Report per cell: the threshold, the exceedance count, both models' parameters,
the Vuong statistic, its two-sided p-value, the selected model, and a convergence
status for each fit.

**Convergence is a result, not a nuisance.** If a fit fails, record the status and
the optimiser's message. Never write NA and move on, never silently drop a cell,
and never substitute a different fitter to make a cell succeed. If GPD fails to
converge at the strictest thresholds this is itself reportable and may be
informative; that is for the reader to weigh, not for you to repair. State which
optimiser and starting values you used, once, and use the same ones everywhere.

## 5. Validation — the part that makes the verdict admissible

Run the identical pipeline, unchanged, on two synthetic panels:

- **Lognormal control.** For each real cell, simulate the same number of draws
  from a lognormal with the parameters fitted to that cell. The pipeline must
  select lognormal.
- **Pareto control.** For each real cell, simulate the same number of draws from
  a Pareto with a tail index in a stated plausible range. The pipeline must
  select the Pareto-type model.

A procedure that cannot recover a known answer cannot deliver an unknown one, and
a procedure that only ever says "lognormal" is not evidence of lognormality.

## 6. Gates — `stopifnot`, halting

- **G1.** On the lognormal control, lognormal is selected in at least 90 percent
  of converged cells.
- **G2.** On the Pareto control, the Pareto-type model is selected in at least 90
  percent of converged cells.
- **G3.** Cell accounting reconciles exactly: converged plus failed plus thin
  equals total cells attempted, in each of the three panels.
- **G4.** The real-data tally is reported separately for each threshold level, not
  pooled across thresholds.

If G1 or G2 fails, report the failure and report no real-data verdict. The
procedure is then the finding.

## 7. The Hill demonstration

Separately, for each year: compute the Hill estimator on the real exceedances
across a range of order statistics k, and compute it on the matched lognormal
control from section 5. Report both curves.

The claim this addresses is that a tail-index estimator run on lognormal data
returns a finite, apparently scale-free index that drifts systematically with k.
Report the numbers that would show this or fail to show it. Draw no conclusion.

## 8. Out of scope

- Do not write sidecars, registry rows, ledger rows, or MANIFEST entries.
- Do not touch `article/`.
- Do not modify anything under `archive/`. You may read
  `archive/retired_pack/code/X2_residual_tail_v5.R` for method — its GPD fitting,
  Vuong and Hill routines — but write fresh code and do not inherit its
  convergence handling, which returned NA verdicts.
- Do not reuse or cite any archived output. In particular `A1_vuong.csv` reports
  four aggregate rows and is not the per-cell object this task produces.
- Do not run S31a, S31b or S31c.

## 9. Deliverables

1. `code/S32_tail_regime.R` — one file, seed set once, gates as `stopifnot`.
2. `output/T33_tail_verdicts.csv` — one row per (panel, year, threshold), where
   panel is `real`, `control_lognormal`, or `control_pareto`.
3. `output/T34_hill_curves.csv` — one row per (year, k, source), source being
   `real` or `control_lognormal`.
4. The SHA256 of every committed file, computed from bytes on disk.

Nothing else. Provenance records are written outside this task.

## 10. Where to write

**Commit to the repository and push.** The S31 run wrote into
`/groups/m-larch/bt307958/REBUILD_V2`, which is a stale partial mirror, not a
clone of the repository; nothing from that run reached origin. Work in a fresh
clone of `SimonBloethner/heterogeneity-rta-effects`, commit there, push to `main`,
and quote the resulting commit SHA in your report. A file that is not at origin
does not exist.

## 11. Structure — plan, then halt

**Round 1.** Post your plan and stop. Run nothing. State: the clone path; the
fitters and optimiser with starting values; the Vuong implementation you will use
and whether it applies a Schwarz correction; the Pareto control's tail-index
range and why; the year coverage and cell count; and your residual-ambiguity list.
Then halt.

**Round 2.** On approval, execute once. If a script errors, stop and report the
error verbatim with the traceback. No patch rounds.

## 12. Report format — exactly these seven headings

1. `WHAT WAS RUN` — clone path, commit SHA pushed, R version, seed, wall time
2. `VALIDATION` — G1 and G2 realised selection rates, with cell counts
3. `REAL-DATA VERDICT` — the tally per threshold level: cells selecting lognormal,
   cells selecting Pareto-type, cells failed, cells thin
4. `CONVERGENCE` — failures by model, threshold and year, with optimiser messages
5. `HILL` — the two curves summarised, real against lognormal control
6. `ARTIFACTS` — each committed file with its SHA256 from disk, and the commit SHA
7. `RESIDUAL AMBIGUITIES` — every one, or the single word `NONE`

## 13. Prohibitions

- Do not fabricate a SHA256, and do not report a hash for a file you have not
  pushed.
- Do not report an artifact as delivered when it exists only in a local or mirror
  directory.
- Do not write NA for a failed fit; write the status.
- Do not tune a fitter, threshold, or starting value to change a verdict.
- Do not pool across thresholds when reporting the tally.
- Do not state a conclusion about which regime holds. Report the tally.
- Do not run more than one execution round.
