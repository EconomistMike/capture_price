library(readr)
library(dplyr)
library(stringr)
library(tidyr)
library(lubridate)
library(purrr)

metric_expressions <- function() {
  path <- testthat::test_path("..", "..", "02-analysis", "capture_price.qmd")
  lines <- readLines(path, warn = FALSE)
  section <- which(lines == "## Data And Metrics")
  stopifnot(length(section) == 1L)
  start <- which(seq_along(lines) > section & lines == "```{r}")[1]
  end <- which(seq_along(lines) > start & lines == "```")[1]
  exprs <- parse(text = lines[seq.int(start + 1L, end - 1L)])
  writes <- which(vapply(exprs, function(x) is.call(x) && identical(x[[1]], as.name("<-")) &&
    identical(x[[2]], as.name("out_dir")), logical(1)))
  stopifnot(length(writes) == 1L)
  selected <- exprs[seq_len(writes - 1L)]
  last <- selected[[length(selected)]]
  stopifnot(is.call(last), identical(last[[1]], as.name("<-")),
    identical(last[[2]], as.name("long_df_all")))
  selected
}

with_synthetic_metrics <- function(files, inspect) {
  root <- tempfile("capture-fixture-")
  dir.create(root)
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  dir.create(file.path(root, "01-nem-data"))
  dir.create(file.path(root, "02-analysis"))
  for (name in names(files)) file.create(file.path(root, "01-nem-data", name))
  env <- new.env(parent = globalenv())
  env$here <- function(...) file.path(root, "02-analysis", ...)
  # Mock only the CSV boundary; downstream calculations use the QMD code.
  env$read_csv <- function(file, show_col_types = FALSE) files[[basename(file)]]
  for (expr in metric_expressions()) eval(expr, envir = env)
  inspect(env)
}

synthetic_metrics <- function() {
  tibble::tibble(Date = c("2025-01-01", "2025-02-01"),
    `Wind - GWh` = c(1, 2), `Wind - Market Value - AUD` = c(50000, 120000),
    `Wind (Curtailment) - GWh` = c(1, 0.5),
    `Solar (Utility) - GWh` = c(3, 4),
    `Solar (Utility) - Market Value - AUD` = c(90000, 160000),
    `Solar (Utility) (Curtailment) - GWh` = c(1, 0),
    `Hydro - GWh` = c(1, 1), `Hydro - Market Value - AUD` = c(60000, 70000),
    `Volume Weighted Price - AUD/MWh` = c(40, 50))
}
