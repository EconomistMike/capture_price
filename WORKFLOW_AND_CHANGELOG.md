# Workflow and Changelog

## Project Workflow

1. **Fetch source CSV files**
   - Script: `01-nem-data/fetch_nem_data.py`
   - Downloads monthly rolling exports for NEM and regions into `01-nem-data/`.

2. **Render analysis and plots**
   - Command: `quarto render 02-analysis/capture_price.qmd`
   - Analysis file: `02-analysis/capture_price.qmd`
   - The analysis automatically selects the latest file per region using filename date (YYYYMMDD prefix) and modified time.

3. **Generate two methodology output sets**
   - `03-outputs/excluding-curtailment/`
     - Original method.
     - Capture price denominator uses reported generation only.
   - `03-outputs/including-curtailment/`
     - Curtailment-adjusted method.
     - For `Wind` and `Solar (Utility)`, denominator includes curtailed generation (`Wind (Curtailment)` and `Solar (Utility) (Curtailment)` GWh).
     - Relevant wind/solar charts include a caption noting this treatment.

4. **Outputs produced**
   - Capture price by technology across regions.
   - Capture ratio by technology across regions.
   - Capture ratio panels by region across technologies.

## Notes on Methodology

- `CapturePrice = MarketValueAUD / (EffectiveEnergyGWh * 1000)`
- `CaptureRatio = CapturePrice / BenchmarkPrice`
- `BenchmarkPrice` preference order:
  1. Source `Volume Weighted Price - AUD/MWh` when available.
  2. Fallback implied benchmark from aggregate market value divided by aggregate generation.

## Changelog

## 2026-02-13

- Added dual-method output architecture in `02-analysis/capture_price.qmd`:
  - `excluding-curtailment` (original),
  - `including-curtailment` (wind and utility solar adjusted for curtailment).
- Added curtailment column handling for variable file schemas:
  - Missing curtailment columns default to zero,
  - Curtailment values are clamped at non-negative when used in denominator adjustments.
- Added method-specific output folders under `03-outputs/`.
- Added curtailment method caption to wind/solar charts in the including-curtailment outputs.
- Verified successful render and output generation for both methods via Quarto.
- Archived legacy root-level `03-outputs/*` artifacts into `03-outputs/_legacy-root/`.
- Updated `readme.md` usage and outputs documentation to point to method-specific subfolders.
- Flattened project structure so `11.34 Capture Price/` is now the canonical repository root.
- Added `archive/legacy-top-level-20260213/` snapshot with selected pre-reorg legacy assets.
