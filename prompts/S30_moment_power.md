# PROMPT S30 — Pooled higher-moment separation: power calculation

ROLE: Execution agent on Festus (R/4.4.1, data.table). You run one task, in a
fresh session, and you halt where instructed. You do not write prose for the
article and you do not decide what the result means.

## 1. Objective

Measure the power of a pooled higher-moment test to distinguish the two
parameterizations that Proposition 3(b) proves observationally equivalent under
normality, at this paper's pair count and window lengths, when the multiplicative
shock is non-normal. Report the power as measured. Do not tune the design toward
any conclusion.

## 2. Why this task exists (context, not instruction)

The propositions appendix currently argues that separation through third- and
higher-order within-pair moments is out of reach, citing the sampling noise of
per-pair sample excess kurtosis, approximately sqrt(24/T) ~ 1.5 at T_post ~ 10.
That instrument is wrong in two ways. The statistic that would actually be used
pools across all pairs, so its standard error falls by sqrt(n). And sqrt(24/T) is
the normal-theory expression, invoked to argue about a departure from normality,
where the variance of sample kurtosis is governed by eighth moments instead.

The appendix claim is therefore to be replaced by a measurement. Your output
decides which way the sentence goes. Both outcomes are acceptable results.

## 3. Model (transcribed from article/main.tex, Proposition \label{prop:ident})

Pre-window gaps:   g_ijt = sigma_ij * u_ijt
Post-window gaps:  g_ijt = theta_ij + nu_ijt + sigma_ij * rho * u_ijt

with u_ijt i.i.d. mean 0 variance 1, nu_ijt i.i.d. N(0, omega^2) independent of
u, persistent effects theta_ij, and post/pre volatility ratio rho >= 0. The post
variance is the composite sigma_ij^2 * rho^2 + omega^2.

Two worlds, with the composite matched pair by pair:

- World T (transitory effect variation): rho = 1, omega^2 = w > 0
- World V (volatility change): omega^2 = 0, rho_ij^2 = (sigma_ij^2 + w) / sigma_ij^2

Both give post variance sigma_ij^2 + w for every pair. theta_ij is a per-pair
constant and is differenced out by the statistic; draw it however you like and
state what you drew.

## 4. Calibration — read, do not hardcode

Every constant below is read at run time from a committed artifact. A hardcoded
value is a failed task even if it is numerically correct.

| Quantity | Source | How |
|---|---|---|
| n pairs | meta/canonical_facts.md | ID `N` |
| E[sigma^2] | meta/canonical_facts.md | ID `ESIGMA2` |
| Var(sigma^2) | meta/canonical_facts.md | ID `VAR_SIGMA2` |
| per-pair T_post | output/T22_theta_A_treated.csv | the empirical per-pair post-cell count |

Use the empirical distribution of T_post across pairs, not its mean. 1/T is
convex and the reciprocal of the mean understates the mean of the reciprocals;
this is the same defect that produced Arm 0 and required Arm 1' (see the V1c
notes in the ledger). If T22_theta_A_treated.csv does not carry a per-pair post
count under any column name, stop and report that in your Round 1 plan rather
than substituting the mean.

Draw sigma_ij^2 from a distribution matched to E[sigma^2] and Var(sigma^2) as
read above. State the family you chose and why in the sidecar specification
block.

## 5. Design grid

- Excess kurtosis of u: kappa_u in {0, 0.75, 1.0, 1.5, 3.0}. Use a standardized
  Student t with df = 4 + 6/kappa_u for the non-zero cells, and a Gaussian for
  kappa_u = 0.
- Transitory share: w / E[sigma^2] in {0.10, 0.25, 0.50, 1.00}
- Replications: at least 400 per cell, raised as gate G4 requires
- Seed: 20260719, set once at the top of the script

## 6. Statistic

The pooled mean, across pairs, of the per-pair sample excess kurtosis of the
post-window gaps, computed with the identical estimator in both worlds. For each
cell report:

- `delta` = E[stat | World V] - E[stat | World T]
- `mc_se` = the Monte Carlo standard error of `delta`
- `z` = |delta| / mc_se

## 7. Gates — stopifnot, halting, not printed

- **G1 (the decisive one).** At kappa_u = 0, |delta| < 3 * mc_se. Proposition
  3(b)'s exact non-identification must reproduce under normality. If G1 fails the
  harness is wrong; report the failure and report nothing else as a result.
- **G2.** Composite match, checked analytically per pair, not by simulation:
  max_ij |Var_post(World V) - Var_post(World T)| < 1e-10.
- **G3.** z is non-decreasing in kappa_u at fixed w, and non-decreasing in w at
  fixed kappa_u. Record any violation in the output table; do not smooth, reorder,
  or re-seed to remove it.
- **G4.** mc_se < 0.10 * |delta| in every cell with kappa_u > 0. If a cell fails,
  raise replications for that cell and record the raised count.

## 8. Also required

Design-effect sensitivity. Report z at effective sample sizes n, n/10 and n/50,
using the fact that z scales as 1/sqrt(inflation). State in the sidecar that these
are assumed inflations and that cross-pair dependence has never been estimated in
this repository, so no design effect is measured here.

