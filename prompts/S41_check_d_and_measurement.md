# PROMPT S41 — Diagnose the write failures, then fix check (d) and measure

ROLE: Execution agent. Fresh session. One pass.

## 0. Part Zero — Diagnostics, before you touch anything

The repository owner writes to `/groups/m-larch/bt307958/` routinely and has
never seen an I/O error there. Several tasks run from your side have failed with
`Input/output error (5)` on that path. The two facts are compatible only if your
session sees a different filesystem view than an interactive login does.

Run these from the environment where the failures occurred, and report each
output verbatim. Do not interpret them; report them.

    hostname
    id
    mount | grep -E 'groups|scratch' || echo 'NO MATCHING MOUNTS'
    ls -ld /groups /groups/m-larch /groups/m-larch/bt307958
    df -h /groups/m-larch/bt307958 2>&1
    touch /groups/m-larch/bt307958/.writetest_$$ && echo WRITE_OK && rm -f /groups/m-larch/bt307958/.writetest_$$ || echo WRITE_FAIL
    ls -l /dev/shm/.privtmp 2>&1 || echo 'no privtmp'

Then the same write test on scratch:

    touch /scratch/bt307958/.writetest_$$ && echo SCRATCH_WRITE_OK && rm -f /scratch/bt307958/.writetest_$$ || echo SCRATCH_WRITE_FAIL

If you run any part of this task inside a batch job (`srun`, `sbatch`), run the
block **both** on the submission host and inside the job, and label which is
which. A difference between the two is the answer.

This part is not optional and its output is the most valuable thing you will
produce. Report it even if everything succeeds.

## 1. Where you work

**Write only under `/scratch/bt307958/`.** Every task that wrote there has
succeeded. Read from `/groups` if a file lives there; reads have worked.

**Do not use `/groups/m-larch/bt307958/REBUILD_V2`.** It is a stale partial
mirror with 133 dirty files, several commits behind HEAD. INV-038 records that
every enforce result ever produced described that directory rather than the
repository, and task S40 repeated the error, publishing a violation count from it
into README.md and MANIFEST.txt, where it still stands.

**Do not create a new clone.** Eight prior tasks each made one. Use one
persistent clone, brought to HEAD:

    WORK=/scratch/bt307958/rta-work
    if [ -d "$WORK/.git" ]; then
      cd "$WORK" && git fetch origin && git reset --hard origin/main && git clean -fd -e data
    else
      git clone https://github.com/SimonBloethner/heterogeneity-rta-effects "$WORK" && cd "$WORK"
    fi

`-e data` matters: `data/` is gitignored and must survive cleaning.

## 2. Establish that the tree is measurable

    git rev-parse HEAD
    git rev-parse origin/main
    git status --porcelain | wc -l

HEAD must equal `origin/main`; porcelain count must be 0 apart from `data/`.
**If not, STOP.** A measurement on an unknown tree measures nothing.

`data/` is gitignored and absent from a fresh clone. Locate a complete copy —
candidates include `/scratch/bt307958/ENFORCE_ROOT/data` and
`/groups/m-larch/bt307958/tails/data`. Prefer one already on `/scratch`. Symlink
it; do not copy:

    ln -sfn <path-to-complete-data-dir> "$WORK/data"

Report the resolved target and the SHA256 of `data/ITPDE_total.rds` and
`data/S1R_ppml.rds`. The latter must be
`45c937cd78805d7b13b4c43f4bc4888e93a2ff15e787ad4fb41d77b51f837d89` — its sidecar
value, pinned by S34. A run reported `0f98d7143df3...` from the stale mirror. If
your copy does not match the sidecar, that is a finding: report it, try another
candidate, and if none matches, STOP.

## 3. Part A — Fix check (d): match paths, not basenames

Check (d) reduces each registry path to `basename()` and greps script text for
that string. Sound only while no archived file shared a basename with a live one.
S38 enrolled `archive/retired_pack/`, creating 77 such collisions. Consequence:
`ITPDE_total.rds` is "archived" by name, so check (d) flags
`S1R_ppml_untreated.R` and `S8R_ge_propagation.R` — the foundation of the
estimation chain — for loading `data/ITPDE_total.rds`, a live input.

