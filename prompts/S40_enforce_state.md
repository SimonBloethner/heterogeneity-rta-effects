# PROMPT S40 — Report the enforce state, and reconcile README and MANIFEST to it

ROLE: Execution agent. Fresh session. Needs R and the repository. No cluster.

One measurement, then a conditional edit that depends on what the measurement
says. Do not decide the outcome in advance.

## 1. Why this task exists

`README.md` and `MANIFEST.txt` both publish the statement that eleven `EXPECTED_N`
violations remain and that the pass condition is unmet. Those lines were written
when that was true. Task S38 added `EXPECTED_N` headers and assertions, so the
statement may now be false. It may also still be true, or true with a different
number.

Publishing a violation count that has not been measured against the repository is
the exact defect INV-038 records: the previous baseline in those two files had
never been measured and was wrong in both directions. **Do not repeat it.** The
number you publish must be the number the tool printed on this tree, in this run.

## 2. Setup

Fresh clone of `SimonBloethner/heterogeneity-rta-effects`, working from the
repository root. Not `/groups/m-larch/bt307958/REBUILD_V2`, a stale mirror.

Record the commit SHA you cloned.

## 3. Step one — measure

    Rscript code/enforce.R

Capture the complete output, exit status included. Quote it verbatim in your
report, in full. If it is long, quote all of it anyway; do not summarise, and do
not elide repeated lines.

If the script errors rather than completing — a missing input, an unreadable
registry, a package that will not load — that is the finding. Report the error
with its traceback and **stop**. Do not repair the script, do not stub an input,
and do not proceed to step two. `enforce.R` reads files under `data/`, which is
gitignored; if those are absent from a fresh clone, say so plainly, report which
paths are missing, and stop. A run on a tree without its data measures nothing.

From the output, extract and report separately:

- the total violation count,
- the count by check letter (a) through (j),
- for any `EXPECTED_N` violations specifically, the script names.

## 4. Step two — reconcile the two published statements

What you do here depends entirely on the number from step one. Three cases.

### Case A — the count is zero

Remove the published-residual statement from both files. They must be edited
together; leaving one is worse than leaving both, because a reader then has two
documents disagreeing about the same fact.

In `README.md`, delete this sentence and nothing else, preserving the sentence
before it and the paragraph that follows:

    As last measured, 11
    EXPECTED_N violations remain, on scripts that load population data without
    asserting its row count: the pass condition is unmet. That figure is a measured
    residual and not a tolerated exception; it is recorded identically in
    `MANIFEST.txt`, and both statements are removed together once the count reaches
    zero.

In `MANIFEST.txt`, delete the block beginning `Measured state, NOT an allowance:`
and running to the end of that paragraph, again preserving what surrounds it.

In both files, replace the deleted text with a single sentence stating that
`enforce.R` reports zero violations as of the commit you cloned, naming that
commit's short SHA. Do not write "all checks pass" or any stronger claim than the
tool's own output supports.

### Case B — the count is non-zero but differs from eleven

Update the number in both files to the measured count, keep the framing that it
is a measured residual rather than a tolerated exception, and keep the sentence
saying both statements are removed together at zero. Add the check letters the
remaining violations fall under.

### Case C — the count is exactly eleven

Change nothing in either file. Report that step two was a no-op and that S38's
Part F did not reduce the count, which is a finding about Part F.

## 5. What not to do

- Do not fix any violation the tool reports. Report it. Fixing is a separate task
  with its own review.
- Do not modify `code/enforce.R`, any script under `code/`, any fixture, or any
  registry row to change the count.
- Do not touch `meta/canonical_facts.md` or `meta/SUPERSEDED.md`. The ledger entry
  for this is written elsewhere, from your report.
- Do not touch `article/`.
- Do not change the status of `code/S13b_matching_sensitivity.R`, which still
  carries the pre-INV-038 status `SUPERSEDED`. That is an open decision (CAV-005)
  and is not yours to make. If `enforce.R` reports anything about that row,
  report it and leave it.
- Do not round, estimate, or infer the count. Read it from the output.

## 6. Commit

Case A or B: commit `README.md` and `MANIFEST.txt` together, in one commit.
Case C: no commit.

Commit message, filling in the measured count:

    README and MANIFEST: publish the measured enforce state

    enforce.R reports <N> violations at <short SHA>. The two files previously
    published eleven, measured before S38 added the EXPECTED_N headers. Both are
    updated together, per the standing rule that a count appearing in one must
    appear identically in the other.

    The number published is the number the tool printed on this tree in this run.
    INV-038 records what happens when it is not.

Push to `main` and quote the commit SHA.

## 7. Report format — exactly these six headings

1. `WHAT WAS RUN` — clone path, cloned commit SHA, R version, command
2. `ENFORCE OUTPUT` — the complete output, verbatim, plus exit status
3. `VIOLATION SUMMARY` — total, by check letter, and script names for any
   `EXPECTED_N` violations
4. `CASE` — which of A, B or C applies, and why
5. `EDITS` — the exact text removed and added in each file, or `NO-OP` for case C
6. `RESIDUAL AMBIGUITIES` — every one, or the single word `NONE`

## 8. Prohibitions

- Do not publish a count you did not measure in this run.
- Do not proceed to step two if `enforce.R` did not complete.
- Do not edit one of the two files without the other.
- Do not fix a violation.
- Do not report a commit SHA you have not pushed.
- Do not run more than one execution round.
