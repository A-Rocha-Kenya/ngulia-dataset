library(dplyr)
library(readr)
library(ggplot2)
library(lubridate)
library(stringr)
library(cli)
library(grid)

# Set paths ---------------------------------------------------------------

project_dir <- here::here()
source(file.path(project_dir, "scripts", "helpers", "plot_style.R"))
source(file.path(project_dir, "scripts", "helpers", "data_paths.R"))
paths <- get_data_paths(project_dir)

curated_dir <- paths$curated_dir
config_dir <- paths$ring_events_config_dir
figures_dir <- file.path(paths$qa_output_dir, "ring_events", "figures")
dir.create(figures_dir, recursive = TRUE, showWarnings = FALSE)

ring_events_path <- file.path(curated_dir, "ring_events.csv")
measurement_ranges_path <- file.path(config_dir, "measurement_ranges.csv")
diagnostic_plot_path <- file.path(
  figures_dir,
  "ring_events_measurements.pdf"
)

source(file.path(project_dir, "scripts", "helpers", "ring_event_helpers.R"))

# Read data ---------------------------------------------------------------

cli_h1("Plot ring-event measurement diagnostics")

ring_events <- read_csv(
  ring_events_path,
  show_col_types = FALSE,
  col_types = cols(.default = col_character())
) |>
  mutate(
    common_name = na_if(common_name, ""),
    species = coalesce(common_name, avibase_id),
    has_time = str_detect(datetime, "T"),
    datetime_local = suppressWarnings(ymd_hms(datetime, tz = "Africa/Nairobi")),
    hour_of_day = hour(datetime_local) + minute(datetime_local) / 60,
    hour_shifted = if_else(hour_of_day < 20, hour_of_day + 24, hour_of_day),
    wing = parse_measurement(wing),
    weight = parse_measurement(weight),
    fat_kaiser = suppressWarnings(as.integer(fat_kaiser))
  )

measurement_ranges <- load_measurement_ranges(measurement_ranges_path)
global_ranges <- measurement_ranges |>
  filter(afring_number == "all")
species_reference <- load_species_reference(file.path(config_dir, "species_reference.csv"))
species_ranges <- measurement_ranges |>
  filter(afring_number != "all") |>
  left_join(species_reference |> select(afring_number, avibase_id), by = "afring_number") |>
  group_by(avibase_id) |>
  summarise(across(ends_with("_min"), min), across(ends_with("_max"), max), .groups = "drop")

species_counts <- ring_events |>
  count(avibase_id, species, sort = TRUE)

if (nrow(species_counts) == 0) {
  cli_abort("No ring-event rows found for measurement diagnostics.")
}

plot_measurement_histogram <- function(data, value_col, x_label, min_value, max_value, title) {
  measurement_data <- data |>
    filter(!is.na(.data[[value_col]]))
  pct_available <- nrow(measurement_data) / nrow(data)

  if (nrow(measurement_data) == 0) {
    return(
      ggplot() +
        annotate("text", x = 0.5, y = 0.5, label = "No data", size = 5, color = "grey35") +
        labs(title = title, x = x_label, y = "Number of captures") +
        theme_void(base_size = 12) +
        theme(
          plot.title = element_text(face = "bold", size = 13, hjust = 0),
          plot.background = element_rect(fill = "#FFFFFF", color = NA),
          panel.background = element_rect(fill = "#FFFFFF", color = NA)
        )
    )
  }

  binwidth <- case_when(
    value_col %in% c("wing", "fat_kaiser") ~ 1,
    value_col == "weight" ~ 0.5,
    TRUE ~ max(diff(range(measurement_data[[value_col]], na.rm = TRUE)) / 30, 0.5)
  )
  boundary <- case_when(
    value_col %in% c("wing", "fat_kaiser") ~ -0.5,
    TRUE ~ 0
  )

  y_max <- hist(
    measurement_data[[value_col]],
    breaks = seq(
      floor(min(measurement_data[[value_col]], na.rm = TRUE)) - binwidth,
      ceiling(max(measurement_data[[value_col]], na.rm = TRUE)) + binwidth,
      by = binwidth
    ),
    plot = FALSE
  )$counts |>
    max()

  ggplot(measurement_data, aes(x = .data[[value_col]])) +
    geom_histogram(
      binwidth = binwidth,
      boundary = boundary,
      closed = "left",
      fill = "#2f5d50",
      color = "#f7f2e8",
      linewidth = 0.2
    ) +
    scale_x_continuous(
      breaks = if (value_col == "fat_kaiser") 0:8 else waiver(),
      limits = if (value_col == "fat_kaiser") c(-0.5, 8.5) else NULL,
      expand = c(0.02, 0.02)
    ) +
    labs(
      title = title,
      subtitle = glue::glue(
        "n = {nrow(measurement_data)} ({scales::percent(pct_available, accuracy = 0.1)})"
      ),
      x = x_label,
      y = "Number of captures"
    ) +
    ngulia_theme(base_size = 12) +
    theme(
      panel.grid.minor = element_blank(),
      panel.grid.major.x = element_blank(),
      plot.title = element_text(face = "bold", size = 13),
      plot.subtitle = element_text(color = "grey30", size = 10),
      plot.background = element_rect(fill = "#FFFFFF", color = NA),
      panel.background = element_rect(fill = "#FFFFFF", color = NA)
    ) +
    {
      if (!is.na(min_value) && !is.na(max_value)) {
        list(
          geom_vline(xintercept = min_value, color = "#b23a48", linetype = "dashed", linewidth = 0.5),
          geom_vline(xintercept = max_value, color = "#b23a48", linetype = "dashed", linewidth = 0.5),
          annotate(
            "text",
            x = min_value,
            y = y_max,
            label = paste0("min ", min_value),
            hjust = 0,
            vjust = -0.2,
            color = "#b23a48",
            size = 3
          ),
          annotate(
            "text",
            x = max_value,
            y = y_max,
            label = paste0("max ", max_value),
            hjust = 1,
            vjust = -0.2,
            color = "#b23a48",
            size = 3
          )
        )
      }
    }
}

