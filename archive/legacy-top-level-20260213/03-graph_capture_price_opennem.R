library(dplyr)
library(tidyr)
library(stringr)
library(ggplot2)
library(ggrepel)
library(patchwork)
library(glue)
library(here)

my_font_size = 9

latest_raw_csv <- function(pattern) {
  files <- list.files(here("01-raw-data"), pattern = pattern, full.names = TRUE)
  if (length(files) == 0) {
    stop(glue("No raw input files matched pattern: {pattern}"))
  }

  # Prefer filesystem modified time (most recently downloaded), then fall back
  # to the leading YYYYMMDD in the filename when present.
  file_dates <- str_match(basename(files), "^([0-9]{8})\\s+")[, 2]
  parsed_dates <- suppressWarnings(lubridate::ymd(file_dates))
  mtimes <- as.POSIXct(file.info(files)$mtime)

  ord <- order(mtimes, parsed_dates, na.last = TRUE)
  files[tail(ord, 1)]
}

# Source https://explore.openelectricity.org.au/energy/nem/?range=all-12-mth-rolling&interval=1M&view=discrete-time&group=Detailed
# Files were sourced from explore.openelectricity.org.au link above on 26 Nov 2024.
# Set time period to ALL / 12Mth rolling; and interview to month.
# For SA, change region to SA first.
# 
# "19991201 Open Electricity.csv",
# "19991201 South Australia.csv",

