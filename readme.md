# capture\_price

This repository contains code to calculate and visualise 12‑month rolling capture prices (in \$/MWh) for various generation technologies in the Australian National Electricity Market (NEM) and individual regions.

## Description

The main analysis script reads monthly generation and market value data from CSV exports provided by the Australian Energy Market Operator (AEMO). It computes the capture price for each technology (market value divided by generation in MWh), applies a 12‑month rolling average, and generates time‑series plots either across all regions or within a specific region.

**Data source:** AEMO monthly generation and market value reports (date‑prefixed CSV files in `01‑nem‑data/`).

## Examples

* **Utility-scale solar capture price**
  ![Utility-scale Solar](https://raw.githubusercontent.com/EconomistMike/capture_price/main/03-outputs/Solar_Utility_.png)

* **Wind capture price**
  ![Wind capture price](https://raw.githubusercontent.com/EconomistMike/capture_price/main/03-outputs/Wind.png)

## Usage

1. Clone the repository:

   ```bash
   git clone https://github.com/EconomistMike/capture_price.git
   cd capture_price
   ```
2. Restore R package environment:

   ```r
   renv::restore()
   ```
3. Run the analysis:

   ```bash
   quarto render 02-analysis/capture_price.qmd
   ```
4. View the generated plots in `03-outputs/`.