plot_time_histogram <- function(data) {
  timed_data <- data |>
    filter(has_time, !is.na(hour_shifted))
  pct_available <- nrow(timed_data) / nrow(data)

  if (nrow(timed_data) == 0) {
    return(
      ggplot() +
        annotate("text", x = 0.5, y = 0.5, label = "No timed records", size = 5, color = "grey35") +
        labs(title = "Time of day", x = "Hour of day", y = "Number of captures") +
        theme_void(base_size = 12) +
        theme(
          plot.title = element_text(face = "bold", size = 13, hjust = 0),
          plot.background = element_rect(fill = "#FFFFFF", color = NA),
          panel.background = element_rect(fill = "#FFFFFF", color = NA)
        )
    )
  }

  ggplot(timed_data, aes(x = hour_shifted)) +
    geom_histogram(
      binwidth = 1,
      boundary = 20,
      closed = "left",
      fill = "#2f5d50",
      color = "#f7f2e8",
      linewidth = 0.2
    ) +
    scale_x_continuous(
      breaks = 20:43,
      labels = c(20:23, 0:19),
      limits = c(20, 44),
      expand = c(0, 0)
    ) +
    labs(
      title = "Time of day",
      subtitle = glue::glue(
        "n = {nrow(timed_data)} ({scales::percent(pct_available, accuracy = 0.1)})"
      ),
      x = "Hour of day, shifted to start at 20:00",
      y = "Number of captures"
    ) +
    ngulia_theme(base_size = 12) +
    theme(
      panel.grid.minor = element_blank(),
      panel.grid.major.x = element_blank(),
      plot.title = element_text(face = "bold", size = 13),
      plot.subtitle = element_text(color = "grey30", size = 10),
      axis.text.x = element_text(size = 9),
      plot.background = element_rect(fill = "#FFFFFF", color = NA),
      panel.background = element_rect(fill = "#FFFFFF", color = NA)
    )
}

draw_species_page <- function(species_data, species_row, limits_row) {
  species_title <- glue::glue(
    "{species_row$species} ({species_row$avibase_id})"
  )
  species_subtitle <- glue::glue("Total records: {species_row$n}")

  wing_plot <- plot_measurement_histogram(
    species_data,
    "wing",
    "Wing (mm)",
    limits_row$wing_min,
    limits_row$wing_max,
    "Wing"
  )
  weight_plot <- plot_measurement_histogram(
    species_data,
    "weight",
    "Weight (g)",
    limits_row$weight_min,
    limits_row$weight_max,
    "Weight"
  )
  fat_plot <- plot_measurement_histogram(
    species_data,
    "fat_kaiser",
    "Fat score (Kaiser scale)",
    NA_real_,
    NA_real_,
    "Fat (Kaiser scale)"
  )
  time_plot <- plot_time_histogram(species_data)

  grid.newpage()
  pushViewport(viewport(layout = grid.layout(3, 2, heights = unit(c(0.9, 4, 4), "null"))))

  pushViewport(viewport(layout.pos.row = 1, layout.pos.col = 1:2))
  grid.text(
    species_title,
    x = unit(0.02, "npc"),
    y = unit(0.7, "npc"),
    just = c("left", "center"),
    gp = gpar(fontsize = 16, fontface = "bold")
  )
  grid.text(
    species_subtitle,
    x = unit(0.02, "npc"),
    y = unit(0.25, "npc"),
    just = c("left", "center"),
    gp = gpar(fontsize = 10, col = "grey30")
  )
  popViewport()

  print(wing_plot, vp = viewport(layout.pos.row = 2, layout.pos.col = 1))
  print(weight_plot, vp = viewport(layout.pos.row = 2, layout.pos.col = 2))
  print(fat_plot, vp = viewport(layout.pos.row = 3, layout.pos.col = 1))
  print(time_plot, vp = viewport(layout.pos.row = 3, layout.pos.col = 2))
  popViewport()
}

# Plot species pages ------------------------------------------------------

pdf(diagnostic_plot_path, width = 11, height = 8.5)

for (i_species in seq_len(nrow(species_counts))) {
  species_row <- species_counts[i_species, ]
  species_data <- ring_events |>
    filter(avibase_id == species_row$avibase_id)

  limits_row <- species_ranges |>
    filter(avibase_id == species_row$avibase_id)

  if (nrow(limits_row) == 0) {
    limits_row <- tibble(
      wing_min = NA_real_,
      wing_max = NA_real_,
      weight_min = NA_real_,
      weight_max = NA_real_
    )
  }

  draw_species_page(species_data, species_row, limits_row)
}

dev.off()

# Report ------------------------------------------------------------------

cli_alert_success("Wrote diagnostic PDF to {diagnostic_plot_path}")
