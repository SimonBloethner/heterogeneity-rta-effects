# PROMPT S44 — Extend the constants generator for Section 6

ROLE: Execution agent. Fresh session. Needs R. No cluster. One pass.

Work under `/scratch/bt307958/rta-work`. Bring it to HEAD:

    cd /scratch/bt307958/rta-work && git fetch origin && git reset --hard origin/main && git clean -fd -e data

Do not create a new clone. Do not use `REBUILD_V2`. `enforce.R` halts unless HEAD
equals `origin/main` and the tree is clean, so commit before measuring.

**Before starting, confirm that `article/main.tex` at HEAD contains the string
`Two now carry evidence`.** If it does not, the researcher's Section 5 revision
has not been pushed. Report that and stop; this task must not run against a tree
whose Section 5 still states that four predictions were tested and three
confirmed.

## 1. What this does

Section 6 is about to be inserted and cites three quantities from the
drift-calibration holdout. The appendix convention is that values come from
generated macros so an article number cannot go stale when its ledger row moves;
`code/S42_a2_constants.R` already emits four such macros into
`article/a2_constants.tex`. This task extends it by three.

Section 6 is body text rather than appendix text, so check (f) does not require
macros there. They are used anyway. The three values are ledgered, the generator
exists, and a hardcoded number in the body is the same defect as one in the
appendix, differing only in whether an automated check happens to look.

## 2. Part A — Extend the generator

Amend `code/S42_a2_constants.R` to emit three additional macros, each parsed from
`meta/canonical_facts.md` at run time. **Do not hardcode any value.**

| Macro | Ledger ID | Expected rendering |
|---|---|---|
| `\HoldoutDThreeMean` | `HOLDOUT_D3_MEAN` | `-0.1013` |
| `\HoldoutDThreeN` | `HOLDOUT_D3_N` | `314` |
| `\HoldoutMaxAbsExDThree` | `HOLDOUT_MAX_ABS_EX_D3` | `0.0569` |

The "Expected rendering" column is for your verification only; the emitted value
must be the one parsed from the ledger. If a parsed value differs from the
expected one, **stop and report** — that means the ledger moved and Section 6's
prose may need rewriting, which is not your call.

`\HoldoutDThreeN` is a count and must render as a bare integer with no decimal
point and no thousands separator. The other two are signed decimals at four
places; the negative must render correctly in math mode.

Keep the four existing macros unchanged. Update gate G3, which currently asserts
exactly four macros, to assert exactly seven. Gates G1 (all IDs found) and G2
(each emitted value round-trips against the ledger) extend to all seven.

Re-run the script. Report `article/a2_constants.tex` verbatim.

## 3. Part B — Reissue the sidecar

`meta/a2_constants.tex.sidecar` must be reissued with the new `PRODUCER_SHA256`
and a specification block listing all seven macros and the ledger ID each derives
from.

The existing sidecar carries a placeholder in place of a `SHA256` for the file it
describes, on the reasoning that check (e) scans `output/` and `data/` only.
**Replace the placeholder with the real SHA256 of `article/a2_constants.tex`,
computed from bytes on disk.** A sidecar that does not pin the file it describes
is not doing its job, and the fact that no check currently reads it is the same
argument that produced INV-039. If check (e) then reports a violation, that is a
finding to report, not a reason to revert to a placeholder.

## 4. Part C — Registry

No new files are created, so no new rows are needed except this prompt:

    prompts/S44_section6_constants.md,prompt,manual,NONE,NONE,executed,17,BUILT

Place this prompt at that path before committing so the row resolves. Confirm the
existing rows for `code/S42_a2_constants.R`, `article/a2_constants.tex` and
`meta/a2_constants.tex.sidecar` are still present and unchanged.

## 5. Part D — Measure

Commit, then:

    Rscript code/enforce.R

Quote the complete output verbatim and report the count. The last measured state
was zero. If yours is not zero, report it with the check letters and **fix
nothing**. If it is zero, update the statement in `README.md` and `MANIFEST.txt`
to name your commit; do not otherwise reword either.

Do not use `--allow-dirty` for a published number.

## 6. Out of scope

- Do not edit `article/main.tex`. Section 6's insertion is a separate step and is
  not yours.
- Do not touch `meta/canonical_facts.md` or `meta/SUPERSEDED.md`.
- Do not modify `code/enforce.R` or any check.
- Do not modify `code/S26_prop_verification.R` or `article/prop_constants.tex`.
- Do not adjust a ledgered value to match a computed one.

## 7. Report format — exactly these six headings

1. `PRECHECK` — whether `Two now carry evidence` is present in `main.tex` at HEAD
2. `WHERE` — clone path, HEAD, origin/main, dirty count
3. `PART A` — the seven parsed values and `a2_constants.tex` verbatim, with G1,
   G2 and G3 realised
4. `PART B` — the reissued sidecar, both hashes, and whether check (e) reacts to
   the real SHA256
5. `PART D` — complete enforce output and the count
6. `RESIDUAL AMBIGUITIES` — every one, or the single word `NONE`

## 8. Prohibitions

- Do not run if the Section 5 precheck fails.
- Do not hardcode a value that should be parsed from the ledger.
- Do not restore a placeholder hash in the sidecar.
- Do not fabricate a SHA256.
- Do not modify a check to make a violation disappear.
- Do not edit `main.tex`.
- Do not report a commit SHA you have not pushed.
