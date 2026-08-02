# PROMPT S38 — Close out the replication package

ROLE: Execution agent. Fresh session. No cluster required for parts A through E;
part F needs only R and the repository.

This is the last package task before submission preparation. Six parts. They are
independent — if one cannot be completed, do the others and say which failed
under residual ambiguities. Do not silently drop one.

Work in a fresh clone of `SimonBloethner/heterogeneity-rta-effects`. Not
`/groups/m-larch/bt307958/REBUILD_V2`, which is a stale mirror.

## Part A — Sidecars for the ten BUILT outputs that lack them

These ten are registered BUILT in `meta/FILE_REGISTRY.csv` and have no
corresponding `meta/<name>.sidecar`:

    output/T9_placebo_holdout.csv
    output/T19_pleq0_bracket.csv
    output/T20_ge_bracket.csv
    output/T21_arms.csv
    output/T22_reliability.csv
    output/T23_anchor.csv
    output/T24_placebo_uncorr.csv
    output/T25_prop_verification.csv
    output/T27_gradient_B_spread.csv
    output/TD1R_population_census.csv

Write one sidecar each, at `meta/<basename>.sidecar`, in the format of
`meta/T28b_v1c_arm1p.csv.sidecar` — read that file first and match its shape.
Required fields:

    FILE:              basename
    SHA256:            computed from the bytes on disk
    PRODUCER:          with the leading `code/` prefix
    PRODUCER_SHA256:   the producing script's own SHA256, computed from disk
    INPUTS:            each input path with its own SHA256
    SEED:              or NONE
    (a short specification block)
    GATES:             each gate the producer asserts, with its realised value
    CREATED:

**`PRODUCER_SHA256` is not in the existing format and is required here.** Without
it nothing pins which version of a script produced a table, which is the defect
INV-040 records for T29.

Derive `PRODUCER` and `INPUTS` from that output's row in
`meta/FILE_REGISTRY.csv`, not from memory. Derive `GATES` by reading the
producing script and reporting the gates it actually asserts. If an input is not
repository-resident — several are `.rds` files under `data/`, which is gitignored
— record the path and write `NOT_IN_REPO` in place of its hash rather than
omitting the line or inventing a value.

If a producing script named in the registry does not exist in the tree, write the
sidecar with `PRODUCER_SHA256: PRODUCER_ABSENT` and report it under residual
ambiguities. Do not guess a producer.

## Part B — Add `PRODUCER_SHA256` to the T29 sidecar

`meta/T29_moment_power.csv.sidecar` records no hash for its producing script.
Add one line directly below its `PRODUCER:` line:

    PRODUCER_SHA256: <sha256 of code/S30_moment_power.R computed from disk>

Change nothing else in that file. This closes item (2) of INV-040's list.

## Part C — Reclassify the superseded ledger stub

`output/canonical_facts.md` is registered `BUILT`. It is a 288-byte tombstone
whose entire content states that it is superseded by `meta/canonical_facts.md`.
`BUILT` means live and citable as the source of a number, which this is not.

In `meta/FILE_REGISTRY.csv`, change that row's status from `BUILT` to `ARCHIVED`
and move the file to `archive/retired_2026-07-29/canonical_facts.md`, updating
the row's `file_path` to match. Preserve CRLF line endings.

Do not delete the file. It is the record of a corrected error.

## Part D — Register `archive/retired_pack/` (INV-039)

`meta/FILE_REGISTRY.csv` contains zero rows matching `archive/retired_pack`.
Because `enforce.R` check (d) builds its forbidden-input set from registry rows
with status `ARCHIVED` or `QUARANTINE`, nothing in that directory is currently
forbidden as a dependency — although `README.md` states nothing in it may be
cited.

Enumerate every committed file under `archive/retired_pack/` from the working
tree, one row each, appended to `meta/FILE_REGISTRY.csv` with CRLF endings:

    <path>,<kind>,archived,NONE,NONE,none,0,ARCHIVED

where `<kind>` is the immediate subdirectory name (`code`, `data`, `output`,
`docs`) or `meta` for files at the pack root.

