library(cli)
library(dplyr)
library(readr)
library(readxl)
library(stringr)
library(tidyr)

# Read taxonomy and project mappings --------------------------------------

source(here::here("scripts/helpers/data_paths.R"))
paths <- get_data_paths()

clements <- read_csv(
  file.path(paths$reference_dir, "taxonomy", "ebird_clements_2025_integrated_checklist.csv"),
  col_types = cols(.default = col_character())
) |>
  transmute(
    avibase_id = `taxon concept ID`, common_name = `English name`,
    scientific_name = `scientific name`, category, species_code, order, family,
    species_avibase_id = if_else(category == "species", avibase_id, NA_character_)
  ) |>
  fill(species_avibase_id) |>
  mutate(species_avibase_id = if_else(
    category %in% c("species", "subspecies", "group (monotypic)", "group (polytypic)", "form", "intergrade"),
    species_avibase_id, NA_character_
  )) |>
  filter(!is.na(avibase_id))

avilist <- read_excel(
  file.path(paths$reference_dir, "taxonomy", "avilist_2025_11jun_extended.xlsx"),
  sheet = "AviList v2025 extended", col_types = "text"
) |>
  transmute(
    avibase_id = AvibaseID, fallback_common_name = English_name_AviList,
    fallback_scientific_name = Scientific_name, fallback_category = Taxon_rank,
    birdlife_url = BirdLife_DataZone_URL, iucn_category = IUCN_Red_List_Category
  ) |>
  filter(!is.na(avibase_id))

species_reference <- read_csv(
  file.path(paths$ring_events_config_dir, "species_reference.csv"),
  col_types = cols(.default = col_character())
) |>
  mutate(taxon_id = coalesce(avibase_id, paste0("ngulia-afring-", afring_number)))
subspecies_lookup <- read_csv(
  file.path(paths$ring_events_config_dir, "subspecies_lookup.csv"),
  col_types = cols(.default = col_character())
)
species_lookup <- read_csv(
  file.path(paths$ring_events_config_dir, "species_lookup.csv"),
  col_types = cols(.default = col_character())
)
taxonomy_crosswalk <- read_csv(
  file.path(paths$taxonomy_config_dir, "ngulia_taxonomy_crosswalk.csv"),
  col_types = cols(.default = col_character())
)

# Preserve reviewed project labels and codes ------------------------------

collapse_taxonomy_values <- function(x) {
  paste(sort(unique(x[!is.na(x) & x != ""])), collapse = "; ") |>
    na_if("")
}

source_names <- species_lookup |>
  filter(input_type %in% c("english", "scientific_name")) |>
  group_by(afring_number, input_type) |>
  summarise(input_text = first(input_text), .groups = "drop") |>
  pivot_wider(names_from = input_type, values_from = input_text) |>
  rename(lookup_common_name = english, lookup_scientific_name = scientific_name)

project_taxa <- species_reference |>
  left_join(source_names, by = "afring_number")

project_taxa <- project_taxa |>
  group_by(taxon_id) |>
  summarise(
    avibase_id = first(avibase_id),
    project_common_name = first(na.omit(common_name), default = NA_character_),
    project_scientific_name = first(na.omit(scientific_name), default = NA_character_),
    lookup_common_name = first(na.omit(lookup_common_name), default = NA_character_),
    lookup_scientific_name = first(na.omit(lookup_scientific_name), default = NA_character_),
    afring_numbers = collapse_taxonomy_values(afring_number),
    ngulia_numbers = collapse_taxonomy_values(ngulia_number),
    ngulia_latin_abbr = collapse_taxonomy_values(latin_abbreviation),
    .groups = "drop"
  )

external_links <- taxonomy_crosswalk |>
  filter(!is.na(avibase_id)) |>
  group_by(avibase_id) |>
  summarise(
    birdlife_id = collapse_taxonomy_values(birdlife_id),
    kbt_seq = collapse_taxonomy_values(kbt_seq),
    abap_ids = collapse_taxonomy_values(unlist(str_split(abap_ids, "\\s*;\\s*"))),
    .groups = "drop"
  )

subspecies_notes <- subspecies_lookup |>
  filter(!is.na(subspecies_avibase_id)) |>
  group_by(subspecies_avibase_id) |>
  summarise(
    source_notes = collapse_taxonomy_values(note),
    .groups = "drop"
  ) |>
  rename(avibase_id = subspecies_avibase_id)

# Build one row per taxonomic concept -------------------------------------

taxonomy <- bind_rows(
  clements |> transmute(taxon_id = avibase_id, avibase_id),
  project_taxa |> select(taxon_id, avibase_id),
  subspecies_lookup |> filter(!is.na(subspecies_avibase_id)) |>
    transmute(taxon_id = subspecies_avibase_id, avibase_id = subspecies_avibase_id),
  taxonomy_crosswalk |> filter(!is.na(avibase_id)) |>
    transmute(taxon_id = avibase_id, avibase_id)
) |>
  distinct(taxon_id, .keep_all = TRUE) |>
  left_join(clements, by = "avibase_id", na_matches = "never") |>
  left_join(avilist, by = "avibase_id", na_matches = "never") |>
  left_join(project_taxa |> select(-avibase_id), by = "taxon_id") |>
  left_join(external_links, by = "avibase_id", na_matches = "never") |>
  left_join(subspecies_notes, by = "avibase_id", na_matches = "never") |>
  mutate(
    scientific_name = coalesce(project_scientific_name, scientific_name, fallback_scientific_name, lookup_scientific_name),
    common_name = coalesce(project_common_name, common_name, fallback_common_name, lookup_common_name, scientific_name, ngulia_latin_abbr, taxon_id),
    category = coalesce(category, fallback_category, if_else(str_detect(common_name, "hybrid"), "hybrid", "unmapped")),
    category = if_else(taxon_id == "ngulia-afring-9999", "non_taxon", category),
    scientific_name = case_when(
      taxon_id == "avibase-AF0D818A" ~ "Aves",
      category == "non_taxon" ~ NA_character_,
      TRUE ~ scientific_name
    ),
    species_avibase_id = coalesce(species_avibase_id, if_else(category == "species", taxon_id, NA_character_)),
    birdlife_id = coalesce(str_extract(birdlife_url, "[0-9]+/?$") |> str_remove("/$"), birdlife_id),
    birdlife_url = coalesce(birdlife_url, if_else(!is.na(birdlife_id), paste0("https://datazone.birdlife.org/species/factsheet/", birdlife_id), NA_character_))
  ) |>
  select(
    taxon_id, avibase_id, common_name, scientific_name, category, species_avibase_id,
    species_code, order, family,
    afring_numbers, ngulia_numbers, ngulia_latin_abbr, source_notes,
    birdlife_id, birdlife_url, iucn_category, kbt_seq, abap_ids
  ) |>
  arrange(taxon_id)

# Write the intermediate reference ---------------------------------------

dir.create(paths$taxonomy_intermediate_dir, recursive = TRUE, showWarnings = FALSE)
write_csv(taxonomy, file.path(paths$taxonomy_intermediate_dir, "taxonomy_reference.csv"), na = "")
cli_alert_success("Wrote {nrow(taxonomy)} taxonomic concepts, including project special entries.")
