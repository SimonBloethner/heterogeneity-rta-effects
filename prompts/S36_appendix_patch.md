# PROMPT S36 — Apply the SYNC-13 appendix patch to article/main.tex

ROLE: Execution agent. Fresh session. This is a mechanical task with no analysis
in it. Read this prompt fully, then execute in one pass — there is no plan-then-
halt round for this one.

No cluster resources are needed. This runs anywhere with a clone and Python 3.

## 1. What this task is

A prepared patch script makes three edits to `article/main.tex`. You run it,
verify the result, commit, and push. You do not write, rewrite, improve, or
reformat any prose, and you do not edit `main.tex` by hand.

The three edits, so you can recognise correct output:

1. **Proposition 3(b)** — removes the claim that separation through higher-order
   within-pair moments is out of reach. That claim cited the sampling noise of a
   *per-pair* sample excess kurtosis; the operative statistic pools across pairs,
   so its noise falls with the pair count rather than the window length.
2. **Remark 3's closing sentence** — "inseparable at any sample size" narrows to
   "exactly inseparable under normality".
3. **Section 4, evidentiary-standard passage** — carried the same overclaim
   ("unavailable at any sample size") and is narrowed to match.

The script also inserts a new Remark 4 carrying `\label{rem:moments}`, which
reports the S30 power calculation and the S34 kurtosis measurement.

## 2. Procedure

1. Fresh clone of `SimonBloethner/heterogeneity-rta-effects`. Not
   `/groups/m-larch/bt307958/REBUILD_V2`, which is a stale mirror.
2. Obtain `apply_appendix_patch.py`. The researcher will place it in the clone
   root, or provide it directly. Do not reconstruct it from this prompt — it is
   not reproduced here, and a reconstruction would not match.
3. From the repository root, run:

       python3 apply_appendix_patch.py

4. Read the script's stdout in full and quote it verbatim in your report.

The script is self-verifying. It refuses and writes nothing if any anchor is
absent or appears more than once, if the patch has already been applied, or if
LaTeX environments come out unbalanced. **If it refuses, stop.** Report its exact
message and do not attempt a manual edit, an anchor adjustment, or a second run.
A refusal means the file is not in the state the patch was built against, and
that is information the researcher needs rather than an obstacle for you to work
around.

## 3. Verification, before committing

Run each of these and report the result:

- `article/main.tex.bak` exists and is byte-identical to the file at `HEAD`
  before your changes.
- Environment balance in the patched file: `\begin` and `\end` counts match for
  `remark`, `proposition`, `corollary`, `equation`, `table`, `document`. Expected
  remark count after the patch: 4.
- `\label{rem:moments}` appears exactly once; `\ref{rem:moments}` appears twice.
- The strings `24/T` and `at any sample size` no longer appear anywhere in the
  file. Both should return zero matches.
- Character count before and after, as the script reports them.

If the document compiles in your environment, compile it and report whether
`Remark 4` and both `\ref{rem:moments}` cross-references resolve. If LaTeX is not
available, say so plainly rather than skipping the line.

## 4. Commit

Commit `article/main.tex` only. Do **not** commit `article/main.tex.bak`, and do
not commit `apply_appendix_patch.py`.

Use the commit message the script prints, verbatim.

Push to `main` and quote the resulting commit SHA.

## 5. Out of scope

- Do not edit any file other than `article/main.tex`.
- Do not touch `meta/`, `output/`, `code/`, or `prompts/`.
- Do not write sidecars, registry rows, or ledger rows.
- Do not fix, reword, or reflow anything you notice in the surrounding LaTeX.
- Do not resolve the dangling `\ref{sec:conclusion}` or `\ref{sec:robustness}`,
  or the `[X-REF:]` placeholders. They are known and are handled elsewhere.

## 6. Report format — exactly these five headings

1. `WHAT WAS RUN` — clone path, Python version, the command
2. `SCRIPT OUTPUT` — stdout verbatim, including any refusal message
3. `VERIFICATION` — every check in section 3, each with its realised value
4. `COMMIT` — the pushed SHA, and the files in the commit
5. `RESIDUAL AMBIGUITIES` — every one, or the single word `NONE`

## 7. Prohibitions

- Do not edit `main.tex` by hand under any circumstance, including to work around
  a refusal.
- Do not modify the patch script.
- Do not run the script twice. It is idempotent by refusal, not by re-application,
  and a second run indicates something went wrong on the first.
- Do not report a commit SHA you have not pushed.
- Do not commit the `.bak`.
