# PROMPT S35 — Is the Jensen slope real, or a skew artifact?

ROLE: Execution agent on Festus (R/4.4.1). One task, fresh session, halt where
instructed.

This is the last task in this thread. It answers one question and adds nothing
else.

## 1. The question

S34 regressed each pair's mean of log eta on its variance of log eta and found a
slope of -0.1966 (SE 0.0010) with intercept -0.2201 (SE 0.0052), where (A2)
predicts slope -0.5 and intercept 0.

Two explanations are consistent with that and they have opposite consequences.

- **The identity fails.** The location restriction E[log eta] = -Var(log eta)/2
  does not hold in these data. The ledger derives ESIGMA2 = 1.3642 as minus twice
  the placebo mean, which uses this identity, so the derivation would need
  qualifying.
- **The estimator attenuates.** The identity holds, but the slope is dragged
  toward zero by two mechanisms that operate even when (A2) is exactly true.
  First, var_i is estimated on roughly twenty cells and enters as a noisy
  regressor. Second, and specific to non-normal gaps: mean_i and var_i are
  computed from the same cells, so under left skew a pair drawing a large negative
  outlier gets both a lower mean and a higher variance, inducing a negative
  correlation between the two that is mechanical rather than structural.

S34's normal control cannot separate these, because it has neither the skew nor
the imposed identity.

## 2. Design — one addition, nothing else

Add a third control panel to the S34 pipeline. Everything upstream and downstream
stays exactly as it is. Do not change the sample, the filters, the
standardisation, the existing controls, or any existing statistic.

**Control C (skewed, identity imposed).** For each pair used in S34, matched pair
by pair with identical observation counts:

1. Take that pair's realised variance of log eta from S34, call it v_i. Read it
   from `output/T39_a2_jensen_identity.csv`; do not recompute it.
2. Draw that pair's observations from a distribution with variance v_i, mean
   exactly -v_i/2, and shape matched to the real pooled data: skewness -0.4755 and
   excess kurtosis 0.7840 as measured in S34. A skew-normal or a shifted
   log-normal will do; state which you used and report the realised skewness and
   excess kurtosis of the pooled control so the match can be checked.
3. The identity therefore holds in this panel **by construction, exactly**.

Run the identical regression of mean_i on var_i, with both computed from the
drawn data exactly as they are computed for the real panel — not from the
generating parameters. That symmetry is the whole point of the control.

## 3. How to read it

The control's realised slope is the answer, and you report it without
interpretation:

- A slope near -0.5 means the pipeline recovers a true identity from skewed data.
  The real panel's -0.20 is then a genuine departure.
- A slope near -0.20 means the pipeline returns roughly the real panel's value
  even when the identity holds exactly. The real slope is then uninformative about
  whether the identity holds.
- Anything between is reported as it falls. Do not round toward either reading.

## 4. Also report

For each of the three panels — real, S34's normal control, and Control C — the
correlation between mean_i and var_i, and the reliability of var_i as a regressor,
estimated by splitting each pair's cells into two halves and correlating the two
half-sample variances. This quantifies the attenuation channel directly and is
reported whatever the slope turns out to be.

## 5. Gates — `stopifnot`

- **G1.** Control C's pooled skewness is within 0.10 of -0.4755 and its pooled
  excess kurtosis within 0.15 of 0.7840. If the shape is not matched the control
  does not test what it claims to.
- **G2.** Control C's imposed means satisfy max_i |mean_generating_i + v_i/2| <
  1e-10. The identity must hold exactly in the generating parameters, whatever the
  realised sample means turn out to be.
- **G3.** Pair counts and per-pair observation counts are identical across all
  three panels.
- **G4.** The real panel's slope and intercept reproduce S34 exactly: slope
  -0.1966, intercept -0.2201, to four decimals. If they do not, the pipeline has
  changed and the comparison is void.

No gate is placed on Control C's realised slope. That value is the result.

## 6. Deliverables

1. `code/S35_jensen_control.R` — one file, seed set once, gates as `stopifnot`.
   It may source or copy from `code/S34_a2_normality.R`; if it copies, say so and
   say what changed.
2. `output/T40_jensen_control.csv` — one row per (panel, statistic): slope,
   intercept, their standard errors, R-squared, n pairs, correlation of mean_i
   with var_i, and reliability of var_i, for all three panels.
3. `output/F5_a2_normality_qq.png` — the PNG S34 could not produce. Use
   `ragg::agg_png()` or `png(type = "cairo")`; if neither is available on the
   node, convert the existing PDF with `pdftoppm` and say so. This is the only
   item in this task unrelated to the question above.
4. The SHA256 of every committed file, from bytes on disk.

No sidecars, no registry rows, no ledger rows, no MANIFEST edits.

## 7. Where to write

A fresh clone of `SimonBloethner/heterogeneity-rta-effects`. Commit, push to
`main`, quote the commit SHA. Not `/groups/m-larch/bt307958/REBUILD_V2`.

## 8. Structure — plan, then halt

**Round 1.** Post your plan and stop. Run nothing. State: the clone path; the
distribution family for Control C and how you will hit both target moments
simultaneously; how you impose the identity exactly; how you match pair by pair;
the split-half rule for the reliability of var_i; and your residual-ambiguity
list. Then halt.

**Round 2.** On approval, execute once. On error, stop and report it verbatim with
the traceback. No patch rounds.

## 9. Report format — exactly these six headings

1. `WHAT WAS RUN` — clone path, pushed commit SHA, R version, seed, wall time
2. `GATES` — G1 to G4, realised values against thresholds
3. `THE THREE SLOPES` — slope, intercept, SEs, R-squared, n, for real, normal
   control, and Control C, in one table
4. `ATTENUATION` — correlation of mean_i with var_i, and reliability of var_i, for
   all three panels
5. `ARTIFACTS` — each committed file with its SHA256, plus the commit SHA
6. `RESIDUAL AMBIGUITIES` — every one, or the single word `NONE`

State no conclusion about whether the identity holds. Report the table.

## 10. Prohibitions

- Do not change the S34 sample, filters, standardisation, or existing statistics.
- Do not compute Control C's mean_i or var_i from generating parameters; compute
  them from the drawn data, exactly as for the real panel.
- Do not tune the shape match, the distribution family, or the seed to move
  Control C's slope.
- Do not re-examine normality, the upper tail, or anything else settled by S34.
- Do not report a hash for a file you have not pushed.
- Do not run more than one execution round.
