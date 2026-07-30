# PROMPT S31 — Tail diagnostics: reproduce and promote

ROLE: Execution agent on Festus (R/4.4.1). One task, fresh session, halt where
instructed. This is a reproduction task, not an analysis task. You are not asked
to improve, modernise, or reinterpret anything.

## 1. Objective

Re-run three archived scripts against the trade panel on the cluster and
establish whether their outputs reproduce the archived copies. Commit the
regenerated outputs and their hashes. Nothing else.

## 2. Why this task exists (context, not instruction)

The paper asserts, in two places, that the outcome tails are lognormal-type
rather than Pareto and that the apparent divergence of higher moments is an
estimator artifact. Both assertions point at a section of the article that
contains no tail diagnostics. The evidence exists but sits under
`archive/retired_pack/`, which is frozen and uncitable.

Those diagnostics describe the distribution of trade flows. They do not read the
effect estimates and are not downstream of the estimator that was retired, so
there is reason to expect them to reproduce unchanged. This task tests that
expectation instead of assuming it. If they reproduce, they earn a live producer
and become citable. If they do not, that is the more important finding and it
surfaces now rather than in referee correspondence.

## 3. What you may change, and what you may not

**Permitted, and nothing else:** file paths. The archived scripts read from
`/groups/m-larch/bt307958/tails/data/` and write to `/scratch/bt307958/`, which
is purged. Repoint the write paths into your repository checkout. Repoint a read
path only if the file has moved, and say so.

**Forbidden:** every other line. Do not change an estimator, a threshold rule, a
convergence criterion, a package call, a seed, a filter, or a default. Do not
"fix" anything you believe is wrong — record it under residual ambiguities and
leave it. A path-only edit is what makes the reproduction test meaningful; any
other edit destroys it.

Produce a unified diff of every change you make to every script and include it
verbatim in your report. If the diff contains anything other than path strings,
the task has failed.

## 4. Inputs to locate before running anything

| Input | Expected location | Needed by |
|---|---|---|
| `ITPDE_total.rds` | `/groups/m-larch/bt307958/tails/data/` | X1, X2 |
| `filtered_trade.rds` | unknown — was a `/scratch` intermediate | X3 |
| `X1_results.rds` | produced by X1 in this run | X3 |

Report the resolved path and SHA256 of every input you find. If
`filtered_trade.rds` cannot be located, X3 is deferred to a later task: run X1
and X2, report the absence, and do not reconstruct the file.

## 5. Scripts and order

All three are under `archive/retired_pack/code/`. Copy them to a scratch working
directory; do not edit them in place under `archive/`.

1. `X1_corrected_LN_anchor_v2.R` — produces the per-year anchor table
2. `X2_residual_tail_v5.R` — produces the residual tail counts
3. `X3_peryear_ratio.R` — depends on X1's output; run only if its second input exists

## 6. The reproduction gate

For each regenerated output, compare against its archived counterpart under
`archive/retired_pack/output/`:

| Regenerated | Archived counterpart |
|---|---|
| anchor table | `A0_anchor_table.csv` (32 rows) |
| residual tails | `A2_residual_tails.csv` |
| per-year ratio | `A3_kappa_convergence.csv` |

Report, per file: whether the SHA256 matches; if not, the maximum absolute
difference and the maximum relative difference over every numeric cell, and the
row and column where each maximum occurs. Do not declare a tolerance and do not
judge whether a difference is acceptable. Report the numbers; the decision is not
yours.

One cell is worth checking explicitly and quoting in the report: the 2019 row of
the anchor table. The archived copy has an expected-value column at 7011.25 and a
ratio column at 1.0582. State the regenerated values of both.

## 7. Out of scope

- Do not write sidecars, registry rows, ledger rows, or MANIFEST entries. Those
  are handled outside this task, from the hashes you report.
- Do not touch `article/`.
- Do not modify anything under `archive/`. Read from it; write nowhere near it.
- Do not run the fourth archived script or any other pack script.
- Do not change the Vuong comparison to operate per year-threshold cell. That is
  a separate task and it depends on the outcome of this one.

## 8. Deliverables

1. Three regenerated outputs (two if X3 is deferred), committed to
   `output/` under the names `T30_tail_anchor.csv`, `T31_residual_tails.csv`,
   and `T32_peryear_ratio.csv`.
2. The three edited scripts, committed to `code/` as `S31a_tail_anchor.R`,
   `S31b_residual_tails.R`, `S31c_peryear_ratio.R`.
3. The SHA256 of every file you commit, computed from the bytes on disk.
4. The unified diff of every script edit.

No other files. In particular, do not append to `meta/FILE_REGISTRY.csv` or
`meta/canonical_facts.md`; those are written from your report by the drafting
side, deliberately, so that the provenance record has a single author.

## 9. Structure — plan, then halt

**Round 1.** Post your plan and stop. Run nothing. The plan states: the
repository checkout path on the cluster; the resolved path and SHA256 of each
input; whether `filtered_trade.rds` was found and therefore whether X3 is in or
out; the exact path edits you intend, quoted as before-and-after strings; and
your residual-ambiguity list. Then halt and wait for approval.

**Round 2.** On approval, execute once and deliver the report. One execution, no
patch rounds. If a script errors, stop, report the error verbatim with the
traceback, and do not attempt a fix.

## 10. Report format — exactly these seven headings

1. `WHAT WAS RUN` — checkout path, R version, scripts in order, wall time
2. `SCRIPT DIFFS` — unified diff per script, verbatim
3. `INPUTS` — each input, resolved path, SHA256
4. `REPRODUCTION` — per output: SHA256 match yes or no; if no, max absolute and
   max relative difference with their locations; plus the two 2019 values
5. `ARTIFACTS` — each committed file with its SHA256 from disk
6. `WHAT YOU NOTICED AND DID NOT FIX` — anything in these scripts that looks
   wrong to you, stated plainly and left alone
7. `RESIDUAL AMBIGUITIES` — every one, or the single word `NONE`

Heading 6 is not optional and `NONE` there is unlikely to be true. Three things
are already suspected: one output carries a column explicitly labelled as a
retired-estimator reference; the Vuong table reports three aggregate rows rather
than per-cell results; and the convergence table's pair count rises with window
length where it should fall. Say whether you see these and whatever else you see.

## 11. Prohibitions

- Do not fabricate a SHA256. Compute each from file bytes after writing.
- Do not mark a deliverable done without executing it.
- Do not silently drop a deliverable; say so under heading 7.
- Do not edit any script line that is not a path.
- Do not write into `archive/`.
- Do not decide whether a numerical difference is acceptable.
- Do not run more than one execution round.
