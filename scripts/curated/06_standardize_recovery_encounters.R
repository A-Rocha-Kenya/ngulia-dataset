library(dplyr)
library(readr)
library(stringr)
source(here::here("scripts/helpers/data_paths.R"))
paths <- get_data_paths()

# Load data -----------------------------------------------------------------

project_dir <- here::here()
recoveries_path <- file.path(project_dir, "data", "04_curated", "recoveries.csv")

taxonomy <- read_csv(file.path(paths$taxonomy_intermediate_dir, "taxonomy_reference.csv"), show_col_types = FALSE, col_types = cols(.default = col_character()))
recoveries <- read_csv(recoveries_path, show_col_types = FALSE, col_types = cols(.default = col_character())) |>
  select(-common_name) |>
  left_join(taxonomy |> select(avibase_id, common_name), by = "avibase_id", relationship = "many-to-one") |>
  relocate(common_name, .after = avibase_id)

# Standardize encounter classifications ------------------------------------

recoveries <- recoveries |>
  mutate(
    method_key = str_to_lower(coalesce(encounter_method, "")),
    encounter_type = if_else(encounter_type %in% c("ringing_control", "control"), "control", "recovery"),
    encounter_type = if_else(method_key == "dead inside lodge", "recovery", encounter_type),
    encounter_condition = if_else(method_key == "dead inside lodge", "dead", encounter_condition),
    mortality_cause_class = case_when(
      !encounter_condition %in% "dead" ~ NA_character_,
      str_detect(method_key, "shot|hunted|by boys|snared|caught and eaten") ~ "intentional_human",
      method_key %in% c("killed by car", "died (hit building)", "hit wires") ~ "unintentional_human",
      str_detect(method_key, "cat") ~ "domestic_animal",
      str_detect(method_key, "stomach.*accipiter") ~ "wild_predation",
      str_detect(method_key, "^killed") ~ "unspecified_killing",
      TRUE ~ "unknown"
    )
  ) |>
  select(-method_key) |>
  relocate(mortality_cause_class, .after = encounter_condition)

stopifnot(
  all(recoveries$encounter_type %in% c("control", "recovery")),
  all(is.na(recoveries$mortality_cause_class) | recoveries$mortality_cause_class %in% c(
    "intentional_human", "unintentional_human", "domestic_animal",
    "wild_predation", "unspecified_killing", "unknown"
  ))
)

write_csv(recoveries, recoveries_path, na = "")
