# =============================================================================
# 5c_diagnose_forest_history.R
#
# QUESTION. `5_build_wild_domesticated_built.R` leaves all HILDA forest in
# `unresolved` unless Lesiv is supplied. Lesiv is not on disk. HILDA's own
# forest codes 40-45 are botanical (leaf type, phenology) and carry no
# management information, so they cannot split wild from domesticated.
#
# But HILDA carries something else we do not use: sixty annual states. A pixel
# that was cropland in 1960 and forest in 2015 has been transformed inside the
# observation window, whatever its leaf type. That is a management fact HILDA
# really does hold.
#
# This script measures how much forest that would move, so the decision to wire
# it in (or not) rests on a number rather than on an impression.
#
# ---------------------------------------------------------------------------
# READING RULE, WRITTEN BEFORE THE MEASUREMENT
# ---------------------------------------------------------------------------
# S = share of 2015 forest AREA (not pixel count) that was NOT forest in 1960,
#     over the same 32-country study area and extent as the pipeline.
#
#   S < 10%   -> HILDA history buys little. The forest bucket stays essentially
#                unresolved and Lesiv is the only route. Do not wire it in.
#   S >= 25%  -> HILDA history alone moves a material share of forest out of
#                `unresolved`. Worth wiring in, with a churn filter.
#   10-25%    -> Worth wiring in but not decisive alone; report and revisit once
#                Lesiv is available.
#
# WHAT THIS MEASUREMENT IS NOT, stated before it is read:
#   * Two endpoints only. Forest -> cropland -> forest returns here as "stable".
#     S is therefore a LOWER BOUND on forest that changed.
#   * NOT churn-filtered. The 2026-08-13 flicker test found 62.6% of HILDA
#     transitions are <= 2-year excursions. A flicker landing exactly on 1960
#     or on 2015 inflates S. So S is a bound from below on real change and from
#     above on nothing -- it cannot be read as the final number either way.
#   * Areas are weighted by true cell area (cellSize), not counted as pixels:
#     0.01 degree cells shrink by ~40% between 34 N and 72 N.
# =============================================================================

suppressPackageStartupMessages(library(terra))

script_arg <- commandArgs(FALSE)
script_arg <- script_arg[startsWith(script_arg, "--file=")]
this_file <- normalizePath(sub("^--file=", "", script_arg[[1]]), mustWork = TRUE)
root <- normalizePath(file.path(dirname(this_file), "../../.."), mustWork = TRUE)

bio <- file.path(root, "Feature explorations", "Biosphere")
hilda_dir <- file.path(bio, "data_raw", "biosphere", "hilda_plus_v2", "states_wgs84")
hilda_path <- function(y) file.path(
  hilda_dir, sprintf("hilda_plus_states_%d_GLOB-v2_wgs84.tif", y)
)

FOREST <- 40L:45L
VALID  <- c(11L, 22L, 23L, 24L, 33L, 40L:45L, 55L, 66L)
year_from <- 1960L
year_to   <- 2015L

# Same extent and same country set as the pipeline, so the numbers are
# comparable with trajectory_summary_10km.csv.
study_ext <- ext(-25, 45, 34, 72)
euro_codes <- c(
  "AT", "BE", "BG", "HR", "CY", "CZ", "DK", "EE", "FI", "FR", "DE", "EL",
  "HU", "IE", "IT", "LV", "LT", "LU", "MT", "NL", "PL", "PT", "RO", "SK",
  "SI", "ES", "SE", "UK", "IS", "LI", "NO", "CH"
)
border_path <- file.path(
  root, "Feature explorations", "_shared", "CNTR_RG_10M_2024_4326.geojson"
)
countries <- vect(border_path)
study <- crop(countries[countries$CNTR_ID %in% euro_codes, ], study_ext)

message("Reading HILDA ", year_from, " and ", year_to)
a <- crop(rast(hilda_path(year_from)), study_ext, snap = "out")
b <- crop(rast(hilda_path(year_to)),   study_ext, snap = "out")

message("Masking to study countries")
a <- mask(a, study)
b <- mask(b, study)

# True area of every 0.01 degree cell, in km2.
area_km2 <- cellSize(b, unit = "km", mask = FALSE)

sum_area <- function(mask_layer) {
  as.numeric(global(ifel(mask_layer, area_km2, 0), "sum", na.rm = TRUE)[1, 1])
}

forest_from <- a %in% FOREST
forest_to   <- b %in% FOREST
valid_to    <- b %in% VALID

land_km2        <- sum_area(valid_to)
forest_to_km2   <- sum_area(forest_to)
forest_from_km2 <- sum_area(forest_from)
converted_km2   <- sum_area(forest_to & !forest_from)   # became forest
stable_km2      <- sum_area(forest_to & forest_from)
lost_km2        <- sum_area(forest_from & !forest_to)   # stopped being forest

S <- 100 * converted_km2 / forest_to_km2

verdict <- if (S < 10) {
  "BELOW 10% -- HILDA history buys little; do not wire it in"
} else if (S >= 25) {
  "AT OR ABOVE 25% -- material; worth wiring in with a churn filter"
} else {
  "BETWEEN 10% AND 25% -- worth wiring in, not decisive alone"
}

out <- data.frame(
  year_from = year_from,
  year_to = year_to,
  land_km2 = land_km2,
  forest_km2_from = forest_from_km2,
  forest_km2_to = forest_to_km2,
  forest_pct_of_land_to = 100 * forest_to_km2 / land_km2,
  converted_to_forest_km2 = converted_km2,
  stable_forest_km2 = stable_km2,
  lost_forest_km2 = lost_km2,
  S_pct_of_2015_forest = S,
  S_pp_of_land = 100 * converted_km2 / land_km2,
  verdict = verdict,
  churn_filtered = FALSE,
  endpoints_only = TRUE,
  stringsAsFactors = FALSE
)

tables_dir <- file.path(bio, "data_processed", "wild_domesticated_built", "tables")
dir.create(tables_dir, recursive = TRUE, showWarnings = FALSE)
csv_path <- file.path(tables_dir, "forest_history_diagnostic.csv")
write.csv(out, csv_path, row.names = FALSE)

cat("\n--- Forest history, ", year_from, " -> ", year_to, " ---\n", sep = "")
cat(sprintf("Study land                       : %12.0f km2\n", land_km2))
cat(sprintf("Forest %d                        : %12.0f km2\n", year_from, forest_from_km2))
cat(sprintf("Forest %d                        : %12.0f km2 (%.1f%% of land)\n",
            year_to, forest_to_km2, 100 * forest_to_km2 / land_km2))
cat(sprintf("  of which NOT forest in %d      : %12.0f km2\n", year_from, converted_km2))
cat(sprintf("  of which forest in both years  : %12.0f km2\n", stable_km2))
cat(sprintf("Forest in %d, gone by %d        : %12.0f km2\n",
            year_from, year_to, lost_km2))
cat(sprintf("\nS = %.2f%% of %d forest area (%.2f pp of study land)\n",
            S, year_to, 100 * converted_km2 / land_km2))
cat("VERDICT against the rule written above: ", verdict, "\n", sep = "")
cat("Endpoints only, not churn-filtered: S is a lower bound on forest that changed.\n")
cat("Wrote ", csv_path, "\n", sep = "")
