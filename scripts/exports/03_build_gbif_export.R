library(cli)
library(dplyr)
library(glue)
library(purrr)
library(readr)
library(stringr)
library(tidyr)
library(yaml)

# Load paths and metadata --------------------------------------------------

project_dir <- here::here()
source(file.path(project_dir, "scripts", "helpers", "data_paths.R"))
source(file.path(project_dir, "scripts", "helpers", "publication_metadata.R"))
paths <- get_data_paths(project_dir)

ring_events_path <- file.path(paths$zenodo_export_dir, "ring_events.csv")
species_reference_path <- file.path(paths$ring_events_config_dir, "species_reference.csv")
species_lookup_path <- file.path(paths$ring_events_config_dir, "species_lookup.csv")
output_dir <- paths$gbif_export_dir

metadata <- read_publication_metadata()
bibliography_xml <- str_c(
  "      <bibtex>",
  xml_escape(read_file(file.path(project_dir, metadata$documents$bibliography))),
  "</bibtex>"
)
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

metadata_scalar <- function(x) {
  if (is.null(x) || identical(x, "")) NA else x
}

zenodo_concept_doi <- metadata_scalar(metadata$zenodo$concept_doi)
zenodo_url <- if (is.na(zenodo_concept_doi)) {
  metadata$repository$url
} else if (str_starts(zenodo_concept_doi, "http")) {
  zenodo_concept_doi
} else {
  paste0("https://doi.org/", zenodo_concept_doi)
}

license_url <- case_when(
  metadata$dataset$license == "CC-BY-4.0" ~ "https://creativecommons.org/licenses/by/4.0/legalcode",
  metadata$dataset$license == "CC0-1.0" ~ "https://creativecommons.org/publicdomain/zero/1.0/legalcode",
  TRUE ~ metadata$dataset$license
)

# Read curated data --------------------------------------------------------

ring_events <- read_csv(
  ring_events_path,
  col_types = cols(
    .default = col_character(),
    ring_event_id = col_character(),
    season = col_integer(),
    ringing_date = col_date(),
    datetime = col_character(),
    ring_number = col_character(),
    ringer_name = col_character(),
    afring_number = col_integer(),
    age = col_integer(),
    sex = col_character(),
    wing = col_double(),
    weight = col_double(),
    fat_ngulia = col_integer(),
    fat_kaiser = col_integer(),
    retrap = col_logical(),
    ring_note = col_character(),
    avibase_id = col_character(),
    common_name = col_character(),
    species_code = col_character(),
    subspecies_avibase_id = col_character()
  )
) |>
  rename(ringNumber = ring_number)

moult_fields <- c(
  "moult_note",
  "primary_moult_status",
  "n_old_primaries_remaining",
  "body_moult_head",
  "body_moult_upperparts",
  "body_moult_underparts",
  paste0("p", 1:10),
  paste0("s", 1:6),
  paste0("t", 1:3),
  paste0("tail", 1:6)
)

moult <- ring_events |>
  select(ring_event_id, all_of(moult_fields)) |>
  rename_with(~ str_replace(.x, "^p", "P"), matches("^p\\d+$")) |>
  rename_with(~ str_replace(.x, "^s", "S"), matches("^s\\d+$")) |>
  rename_with(~ str_replace(.x, "^t", "T"), matches("^t\\d+$")) |>
  rename_with(~ str_replace(.x, "^tail", "Tail"), matches("^tail\\d+$"))

species_reference <- read_csv(
  species_reference_path,
  show_col_types = FALSE
) |>
  transmute(
    afring_number,
    reference_common_name = na_if(common_name, ""),
    reference_scientific_name = na_if(scientific_name, "")
  )

species_lookup <- read_csv(
  species_lookup_path,
  show_col_types = FALSE
) |>
  filter(input_type == "scientific_name") |>
  transmute(
    afring_number,
    lookup_scientific_name = na_if(input_text, "Lost or destroyed ring")
  ) |>
  distinct(afring_number, .keep_all = TRUE)