Enumerate with `git ls-files archive/retired_pack/`, not with a shell glob, so
that the enumeration is exactly the committed set.

Also append a row for `prompts/S37_registry_enrolment.md`, which registered the
others but could not register itself:

    prompts/S37_registry_enrolment.md,prompt,manual,NONE,NONE,executed,14,BUILT

and one for this prompt:

    prompts/S38_package_closeout.md,prompt,manual,NONE,NONE,executed,14,BUILT

## Part E — Make check (d) structural

Part D closes the instance. This closes the class.

In `code/enforce.R`, amend check (d) so that **any path under `archive/` is a
forbidden input to a BUILT output, whether or not it appears in the registry**,
in addition to the existing registry-driven test. A file absent from the registry
must not thereby escape the check.

Per the standing rule that every check carries a known-pass and known-fail
fixture: add both to `tests/fixtures/`, following the pattern of the fixtures
already there, and confirm the amended check discriminates. Report the fixture
paths and the discrimination result. **If you cannot add both fixtures, do not
merge the amendment** — report that Part E was not completed and leave
`enforce.R` untouched.

## Part F — The eleven EXPECTED_N headers

Eleven scripts load population data without asserting its row count. Locate them
by running `Rscript code/enforce.R` and reading the violations it reports.

For each, add an `EXPECTED_N:` header whose value is **derived from the loaded
data at run time**, not written by hand, and a `stopifnot()` that asserts the
loaded object matches it. A hand-written constant is a failed task even if
numerically correct.

Do not change any script's behaviour beyond adding the assertion. If adding an
assertion would make a script fail, **stop and report it** — that is a finding
about the script, not an obstacle to work around.

After this part, `Rscript code/enforce.R` should report zero violations. Report
the realised count whatever it is. If it is not zero, list what remains.

## Out of scope

- Do not touch `article/`.
- Do not touch `meta/canonical_facts.md` or `meta/SUPERSEDED.md`. Ledger entries
  are written elsewhere.
- Do not change the status of `code/S13b_matching_sensitivity.R`. It carries the
  pre-INV-038 status `SUPERSEDED`; that is an open decision (CAV-005) and is not
  yours to make.
- Do not re-run any analysis script, and do not regenerate any output. No number
  in the repository should change as a result of this task.
- Do not re-sort or reformat existing registry rows.

## Verification — report each realised value

1. Every BUILT output in the registry has a sidecar. Report the count of BUILT
   outputs and the count with sidecars; they must be equal.
2. Every sidecar's `SHA256` matches the bytes of the file it describes.
   Recompute all of them, not only the new ones, and report any mismatch.
3. Every sidecar's `PRODUCER_SHA256` matches the bytes of the named script.
4. `meta/FILE_REGISTRY.csv`: 8 columns on every row, no duplicate `file_path`,
   CRLF throughout, and a count of rows matching `archive/retired_pack` greater
   than zero.
5. `Rscript code/enforce.R` violation count.
6. The amended check (d) fixtures pass and fail as intended.

## Report format — exactly these eight headings

1. `WHAT WAS RUN` — clone path, R version, wall time
2. `PART A` — the ten sidecars, each with its computed SHA256 and PRODUCER_SHA256
3. `PART B` — the line added
4. `PARTS C AND D` — rows changed, rows added, the enumeration command and count
5. `PART E` — the amendment, the two fixtures, the discrimination result
6. `PART F` — the eleven scripts, and the enforce violation count before and after
7. `VERIFICATION` — all six checks with realised values
8. `RESIDUAL AMBIGUITIES` — every one, or the single word `NONE`

## Prohibitions

- Do not fabricate a SHA256. Every hash is computed from bytes on disk.
- Do not write a sidecar for a file you have not hashed.
- Do not invent a producer, an input, or a gate. Read them.
- Do not hand-write an `EXPECTED_N` value.
- Do not merge the check (d) amendment without both fixtures.
- Do not mark a part done without executing it. Six parts; account for all six.
- Do not change any reported number.
- Commit and push to `main`; quote the commit SHA. A file not at origin does not
  exist.
