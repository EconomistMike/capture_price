# Opt-in capture export checks

```r
source("checks/capture-input.R")
issues <- capture_input_issues(export_table, region = "New South Wales")
assert_capture_input(export_table, region = "New South Wales")
```

`export_table` is an already loaded table. The checker performs no I/O, does not change its inputs, and is not wired into the collector or QMD. It returns `row`, `field` and `message` diagnostics; the assertion raises `capture_input_error` with `$issues`. Source it explicitly before processing exports if this analytical policy is appropriate.

The supported schema has `Date` first (unique, real ISO dates), one exact `<technology> - GWh` and `<technology> - Market Value - AUD` heading for each present technology, and a supported region name. Technologies can be absent entirely. Present pairs must have matching missingness, at least one finite pair must exist per date, and generation must be non-negative. A zero generation/value pair is accepted; zero generation with a non-zero value requires review. Prices and market values can be negative or zero. Numeric columns reject text, infinities and NaN; paired NA is accepted. Optional source VW prices and wind/utility-solar curtailment are checked when present; negative curtailment is rejected before the QMD can clamp it. All whitespace variants recognised by the QMD are discovered, and noncanonical or ambiguous curtailment headings require review.

This deliberately narrow schema catches ambiguous headings, `AUD million` headings, mismatched fallback populations and unknown regions. It is an analytical contract, not an official Open Electricity schema validator. A rejected heading can be a legitimate export variant requiring an explicit adapter. Declared units cannot establish that an amount is truly in those units. The checker cannot establish source provenance, export-window duration, complete technology coverage, dispatch intervals, or equality of benchmarks across separate files for the same normalised region. It does not validate generated charts.

The production fallback still independently sums value and generation with `na.rm = TRUE`; missing market values can bias the benchmark downwards or produce zero. The QMD still accepts duplicate dates, ambiguous column matches and unknown regions, and clips negative capture prices in one chart. These are unresolved production risks. Passing this check protects only the stated policy, and it has no effect unless a caller invokes it. Existing calculation tests continue to run unchanged.