ebird_taxonomy <- auk::ebird_taxonomy |>
  transmute(
    avibase_id = taxon_concept_id,
    taxonomy_scientific_name = scientific_name,
    taxonomy_common_name = common_name,
    taxonomy_category = category,
    taxonomy_order = order,
    taxonomy_family = family
  ) |>
  distinct(avibase_id, .keep_all = TRUE)

subspecies_taxonomy <- ebird_taxonomy |>
  rename(
    subspecies_avibase_id = avibase_id,
    subspecies_scientific_name = taxonomy_scientific_name,
    subspecies_common_name = taxonomy_common_name,
    subspecies_category = taxonomy_category,
    subspecies_order = taxonomy_order,
    subspecies_family = taxonomy_family
  )

# Prepare identifiers and taxonomy ----------------------------------------

ring_events <- ring_events |>
  left_join(species_reference, by = "afring_number") |>
  left_join(species_lookup, by = "afring_number") |>
  left_join(ebird_taxonomy, by = "avibase_id") |>
  left_join(subspecies_taxonomy, by = "subspecies_avibase_id") |>
  mutate(
    eventID = paste0("ngulia:ringing-day:", ringing_date),
    occurrenceID = paste0("ngulia:ring-event:", ring_event_id),
    organismID = paste0("ngulia:ring:", ringNumber),
    resolved_note_taxon = !is.na(subspecies_scientific_name),
    taxonID = case_when(
      afring_number == 0L ~ NA_character_,
      resolved_note_taxon ~ subspecies_avibase_id,
      TRUE ~ avibase_id
    ),
    taxonID = if_else(
      is.na(taxonID),
      NA_character_,
      paste0(
        "https://avibase.bsc-eoc.org/species.jsp?avibaseid=",
        str_remove(taxonID, "^avibase-")
      )
    ),
    scientificName = if_else(
      afring_number == 0L,
      "Aves",
      coalesce(
        subspecies_scientific_name,
        taxonomy_scientific_name,
        na_if(reference_scientific_name, "Unknown"),
        lookup_scientific_name
      )
    ),
    vernacularName = if_else(
      afring_number == 0L,
      NA_character_,
      coalesce(
        subspecies_common_name,
        common_name,
        taxonomy_common_name,
        reference_common_name
      )
    ),
    taxonRank = case_when(
      afring_number == 0L ~ "class",
      resolved_note_taxon & subspecies_category == "subspecies" ~ "subspecies",
      resolved_note_taxon &
        subspecies_category == "issf" &
        !str_detect(subspecies_scientific_name, "\\[[^]]+ Group\\]") ~ "subspecies",
      resolved_note_taxon & subspecies_category == "species" ~ "species",
      resolved_note_taxon ~ NA_character_,
      taxonomy_category == "species" ~ "species",
      TRUE ~ NA_character_
    ),
    order = coalesce(subspecies_order, taxonomy_order),
    family = coalesce(subspecies_family, taxonomy_family),
    identificationRemarks = case_when(
      !is.na(subspecies_avibase_id) & !resolved_note_taxon ~ paste0(
        "Unresolved source subspecies Avibase ID: ",
        subspecies_avibase_id
      ),
      subspecies_category == "hybrid" | taxonomy_category == "hybrid" ~ paste0(
        "Scientific name is a hybrid formula rather than a ranked taxon; ",
        "taxonRank is intentionally left empty."
      )
    ),
    captureEventDate = case_when(
      str_length(datetime) == 10 ~ datetime,
      str_ends(datetime, fixed("+03:00")) ~ datetime,
      str_ends(datetime, "Z") ~ str_replace(datetime, "Z$", "+03:00"),
      TRUE ~ paste0(str_replace(datetime, " ", "T"), "+03:00")
    )
  )

# Build Event core ---------------------------------------------------------

