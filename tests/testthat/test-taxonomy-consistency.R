library(stringr)
library(tidyr)
source(here::here("scripts/helpers/ring_event_main.R"))

consistency_taxonomy <- tibble(
  avibase_id = c("a", "a1", "a2", "b", "b1", "c", "ab", "avibase-AF0D818A"),
  common_name = c("Species A", "A one", "A two", "Species B", "B one", "Species C", "A/B", "Unknown"),
  scientific_name = c("Genus alpha", "Genus alpha one", "Genus alpha two", "Genus beta", "Genus beta one", "Other gamma", "Genus alpha/beta", "Aves"),
  category = c("species", "subspecies", "subspecies", "species", "subspecies", "species", "slash", "unmapped"),
  species_avibase_id = c("a", "a", "a", "b", "b", "c", NA, NA)
)
consistency_reference <- tibble(afring_number = c("1", "2", "0"), avibase_id = c("a", "ab", "avibase-AF0D818A"))
consistency_notes <- tibble(
  afring_number = c(rep("1", 5), rep("2", 3), "0"),
  note = c("one", "two", "foreign subspecies", "foreign species", "same species", "one", "beta one", "foreign species", "one"),
  subspecies_avibase_id = c("a1", "a2", "b1", "c", "a", "a1", "b1", "c", "a1")
)

test_that("species and subspecies contradictions are audited and become Unknown for any taxon", {
  events <- tibble(afring_number = "1", ring_note = c("foreign subspecies", "foreign species"))
  result <- add_taxonomy(events, consistency_reference, consistency_notes, consistency_taxonomy)
  expect_equal(result$ring_events$avibase_id, rep("avibase-AF0D818A", 2))
  expect_true(all(is.na(result$ring_events$subspecies_avibase_id)))
  expect_equal(result$ring_events$ring_note, events$ring_note)
  expect_equal(result$audit$source_avibase_id, rep("a", 2))
  expect_equal(result$audit$note_avibase_id, c("b1", "c"))
  expect_true(all(result$audit$taxonomy_conflict))
  expect_equal(result$audit$action, rep("replace_taxon_unknown", 2))
})

test_that("compatible lower ranks survive and unmapped prose does not cause a conflict", {
  events <- tibble(afring_number = "1", ring_note = c("one", "same species|one", "one|one", NA, "plumage description"))
  result <- add_taxonomy(events, consistency_reference, consistency_notes, consistency_taxonomy)
  expect_equal(result$ring_events$avibase_id, rep("a", 5))
  expect_equal(result$ring_events$subspecies_avibase_id, c(rep("a1", 3), NA, NA))
  expect_false(any(result$audit$taxonomy_conflict))
})

test_that("slash refinement requires membership rather than accepting any diagnostic note", {
  events <- tibble(afring_number = "2", ring_note = c("one", "beta one", "foreign species", NA))
  result <- add_taxonomy(events, consistency_reference, consistency_notes, consistency_taxonomy)
  expect_equal(result$ring_events$avibase_id, c("a", "b", "avibase-AF0D818A", "ab"))
  expect_equal(result$ring_events$subspecies_avibase_id, c("a1", "b1", NA, NA))
  expect_equal(result$audit$taxonomy_conflict, c(FALSE, FALSE, TRUE))
})

test_that("multiple conflicting notes cannot be resolved by their order", {
  events <- tibble(afring_number = "1", ring_note = c("one|two", "two|one", "one|foreign subspecies", "foreign subspecies|one"))
  result <- add_taxonomy(events, consistency_reference, consistency_notes, consistency_taxonomy)
  expect_equal(result$ring_events$avibase_id, rep("avibase-AF0D818A", 4))
  expect_true(all(is.na(result$ring_events$subspecies_avibase_id)))
  expect_true(all(result$audit$taxonomy_conflict))
})

test_that("slash membership uses the note's explicit parent despite duplicate species names", {
  taxonomy <- bind_rows(consistency_taxonomy, consistency_taxonomy |> filter(avibase_id == "a") |> mutate(avibase_id = "other-a-concept", species_avibase_id = "other-a-concept"))
  events <- tibble(afring_number = "2", ring_note = "one")
  result <- add_taxonomy(events, consistency_reference, consistency_notes, taxonomy)
  expect_equal(result$ring_events$avibase_id, "a")
  expect_false(result$audit$taxonomy_conflict)
})
