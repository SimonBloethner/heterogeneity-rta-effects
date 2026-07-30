# PROMPT S33 — The regime question, settled in one round

ROLE: Execution agent on Festus (R/4.4.1). One task, fresh session, halt where
instructed.

This task must not come back empty. It carries two independent instruments, and
the second runs whether or not the first survives calibration.

## 1. Objective

Establish whether the upper tail of the trade distribution is scale-free or
lognormal, using two instruments that fail in different ways, and validate each
against data whose answer is known before applying it to data whose answer is
not.

## 2. Why the previous round did not settle it

S32 reported that the Vuong comparison lacked power. It did not. On the Pareto
control the statistic was positive — favouring lognormal — in 48 of 69 converged
cells, reaching +44.3. A test short of power returns statistics near zero; one
returning +44 on data generated from a Pareto is confidently wrong. Two further
symptoms point the same way: the GPD failed to converge at p90 and p95, where
roughly 2,500 exceedances were available, while converging at p97.5 and p99 where
far fewer were; and the lognormal control "passed" only because a procedure that
always answers lognormal passes a lognormal control by construction.

The leading hypothesis is that the GPD was fitted to raw values rather than to
excesses over the threshold, or with a mismatched threshold argument. That single
defect would produce all three symptoms. Confirm or eliminate it in Stage 0. Do
not assume it.

## 3. Stage 0 — calibration, before anything else runs

This stage uses no real data.

1. Draw 5,000 observations from a Pareto with alpha = 1.5 and a known scale.
   Fit the GPD to the excesses over a threshold at the 50th percentile. The shape
   parameter must return xi = 1/alpha = 0.667. Report the recovered xi and its
   standard error.
2. Repeat at alpha = 1.0, 2.0 and 3.0, so xi = 1.0, 0.5 and 0.333.
3. Draw 5,000 observations from a lognormal with known parameters, left-truncate
   at the 50th percentile, and refit. The fitted parameters must recover the
   generating ones.

**Gate C1.** Every recovered xi lies within 0.05 of its true value, and the
lognormal parameters within 0.05 of theirs.

If C1 fails, the fitter or its inputs are wrong. Report the failure, state
precisely what you passed to the fitter — raw values or excesses, and the
threshold argument — and stop Stage 1. Proceed directly to Stage 2, which does
not depend on any fitter.

## 4. Stage 1 — the likelihood comparison, made auditable

Only if C1 passes. Same cell structure as S32: every year in the panel crossed
with thresholds at p90, p95, p97.5 and p99, on positive bilateral trade flows in
levels from `ITPDE_total.rds`, and on the two synthetic controls.

Fit the lognormal left-truncated at the threshold and the GPD to the excesses
over the same threshold. Both densities must describe the same random variable on
the same support, so that their log-likelihoods are comparable. State in one
sentence in the report how you ensured this.

**Report per cell the two log-likelihoods themselves**, not only the test
statistic. A scalar hides a wrong-footing error; two log-likelihoods side by side
do not. Also report the per-observation mean log-likelihood under each model.

Convergence status is a recorded category with the optimiser's message attached.
Never NA, never dropped, never a substituted fitter.

**Gate C2.** On the Pareto control, the Pareto-type model is selected in at least
90 percent of converged cells. **Gate C3.** On the lognormal control, the
lognormal is selected in at least 90 percent. If either fails, Stage 1 yields no
real-data verdict and Stage 2 becomes the deliverable.

## 5. Stage 2 — the model-free instruments, which run regardless

No fitting, no optimiser, no convergence to fail. Run all of this on the real
data and on both controls, always all three.

**Mean excess.** Over a grid of thresholds spanning the upper tail, compute
e(u) = mean(X - u | X > u). A generalised Pareto tail gives e(u) linear and
increasing in u with positive slope; a lognormal gives e(u) growing sublinearly,
with e(u)/u falling toward zero. Report e(u), e(u)/u, and the fitted slope of
e(u) on u over the top decile, with its standard error.