events <- ring_events |>
  distinct(eventID, ringing_date) |>
  arrange(ringing_date) |>
  transmute(
    eventID,
    type = "Event",
    eventDate = as.character(ringing_date),
    eventType = "bird capture and ringing session",
    samplingProtocol = metadata$gbif$sampling_protocol,
    locationID = "ngulia-ringing-station",
    locality = metadata$dataset$geographic_coverage$description,
    country = metadata$dataset$geographic_coverage$country,
    countryCode = metadata$dataset$geographic_coverage$country_code,
    decimalLatitude = metadata_scalar(metadata$dataset$geographic_coverage$latitude),
    decimalLongitude = metadata_scalar(metadata$dataset$geographic_coverage$longitude),
    geodeticDatum = if_else(is.na(decimalLatitude), NA_character_, "WGS84"),
    coordinateUncertaintyInMeters = metadata_scalar(
      metadata$dataset$geographic_coverage$coordinate_uncertainty_m
    )
  )

# Build Occurrence extension ----------------------------------------------

occurrences <- ring_events |>
  arrange(ringing_date, datetime, ring_event_id) |>
  transmute(
    eventID,
    occurrenceID,
    organismID,
    basisOfRecord = metadata$gbif$basis_of_record,
    occurrenceStatus = "present",
    individualCount = 1L,
    organismQuantity = 1L,
    organismQuantityType = "individuals",
    eventDate = captureEventDate,
    taxonID,
    scientificName,
    taxonRank,
    kingdom = "Animalia",
    phylum = "Chordata",
    class = "Aves",
    order,
    family,
    vernacularName,
    sex = case_when(sex == "M" ~ "male", sex == "F" ~ "female"),
    lifeStage = case_when(
      age == 1L ~ "pullus",
      age == 2L ~ "full-grown, age unknown",
      age == 3L ~ "first calendar year",
      age == 4L ~ "after first calendar year",
      age == 5L ~ "second calendar year",
      age == 6L ~ "after second calendar year",
      age == 7L ~ "third calendar year",
      age == 8L ~ "after third calendar year",
      age == 9L ~ "fourth calendar year"
    ),
    dynamicProperties = case_when(
      retrap ~ '{"retrap":true}',
      !retrap ~ '{"retrap":false}'
    ),
    occurrenceRemarks = ring_note,
    recordedBy = ringer_name,
    identificationRemarks,
    datasetName = metadata$dataset$data_title,
    license = license_url
  )

# Build bird-level ExtendedMeasurementOrFact extension --------------------

measurement_keys <- ring_events |>
  select(ring_event_id, eventID, occurrenceID)

# Define the exported measurement labels, units, and methods.
capture_measurement_specs <- tribble(
  ~source_field, ~measurementType, ~measurementUnit, ~measurementMethod,
  "wing", "wing length", "mm", "Wing length recorded by the source ringing workflow.",
  "weight", "body mass", "g", "Body mass recorded by the source ringing workflow.",
  "fat_ngulia", "fat score", "dimensionless", "Ngulia fat scale (0-4).",
  "fat_kaiser", "fat score", "dimensionless", "Kaiser fat scale (0-8).",
  "uncertain_sex", "reported sex", NA, "Uncertain sex retained from the curated ringing record."
)

capture_measurements <- ring_events |>
  transmute(
    eventID,
    occurrenceID,
    wing = as.character(wing),
    weight = as.character(weight),
    fat_ngulia = as.character(fat_ngulia),
    fat_kaiser = as.character(fat_kaiser),
    uncertain_sex = case_when(sex == "M?" ~ "probably male", sex == "F?" ~ "probably female")
  ) |>
  pivot_longer(
    -c(eventID, occurrenceID),
    names_to = "source_field",
    values_to = "measurementValue",
    values_drop_na = TRUE
  ) |>
  left_join(capture_measurement_specs, by = "source_field")

