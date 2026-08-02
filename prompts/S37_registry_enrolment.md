# PROMPT S37 — Registry enrolment and two vocabulary fixes

ROLE: Execution agent. Fresh session. Mechanical task, no analysis, no cluster.
Execute in one pass; there is no plan-then-halt round.

Every command below has been validated against the current file. Run them as
written. Do not improvise, reorder, or "improve" any of them.

## 1. What this task does

`meta/FILE_REGISTRY.csv` is missing rows for everything produced by tasks S31
through S36. It also carries two defects: one invented `kind` value, and two
exactly duplicated rows. This task fixes all three. Nothing else in the
repository is touched.

## 2. Setup

Fresh clone of `SimonBloethner/heterogeneity-rta-effects`, working from the
repository root. Not `/groups/m-larch/bt307958/REBUILD_V2`, which is a stale
mirror.

Before changing anything, record and report:

    wc -l meta/FILE_REGISTRY.csv
    md5sum meta/FILE_REGISTRY.csv
    sed -n '132,135p' meta/FILE_REGISTRY.csv

The expected starting state is 257 lines. Lines 133 and 135 must be exact
duplicates of 132 and 134 respectively. **If the line count differs, or if lines
133 and 135 are not duplicates, STOP.** Report what you found and make no
changes. A mismatch means the file has drifted from the state these commands
were written against, and the line-number deletion in step 4 would then remove
the wrong rows.

## 3. Step one — correct the invented `kind` value

The row for the T29 sidecar carries `kind` = `sidecar`. That value appears
nowhere else in the file; every other file under `meta/` uses `meta`. It was
invented by the S30 run.

    sed -i.bak 's|^meta/T29_moment_power.csv.sidecar,sidecar,|meta/T29_moment_power.csv.sidecar,meta,|' meta/FILE_REGISTRY.csv

Verify: `grep -c ',sidecar,' meta/FILE_REGISTRY.csv` must return 0.

## 4. Step two — remove the two duplicate rows

Lines 133 and 135 are byte-identical copies of 132 and 134. Delete the second
copy of each, higher line number first:

    sed -i '135d;133d' meta/FILE_REGISTRY.csv

Verify: the file is now 255 lines, and

    grep -c 'audit/S14_placebo_diagnostic.R' meta/FILE_REGISTRY.csv
    grep -c 'audit/S15_settle.R' meta/FILE_REGISTRY.csv

both return 1.

## 5. Step three — append 25 rows

The file uses CRLF line endings. The `printf` below emits them explicitly; do
not substitute `cat`, a heredoc, or an editor, all of which will write LF and
corrupt the file's consistency.

    printf '%s\r\n' \
    'code/S32_tail_regime.R,code,manual,ITPDE_total.rds,20260730,G1_PASS_G2_FAIL,14,AUDIT' \
    'code/S33_tail_regime_v2.R,code,manual,ITPDE_total.rds,20260730,C1_FAIL_C4_PASS_C5_FAIL,14,AUDIT' \
    'code/S34_a2_normality.R,code,manual,S1R_ppml.rds,20260731,G1_G2_G3_PASS,14,BUILT' \
    'code/S35_jensen_control.R,code,manual,output/T39_a2_jensen_identity.csv;S1R_ppml.rds,20260731,G1_G2_G3_G4_PASS,14,BUILT' \
    'output/T33_tail_verdicts.csv,output,code/S32_tail_regime.R,ITPDE_total.rds,20260730,G2_FAIL_no_verdict,14,AUDIT' \
    'output/T34_hill_curves.csv,output,code/S32_tail_regime.R,ITPDE_total.rds,20260730,none,14,AUDIT' \
    'output/T35_fitter_calibration.csv,output,code/S33_tail_regime_v2.R,ITPDE_total.rds,20260730,C1_FAIL,14,AUDIT' \
    'output/T36_tail_comparison.csv,output,code/S33_tail_regime_v2.R,ITPDE_total.rds,20260730,skipped_C1_FAIL,14,AUDIT' \
    'output/T37_tail_modelfree.csv,output,code/S33_tail_regime_v2.R,ITPDE_total.rds,20260730,C4_PASS_C5_FAIL,14,AUDIT' \
    'output/T38_a2_normality.csv,output,code/S34_a2_normality.R,S1R_ppml.rds,20260731,G1_G2_G3_PASS,14,BUILT' \
    'output/T39_a2_jensen_identity.csv,output,code/S34_a2_normality.R,S1R_ppml.rds,20260731,G1_G2_G3_PASS,14,BUILT' \
    'output/T40_jensen_control.csv,output,code/S35_jensen_control.R,output/T39_a2_jensen_identity.csv;S1R_ppml.rds,20260731,G1_G2_G3_G4_PASS,14,BUILT' \
    'output/F5_a2_normality_qq.pdf,output,code/S34_a2_normality.R,S1R_ppml.rds,20260731,inherited,14,BUILT' \
    'output/F5_a2_normality_qq.png,output,code/S35_jensen_control.R,output/F5_a2_normality_qq.pdf,NONE,none,14,BUILT' \
    'meta/T38_a2_normality.csv.sidecar,meta,code/S34_a2_normality.R,output/T38_a2_normality.csv,NONE,exists,14,BUILT' \
    'meta/T39_a2_jensen_identity.csv.sidecar,meta,code/S34_a2_normality.R,output/T39_a2_jensen_identity.csv,NONE,exists,14,BUILT' \
    'meta/T40_jensen_control.csv.sidecar,meta,code/S35_jensen_control.R,output/T40_jensen_control.csv,NONE,exists,14,BUILT' \
    'meta/F5_a2_normality_qq.pdf.sidecar,meta,code/S34_a2_normality.R,output/F5_a2_normality_qq.pdf,NONE,exists,14,BUILT' \
    'meta/F5_a2_normality_qq.png.sidecar,meta,code/S35_jensen_control.R,output/F5_a2_normality_qq.png,NONE,exists,14,BUILT' \
    'prompts/S31_tail_reproduction.md,prompt,manual,NONE,NONE,withdrawn_S31a_S31c,14,AUDIT' \
    'prompts/S32_tail_regime.md,prompt,manual,NONE,NONE,superseded_by_S34,14,AUDIT' \
    'prompts/S33_tail_regime_v2.md,prompt,manual,NONE,NONE,superseded_by_S34,14,AUDIT' \
    'prompts/S34_a2_normality.md,prompt,manual,NONE,NONE,executed,14,BUILT' \
    'prompts/S35_jensen_control.md,prompt,manual,NONE,NONE,executed,14,BUILT' \
    'prompts/S36_appendix_patch.md,prompt,manual,NONE,NONE,executed,14,BUILT' \
    >> meta/FILE_REGISTRY.csv

