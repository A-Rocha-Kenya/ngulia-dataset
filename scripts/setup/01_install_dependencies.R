# Install R dependencies -------------------------------------------------

packages <- c(
  "auk",
  "cli",
  "dplyr",
  "ecmwfr",
  "ggplot2",
  "glue",
  "here",
  "jsonlite",
  "lubridate",
  "mgcv",
  "patchwork",
  "purrr",
  "readr",
  "readxl",
  "rlang",
  "scales",
  "stringr",
  "testthat",
  "tidyr",
  "data.table",
  "htmltools",
  "MASS",
  "nnet",
  "rnaturalearth",
  "rnaturalearthdata",
  "sf",
  "tibble",
  "yaml"
)

install.packages(setdiff(packages, rownames(installed.packages())))