## 9. Out of scope — do not do these

- Any simulation of the equivalence itself. Proposition 3(b) proves the two data
  distributions identical; a Kolmogorov-Smirnov test on them would be redundant
  and its p-value uniform by construction. Do not write one.
- Any edit to article/main.tex or article/prop_constants.tex.
- Any modification of an existing ledger row, registry row, or sidecar.
- Any GE, policy, or trade-weighted quantity.
- Any read from archive/. Nothing under that path is citable; see INV-039.

## 10. Deliverables and reproduction discipline

All six, or the task is incomplete. The point of this section is that nobody
should ever have to search for the producer of a number again.

1. **`code/S30_moment_power.R`** — a single file. Header block carrying
   `EXPECTED_N:` whose value is *derived from the loaded data*, not written by
   hand. Seed set once. Every gate a `stopifnot()`, never a `cat()`.

2. **`output/T29_moment_power.csv`** — one row per (kappa_u, w) cell. Columns,
   in this order: `kappa_u`, `w_over_Esigma2`, `delta`, `mc_se`, `z`,
   `z_deff10`, `z_deff50`, `reps`, `n_pairs`, `G3_violation`, `G4_pass`.

3. **`meta/T29_moment_power.csv.sidecar`** — exactly the format of
   `meta/T28b_v1c_arm1p.csv.sidecar`. Read that file first and match it:
   `FILE:` / `SHA256:` / `PRODUCER:` / `INPUTS:` with each input path followed by
   its own SHA256 / `SEED:`, then a specification block, then a `GATES:` block
   giving each gate's realized value against its threshold and PASS, then
   `CREATED:`. Write `PRODUCER: code/S30_moment_power.R` with the leading
   `code/`. Thirteen sidecars in this tree omit that prefix and broke enforce.R
   check (b); do not add a fourteenth.

4. **Registry rows** appended to `meta/FILE_REGISTRY.csv` for all four new files:
   `code/S30_moment_power.R`, `output/T29_moment_power.csv`,
   `meta/T29_moment_power.csv.sidecar`, and `prompts/S30_moment_power.md` (this
   prompt). Column order is
   `file_path,kind,producer_script,inputs,seed,gate,stage,status`; line endings
   are CRLF, matching the existing file. Status `BUILT` for all four.

5. **Ledger rows** appended to `meta/canonical_facts.md` under a new section
   `## Higher-Moment Separation (S30)`, with these IDs and no others:
   `MOMPOW_KAPPA0_DELTA`, `MOMPOW_KAPPA1_W50_Z`, `MOMPOW_MAX_Z`,
   `MOMPOW_DEFF50_MAX_Z`. Each row's Producer column reads exactly
   `code/S30_moment_power.R -> output/T29_moment_power.csv`. Append only; touch
   no existing row.

6. **Producer consistency assertion.** Before you finish, assert that the
   producer string for T29 is byte-identical in all three places it appears: the
   ledger Producer column, the sidecar `PRODUCER:` field, and the registry
   `producer_script` column. This repository already contains one disagreement of
   exactly this kind — `meta/T1R_spec_spread.csv.sidecar` names
   `code/S10R_exhibits.R` while the ledger names `code/S9R_spec_spread.R`. Do not
   create a second. If you notice further pre-existing disagreements, list them in
   your report and do not fix them.

## 11. Structure — plan, then halt

**Round 1.** Post your plan and stop. Do not execute anything. The plan states:
the four file paths; the sigma^2 family you will draw from and why; the column
name in T22_theta_A_treated.csv you will use for per-pair T_post; the grid; each
gate with its numeric threshold; the four ledger IDs; and your residual-ambiguity
list. Then halt and wait.

**Round 2.** On explicit approval, execute once and deliver the report. One
execution. No patch rounds.

## 12. Report format — exactly these eight headings

1. `WHAT WAS RUN` — script path, R version, seed, reps, grid, wall time
2. `RESULTS` — the T29 table as the script printed it, not reformatted
3. `GATES` — each gate, realized value, threshold, PASS or FAIL
4. `ARTIFACTS` — each file created, its SHA256 computed from the bytes on disk,
   and the SHA256 written into the sidecar, with the equality asserted
5. `REGISTRY AND LEDGER` — the exact lines appended, quoted verbatim
6. `PRODUCER CONSISTENCY` — the three producer strings quoted, and the result of
   the assertion in item 10.6
7. `WHAT THIS DOES NOT SHOW` — one paragraph, your own words
8. `RESIDUAL AMBIGUITIES` — every one, or the single word `NONE`

## 13. Prohibitions

- Do not fabricate a SHA256. Compute each one from the file bytes after writing.
- Do not mark an item done without executing it.
- Do not silently drop a deliverable. If you cannot complete one, say so under
  heading 8.
- Do not modify an existing ledger row, registry row, or sidecar.
- Do not read from `archive/`.
- Do not run multiple patch rounds. One execution.
- Where `meta/canonical_facts.md` and anything in `output/` disagree, the ledger
  governs. Report the disagreement; do not resolve it.