## 6. Verification — run all six and report each realised value

1. Line count is 280.
2. Column count is 8 on every row and nothing else:

       awk -F, 'NR>1 && NF>0 {print NF}' meta/FILE_REGISTRY.csv | sort -u

   must print `8` and nothing else.
3. No duplicate `file_path`:

       awk -F, 'NR>1{print $1}' meta/FILE_REGISTRY.csv | sort | uniq -d

   must print nothing.
4. `grep -c ',sidecar,' meta/FILE_REGISTRY.csv` returns 0.
5. Every appended `file_path` exists on disk. For each of the 25 paths, confirm
   the file is present in the working tree and report any that are not.
6. CRLF consistency: the count of `\r\n` equals the line count.

       file meta/FILE_REGISTRY.csv

   should report CRLF line terminators.

If check 5 finds a missing file, report it and still commit — a registry row for
a file that should exist but does not is exactly the condition the registry is
for surfacing. Do not delete the row.

## 7. Commit

Commit `meta/FILE_REGISTRY.csv` only. Do NOT commit `meta/FILE_REGISTRY.csv.bak`
created by step 3; delete it or leave it untracked.

Commit message, verbatim:

    Registry: enroll the S32-S36 artifacts; fix kind vocabulary and duplicate rows

    25 rows for four scripts, ten outputs, five sidecars and six prompts. The
    (A2) diagnostic chain (S34/S35) is BUILT and is cited by SYNC-13. The
    abandoned lognormal-versus-Pareto attempts (S32/S33, T33-T37) are AUDIT,
    with the failed gate recorded in the gate column so the reason is visible at
    the row rather than only in the register.

    Also: meta/T29_moment_power.csv.sidecar carried kind 'sidecar', a value
    invented by the S30 run and used nowhere else; corrected to 'meta'. And
    audit/S14 and audit/S15 each appeared twice as exact duplicates; the second
    copies removed.

Push to `main` and quote the resulting commit SHA.

## 8. Out of scope

- Do not edit any file other than `meta/FILE_REGISTRY.csv`.
- Do not touch `article/`, `code/`, `output/`, `meta/canonical_facts.md`, or
  `meta/SUPERSEDED.md`.
- Do not write sidecars. The five for the (A2) artifacts already exist; the
  remainder are handled elsewhere.
- Do not run `code/enforce.R`, and do not attempt to fix any violation it would
  report. Eleven EXPECTED_N violations are known and are handled elsewhere.
- Do not re-sort, re-order, or reformat existing rows.
- Do not change the status of any existing row. In particular
  `code/S13b_matching_sensitivity.R` still carries the pre-INV-038 status
  `SUPERSEDED`; that is a known open decision (CAV-005) and is not yours to make.

## 9. Report format — exactly these five headings

1. `STARTING STATE` — line count, md5sum, and lines 132-135 verbatim
2. `COMMANDS RUN` — each command and its exit status
3. `VERIFICATION` — all six checks from section 6, each with its realised value
4. `COMMIT` — the pushed SHA and the files in the commit
5. `RESIDUAL AMBIGUITIES` — every one, or the single word `NONE`

## 10. Prohibitions

- Do not proceed past section 2 if the starting state does not match.
- Do not substitute a heredoc, `cat`, or an editor for the `printf`; LF endings
  would corrupt the file's consistency.
- Do not delete a row because its file is missing on disk.
- Do not commit the `.bak`.
- Do not report a commit SHA you have not pushed.