moult_measurement_specs <- tibble(source_field = names(moult)[-1]) |>
  mutate(
    measurementType = case_when(
      source_field == "moult_note" ~ "moult note",
      source_field == "primary_moult_status" ~ "primary moult status",
      source_field == "n_old_primaries_remaining" ~ "old primaries remaining",
      source_field == "body_moult_head" ~ "body moult score: head",
      source_field == "body_moult_upperparts" ~ "body moult score: upperparts",
      source_field == "body_moult_underparts" ~ "body moult score: underparts",
      str_detect(source_field, "^P[0-9]+$") ~ paste0("primary feather ", source_field, " moult score"),
      str_detect(source_field, "^S[0-9]+$") ~ paste0("secondary feather ", source_field, " moult score"),
      str_detect(source_field, "^T[0-9]+$") ~ paste0("tertial feather ", source_field, " moult score"),
      str_detect(source_field, "^Tail[0-9]+$") ~ paste0("tail feather ", str_remove(source_field, "Tail"), " moult score")
    ),
    measurementUnit = case_when(
      source_field == "n_old_primaries_remaining" ~ "dimensionless",
      str_starts(source_field, "body_moult_") ~ "dimensionless",
      str_detect(source_field, "^(P|S|T|Tail)[0-9]+$") ~ "dimensionless"
    ),
    measurementMethod = case_when(
      source_field == "moult_note" ~ "Source notation or processing note retained during conservative moult decoding.",
      source_field == "primary_moult_status" ~ "Reported overall status or status derived from a complete primary-feather sequence as documented in the dataset methods.",
      str_starts(source_field, "body_moult_") ~ "Source body-moult ordinal score (0-3); biological meanings are not inferred.",
      str_detect(source_field, "^(P|S|T|Tail)[0-9]+$") ~ "Source-specific Ngulia or SAFRING feather score standardized as documented in the dataset methods."
    )
  )

moult_measurements <- moult |>
  left_join(measurement_keys, by = "ring_event_id") |>
  select(eventID, occurrenceID, all_of(names(moult)[-1])) |>
  pivot_longer(
    -c(eventID, occurrenceID),
    names_to = "source_field",
    values_to = "measurementValue",
    values_drop_na = TRUE
  ) |>
  left_join(moult_measurement_specs, by = "source_field")

measurements <- bind_rows(capture_measurements, moult_measurements) |>
  mutate(
    measurementID = paste0(occurrenceID, ":measurement:", source_field),
    measurementRemarks = NA_character_
  ) |>
  arrange(eventID, occurrenceID, measurementID) |>
  select(
    eventID,
    occurrenceID,
    measurementID,
    measurementType,
    measurementValue,
    measurementUnit,
    measurementMethod,
    measurementRemarks
  )

# Write Darwin Core tables -------------------------------------------------

write_csv(events, file.path(output_dir, "event.csv"), na = "")
write_csv(occurrences, file.path(output_dir, "occurrence.csv"), na = "")
write_csv(
  measurements,
  file.path(output_dir, "extended_measurement_or_fact.csv"),
  na = ""
)

# Write Darwin Core Archive descriptor ------------------------------------

