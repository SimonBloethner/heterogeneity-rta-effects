# PROMPT S34 — Does (A2) hold? Normality of the log gaps

ROLE: Execution agent on Festus (R/4.4.1). One task, fresh session, halt where
instructed.

Supersedes S32 and S33 entirely. Both tested the wrong object: raw trade flows in
levels. The assumption the propositions rest on is stated on the residual, not on
the flow. Do not run either script and do not cite their outputs.

## 1. What is being tested

Assumption (A2), as written in the propositions appendix:

    log eta_ijt = -sigma^2_ij / 2 + u_ijt,   u_ijt ~ iid N(0, sigma^2_ij)

where eta_ijt is observed trade divided by the fitted counterfactual. Proposition
1(a) follows immediately from it, Var(eta) = exp(sigma^2) - 1 comes from it, and
the composite variance in Proposition 3 inherits it. Nothing here concerns the
marginal distribution of trade flows.

Two implications are separately testable, and both are wanted:

- **Normality.** The within-pair log gaps are normal.
- **The Jensen identity.** Per pair, the mean of log eta equals minus half its
  variance. This is (A2)'s location restriction and it is what Proposition 1(a)
  uses. It can hold or fail independently of normality.

## 2. Sample

Untreated cells only, matching the domain on which the counterfactual was fitted:
every year of every never-treated pair, plus every pre-band year of every
switcher. No cell in which an agreement is in force. This is the zero-effect
regime the propositions describe.

Locate the cell-level log gaps in the existing chain rather than recomputing them.
They are produced downstream of `code/S1R_ppml_untreated.R` and
`code/S3R_theta.R`. Report in Round 1 the exact file and column you will use, and
its SHA256. If the cell-level gaps exist only as an intermediate that was never
saved, say so in Round 1 and stop; do not refit the PPML.

Restrict to pairs with at least 8 untreated cells and report how many pairs that
excludes.

## 3. Standardisation and its reference

Within each pair, standardise: z_ijt = (log eta_ijt - mean_i) / sd_i, using that
pair's own mean and standard deviation.

**Do not compare z to a theoretical standard normal.** Within-pair centring and
scaling on short windows deforms the distribution even when the underlying data
are exactly normal, so a theoretical normal is the wrong reference and would
manufacture a rejection.

Instead build a **matched normal control**: for every pair, draw the same number
of observations from a normal, and pass them through the identical
standardisation and identical downstream code. Every statistic below is reported
for the real data and for the control, side by side. The control is the reference.
This is the whole design: nothing is fitted, nothing can fail to converge, and any
deformation introduced by the pipeline appears in both columns and cancels.

## 4. Statistics — all four, real and control

1. **Per-pair rejection rate.** Test each pair's log gaps for normality at the 5
   percent level, using the same test for both panels. Report the fraction of
   pairs rejecting, overall and by year. Under (A2) the real rate should sit near
   the control's rate, which should sit near 0.05. Report the difference with a
   binomial standard error.
2. **Pooled shape.** Skewness and excess kurtosis of pooled z, per year and
   overall, for both panels.
3. **Upper tail.** Quantiles of z at 0.95, 0.99, 0.995 and 0.999, per year and
   overall, for both panels, and the observed-to-control ratio at each. A tail
   deviation confined to the extremes must be visible here rather than averaged
   into the shape statistics.
4. **Jensen identity.** Per pair, compute mean_i(log eta) and var_i(log eta).
   Regress mean_i on var_i across pairs with an intercept. Under (A2) the slope is
   -0.5 and the intercept 0. Report both with standard errors, the R-squared, and
   the number of pairs. Report the same regression on the control, where the
   identity holds by construction only if you impose it — state whether you did.

## 5. Gates — `stopifnot`

- **G1.** The control's per-pair rejection rate lies within 0.02 of 0.05. If it
  does not, the pipeline deforms normal data and no reading of the real panel is
  admissible.
- **G2.** Cell and pair accounting reconciles exactly across both panels: pairs
  used plus pairs excluded equals pairs available, and the same for cells.
- **G3.** Both panels carry identical pair counts and identical per-pair
  observation counts. The control must be matched pair by pair, not in aggregate.

No gate is placed on the real data's own values. Whatever they are, they are the
result.

## 6. Figure

One QQ figure: pooled z for the real panel against the pooled z of the matched
control, with the diagonal drawn, plus an inset restricted to the top one percent
so the extreme tail is legible. Save as `output/F5_a2_normality_qq.pdf` and
`.png`. No annotations interpreting the plot.

## 7. Deliverables

1. `code/S34_a2_normality.R` — one file, seed set once, gates as `stopifnot`.
2. `output/T38_a2_normality.csv` — statistics 1 to 3, long format, one row per
   (panel, year, statistic, grid point).
3. `output/T39_a2_jensen_identity.csv` — statistic 4: per-pair means and
   variances, plus a summary row carrying the regression coefficients.
4. `output/F5_a2_normality_qq.pdf` and `.png`.
5. The SHA256 of every committed file, from bytes on disk.

No sidecars, no registry rows, no ledger rows, no MANIFEST edits.

## 8. Where to write

A fresh clone of `SimonBloethner/heterogeneity-rta-effects`. Commit, push to
`main`, quote the commit SHA. Not `/groups/m-larch/bt307958/REBUILD_V2`, which is
a stale mirror; an earlier run wrote there and nothing reached origin.

## 9. Structure — plan, then halt

**Round 1.** Post your plan and stop. Run nothing. State: the clone path; the file
and column holding the cell-level log gaps, with its SHA256; the untreated-cell
filter as code; the normality test you will use for statistic 1 and why it suits
windows of this length; how you match the control pair by pair; and your
residual-ambiguity list. Then halt.

**Round 2.** On approval, execute once. On error, stop and report it verbatim with
the traceback. No patch rounds.

## 10. Report format — exactly these seven headings

1. `WHAT WAS RUN` — clone path, pushed commit SHA, R version, seed, wall time
2. `SAMPLE` — pairs and cells available, used, excluded, with the reason
3. `GATES` — G1, G2, G3, realised values against thresholds
4. `NORMALITY` — rejection rates real against control with the difference and its
   standard error; pooled skewness and excess kurtosis; both panels
5. `UPPER TAIL` — the four quantiles, both panels, with ratios
6. `JENSEN IDENTITY` — slope, intercept, standard errors, R-squared, n pairs,
   both panels
7. `RESIDUAL AMBIGUITIES` — every one, or the single word `NONE`

State no conclusion about whether (A2) holds. Report the six tables.

## 11. Prohibitions

- Do not compare the real panel to a theoretical normal. The matched control is
  the reference.
- Do not refit the PPML or recompute the counterfactual.
- Do not use treated cells.
- Do not trim, winsorise, or exclude outliers. The tail is the object of interest.
- Do not tune the test, the minimum window length, or the control to change a
  reading.
- Do not report a hash for a file you have not pushed.
- Do not run more than one execution round.
