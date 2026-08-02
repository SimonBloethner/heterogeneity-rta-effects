# PROMPT S42 — Generate the Remark 4 macros and clear check (f)

ROLE: Execution agent. Fresh session. Needs R. One pass.

Work under `/scratch/bt307958/rta-work`, the persistent clone. Bring it to HEAD
with `git fetch origin && git reset --hard origin/main && git clean -fd -e data`.
Do not create a new clone. Do not use `REBUILD_V2`.

## 1. The defect

`enforce.R` check (f) reports two violations, both in the propositions appendix:

    main.tex line 2017: numeric literal(s) 2.96, 11.44 with no resolving ledger ID or macro
    main.tex line 2021: numeric literal(s) 0.784, -0.269 with no resolving ledger ID or macro

Those lines are in Remark 4 (`\label{rem:moments}`), added by task S36. They
state the values as typed literals with a trailing `%` fact-comment. That is the
convention used in the body of the paper. The appendix uses a different one:
values are supplied by auto-generated macros — `\PropEsigsq`, `\PropVarEta`,
`\PropRpred` and so on — emitted into `article/prop_constants.tex` by
`code/S26_prop_verification.R`.

The check is correct and the remark is wrong. A typed appendix literal goes stale
silently when its ledger row changes; a macro cannot. Fix the remark, not the
check.

## 2. Part A — A generator for the new constants

Write `code/S42_a2_constants.R`. It reads `meta/canonical_facts.md` and emits
`article/a2_constants.tex`, a file of `\newcommand` definitions, in the style and
header format of `article/prop_constants.tex` — read that file first and match it.

Four macros, each parsed from the ledger at run time. **Do not hardcode any
value**; a hardcoded constant is a failed task even if numerically correct.

| Macro | Ledger ID | Expected |
|---|---|---|
| `\MomPowMinZ` | `MOMPOW_IDENT_MIN_Z` | 2.96 |
| `\MomPowMaxZ` | `MOMPOW_IDENT_MAX_Z` | 11.44 |
| `\AtwoExKurt` | `A2_EXKURT` | 0.784 |
| `\AtwoExKurtControl` | `A2_EXKURT_CONTROL` | -0.269 |

The "Expected" column is for your verification only. The emitted value must be
the one parsed from the ledger. If a parsed value differs from the expected one,
**stop and report** — that means the ledger moved and the remark's prose may need
rewriting, which is not your call.

Round to the precision shown: `A2_EXKURT` is ledgered as `0.784025494520271` and
must be emitted as `0.784`. Negative values must render correctly in math mode.

Gates, as `stopifnot()`:

- G1: all four IDs found in the ledger; a missing ID halts.
- G2: each emitted value, re-parsed from the file just written, round-trips to the
  value taken from the ledger.
- G3: the emitted file defines exactly four macros and no others.

## 3. Part B — Wire it into the document

In `article/main.tex`, add `\input{a2_constants}` immediately after the existing
`\input{prop_constants}` line. If the existing input uses a different form, match
it exactly.

Then replace the two flagged passages. Anchors are given in full; each occurs
once. Change nothing outside them.

**Anchor 1** — find:

    pairs, separation runs from $2.96$ to $11.44$ across excess kurtosis in
    $[0.75,\,3.0]$ and transitory shares in $[0.10,\,1.00]$
    % [MOMPOW_IDENT_MIN_Z, MOMPOW_IDENT_MAX_Z]

replace with:

    pairs, separation runs from $\MomPowMinZ$ to $\MomPowMaxZ$ across excess
    kurtosis in $[0.75,\,3.0]$ and transitory shares in $[0.10,\,1.00]$
    % [MOMPOW_IDENT_MIN_Z, MOMPOW_IDENT_MAX_Z]

**Anchor 2** — find:

    gaps carry an excess kurtosis of $0.784$ against $-0.269$ for a matched normal
    control passed through identical code, a net departure near unity that falls
    inside the simulated grid

replace with:

    gaps carry an excess kurtosis of $\AtwoExKurt$ against $\AtwoExKurtControl$ for
    a matched normal control passed through identical code, a net departure near
    unity that falls inside the simulated grid

Leave the `%` fact-comments in place. They are the body convention and are
harmless; the macros satisfy the appendix rule.

## 4. Part C — Register

Sidecar `meta/a2_constants.tex.sidecar`, in the format of
`meta/T28b_v1c_arm1p.csv.sidecar`, carrying `FILE`, `SHA256`, `PRODUCER`,
`PRODUCER_SHA256`, `INPUTS` (the ledger, with its hash), `SEED: NONE`, a
specification block, `GATES`, and `CREATED`. Every hash computed from bytes on
disk.

Three registry rows, CRLF:

    code/S42_a2_constants.R,code,manual,meta/canonical_facts.md,NONE,G1_G2_G3_PASS,15,BUILT
    article/a2_constants.tex,article,code/S42_a2_constants.R,meta/canonical_facts.md,NONE,G1_G2_G3_PASS,15,BUILT
    meta/a2_constants.tex.sidecar,meta,code/S42_a2_constants.R,article/a2_constants.tex,NONE,exists,15,BUILT
    prompts/S42_a2_constants.md,prompt,manual,NONE,NONE,executed,15,BUILT

(Four rows; the count in the sentence above is wrong and the list is correct.)

## 5. Part D — Two stale statements in MANIFEST.txt

S41 reported both and correctly left them alone. Fix them now.

- MANIFEST states `archive/retired_pack/` has zero registry rows. S38 enrolled 77.
  Correct the sentence to say it is enrolled, and that check (d) is additionally
  structural against any path under `archive/`.
- MANIFEST states the registry has 252 rows. Report the actual count and use it.

Do not touch the violation-count statement in either `README.md` or
`MANIFEST.txt` until Part E tells you what it should say.

## 6. Part E — Measure and publish

    Rscript code/enforce.R

Quote the complete output verbatim. The expectation is zero violations. If it is
zero, update `README.md` and `MANIFEST.txt` together to state that `enforce.R`
reports zero violations at the named commit — nothing stronger, no claim that all
checks are exhaustive. If it is not zero, publish the measured count with the
check letters, and **do not fix anything** — report it.

If the preflight halts because your tree is dirty, commit first, then re-run. Do
not use `--allow-dirty` to obtain a publishable number.

## 7. Out of scope

- Do not modify `code/enforce.R` or any check.
- Do not modify `code/S26_prop_verification.R` or `article/prop_constants.tex`.
- Do not touch `meta/canonical_facts.md` or `meta/SUPERSEDED.md`.
- Do not edit `article/main.tex` beyond the `\input` line and the two anchors.
- Do not change the status of `code/S13b_matching_sensitivity.R` (CAV-005).
- Do not regenerate any output or re-run any analysis script.

## 8. Report format — exactly these seven headings

1. `WHERE` — clone path, HEAD, origin/main, dirty count
2. `PART A` — the generator, the four parsed values, the emitted file verbatim,
   and the three gates with realised values
3. `PART B` — the `\input` line added and the two anchor replacements
4. `PART C` — the sidecar, its hashes, and the four registry rows
5. `PART D` — the two MANIFEST corrections, before and after
6. `PART E` — complete enforce output, the count, and the edits to both files
7. `RESIDUAL AMBIGUITIES` — every one, or the single word `NONE`

## 9. Prohibitions

- Do not hardcode a value that should be parsed from the ledger.
- Do not fabricate a SHA256.
- Do not modify a check to make a violation disappear.
- Do not use `--allow-dirty` for a published number.
- Do not edit `main.tex` outside the two anchors and the `\input` line.
- Do not report a commit SHA you have not pushed.