meta_xml <- paste0(
  "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n",
  "<archive xmlns=\"http://rs.tdwg.org/dwc/text/\" metadata=\"eml.xml\">\n",
  "  <core encoding=\"UTF-8\" linesTerminatedBy=\"\\n\" fieldsTerminatedBy=\",\" fieldsEnclosedBy=\"&quot;\" ignoreHeaderLines=\"1\" rowType=\"http://rs.tdwg.org/dwc/terms/Event\">\n",
  "    <files><location>event.csv</location></files>\n",
  "    <id index=\"0\"/>\n",
  "    <field index=\"1\" term=\"http://purl.org/dc/terms/type\"/>\n",
  "    <field index=\"2\" term=\"http://rs.tdwg.org/dwc/terms/eventDate\"/>\n",
  "    <field index=\"3\" term=\"http://rs.tdwg.org/dwc/terms/eventType\"/>\n",
  "    <field index=\"4\" term=\"http://rs.tdwg.org/dwc/terms/samplingProtocol\"/>\n",
  "    <field index=\"5\" term=\"http://rs.tdwg.org/dwc/terms/locationID\"/>\n",
  "    <field index=\"6\" term=\"http://rs.tdwg.org/dwc/terms/locality\"/>\n",
  "    <field index=\"7\" term=\"http://rs.tdwg.org/dwc/terms/country\"/>\n",
  "    <field index=\"8\" term=\"http://rs.tdwg.org/dwc/terms/countryCode\"/>\n",
  "    <field index=\"9\" term=\"http://rs.tdwg.org/dwc/terms/decimalLatitude\"/>\n",
  "    <field index=\"10\" term=\"http://rs.tdwg.org/dwc/terms/decimalLongitude\"/>\n",
  "    <field index=\"11\" term=\"http://rs.tdwg.org/dwc/terms/geodeticDatum\"/>\n",
  "    <field index=\"12\" term=\"http://rs.tdwg.org/dwc/terms/coordinateUncertaintyInMeters\"/>\n",
  "  </core>\n",
  "  <extension encoding=\"UTF-8\" linesTerminatedBy=\"\\n\" fieldsTerminatedBy=\",\" fieldsEnclosedBy=\"&quot;\" ignoreHeaderLines=\"1\" rowType=\"http://rs.tdwg.org/dwc/terms/Occurrence\">\n",
  "    <files><location>occurrence.csv</location></files>\n",
  "    <coreid index=\"0\"/>\n",
  "    <field index=\"1\" term=\"http://rs.tdwg.org/dwc/terms/occurrenceID\"/>\n",
  "    <field index=\"2\" term=\"http://rs.tdwg.org/dwc/terms/organismID\"/>\n",
  "    <field index=\"3\" term=\"http://rs.tdwg.org/dwc/terms/basisOfRecord\"/>\n",
  "    <field index=\"4\" term=\"http://rs.tdwg.org/dwc/terms/occurrenceStatus\"/>\n",
  "    <field index=\"5\" term=\"http://rs.tdwg.org/dwc/terms/individualCount\"/>\n",
  "    <field index=\"6\" term=\"http://rs.tdwg.org/dwc/terms/organismQuantity\"/>\n",
  "    <field index=\"7\" term=\"http://rs.tdwg.org/dwc/terms/organismQuantityType\"/>\n",
  "    <field index=\"8\" term=\"http://rs.tdwg.org/dwc/terms/eventDate\"/>\n",
  "    <field index=\"9\" term=\"http://rs.tdwg.org/dwc/terms/taxonID\"/>\n",
  "    <field index=\"10\" term=\"http://rs.tdwg.org/dwc/terms/scientificName\"/>\n",
  "    <field index=\"11\" term=\"http://rs.tdwg.org/dwc/terms/taxonRank\"/>\n",
  "    <field index=\"12\" term=\"http://rs.tdwg.org/dwc/terms/kingdom\"/>\n",
  "    <field index=\"13\" term=\"http://rs.tdwg.org/dwc/terms/phylum\"/>\n",
  "    <field index=\"14\" term=\"http://rs.tdwg.org/dwc/terms/class\"/>\n",
  "    <field index=\"15\" term=\"http://rs.tdwg.org/dwc/terms/order\"/>\n",
  "    <field index=\"16\" term=\"http://rs.tdwg.org/dwc/terms/family\"/>\n",
  "    <field index=\"17\" term=\"http://rs.tdwg.org/dwc/terms/vernacularName\"/>\n",
  "    <field index=\"18\" term=\"http://rs.tdwg.org/dwc/terms/sex\"/>\n",
  "    <field index=\"19\" term=\"http://rs.tdwg.org/dwc/terms/lifeStage\"/>\n",
  "    <field index=\"20\" term=\"http://rs.tdwg.org/dwc/terms/dynamicProperties\"/>\n",
  "    <field index=\"21\" term=\"http://rs.tdwg.org/dwc/terms/occurrenceRemarks\"/>\n",
  "    <field index=\"22\" term=\"http://rs.tdwg.org/dwc/terms/recordedBy\"/>\n",
  "    <field index=\"23\" term=\"http://rs.tdwg.org/dwc/terms/identificationRemarks\"/>\n",
  "    <field index=\"24\" term=\"http://rs.tdwg.org/dwc/terms/datasetName\"/>\n",
  "    <field index=\"25\" term=\"http://purl.org/dc/terms/license\"/>\n",
  "  </extension>\n",
  "  <extension encoding=\"UTF-8\" linesTerminatedBy=\"\\n\" fieldsTerminatedBy=\",\" fieldsEnclosedBy=\"&quot;\" ignoreHeaderLines=\"1\" rowType=\"http://rs.iobis.org/obis/terms/ExtendedMeasurementOrFact\">\n",
  "    <files><location>extended_measurement_or_fact.csv</location></files>\n",
  "    <coreid index=\"0\"/>\n",
  "    <field index=\"1\" term=\"http://rs.tdwg.org/dwc/terms/occurrenceID\"/>\n",
  "    <field index=\"2\" term=\"http://rs.tdwg.org/dwc/terms/measurementID\"/>\n",
  "    <field index=\"3\" term=\"http://rs.tdwg.org/dwc/terms/measurementType\"/>\n",
  "    <field index=\"4\" term=\"http://rs.tdwg.org/dwc/terms/measurementValue\"/>\n",
  "    <field index=\"5\" term=\"http://rs.tdwg.org/dwc/terms/measurementUnit\"/>\n",
  "    <field index=\"6\" term=\"http://rs.tdwg.org/dwc/terms/measurementMethod\"/>\n",
  "    <field index=\"7\" term=\"http://rs.tdwg.org/dwc/terms/measurementRemarks\"/>\n",
  "  </extension>\n",
  "</archive>\n"
)

