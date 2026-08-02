# PROMPT S39 — Ledger SYNC-14: append the drift-calibration holdout section

ROLE: Execution agent. Fresh session. Mechanical, no cluster, no R.

Two edits to one file. Both are verified by SHA256 against a target computed in
advance, so a transcription error cannot survive this task.

## 1. What this does and why

`output/T9_placebo_holdout.csv` supplies nine quantities that Section 4's
calibration paragraph and Section 6's bounded-tolerances subsection both depend
on. None of them has a row in `meta/canonical_facts.md`. The article therefore
cites them straight from the CSV, which places them outside the dependency
closure and outside the standing rule that the ledger is sole authority. This
task ledgers them.

No number changes. Nothing is recomputed. This is a provenance repair.

## 2. Setup and pre-state check

Fresh clone of `SimonBloethner/heterogeneity-rta-effects`, working from the
repository root. Not `/groups/m-larch/bt307958/REBUILD_V2`, a stale mirror.

    sha256sum meta/canonical_facts.md
    wc -c meta/canonical_facts.md

Expected, exactly:

    4d45a999e154bee4f0ca54a4ec7fdc35d1dd77941030cd64394e4af7d8f3e472
    43274

**If either differs, STOP.** Report what you found and change nothing. A
mismatch means the ledger has moved since this task was written, and the target
hash in section 5 would then be unreachable. Do not attempt to reconcile it.

## 3. Edit one — the amendment line

    sed -i '/^Amended: 2026-08-02 (SYNC-13/a Amended: 2026-08-02 (SYNC-14: drift-calibration holdout ledgered; T9 values were cited from output\/ with no ledger row)' meta/canonical_facts.md

On macOS/BSD `sed`, use `sed -i ''` instead of `sed -i`.

Verify the file now contains exactly one line beginning
`Amended: 2026-08-02 (SYNC-14:` and that it sits immediately below the SYNC-13
line.

## 4. Edit two — append the section

The researcher will supply a file named `append_tail.txt`. Place it in the
repository root. Do not retype its contents, do not reflow it, and do not open it
in an editor that may alter trailing whitespace or line endings.

Verify it before use:

    sha256sum append_tail.txt
    wc -c append_tail.txt

Expected, exactly:

    b102f7582c8acc062e205ce9b3fdfcfc41c1f48c105611497c8119c178d9ac1a
    3821

If either differs, STOP and report. The file has been altered in transit.

Then:

    cat append_tail.txt >> meta/canonical_facts.md

Use `cat`, not an editor, not a heredoc, not copy-paste. The block begins with a
blank line and ends with a single newline; both matter.

## 5. Verification — the decisive check

    sha256sum meta/canonical_facts.md
    wc -c meta/canonical_facts.md

Required, exactly:

    211418efeefab15c274a2d78cdf01bee16e511deed50f02f47c9ec2b082d5976
    47215

**If the hash does not match, do not commit.** Restore the file with
`git checkout meta/canonical_facts.md`, report the hash you obtained, and stop.
A mismatch means one of the two edits did not land as specified, and a ledger
that differs from its verified source by an unknown amount is worse than one that
was never edited.

Also confirm, and report each:

- `grep -c '^| HOLDOUT_' meta/canonical_facts.md` returns 9.
- `grep -c '^Amended: 2026-08-02 (SYNC-14' meta/canonical_facts.md` returns 1.
- The file still ends with a single newline.

## 6. Delete the transfer file

`append_tail.txt` is a transfer artifact and must not enter the tree. Delete it
from the working directory before committing, and confirm it does not appear in
`git status`. An unregistered file left in the repository is the condition
INV-039 exists to record; do not create a second instance of it.

## 7. Commit

Commit `meta/canonical_facts.md` only. Commit message, verbatim:

    Ledger SYNC-14: drift-calibration holdout (T9)

    Nine HOLDOUT_* IDs for the held-out validation of the size-decile drift
    correction. Until now Section 4's calibration paragraph and Section 6's
    bounded-tolerances subsection cited these figures directly from
    output/T9_placebo_holdout.csv with no ledger row, which placed them outside
    the dependency closure and outside the sole-authority rule. No number
    changes; this is a provenance repair.

    Four binding notes. Decile 3 registers PARTIAL at -0.1013 on 314 pairs and
    must not be absorbed into the pooled 0.0188. The 0.10 bound is the
    resolution of the correction layer rather than an incidental tolerance, so
    claims about size-profile structure below it are unsupported; the gradient
    at 0.9137 clears it by nearly an order of magnitude, so the fall-then-floor
    reading is unaffected. And the partition is not refined because the folds are
    already thin at 19 and 94 pairs in the smallest deciles.

    Newly stated: the largest absolute decile mean among the nine that pass is
    0.0569, so those nine clear the bound with room rather than sitting against
    it.

Push to `main` and quote the commit SHA.

## 8. Out of scope

- Do not edit any file other than `meta/canonical_facts.md`.
- Do not touch `meta/SUPERSEDED.md`, `meta/FILE_REGISTRY.csv`, `article/`,
  `code/`, or `output/`.
- Do not recompute anything from `output/T9_placebo_holdout.csv`. The values in
  the block were verified against that file already.
- Do not commit `append_tail.txt`.
- Do not reformat, re-sort, or re-wrap any existing ledger content.

## 9. Report format — exactly these five headings

1. `PRE-STATE` — hash and byte count before any change
2. `EDITS` — each command and its exit status
3. `VERIFICATION` — final hash, byte count, and the three greps, each with its
   realised value
4. `COMMIT` — pushed SHA, files in the commit, and confirmation that
   `append_tail.txt` is absent from it
5. `RESIDUAL AMBIGUITIES` — every one, or the single word `NONE`

## 10. Prohibitions

- Do not proceed if the pre-state hash does not match.
- Do not commit if the post-state hash does not match; restore and report.
- Do not retype or reconstruct the append block from any source.
- Do not report a hash you have not computed from bytes on disk.
- Do not run more than one execution round.
