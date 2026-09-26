library(dplyr)
library(readr)
library(stringr)

# Load data -----------------------------------------------------------------

project_dir <- here::here()
recoveries_path <- file.path(project_dir, "data", "04_curated", "recoveries.csv")

recoveries <- read_csv(recoveries_path, show_col_types = FALSE)

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
