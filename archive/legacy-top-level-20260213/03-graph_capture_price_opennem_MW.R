library(tidyverse)
library(ggrepel)
library(patchwork)
library(glue)
library(here)

my_font_size = 9

# Source https://explore.openelectricity.org.au/energy/nem/?range=all-12-mth-rolling&interval=1M&view=discrete-time&group=Detailed
# Files were sourced from explore.openelectricity.org.au link above on 26 Nov 2024.
# Set time period to ALL / 12Mth rolling; and interview to month.
# For SA, change region to SA first.
# 
# "19991201 Open Electricity.csv",
# "19991201 South Australia.csv",

save_capture_graph <- function(file, region){
  # Read and clean the main data
  df <- read.csv(file) |>
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
      tech_type = case_when(
        str_starts(tech, "(solar|wind)") ~ "renewable",
        str_starts(tech, "(coal|gas)")  ~ "fossil fuel",
        .default = "other"),
      opacity = 1
    )
  
  # Save the cleaned dataframe
  write.csv(df, here(glue("04-output/processed_data_{region}.csv")), row.names = FALSE)
  
  # Process data for c_graph
  c_graph_data <- df |>
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
           label = if_else(date == max(date), tech, NA),
           label = str_replace(label, "_(.*)$", " (\\1)")) |> 
    filter(.by = tech, 
           mean(g_wh / total_production_in_period) > .01) |> 
    filter(date %within% interval(ymd("2012-06-01"), ymd("2026-06-01")))
  
  # Save c_graph data to CSV
  write.csv(c_graph_data, here(glue("04-output/c_graph_data_{region}.csv")), row.names = FALSE)
  
  # Create c_graph plot
  c_graph <- c_graph_data |> 
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
      name = NULL
    ) +
    scale_x_date(
      limits = c(ymd("2012-06-01"), ymd("2024-12-31")),
      date_breaks = "year",
      date_labels = "%Y",
      name = NULL) +
    labs(title = glue("Capture price of energy source relative to weighted average wholesale price in the NEM")) +
    theme_minimal() +
    theme(
      text = element_text(family = "Frugal Sans", size = my_font_size),
      strip.text.x = element_text(size=my_font_size*1.25),
      plot.margin = unit(c(.2,4,.2,.2), units = "cm"),
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
    filter(date %within% interval(ymd("2012-06-01"), ymd("2024-12-31"))) |>
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
    scale_y_continuous(labels = scales::label_percent(), limits = c(0, 1), expand = c(0,0), name = NULL) +
    scale_x_date(
      limits = c(ymd("2012-06-01"), ymd("2024-12-31")),
      date_breaks = "year",
      date_labels = "%Y",
      name = NULL) +
    labs(title = glue("Annual penetration of wind and solar in the NEM")) +
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
    filter(date %within% interval(ymd("2012-06-01"), ymd("2024-12-31"))) |>
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
    scale_y_continuous(labels = scales::label_currency(suffix = "per MW"), expand = c(0,0), name = NULL) +
    scale_x_date(
      limits = c(ymd("2012-06-01"), ymd("2024-12-31")),
      date_breaks = "year",
      date_labels = "%Y",
      name = NULL) +
    labs(title = glue("Wholesale price (12-month weighted average)")) +
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

save_capture_graph(here("01-raw-data/19991201 Open Electricity.csv"), "NEM")
save_capture_graph(here("01-raw-data/19991201 South Australia.csv"), "South Australia")
