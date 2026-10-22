# Synthetic checks

From the repository root, run:

```sh
Rscript --vanilla tests/run-tests.R
```

The suite uses `testthat` and the analysis libraries in a compatible existing R environment. It never restores packages, downloads inputs, runs a collector, invokes `tar_make()` or starts Shiny. Use `--vanilla` to avoid the project profile bootstrapping `renv` during verification. On a busy host, prefix the command with `nice -n 10`.

All observations are fabricated. Passing these checks protects the listed examples; it does not establish the correctness of real source data or resolve every known methodological risk.

Dependencies: `testthat`, `readr`, `dplyr`, `stringr`, `tidyr`, `lubridate`, `purrr`, `tibble`.

The helper parses and executes the existing “Data And Metrics” R chunk through `long_df_all`, stopping before output-directory creation and plotting. The `here()` root is redirected to a temporary fixture tree, and `read_csv()` returns fabricated in-memory tables keyed by the placeholder filenames. Column matching, method expansion, benchmark construction and joins use the actual analysis code. These in-memory calculation tests mock CSV parsing; separate CSV-boundary tests below exercise the real compiled `vroom` reader. Tests cover GWh/MWh scaling, signed prices, zero generation, aggregate weighting with complete inputs, curtailment denominators, absent curtailment latest-export selection, region-specific benchmark joins, and zero/negative benchmark ratios. No plotting packages or real exports are needed.

Remaining production risks: mismatched value/energy missingness in the fallback benchmark; duplicate or malformed dates; ambiguous column matches; unknown regions becoming NA; export-window provenance; and plotting that clips negative prices. Missing curtailment currently means zero; equivalence here records that documented convention and does not prove missing values are physically zero. The input fixtures represent already aggregated export windows; the R code does not construct a rolling 12-month sum itself.

The helper requires the named section, a unique output boundary, and `long_df_all` as the last selected assignment. Review this extraction contract when the QMD changes; it is not a general sandbox for arbitrary R code.

The follow-up `test-input-quality.R` specifies the opt-in export policy in `checks/capture-input.R`, including valid and invalid schemas, units, dates, regions, paired coverage, numeric values and zero-generation consistency. See `checks/README.md` for limitations. A supported fixture also executes the QMD after validation; this does not wire the check into production. The complete command used on CISBox3 (whose `Rscript` wrapper does not support `--vanilla`) is:

```sh
nice -n 10 R --vanilla --slave --file=tests/run-tests.R
```

`test-csv-boundary.R` additionally writes fabricated temporary CSVs and executes the same QMD metric expressions using the real `readr::read_csv()` (including compiled `vroom`). It covers dates, signed arithmetic, row counts, complete fallback weighting and absent optional columns. The earlier in-memory calculation tests retain their explicit CSV mock; CSV parsing is now covered separately. No pre-existing export is read.