save_capture_graph <- function(file, region){
  df <- read.csv(file, fileEncoding = "UTF-8-BOM") |>
    janitor::clean_names() |> 
    select(
      date,
      volume_weighted_price_aud_m_wh,
      ends_with("value_aud"),
      ends_with("g_wh")) |>
    pivot_longer(cols = !c(date, volume_weighted_price_aud_m_wh)) |>
    separate_wider_regex(name, c(tech = ".*", "_", var = "(?:market_value_aud)|(?:g_wh)$")) |>
    pivot_wider(id_cols = c(date, tech, volume_weighted_price_aud_m_wh), names_from = var, values_from = value) |> 
    mutate(
      date = lubridate::ymd(date),
      tech = str_replace(tech, "^solar$", "solar_utility"),
      tech_type = case_when(
        str_starts(tech, "(solar|wind)") ~ "renewable",
        str_starts(tech, "(coal|gas)")  ~ "fossil fuel",
        .default = "other"),
      highlight = tech %in% c("wind", "solar_utility", "solar_rooftop"),
      opacity = case_when(
        highlight ~ 1,
        .default = 0.25
      )
    )

  if (min(df$date, na.rm = TRUE) < lubridate::ymd("1999-01-01")) {
    warning(glue(
      "{basename(file)} starts at {min(df$date, na.rm = TRUE)}; this looks like a non-rolling export. " ,
      "For charts matching prior outputs, export with range=all-12-mth-rolling and interval=1M."
    ))
  }

  # Keep tech ordering stable so colors don't reshuffle when
  # OpenElectricity adds/removes categories.
  tech_levels <- c(
    "gas_ocgt",
    "gas_ccgt",
    "gas_steam",
    "hydro",
    "coal_black",
    "coal_brown",
    "wind",
    "solar_utility",
    "solar_rooftop"
  )
  df <- df |>
    mutate(
      tech = factor(
        tech,
        levels = c(tech_levels, setdiff(sort(unique(tech)), tech_levels))
      )
    )

  start_date <- lubridate::ymd("2012-06-01")
  end_date <- max(df$date, na.rm = TRUE)
  
  c_graph <- df |>
    mutate(
      value_per_mwh = (market_value_aud/(g_wh*1000))/volume_weighted_price_aud_m_wh,
      value_per_mwh = case_when(
        is.infinite(value_per_mwh) ~ NA,
        is.nan(value_per_mwh) ~ NA,
        .default = value_per_mwh)
    ) |>
    drop_na(value_per_mwh) |> 
    mutate(.by = date,
           total_production_in_period = sum(g_wh)) |> 
    pivot_longer(cols = c(value_per_mwh), names_to = "var", values_to = "value") |> 
    mutate(.by = tech,
           label = if_else(date == max(date), as.character(tech), NA),
           label = str_replace(label, "_(.*)$", " (\\1)")) |>
    filter(.by = tech, 
           # Production averaging 1% (over time & per period).
           mean(g_wh / total_production_in_period) > .01,
           # all(market_value_aud != 0),
           ) |>
    filter(dplyr::between(date, start_date, end_date)) |>
    ggplot(aes(x = date, y = value, group = tech, color = tech, alpha = opacity)) +
    geom_line() +
    geom_hline(yintercept = 1) +
    geom_text_repel(
      aes(label = label),
      na.rm = TRUE,
      hjust = 0,
      nudge_x = 90,
      direction = "y",
      xlim = c(-100, 100000),
      segment.color = NA) +
    guides(color = "none") +
    scale_alpha_identity() +
    scale_y_continuous(
      labels = scales::label_percent(),
      limits = c(0, NA),
      expand = c(0,0),
      breaks = seq(0,3,.5),
      name = "Capture price / generation-weighted price"
    ) +
    scale_x_date(
      limits = c(start_date, end_date),
      date_breaks = "year",
      date_labels = "%Y",
      name = NULL) +
    labs(title = glue("{region} - Capture price as proportion of volume-weighted price (average, 12 months to date)")) +
    theme_minimal() +
    theme(
      text = element_text(family = "Frugal Sans", size = my_font_size),
      strip.text.x = element_text(size=my_font_size*1.25),
      plot.margin = unit(c(.2,4,.2,.2), units = "cm"),
      # panel.grid.major = element_blank(),
      panel.grid.minor = element_blank(),
      plot.title = element_text(size = my_font_size * 1.25**2 ),
      axis.title = element_text(size=my_font_size * 1.25),
      axis.title.x = element_text(margin = margin(t = my_font_size*1.25)),
      axis.title.y = element_text(margin = margin(r = my_font_size*1.25)),
      axis.text = element_text(size=my_font_size),
    ) +
    coord_cartesian(clip = "off")
  
  p_graph <- df |> 
    select(date, tech_type, g_wh) |> 
    summarise(
      .by = c(date, tech_type),
      g_wh = sum(g_wh)) |> 
    mutate(
      .by = date,
      penetration = g_wh / sum(g_wh)) |> 
    filter(tech_type == "renewable") |>
    filter(dplyr::between(date, start_date, end_date)) |>
    mutate(label = if_else(date == max(date), "wind + solar", NA)) |>
    ggplot(aes(x = date, y = penetration)) +
    geom_line() +
    geom_text_repel(
      aes(label = label),
      na.rm = TRUE,
      hjust = 0,
      nudge_x = 90,
      direction = "y",
      xlim = c(-100, 100000),
      segment.color = NA) +
    # guides(color = "none") +
    scale_y_continuous(labels = scales::label_percent(), limits = c(0, 1), expand = c(0,0), name = "Wind + solar penetration") +
    scale_x_date(
      limits = c(start_date, end_date),
      date_breaks = "year",
      date_labels = "%Y",
      name = NULL) +
    labs(title = glue("{region} - Penetration of wind and solar (average, 12 months to date)")) +
    coord_cartesian(clip = "off") +
    theme_minimal() +
    theme(
      text = element_text(family = "Frugal Sans", size = my_font_size),
      strip.text.x = element_text(size=my_font_size*1.25),
      plot.margin = unit(c(.2,4,.2,.2), units = "cm"),
      # panel.grid.major = element_blank(),
      panel.grid.minor = element_blank(),
      plot.title = element_text(size = my_font_size * 1.25**2 ),
      axis.title = element_text(size=my_font_size * 1.25),
      axis.title.x = element_text(margin = margin(t = my_font_size*1.25)),
      axis.title.y = element_text(margin = margin(r = my_font_size*1.25)),
      axis.text = element_text(size=my_font_size),
    )
  
  weighted_price_graph <- df |> 
    distinct(date, volume_weighted_price_aud_m_wh) |> 
    filter(dplyr::between(date, start_date, end_date)) |>
    mutate(label = if_else(date == max(date), "Wholesale price", NA)) |>
    ggplot(aes(x = date, y = volume_weighted_price_aud_m_wh)) +
    geom_line() +
    geom_text_repel(
      aes(label = label),
      na.rm = TRUE,
      hjust = 0,
      nudge_x = 90,
      direction = "y",
      xlim = c(-100, 100000),
      segment.color = NA) +
    # guides(color = "none") +
    scale_y_continuous(labels = scales::label_currency(suffix = " /MWh"), expand = c(0,0), name = "Volume-weighted price") +
    scale_x_date(
      limits = c(start_date, end_date),
      date_breaks = "year",
      date_labels = "%Y",
      name = NULL) +
    labs(title = glue("{region} - Volume Weighted Wholesale Price ($, 12 months to date)")) +
    coord_cartesian(clip = "off") +
    theme_minimal() +
    theme(
      text = element_text(family = "Frugal Sans", size = my_font_size),
      strip.text.x = element_text(size=my_font_size*1.25),
      plot.margin = unit(c(.2,4,.2,.2), units = "cm"),
      # panel.grid.major = element_blank(),
      panel.grid.minor = element_blank(),
      plot.title = element_text(size = my_font_size * 1.25**2 ),
      axis.title = element_text(size=my_font_size * 1.25),
      axis.title.x = element_text(margin = margin(t = my_font_size*1.25)),
      axis.title.y = element_text(margin = margin(r = my_font_size*1.25)),
      axis.text = element_text(size=my_font_size),
    )

  myplot <- c_graph + p_graph + weighted_price_graph + plot_layout(heights = c(4, 1, 1))
  
  ggsave(
       here(glue("04-output/capture_graph_{region}.png")),
       plot = myplot,
       width = 12,
       height = 8,
       dpi = 300,
  )
  return(myplot)
}

save_capture_graph(latest_raw_csv("Open Electricity\\.csv$"), "NEM")
save_capture_graph(latest_raw_csv("South Australia\\.csv$"), "South Australia")