**Max-to-sum.** For powers p = 1, 2, 3, 4 compute R(p) = max(X^p) / sum(X^p) as
a function of sample size, using the within-year sample. Where the p-th moment is
finite this ratio falls toward zero as n grows; where it is infinite it does not.
Report R(p) at several sample sizes per year.

**Gate C4.** On the Pareto control the mean-excess slope is positive and R(2)
does not fall toward zero. **Gate C5.** On the lognormal control e(u)/u declines
and R(p) falls toward zero for every p. These two gates validate the instruments
in both directions. If they fail, say so — do not report a real-data reading from
an instrument that cannot read the controls.

## 6. What a result looks like

A verdict is the two instruments' readings placed side by side, per threshold
level, never pooled, with the controls' readings beside them. If they agree the
question is settled. If they disagree, say so plainly; that is a finding and not
a failure. State no conclusion in prose — report the tables.

## 7. Deliverables

1. `code/S33_tail_regime_v2.R` — one file, seed set once, gates as `stopifnot`
   except where the prompt directs a stage to continue after a failed gate.
2. `output/T35_fitter_calibration.csv` — Stage 0.
3. `output/T36_tail_comparison.csv` — Stage 1, one row per (panel, year,
   threshold), carrying both log-likelihoods, both mean per-observation
   log-likelihoods, both parameter sets, both convergence statuses, the statistic,
   its p-value and the winner.
4. `output/T37_tail_modelfree.csv` — Stage 2, long format, one row per (panel,
   year, instrument, grid point).
5. The SHA256 of every committed file, from bytes on disk.

No sidecars, no registry rows, no ledger rows, no MANIFEST edits. Provenance is
written outside this task, deliberately, so it has one author.

## 8. Where to write

A fresh clone of `SimonBloethner/heterogeneity-rta-effects`. Commit, push to
`main`, quote the commit SHA. Not `/groups/m-larch/bt307958/REBUILD_V2`, which is
a stale mirror; an earlier run wrote there and nothing reached origin. A file that
is not at origin does not exist.

## 9. Structure — plan, then halt

**Round 1.** Post your plan and stop. Run nothing. State: the clone path; exactly
what you pass to the GPD fitter and its threshold argument, quoted as code; the
Vuong implementation and whether it applies a Schwarz correction; how you make the
two log-likelihoods describe the same variable on the same support; the mean-excess
and max-to-sum grids; and your residual-ambiguity list. Then halt.

**Round 2.** On approval, execute once. On error, stop and report it verbatim with
the traceback. No patch rounds.

## 10. Report format — exactly these seven headings

1. `WHAT WAS RUN` — clone path, pushed commit SHA, R version, seed, wall time
2. `STAGE 0 CALIBRATION` — recovered xi against true xi at each alpha, C1 verdict,
   and what you passed to the fitter
3. `STAGE 1` — C2 and C3 rates with cell counts; if admissible, the real-data tally
   per threshold level; log-likelihood columns confirmed present
4. `STAGE 2` — C4 and C5 verdicts; mean-excess slopes and R(p) behaviour for all
   three panels, per threshold level
5. `THE TWO INSTRUMENTS SIDE BY SIDE` — agreement or disagreement, stated flatly
6. `ARTIFACTS` — each committed file with its SHA256, plus the commit SHA
7. `RESIDUAL AMBIGUITIES` — every one, or the single word `NONE`

## 11. Prohibitions

- Do not tune a fitter, threshold, starting value, or control parameter to change
  a verdict. If a control seems badly chosen, say so and run it as specified.
- Do not write NA for a failed fit.
- Do not pool across threshold levels.
- Do not report a hash for a file you have not pushed, or an artifact that exists
  only in a local or mirror directory.
- Do not state a conclusion about which regime holds.
- Do not skip Stage 2 under any circumstances, including a Stage 0 failure.
- Do not run more than one execution round.
