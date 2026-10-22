test_that("GWh converts to MWh once and regional joins retain row cardinality", {
  with_synthetic_metrics(list("20250101 New South Wales.csv" = synthetic_metrics()), function(env) {
    wind <- filter(env$long_df_all, Source == "Wind", Method == "excluding-curtailment")
    expect_equal(wind$CapturePrice, c(50, 60))
    expect_equal(wind$CaptureRatio, c(1.25, 1.2))
    expect_equal(as.character(wind$Region), rep("New South Wales", 2))
    expect_equal(nrow(env$all_metrics), 2L * 14L)
    expect_equal(nrow(env$long_df_all), 2L * nrow(env$all_metrics))
    expect_equal(nrow(env$benchmark_prices), 2L)
  })
})

test_that("curtailment changes only wind and utility solar denominators", {
  with_synthetic_metrics(list("20250101 Open Electricity.csv" = synthetic_metrics()), function(env) {
    jan <- filter(env$long_df_all, Date == as.Date("2025-01-01"))
    adjusted <- filter(jan, Method == "including-curtailment")
    expect_equal(adjusted$CapturePrice[adjusted$Source == "Wind"], 25)
    expect_equal(adjusted$CapturePrice[adjusted$Source == "Solar (Utility)"], 22.5)
    expect_equal(adjusted$CapturePrice[adjusted$Source == "Hydro"], 60)
    expect_true(all(as.character(jan$Region) == "NEM"))
    expect_equal(adjusted$BenchmarkPrice[adjusted$Source == "Wind"], 40)
  })
})

test_that("a complete fallback uses aggregate value divided by aggregate energy", {
  data <- synthetic_metrics()
  data$`Volume Weighted Price - AUD/MWh` <- NULL
  with_synthetic_metrics(list("20250101 New South Wales.csv" = data), function(env) {
    # January has 200000 invented dollars and 5 invented GWh: 40 AUD/MWh.
    expect_equal(env$benchmark_prices$BenchmarkPrice, c(40, 50))
    expect_false(isTRUE(all.equal(40, mean(c(50, 30, 60)))))
  })
})

test_that("zero and negative prices remain signed and zero volume is undefined", {
  data <- synthetic_metrics()
  data$`Wind - Market Value - AUD` <- c(-10000, 0)
  data$`Hydro - GWh` <- c(0, 0)
  with_synthetic_metrics(list("20250101 New South Wales.csv" = data), function(env) {
    wind <- filter(env$long_df_all, Source == "Wind", Method == "excluding-curtailment")
    expect_equal(wind$CapturePrice, c(-10, 0))
    hydro <- filter(env$long_df_all, Source == "Hydro")
    expect_true(all(is.na(hydro$CapturePrice)))
    expect_false(any(is.infinite(env$long_df_all$CapturePrice)))
  })
})

test_that("absent curtailment columns leave both methods equivalent", {
  data <- synthetic_metrics()
  data$`Wind (Curtailment) - GWh` <- NULL
  data$`Solar (Utility) (Curtailment) - GWh` <- NULL
  with_synthetic_metrics(list("20250101 New South Wales.csv" = data), function(env) {
    a <- filter(env$long_df_all, Method == "excluding-curtailment")
    b <- filter(env$long_df_all, Method == "including-curtailment")
    expect_equal(a$CapturePrice, b$CapturePrice)
  })
})

test_that("the latest filename date wins within each region", {
  old <- synthetic_metrics()
  old$`Wind - Market Value - AUD` <- c(10000, 10000)
  with_synthetic_metrics(list("20240101 New South Wales.csv" = old,
    "20250101 New South Wales.csv" = synthetic_metrics()), function(env) {
      expect_length(env$files, 1L)
      expect_equal(basename(env$files), "20250101 New South Wales.csv")
      wind <- filter(env$long_df_all, Source == "Wind", Method == "excluding-curtailment")
      expect_equal(wind$CapturePrice, c(50, 60))
  })
})

test_that("benchmark joins isolate regions that share the same dates", {
  qld <- synthetic_metrics()
  qld$`Volume Weighted Price - AUD/MWh` <- c(80, 100)
  qld$`Wind - Market Value - AUD` <- c(80000, 240000)
  with_synthetic_metrics(list("20250101 New South Wales.csv" = synthetic_metrics(),
    "20250101 Queensland.csv" = qld), function(env) {
      wind <- filter(env$long_df_all, Source == "Wind", Method == "excluding-curtailment")
      nsw <- filter(wind, Region == "New South Wales")
      qld_out <- filter(wind, Region == "Queensland")
      expect_equal(nsw$BenchmarkPrice, c(40, 50))
      expect_equal(qld_out$BenchmarkPrice, c(80, 100))
      expect_equal(qld_out$CaptureRatio, c(1, 1.2))
      expect_equal(nrow(env$benchmark_prices), 4L)
      expect_equal(nrow(env$all_metrics), 56L)
      expect_equal(nrow(env$long_df_all), 112L)
    })
})

test_that("zero and negative benchmark prices retain undefined and signed ratios", {
  data <- synthetic_metrics()
  data$`Volume Weighted Price - AUD/MWh` <- c(0, -50)
  with_synthetic_metrics(list("20250101 New South Wales.csv" = data), function(env) {
    wind <- filter(env$long_df_all, Source == "Wind", Method == "excluding-curtailment")
    expect_true(is.na(wind$CaptureRatio[1]))
    expect_equal(wind$CaptureRatio[2], -1.2)
    expect_false(any(is.infinite(env$long_df_all$CaptureRatio)))
  })
})