The scripts are correct. The check is wrong. **Do not modify any script to satisfy
it.**

Amend check (d) so its registry-driven half compares **full paths**: a violation
requires the script to reference the archived or quarantined file's full registry
path, not merely its basename. Leave the structural half (near line 205)
unchanged — it tests for the literal `archive/`, which is a path test and correct.

## 4. Part B — Fixtures

Add two under `tests/fixtures/`, shaped like the existing `check_d_pass.R` and
`check_d_fail.R`:

- PASS fixture loading `data/ITPDE_total.rds`
- FAIL fixture loading `archive/retired_pack/data/ITPDE_total.rds`

They differ only in path and share a basename, so they discriminate exactly the
defect being fixed. Run the harness; report that each behaves as labelled. **If
the PASS fixture does not pass, the fix is wrong — report and do not commit it.**

## 5. Part C — Register `data/ITPDE_total.rds`

No registry row has `file_path` = `data/ITPDE_total.rds`, though seven rows name
it as an input and the only row with that basename is the archived pack copy.
Append, CRLF:

    data/ITPDE_total.rds,data,external,ITPD-E Release 2,NONE,none,0,ANCHOR

`ANCHOR`: a live dependency, not itself citable as the source of a number.

## 6. Part D — Refuse to measure an unknown tree

Add a preflight to `code/enforce.R`, before any check: halt unless
`git rev-parse HEAD` equals `git rev-parse origin/main` and `git status
--porcelain` (excluding `data/`) is empty. Print both SHAs and the dirty count in
the halt message. Provide `--allow-dirty` to skip it, printing a banner stating
the result does not describe `origin/main` and must not be published. Default is
halt.

Two runs have now measured `REBUILD_V2` and reported the number as if it
described the repository.

## 7. Part E — Measure, then publish

Only after Parts A through D:

    Rscript code/enforce.R

Quote the complete output verbatim. Then update `README.md` and `MANIFEST.txt`
together to state the measured count and the commit measured at. Both currently
publish "7 violations" from the S40 run; **that figure came from the stale mirror
and does not describe this repository.** Replace it whatever your count is. If
zero, remove the residual statement from both and state that `enforce.R` reports
zero violations at the named commit — nothing stronger.

Expectation, stated so you can contradict it: S40's two SHA256 violations are
stale-file artifacts. `T39_a2_jensen_identity.csv` at origin hashes to
`7906ff4def77...`, exactly its sidecar value. If either reappears on a clean tree,
that is a real finding and must be reported, not explained away.

**Do not fix any violation you find.** Report it.

## 8. Out of scope

- No script under `code/` other than `enforce.R`.
- Not `meta/canonical_facts.md`, not `meta/SUPERSEDED.md`, not `article/`.
- Not the status of `code/S13b_matching_sensitivity.R` (CAV-005, open decision).
- No regeneration of outputs, no re-running of analysis.

## 9. Report format — exactly these nine headings

1. `PART ZERO` — every diagnostic command and its verbatim output
2. `WHERE` — clone path, HEAD, origin/main, dirty count, `data/` target, two hashes
3. `PART A` — the diff to check (d)
4. `PART B` — the two fixtures and the discrimination result
5. `PART C` — the registry row appended
6. `PART D` — the preflight and its halt message
7. `PART E` — complete enforce output, the count, edits to both files
8. `COMMIT` — pushed SHA and files
9. `RESIDUAL AMBIGUITIES` — every one, or the single word `NONE`

## 10. Prohibitions

- Do not skip Part Zero, even if everything works.
- Do not write outside `/scratch/bt307958/`.
- Do not use or sync `REBUILD_V2`.
- Do not create an additional clone.
- Do not copy `data/`; symlink it.
- Do not modify a script to satisfy a failing check.
- Do not publish a count measured on a dirty or behind-origin tree.
- Do not commit the amendment if the PASS fixture fails.
- Do not report a commit SHA you have not pushed.
