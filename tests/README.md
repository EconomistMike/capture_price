# Synthetic checks

From the repository root, run:

```sh
Rscript --vanilla tests/run-tests.R
```

The suite uses `testthat` and the analysis libraries in a compatible existing R environment. It never restores packages, downloads inputs, runs a collector, invokes `tar_make()` or starts Shiny. Use `--vanilla` to avoid the project profile bootstrapping `renv` during verification. On a busy host, prefix the command with `nice -n 10`.

All observations are fabricated. Passing these checks protects the listed examples; it does not establish the correctness of real source data or resolve every known methodological risk.

Dependencies: `testthat`, `readr`, `dplyr`, `stringr`, `tidyr`, `lubridate`, `purrr`, `tibble`.

The helper parses and executes the existing “Data And Metrics” R chunk through `long_df_all`, stopping before output-directory creation and plotting. The `here()` root is redirected to a temporary fixture tree, and `read_csv()` returns fabricated in-memory tables keyed by the placeholder filenames. Column matching, method expansion, benchmark construction and joins use the actual analysis code. CSV parsing is mocked and unverified; this avoids requiring a compatible compiled `vroom` dependency for calculation tests. Tests cover GWh/MWh scaling, signed prices, zero generation, aggregate weighting with complete inputs, curtailment denominators, absent curtailment latest-export selection, region-specific benchmark joins, and zero/negative benchmark ratios. No plotting packages or real exports are needed.

Open risks outside this suite: mismatched value/energy missingness in the fallback benchmark; duplicate or malformed dates; ambiguous column matches; unknown regions becoming NA; export-window provenance; and plotting that clips negative prices. Missing curtailment currently means zero; equivalence here records that documented convention and does not prove missing values are physically zero. The input fixtures represent already aggregated export windows; the R code does not construct a rolling 12-month sum itself.

The helper requires the named section, a unique output boundary, and `long_df_all` as the last selected assignment. Review this extraction contract when the QMD changes; it is not a general sandbox for arbitrary R code.
