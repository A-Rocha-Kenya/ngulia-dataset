library(stringr)
library(tidyr)
source(here::here("scripts/helpers/ring_event_main.R"))

shrike_taxonomy <- tibble(
  avibase_id = c("avibase-959151D9", "avibase-EE7915A2", "avibase-97166F72", "avibase-E40C1C33", "avibase-20A6541A", "avibase-F2CEFD1A", "avibase-AF0D818A"),
  common_name = c("Red-tailed/Isabelline Shrike", "Red-tailed Shrike", "Isabelline Shrike", "Isabelline Shrike (Daurian)", "Lanius isabellinus arenarius", "Red-backed Shrike", "Unknown"),
  scientific_name = c("Lanius phoenicuroides/isabellinus", "Lanius phoenicuroides", "Lanius isabellinus", "Lanius isabellinus isabellinus", "Lanius isabellinus arenarius", "Lanius collurio", "Aves"),
  category = c("slash", "species", "species", "group (monotypic)", "subspecies", "species", "unmapped"),
  species_avibase_id = c(NA, "avibase-EE7915A2", "avibase-97166F72", "avibase-97166F72", "avibase-97166F72", "avibase-F2CEFD1A", NA_character_)
)
shrike_reference <- read_csv(here::here("config/ring_events/species_reference.csv"), col_types = cols(.default = col_character()), show_col_types = FALSE)
shrike_notes <- read_csv(here::here("config/ring_events/subspecies_lookup.csv"), col_types = cols(.default = col_character()), show_col_types = FALSE)

test_that("historical lumped shrikes retain the slash identification without diagnostic notes", {
  expect_equal(shrike_reference$avibase_id[shrike_reference$afring_number == "2288"], "avibase-959151D9")
  events <- tibble(afring_number = "2288", ring_note = c(NA, "", "isab?", "?karelini", "Sandy grey back warm-red crown"))
  resolved <- add_taxonomy(events, shrike_reference, shrike_notes, shrike_taxonomy)$ring_events
  expect_equal(resolved$avibase_id, rep("avibase-959151D9", nrow(events)))
  expect_true(all(is.na(resolved$subspecies_avibase_id)))
})

test_that("historical race labels resolve the split species and preserve valid lower ranks", {
  events <- tibble(
    afring_number = "2288",
    ring_note = c("phoen", "phoenicuroides", "phoen.", "karelini", "karel", "turkistan",
                  "isabellinus", "isabell", "Isab", "specul.", "speculigerus", "specul", "specu.", "arenarius", "other note|phoen.|1040 hrs")
  )
  resolved <- add_taxonomy(events, shrike_reference, shrike_notes, shrike_taxonomy)$ring_events
  expect_equal(resolved$avibase_id, c(rep("avibase-EE7915A2", 6), rep("avibase-97166F72", 8), "avibase-EE7915A2"))
  expect_equal(resolved$subspecies_avibase_id, c(rep(NA_character_, 9), rep("avibase-E40C1C33", 4), "avibase-20A6541A", NA_character_))
  expect_equal(resolved$common_name, shrike_taxonomy$common_name[match(resolved$avibase_id, shrike_taxonomy$avibase_id)])
  expect_equal(resolved$ring_note, events$ring_note)
  notes <- filter(shrike_notes, afring_number == "2288", !is.na(subspecies_avibase_id))
  expect_true(all(notes$subspecies_avibase_id %in% shrike_taxonomy$avibase_id))
})

test_that("all reviewed conflicting shrike notes produce Unknown with no subspecies", {
  events <- tibble(afring_number = "708", ring_note = c("phoenicuroides", "phoen", "isabellinus", "phon", "Turk"))
  resolved <- add_taxonomy(events, shrike_reference, shrike_notes, shrike_taxonomy)$ring_events
  expect_equal(resolved$avibase_id, rep("avibase-AF0D818A", 5))
  expect_equal(resolved$common_name, rep("Unknown", 5))
  expect_equal(resolved$ring_note, events$ring_note)
  expect_true(all(is.na(resolved$subspecies_avibase_id)))
})
