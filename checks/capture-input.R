# Opt-in analytical checks for the export schema used by capture_price.qmd.
# No I/O, coercion of inputs, collectors or pipeline changes.
capture_input_issues <- function(data, region) {
  issues <- data.frame(row = integer(), field = character(), message = character())
  add <- function(field, message, rows = NA_integer_) {
    if (length(rows)) issues <<- rbind(issues, data.frame(row = as.integer(rows), field = field, message = message))
  }
  regions <- c("New South Wales", "Queensland", "South Australia", "Tasmania", "Victoria",
    "Western Australia", "Western Australia (SWIS)", "NEM", "Open Electricity")
  if (!is.character(region) || length(region) != 1L || is.na(region) || !region %in% regions) {
    add("Region", "Supply one supported region; unknown regions become NA in the analysis.")
  }
  if (!is.data.frame(data)) {
    add("schema", "Expected an export data frame.")
    return(issues)
  }
  if (anyNA(names(data)) || any(names(data) == "") || anyDuplicated(names(data))) {
    add("columns", "Column names must be present and unique.")
    return(issues)
  }
  if (!nrow(data)) add("rows", "The export has no observations.")
  if (!length(names(data)) || names(data)[1] != "Date") {
    add("Date", "The supported export requires Date as its first column.")
  } else {
    x <- data$Date
    valid_type <- (is.character(x) || inherits(x, "Date")) && is.null(dim(x))
    if (!valid_type) {
      add("Date", "Expected ISO date strings or a Date vector.")
    } else {
      txt <- as.character(x)
      parsed <- suppressWarnings(as.Date(txt, format = "%Y-%m-%d"))
      bad <- is.na(x) | !grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", txt) | is.na(parsed) |
        format(parsed, "%Y-%m-%d") != txt
      bad[is.na(bad)] <- TRUE
      add("Date", "Expected real, non-missing ISO dates.", which(bad))
      add("Date", "Duplicate observation dates require review before aggregation.", which(duplicated(x)))
    }
  }
  number <- function(field, nonnegative = FALSE) {
    x <- data[[field]]
    if (!is.numeric(x) || is.complex(x) || !is.null(dim(x))) {
      add(field, "Expected a numeric vector in the declared unit.")
      return(FALSE)
    }
    bad <- is.nan(x) | (!is.na(x) & (!is.finite(x) | (nonnegative & x < 0)))
    add(field, "Expected finite values (or NA); energy must be non-negative.", which(bad))
    TRUE
  }
  technologies <- c("Coal (Brown)", "Coal (Black)", "Bioenergy (Biomass)", "Battery (Discharging)",
    "Distillate", "Gas (Steam)", "Gas (CCGT)", "Gas (OCGT)", "Gas (Reciprocating)",
    "Gas (Waste Coal Mine)", "Hydro", "Wind", "Solar (Utility)", "Solar (Rooftop)")
  covered <- rep(FALSE, nrow(data)); present <- 0L
  for (tech in technologies) {
    # Match the QMD's broad candidates, then require the supported exact units.
    prefix <- startsWith(names(data), paste0(tech, " -"))
    energy <- names(data)[prefix & grepl("GWh$", names(data))]
    value <- names(data)[startsWith(names(data), tech) & grepl("Market Value", names(data), fixed = TRUE)]
    if (!length(energy) && !length(value)) next
    present <- present + 1L
    e <- paste0(tech, " - GWh"); v <- paste0(tech, " - Market Value - AUD")
    if (!identical(energy, e) || !identical(value, v)) {
      add(tech, "Require one exact GWh energy column and one Market Value - AUD column; review ambiguous/scaled headings.")
      next
    }
    e_ok <- number(e, TRUE); v_ok <- number(v)
    if (e_ok && v_ok) {
      en <- data[[e]]; val <- data[[v]]
      add(tech, "Energy and value missingness differ; the fallback would sum different populations.",
        which(xor(is.na(en), is.na(val))))
      add(tech, "Non-zero market value with zero generation needs an explicit policy.",
        which(!is.na(en) & !is.na(val) & en == 0 & val != 0))
      covered <- covered | (is.finite(en) & is.finite(val))
    }
  }
  if (!present) add("technologies", "No supported energy/value technology pair is present.")
  add("coverage", "No complete finite energy/value pair exists for this date.", which(!covered))
  vw <- "Volume Weighted Price - AUD/MWh"
  if (vw %in% names(data)) number(vw)
  curtailment_patterns <- c(
    "Wind (Curtailment) - GWh" = "^Wind \\(Curtailment\\) -\\s*GWh$",
    "Solar (Utility) (Curtailment) - GWh" = "^Solar \\(Utility\\) \\(Curtailment\\) -\\s*GWh$"
  )
  for (canonical in names(curtailment_patterns)) {
    candidates <- grep(curtailment_patterns[[canonical]], names(data), value = TRUE)
    if (!length(candidates)) next
    if (!identical(candidates, canonical)) {
      add(canonical, "Require one canonical curtailment heading; review variants or ambiguous columns consumed by the QMD.")
    } else {
      number(canonical, nonnegative = TRUE)
    }
  }
  rownames(issues) <- NULL
  issues
}

assert_capture_input <- function(data, region) {
  issues <- capture_input_issues(data, region)
  if (nrow(issues)) stop(structure(list(message = paste(nrow(issues), "capture input issue(s); inspect condition$issues."),
    call = NULL, issues = issues), class = c("capture_input_error", "error", "condition")))
  invisible(TRUE)
}
