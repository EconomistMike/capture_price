source(testthat::test_path("..", "..", "checks", "capture-input.R"))

expect_capture_issue <- function(data, field, region = "New South Wales") {
  issues <- capture_input_issues(data, region)
  expect_true(any(issues$field == field), info = field)
  expect_error(assert_capture_input(data, region), class = "capture_input_error")
}

test_that("complete invented exports pass unchanged, including signed prices", {
  x <- synthetic_metrics()
  before <- serialize(x, NULL)
  expect_equal(nrow(capture_input_issues(x, "New South Wales")), 0L)
  expect_true(assert_capture_input(x, "Open Electricity"))
  expect_identical(serialize(x, NULL), before)
  x$`Wind - Market Value - AUD` <- c(-10000, 0)
  x$`Volume Weighted Price - AUD/MWh` <- c(-20, 0)
  expect_true(assert_capture_input(x, "Western Australia (SWIS)"))
})

test_that("supported export schema rejects ambiguous headings and currency scales", {
  x <- synthetic_metrics(); names(x)[2] <- names(x)[3]
  expect_capture_issue(x, "columns")
  x <- synthetic_metrics(); x$`Wind - extra GWh` <- c(1, 2)
  expect_capture_issue(x, "Wind")
  x <- synthetic_metrics(); names(x)[3] <- "Wind - Market Value - AUD million"
  expect_capture_issue(x, "Wind")
  x <- synthetic_metrics(); x$`Wind - Market Value - AUD` <- NULL
  expect_capture_issue(x, "Wind")
  expect_capture_issue(data.frame(Date = "2025-01-01"), "technologies")
  expect_capture_issue("not a table", "schema")
})

test_that("dates must be real unique ISO dates in the first column", {
  for (bad in c("2025-02-30", "01/02/2025", "2025-01-01 trailing", NA_character_)) {
    x <- synthetic_metrics(); x$Date[1] <- bad
    expect_capture_issue(x, "Date")
  }
  x <- synthetic_metrics(); x$Date[2] <- x$Date[1]
  expect_capture_issue(x, "Date")
  x <- synthetic_metrics()[c(2, 1, 3:10)]
  expect_capture_issue(x, "Date")
  x <- synthetic_metrics(); x$Date <- as.Date(x$Date)
  expect_true(assert_capture_input(x, "NEM"))
  expect_capture_issue(x[FALSE, ], "rows")
})

test_that("unknown or missing regions cannot collapse into an NA factor group", {
  for (region in list("Invented region", NA_character_, c("NEM", "Queensland"), character())) {
    expect_capture_issue(synthetic_metrics(), "Region", region)
  }
})

test_that("energy and market value must cover the same observations", {
  x <- synthetic_metrics(); x$`Wind - Market Value - AUD`[1] <- NA_real_
  expect_capture_issue(x, "Wind")
  x <- synthetic_metrics(); x$`Wind - GWh`[1] <- NA_real_
  expect_capture_issue(x, "Wind")
  x <- synthetic_metrics()
  for (field in grep("Market Value", names(x), value = TRUE)) x[[field]][] <- NA_real_
  expect_capture_issue(x, "coverage")
  x <- synthetic_metrics(); x$`Wind - GWh`[1] <- NA_real_
  x$`Wind - Market Value - AUD`[1] <- NA_real_
  expect_true(assert_capture_input(x, "Queensland"))
})

test_that("numeric columns reject non-finite values, text and negative energy", {
  for (bad in list(-1, Inf, NaN, "1 GWh")) {
    x <- synthetic_metrics(); x$`Wind - GWh`[1] <- bad
    expect_capture_issue(x, "Wind - GWh")
  }
  for (bad in list(Inf, NaN, "50000 AUD")) {
    x <- synthetic_metrics(); x$`Wind - Market Value - AUD`[1] <- bad
    expect_capture_issue(x, "Wind - Market Value - AUD")
  }
  x <- synthetic_metrics(); x$`Volume Weighted Price - AUD/MWh`[1] <- Inf
  expect_capture_issue(x, "Volume Weighted Price - AUD/MWh")
  x <- synthetic_metrics(); x$`Wind (Curtailment) - GWh`[1] <- -1
  expect_capture_issue(x, "Wind (Curtailment) - GWh")
})

test_that("absent optional columns and zero generation have explicit supported meanings", {
  x <- synthetic_metrics()
  x$`Volume Weighted Price - AUD/MWh` <- NULL
  x$`Wind (Curtailment) - GWh` <- NULL
  x$`Solar (Utility) (Curtailment) - GWh` <- NULL
  x$`Wind - GWh` <- c(0, 0); x$`Wind - Market Value - AUD` <- c(0, 0)
  expect_true(assert_capture_input(x, "Queensland"))
  x$`Wind - Market Value - AUD`[1] <- 1
  expect_capture_issue(x, "Wind")
})

test_that("checks accept data before actual QMD calculations without changing the maths", {
  x <- synthetic_metrics()
  expect_true(assert_capture_input(x, "New South Wales"))
  with_synthetic_metrics(list("20250101 New South Wales.csv" = x), function(env) {
    wind <- filter(env$long_df_all, Source == "Wind", Method == "including-curtailment")
    expect_equal(wind$CapturePrice, c(25, 48))
    expect_equal(wind$CaptureRatio, c(0.625, 0.96))
  })
})

test_that("all QMD-recognised curtailment headings must be canonical and unique", {
  for (canonical in c("Wind (Curtailment) - GWh", "Solar (Utility) (Curtailment) - GWh")) {
    for (gap in c("", "  ", "\t")) {
      variant <- sub(" - GWh", paste0(" -", gap, "GWh"), canonical, fixed = TRUE)
      x <- synthetic_metrics(); names(x)[names(x) == canonical] <- variant
      expect_capture_issue(x, canonical)
      x[[variant]][1] <- -1
      expect_capture_issue(x, canonical)
      x <- synthetic_metrics(); x[[variant]] <- x[[canonical]]
      expect_capture_issue(x, canonical)
    }
  }
})

test_that("diagnostics preserve rows and are carried by the assertion condition", {
  x <- synthetic_metrics(); x$`Wind - GWh`[2] <- -1
  issues <- capture_input_issues(x, "New South Wales")
  expect_equal(issues$row[issues$field == "Wind - GWh"], 2L)
  condition <- tryCatch(assert_capture_input(x, "New South Wales"), capture_input_error = identity)
  expect_identical(condition$issues, issues)
  x <- synthetic_metrics(); x$`Wind - GWh` <- c(1+1i, 2+0i)
  expect_capture_issue(x, "Wind - GWh")
})


test_that("malformed technology presence cannot hide behind another complete pair", {
  for (heading in c("Wind - MWh", "Wind - GWh ")) {
    x <- synthetic_metrics()
    names(x)[names(x) == "Wind - GWh"] <- heading
    x$`Wind - Market Value - AUD` <- NULL
    expect_capture_issue(x, "Wind")
    expect_false(any(capture_input_issues(x, "New South Wales")$field == "coverage"))
  }
  x <- synthetic_metrics()
  x$`Wind - GWh` <- NULL
  x$`Wind - Market Value - AUD` <- NULL
  expect_true(assert_capture_input(x, "New South Wales"))
})
