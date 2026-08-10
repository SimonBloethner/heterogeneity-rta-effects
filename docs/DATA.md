# Data Sources and Construction

This document closes the one gap that prevents a third party from running the
pipeline in `README.md`. Stage 1 begins with

```bash
Rscript code/S1R_ppml_untreated.R
```

which opens by hashing `data/ITPDE_total.rds` and calling `stop()` if the file
is absent or does not match. That file is not distributed with this repository:
`meta/FILE_REGISTRY.csv` records it as `external`, source `ITPD-E Release 2`,
status `ANCHOR`. Its construction was never scripted. This document specifies
what it must contain and how to verify a rebuild.

## Sources

| Variable | Source | Citation |
|----------|--------|----------|
| Bilateral trade | International Trade and Production Database for Estimation, Release 2 | Borchert et al. (2021, 2022) |
| Bilateral trade agreements | Egger and Larch RTA database | Egger and Larch (2008) |
| Bilateral distance | GeoDist | Mayer and Zignago (2011) |
| Gross domestic product | Dynamic Gravity Dataset | Gurevich and Herman (2018) |

ITPD-E is distributed by the USITC and requires registration but no fee. The
Egger–Larch agreement data and GeoDist are publicly downloadable. Exact
retrieval URLs should be recorded here with an access date.

> **To be filled in:** the download URL and access date for each of the four
> sources, and the ITPD-E release/vintage string as it appears in the
> distributed file.

## Required schema

`data/ITPDE_total.rds` is an R serialization of a rectangular table. The live
chain reads the following columns; scripts that use each are named.

| Column | Type | Used by |
|--------|------|---------|
| `exporter` | character | `S1R_ppml_untreated.R`, `S9R_spec_spread.R` |
| `importer` | character | `S1R_ppml_untreated.R`, `S9R_spec_spread.R` |
| `year` | integer | `S1R_ppml_untreated.R`, `S9R_spec_spread.R` |
| `trade` | numeric | all |
| `rta` | 0/1 integer | all |
| `distance` | numeric | `S9R_spec_spread.R`, specifications (C) and (CY) |

Two properties matter and are easy to get wrong:

**Zero flows are retained.** `S9R_spec_spread.R` reports positive and zero flow
counts separately and estimates on both. `S1R_ppml_untreated.R` filters to
`trade > 0` itself. The stored file must therefore contain the zeros; if you
build it from observed positive flows only, specification (B) and (C) will not
reproduce.

**Domestic flows are retained in storage and filtered in code.** Both consuming
scripts apply `exporter != importer` themselves.

No live script in the R-chain references GDP. The Dynamic Gravity data is cited
in the paper's data description and may be required by the vendored gravity
code used in Stage 5 (`code/vendor/gravity_functions.R`, consumed by
`S46_ge_twodyad.R` and `S47_ge_gradient.R`).

> **To be verified:** whether the GE stage requires GDP columns in
> `ITPDE_total.rds` or supplies them separately. If required, add them to the
> schema table above.

## Construction

> **To be filled in.** The following steps are inferred from the consuming
> scripts and from the paper's data description. They are not a transcript of
> what was actually run, and should be replaced with one.

1. Aggregate ITPD-E to total bilateral trade by exporter, importer and year,
   summing across sectors.
2. Restrict to 1988–2019.
3. Harmonize country codes across the four sources and resolve the country set
   to the 280 reporters the paper describes.
4. Merge the Egger–Larch agreement indicator as `rta`, coded 1 from the year an
   agreement is in force.
5. Merge GeoDist bilateral distance as `distance`.
6. Rectangularize so that zero flows are present rather than missing.
7. `saveRDS()` to `data/ITPDE_total.rds`.

## Verification

A rebuild is correct if it reproduces the frozen facts that `S1R` already
asserts. After filtering to `exporter != importer & trade > 0`:

```r
d <- readRDS("data/ITPDE_total.rds")
d <- d[d$exporter != d$importer & d$trade > 0, ]
stopifnot(nrow(d) == 794720, min(d$year) == 1988, max(d$year) == 2019)
```

These are content invariants and are the right test. A rebuild that passes them
will carry the pipeline through to the ledgered gates in `README.md`.

## A note on the input SHA gate

`S1R_ppml_untreated.R` line 32 pins

```
INPUT_SHA <- "e488c36afdf7c9fd1d38667a18b7855eb39e4085430ef96eab946e2d89fe4c01"
```

and halts on mismatch. This is a hash of the *serialized object*, not of the
source data. Two people building the same table from the same sources will
produce different bytes if their R version, `saveRDS` compression setting, or
column ordering differs. As written, the gate cannot be passed by anyone who
did not receive the original file.

The gate should either be relaxed to a warning when the content invariants
above pass, or replaced by them. It is a genuine protection against silently
substituting a different input, so it should not simply be deleted — but in its
current form it makes the package unrunnable by its intended audience.

## References

Borchert, I., M. Larch, S. Shikher, and Y. V. Yotov (2021): "The International
Trade and Production Database for Estimation (ITPD-E)," *International
Economics*, 166, 140–166.

Borchert, I., M. Larch, S. Shikher, and Y. V. Yotov (2022): "The International
Trade and Production Database for Estimation — Release 2 (ITPD-E-R02)," USITC
Economics Working Paper 2022-07-A.

Egger, P., and M. Larch (2008): "Interdependent Preferential Trade Agreement
Memberships: An Empirical Analysis," *Journal of International Economics*, 76,
384–399.

Gurevich, T., and P. Herman (2018): "The Dynamic Gravity Dataset: 1948–2016,"
USITC Economics Working Paper 2018-02-A.

Mayer, T., and S. Zignago (2011): "Notes on CEPII's Distances Measures: The
GeoDist Database," CEPII Working Paper 2011-25.