writeLines(meta_xml, file.path(output_dir, "meta.xml"))

# Write EML and human-readable documentation -------------------------------

creator_xml <- map_chr(metadata$authors, \(x) {
  organization_xml <- if (!is.null(x$affiliation) && nzchar(x$affiliation)) {
    glue("      <organizationName>{xml_escape(x$affiliation)}</organizationName>\n")
  } else {
    ""
  }
  orcid_xml <- if (!is.null(x$orcid) && nzchar(x$orcid)) {
    glue("      <userId directory=\"https://orcid.org/\">{xml_escape(x$orcid)}</userId>\n")
  } else {
    ""
  }

  glue(
    "    <creator>\n",
    "      <individualName>\n",
    "        <givenName>{xml_escape(x$given_name)}</givenName>\n",
    "        <surName>{xml_escape(x$family_name)}</surName>\n",
    "      </individualName>\n",
    "{organization_xml}",
    "{orcid_xml}",
    "    </creator>"
  )
})

keyword_xml <- map_chr(
  metadata$dataset$keywords,
  \(x) glue("        <keyword>{xml_escape(x)}</keyword>")
)
creators <- paste(creator_xml, collapse = "\n")
keywords <- paste(keyword_xml, collapse = "\n")
creator_roles <- publication_author_roles_text(metadata$authors)
funding_text <- purrr::map_chr(
  metadata$funding,
  \(x) glue("{x$funder}: {x$support}")
) |>
  paste(collapse = " ")
