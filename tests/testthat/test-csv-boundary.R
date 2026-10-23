# Exercise real readr/vroom parsing, retaining the earlier mocked metric tests.
with_synthetic_csv_metrics <- function(files, inspect) {
  root <- tempfile("capture-csv-fixture-")
  dir.create(root)
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  dir.create(file.path(root, "01-nem-data"))
  dir.create(file.path(root, "02-analysis"))
  for (name in names(files)) readr::write_csv(files[[name]], file.path(root, "01-nem-data", name))
  env <- new.env(parent = globalenv())
  env$here <- function(...) file.path(root, "02-analysis", ...)
  # Real CSV reader: no read_csv override is installed in this environment.
  for (expr in metric_expressions()) eval(expr, envir = env)
  inspect(env)
}

test_that("real synthetic CSV parsing preserves dates, signed prices and GWh units", {
  x <- synthetic_metrics()
  x$`Wind - Market Value - AUD` <- c(-10000, 120000)
  with_synthetic_csv_metrics(list("20250101 New South Wales.csv" = x), function(env) {
    wind <- filter(env$long_df_all, Source == "Wind", Method == "excluding-curtailment")
    expect_s3_class(wind$Date, "Date")
    expect_equal(wind$Date, as.Date(c("2025-01-01", "2025-02-01")))
    expect_equal(wind$CapturePrice, c(-10, 60))
    expect_equal(wind$CaptureRatio, c(-0.25, 1.2))
    expect_equal(nrow(env$long_df_all), 56L)
  })
})

test_that("real synthetic CSV fallback and optional missing columns retain weighting", {
  x <- synthetic_metrics()
  x$`Volume Weighted Price - AUD/MWh` <- NULL
  x$`Wind (Curtailment) - GWh` <- NULL
  x$`Solar (Utility) (Curtailment) - GWh` <- NULL
  with_synthetic_csv_metrics(list("20250101 Open Electricity.csv" = x), function(env) {
    expect_equal(env$benchmark_prices$BenchmarkPrice, c(40, 50))
    wind <- filter(env$long_df_all, Source == "Wind")
    expect_equal(wind$CapturePrice, c(50, 50, 60, 60))
    expect_true(all(as.character(wind$Region) == "NEM"))
  })
})
