# Data Sources and Construction

Stage 1 of the pipeline in `README.md` begins with

```bash
Rscript code/S1R_ppml_untreated.R
```

which opens by hashing `data/ITPDE_total.rds` and calling `stop()` if the file
is absent or does not match. That path is empty in a fresh clone, and
`meta/FILE_REGISTRY.csv` records the file as `external` with status `ANCHOR`,
which reads as though it were not distributed.

**It is distributed.** The file is committed at
`archive/retired_pack/data/ITPDE_total.rds` (15.2 MB), and its SHA256 is
`e488c36afdf7c9fd1d38667a18b7855eb39e4085430ef96eab946e2d89fe4c01` — the value
`S1R_ppml_untreated.R` pins. Before running Stage 1:

```bash
cp archive/retired_pack/data/ITPDE_total.rds data/ITPDE_total.rds
sha256sum data/ITPDE_total.rds
# e488c36afdf7c9fd1d38667a18b7855eb39e4085430ef96eab946e2d89fe4c01
```

That is the whole of the setup. The rest of this document records where the
data came from, what the file contains, and how to verify a rebuild for anyone
reconstructing it from source rather than using the distributed copy.

## Provenance

| Variable | Source | Citation |
|----------|--------|----------|
| Bilateral trade | International Trade and Production Database for Estimation, Release 2 | Borchert et al. (2021, 2022) |
| Bilateral trade agreements | Egger and Larch RTA database | Egger and Larch (2008) |
| Bilateral distance | GeoDist | Mayer and Zignago (2011) |
| Gross domestic product | Dynamic Gravity Dataset | Gurevich and Herman (2018) |

ITPD-E was retrieved from the USITC gravity portal,
<https://www.usitc.gov/data/gravity/gravity_portal_itpd_e>, on 2 July 2022.
After excluding domestic flows the panel covers 280 countries over 1988–2019.

GDP enters the general-equilibrium stage as a computed quantity rather than as
a column of `ITPDE_total.rds`: expenditures and income are constructed from the
trade flows themselves in `code/vendor/gravity_functions.R`. The Dynamic
Gravity citation covers the country-level scaffolding, not an input variable
the consuming scripts read.

Country-code harmonization and the resolution of the country set are carried
out in the construction code rather than described here; see the pipeline
scripts for the operative definitions.

## Schema

`data/ITPDE_total.rds` is an R serialization of a rectangular table. The live
chain reads the following columns.

| Column | Type | Used by |
|--------|------|---------|
| `exporter` | character | `S1R_ppml_untreated.R`, `S9R_spec_spread.R` |
| `importer` | character | `S1R_ppml_untreated.R`, `S9R_spec_spread.R` |
| `year` | integer | `S1R_ppml_untreated.R`, `S9R_spec_spread.R` |
| `trade` | numeric | all |
| `rta` | 0/1 integer | all |
| `distance` | numeric | `S9R_spec_spread.R`, specifications (C) and (CY) |

Two properties matter if the file is ever rebuilt:

**Zero flows are retained in storage.** `S9R_spec_spread.R` reports positive and
zero flow counts separately and estimates on both. `S1R_ppml_untreated.R`
filters to `trade > 0` itself. A file built from observed positive flows only
reproduces Stage 1 but not specifications (B) and (C).

**Domestic flows are retained in storage.** Both consuming scripts apply
`exporter != importer` themselves.

## Verifying a rebuild

A reconstruction from source is correct if it reproduces the frozen facts that
`S1R_ppml_untreated.R` already asserts at line 44. After filtering:

```r
d <- readRDS("data/ITPDE_total.rds")
d <- d[d$exporter != d$importer & d$trade > 0, ]
stopifnot(nrow(d) == 794720, min(d$year) == 1988, max(d$year) == 2019)
```

These are content invariants and are the right test for a rebuild. The
`INPUT_SHA` gate above them hashes the serialized object, so a rebuild will not
match it even when correct: R version, `saveRDS` compression and column order
all change the bytes. That gate is intended for the distributed file, where it
is exact and should be kept. Anyone rebuilding from source should expect it to
fail and should satisfy the content invariants instead.

## Note on the existence allowlist

`meta/EXISTENCE_ALLOWLIST.txt` lists `data/ITPDE_total.rds` with the comment
that it is "too large (>10 MB) to commit." The file is in fact committed, under
`archive/retired_pack/`. The allowlist entry is still correct in effect —
`data/ITPDE_total.rds` is absent from a fresh clone until the copy step above —
but the stated reason is not.

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