publisher_url_xml <- if (!is.null(metadata$publisher$url) && nzchar(metadata$publisher$url)) {
  glue("\n      <onlineUrl>{xml_escape(metadata$publisher$url)}</onlineUrl>")
} else {
  ""
}
publisher_xml <- glue(
  "    <publisher>\n",
  "      <organizationName>{xml_escape(metadata$publisher$name)}</organizationName>",
  "{publisher_url_xml}\n",
  "    </publisher>"
)
metadata_provider_xml <- glue(
  "    <metadataProvider>\n",
  "      <organizationName>{xml_escape(metadata$gbif$publishing_organization)}</organizationName>\n",
  "      <electronicMailAddress>{xml_escape(metadata$dataset$contact_email)}</electronicMailAddress>\n",
  "    </metadataProvider>"
)
contact_xml <- glue(
  "    <contact>\n",
  "      <organizationName>{xml_escape(metadata$gbif$publishing_organization)}</organizationName>\n",
  "      <electronicMailAddress>{xml_escape(metadata$dataset$contact_email)}</electronicMailAddress>\n",
  "    </contact>"
)
license_xml <- case_when(
  metadata$dataset$license == "CC-BY-4.0" ~ paste0(
    "    <intellectualRights>\n",
    "      <para>This work is licensed under a <ulink url=\"http://creativecommons.org/licenses/by/4.0/legalcode\"><citetitle>Creative Commons Attribution (CC-BY) 4.0 License</citetitle></ulink>.</para>\n",
    "    </intellectualRights>\n",
    "    <licensed>\n",
    "      <licenseName>Creative Commons Attribution 4.0 International</licenseName>\n",
    "      <url>https://spdx.org/licenses/CC-BY-4.0.html</url>\n",
    "      <identifier>CC-BY-4.0</identifier>\n",
    "    </licensed>"
  ),
  metadata$dataset$license == "CC0-1.0" ~ paste0(
    "    <intellectualRights>\n",
    "      <para>To the extent possible under law, the publisher has waived all copyright and related or neighboring rights to this work under a <ulink url=\"http://creativecommons.org/publicdomain/zero/1.0/legalcode\"><citetitle>CC0 1.0 Universal Public Domain Dedication</citetitle></ulink>.</para>\n",
    "    </intellectualRights>\n",
    "    <licensed>\n",
    "      <licenseName>CC0 1.0 Universal</licenseName>\n",
    "      <url>https://spdx.org/licenses/CC0-1.0.html</url>\n",
    "      <identifier>CC0-1.0</identifier>\n",
    "    </licensed>"
  ),
  TRUE ~ glue("    <intellectualRights><para>{xml_escape(metadata$dataset$license)}</para></intellectualRights>")
)
eml_package_id <- glue("{metadata$repository$url}/gbif/eml-{metadata$dataset$temporal_coverage$end}.xml")

eml <- glue(
  "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n",
  "<eml:eml xmlns:eml=\"https://eml.ecoinformatics.org/eml-2.2.0\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xsi:schemaLocation=\"https://eml.ecoinformatics.org/eml-2.2.0 https://rs.gbif.org/schema/eml-gbif-profile/1.3/eml.xsd\" packageId=\"{eml_package_id}\" system=\"https://gbif.org\" scope=\"system\" xml:lang=\"eng\">\n",
  "  <dataset>\n",
  "    <title>{xml_escape(metadata$dataset$data_title)} (GBIF ringing-event subset)</title>\n",
  "{creators}\n",
  "{metadata_provider_xml}\n",
  "    <pubDate>{format(Sys.Date(), '%Y-%m-%d')}</pubDate>\n",
  "    <language>{metadata$dataset$language}</language>\n",
  "    <abstract>\n",
  "      <para>This GBIF resource contains ringing-day events from the Ngulia ringing project in Kenya, individual bird capture and recapture occurrences, and bird-level biometric and moult observations. It excludes daily species-count summaries, environmental covariates, and analytical products. Dataset documentation and the reproducible processing workflow are available at {xml_escape(zenodo_url)}</para>\n",
  "    </abstract>\n",
  "    <keywordSet>\n{keywords}\n        <keywordThesaurus>None</keywordThesaurus>\n    </keywordSet>\n",
  "    <additionalInfo>\n",
  "      <para>{xml_escape(metadata$dataset$limitations_summary)} Event dates use the curated ringing day, which assigns captures from 20:00 onward to the following day unless the source already uses ringing-day dates. Occurrence dates preserve the cleaned source date and available time; date-only values may be ringing-day labels rather than independently known capture dates. Each daily event has at least one curated individual capture. A species missing from an event must not be interpreted as biologically absent from Ngulia. Creator roles: {xml_escape(creator_roles)} Funding: {xml_escape(funding_text)}</para>\n",
  "    </additionalInfo>\n",
  "{license_xml}\n",
  "    <coverage>\n",
  "      <geographicCoverage>\n",
  "        <geographicDescription>{xml_escape(metadata$dataset$geographic_coverage$description)}</geographicDescription>\n",
  "        <boundingCoordinates>\n",
  "          <westBoundingCoordinate>{metadata$dataset$geographic_coverage$longitude}</westBoundingCoordinate>\n",
  "          <eastBoundingCoordinate>{metadata$dataset$geographic_coverage$longitude}</eastBoundingCoordinate>\n",
  "          <northBoundingCoordinate>{metadata$dataset$geographic_coverage$latitude}</northBoundingCoordinate>\n",
  "          <southBoundingCoordinate>{metadata$dataset$geographic_coverage$latitude}</southBoundingCoordinate>\n",
  "        </boundingCoordinates>\n",
  "      </geographicCoverage>\n",
  "      <temporalCoverage><rangeOfDates>",
  "<beginDate><calendarDate>{metadata$dataset$temporal_coverage$start}</calendarDate></beginDate>",
  "<endDate><calendarDate>{metadata$dataset$temporal_coverage$end}</calendarDate></endDate>",
  "</rangeOfDates></temporalCoverage>\n",
  "    </coverage>\n",
  "{contact_xml}\n",
  "{publisher_xml}\n",
  "    <methods><methodStep><description><para>",
  "{xml_escape(metadata$dataset$methods_summary)}",
  "</para></description></methodStep></methods>\n",
  "    <literatureCited>\n{bibliography_xml}\n    </literatureCited>\n",
  "  </dataset>\n",
  "</eml:eml>\n"
)

writeLines(eml, file.path(output_dir, "eml.xml"))
unlink(file.path(output_dir, c(
  ".DS_Store",
  "README.md",
  "references.bib",
  "ngulia_gbif_dwca.zip"
)))

archive_files <- c(
  "event.csv",
  "occurrence.csv",
  "extended_measurement_or_fact.csv",
  "meta.xml",
  "eml.xml"
)
utils::zip(
  file.path(output_dir, "ngulia_gbif_dwca.zip"),
  file.path(output_dir, archive_files),
  flags = "-jq"
)

cli_alert_success("Wrote {nrow(events)} daily events to {.file event.csv}.")
cli_alert_success("Wrote {nrow(occurrences)} individual captures to {.file occurrence.csv}.")
cli_alert_success("Wrote {nrow(measurements)} bird-level facts to {.file extended_measurement_or_fact.csv}.")
cli_alert_success("Built {.file ngulia_gbif_dwca.zip}.")

if (sum(is.na(occurrences$scientificName)) > 0) {
  cli_alert_warning("{sum(is.na(occurrences$scientificName))} occurrences have no resolved scientific name.")
}
if (is.na(metadata_scalar(metadata$dataset$geographic_coverage$latitude))) {
  cli_alert_warning("GBIF coordinates and coordinate uncertainty remain to be completed in {.file config/publication/dataset_metadata.yml}.")
}
if (is.na(zenodo_concept_doi)) {
  cli_alert_warning("The Zenodo concept DOI remains to be completed in {.file config/publication/dataset_metadata.yml}.")
}
if (length(metadata$authors) == 0) {
  cli_alert_warning("GBIF dataset creators remain to be completed in {.file config/publication/dataset_metadata.yml}.")
}
if (identical(metadata$gbif$publishing_organization, "")) {
  cli_alert_warning("The GBIF publishing organization remains to be completed in {.file config/publication/dataset_metadata.yml}.")
}
