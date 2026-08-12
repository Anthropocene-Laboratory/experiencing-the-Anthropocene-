# =============================================================================
# 1_build_layerA_stack_30km.R
#
# Builds ONE harmonised 30-km EPSG:3035 stack from every gridded layer this
# workspace can put on a common grid, plus the Layer-B filters held OUT of any
# clustering (AGENTS.md: "do not collapse the layers").
#
# 30 km is not a style choice: the coarsest analytic input (ERA5-HEAT UTCI) is
# 0.25 degrees (~28 km N-S). Any finer common grid would invent precision.
#
# EVERY BAND CARRIES A ROLE (see `band_roles` below), and the roles - not a
# hand-maintained list further down the file - decide what counts as an
# analysis variable. An earlier version of this script hardcoded the list twice
# and the two copies disagreed: the header claimed Layer-B filters were held
# out while the completeness message counted pop_dens_km2 among the "Layer-A"
# variables. Declaring the roles once removes the way that drifts.
#
#   A   experienceable feature   -> enters the analysis
#   B   exposure filter          -> carried on the grid, held OUT of clustering
#   QC  housekeeping             -> masking / weighting only, never a variable
#   alt redundant alternative    -> carried for comparison, out by default
#
# DELIBERATELY NOT IN THE STACK (and why):
#   heatwave_days_2022_tn_w2      night-time variant of hw_days; comparison only
#   heatwave_days_2022_compound   superseded 2026-06-27 (near-zero over 2022)
#   exposed_person_days, ghd_weighted_exposure
#                                 already A x B products; stacking them beside
#                                 their own inputs would double-count
#   pop1991                       baseline-era comparison, not a 2022 state
#   eobs_tx90 / eobs_tn90         365-band thresholds, an input to hw_days
#
# Run from the workspace ROOT.
# Writes: data_processed/layerA_stack_30km.tif
#         data_processed/tables/layerA_stack_30km.csv
#         data_processed/tables/layerA_stack_30km_bands.csv   <- the role table
# =============================================================================

suppressPackageStartupMessages({
  library(sf); library(terra)
})

root <- normalizePath(here::here(), winslash = "/", mustWork = TRUE)
GRID_M <- 30000
MIN_UTCI_COVERAGE <- 0.95 * 8760

inputs <- c(
  utci     = "Feature explorations/Heatwaves/data_processed/utci_heatstress_hours_2022.nc",
  hwd      = "Feature explorations/Heatwaves/data_processed/heatwave_days_2022_tx_w2.nc",
  crop     = "Feature explorations/Heatwaves/data_processed/crop_frac_0p1deg.tif",
  pm25     = "Feature explorations/Air quality/data_processed/cams_pm25_2024_annual_3km_3035.tif",
  built    = "Feature explorations/Technosphere/data_processed/eu_fraction_wsf3d_3km.tif",
  height   = "Feature explorations/Technosphere/data_processed/eu_height_wsf3d_3km.tif",
  light    = "Feature explorations/Technosphere/data_processed/eu_light_pollution_3km.tif",
  road     = "Feature explorations/Transport/data_processed/road_density_grip4_8km.tif",
  tland    = "Feature explorations/Transport/data_processed/transport_land_share_10km.tif",
  ookla_fx = "Feature explorations/Connectivity/data_processed/ookla_fixed_speed_5km.tif",
  ookla_mb = "Feature explorations/Connectivity/data_processed/ookla_mobile_speed_5km.tif",
  bii      = "Feature explorations/Biosphere/data_raw/biosphere/bii_v2_1_1/bii-2020_v2-1-1.tif",
  hilda    = "Feature explorations/Biosphere/data_processed/hilda_change_freq_10km_mean.tif",
  hilda_v2 = "Feature explorations/Biosphere/data_processed/hilda_v2_change_freq_1960_2019_10km_mean.tif",
  pop      = "Feature explorations/_shared/pop2020_0p1deg.tif",
  gdp      = "Feature explorations/_shared/gdp_kummu/rast_adm2_gdp_perCapita_1990_2022.tif",
  cntr     = "Feature explorations/_shared/CNTR_RG_10M_2024_4326.geojson"
)
missing <- inputs[!file.exists(file.path(root, inputs))]
if (length(missing)) stop("Run from the workspace root; missing: ", paste(missing, collapse = ", "))

out_dir    <- file.path(root, "Feature explorations/Analysis/data_processed")
out_tables <- file.path(out_dir, "tables")
dir.create(out_tables, recursive = TRUE, showWarnings = FALSE)

# 1. COMMON 30-KM EQUAL-AREA TEMPLATE ------------------------------------------
r_utci_all <- rast(file.path(root, inputs[["utci"]]))
stopifnot(all(c("hours_strong", "hours_valid") %in% names(r_utci_all)))
template <- rast(ext(project(r_utci_all[["hours_strong"]], "EPSG:3035", res = GRID_M,
                             method = "average")),
                 resolution = GRID_M, crs = "EPSG:3035")

# Most inputs are continuous intensities, fractions or count densities, so an
# areal mean ("average") is the correct aggregator. Three are not, and each gets
# its own function below: population (a count), Ookla speed (a test-weighted
# mean) and building height (a mean over built surface only).
to_grid <- function(path, layer = NULL) {
  r <- rast(file.path(root, path))
  if (!is.null(layer)) r <- r[[layer]]
  project(r, template, method = "average")
}

r_utci_strong <- to_grid(inputs[["utci"]], "hours_strong")
r_utci_valid  <- to_grid(inputs[["utci"]], "hours_valid")
r_hwdays      <- to_grid(inputs[["hwd"]])
r_crop        <- to_grid(inputs[["crop"]])
r_pm25        <- to_grid(inputs[["pm25"]])
r_built       <- to_grid(inputs[["built"]])
r_light       <- to_grid(inputs[["light"]])
r_road        <- to_grid(inputs[["road"]])       # m of road per km2, already a density
r_tland       <- to_grid(inputs[["tland"]])      # % of cell in CLC class 122
r_hilda       <- to_grid(inputs[["hilda"]])
r_hilda_v2    <- to_grid(inputs[["hilda_v2"]])

# BII and GDP are global; crop to the European window before projecting.
win_4326 <- ext(project(as.polygons(ext(template), crs = "EPSG:3035"), "EPSG:4326"))
r_bii <- project(crop(rast(file.path(root, inputs[["bii"]])), win_4326), template, method = "average")
r_gdp_all <- rast(file.path(root, inputs[["gdp"]]))
r_gdp <- project(crop(r_gdp_all[["gdp_pc_2022"]], win_4326), template, method = "average")

# Population: counts must be summed, not averaged, before densifying.
r_pop_cnt <- project(rast(file.path(root, inputs[["pop"]])), template, method = "sum")
r_popdens <- r_pop_cnt / ((GRID_M / 1000)^2)   # people per km2

# Ookla: band 1 is already a test-weighted mean WITHIN its 5-km tile, band 2 is
# the test count behind it (1 to ~40000). Averaging band 1 across tiles would
# give a tile with one test the same weight as a tile with forty thousand, so
# the aggregation has to be re-weighted: sum(speed x tests) / sum(tests).
# NA is set to 0 before summing so that partially covered 30-km cells still get
# a number; cells where no test at all was recorded come back NA rather than 0,
# because "nobody measured here" is not "the connection is infinitely slow".
ookla_to_grid <- function(path) {
  r    <- rast(file.path(root, path))
  mbps <- r[["mbps_test_weighted"]]
  n    <- r[["tests"]]
  keep <- !is.na(mbps) & !is.na(n)
  num  <- project(ifel(keep, mbps * n, 0), template, method = "sum")
  den  <- project(ifel(keep, n, 0), template, method = "sum")
  list(speed = ifel(den > 0, num / den, NA),
       tests = ifel(den > 0, den, NA))
}
ookla_fx <- ookla_to_grid(inputs[["ookla_fx"]])
ookla_mb <- ookla_to_grid(inputs[["ookla_mb"]])

# Building height: the source cell value is a mean height over the built part of
# a 3-km cell, undefined where nothing is built. A plain areal mean would let a
# 3-km cell that is 0.1% built pull the 30-km value as hard as one that is 40%
# built. Weight by built fraction instead - the two rasters share a grid, which
# is asserted rather than assumed.
r_h_src  <- rast(file.path(root, inputs[["height"]]))
r_fr_src <- rast(file.path(root, inputs[["built"]]))
compareGeom(r_h_src, r_fr_src, stopOnError = TRUE)
h_keep  <- !is.na(r_h_src) & !is.na(r_fr_src)
h_num   <- project(ifel(h_keep, r_h_src * r_fr_src, 0), template, method = "sum")
h_den   <- project(ifel(h_keep, r_fr_src, 0), template, method = "sum")
r_height <- ifel(h_den > 0, h_num / h_den, NA)

# 2. STUDY MASK ----------------------------------------------------------------
countries <- st_read(file.path(root, inputs[["cntr"]]), quiet = TRUE)
europe_ids <- unique(c(
  countries$CNTR_ID[countries$EU_STAT == "T" | countries$EFTA_STAT == "T" | countries$CC_STAT == "T"],
  "UK", "XK", "AD", "BY", "MC", "MD", "SM", "VA", "FO", "GI"
))
europe_land <- st_transform(st_make_valid(countries[countries$CNTR_ID %in% europe_ids, ]), 3035)
st_write(europe_land, file.path(out_dir, "study_mask_europe_3035.gpkg"),
         delete_dsn = TRUE, quiet = TRUE)

# 3. ASSEMBLE, WITH ONE DECLARED ROLE PER BAND ---------------------------------
stk <- c(r_built, r_height, r_light, r_pm25, r_road, r_tland,
         ookla_fx$speed, ookla_mb$speed,
         r_utci_strong, r_hwdays, r_crop, r_bii, r_hilda,
         r_popdens, r_gdp,
         r_utci_valid, ookla_fx$tests, ookla_mb$tests, r_hilda_v2)

band_roles <- rbind(
  data.frame(band = "built_pct",          role = "A",   feature = "Technosphere",
             unit = "% of cell covered by building footprint",
             note = "WSF3D via 3 km product."),
  data.frame(band = "built_height_m",     role = "A",   feature = "Technosphere",
             unit = "m, mean height weighted by built fraction",
             note = "Long tail at source (max ~283 m at 3 km); cap before mapping."),
  data.frame(band = "light_mcd_m2",       role = "A",   feature = "Technosphere",
             unit = "mcd/m2 artificial night sky brightness", note = ""),
  data.frame(band = "pm25_ug_m3",         role = "A",   feature = "Air quality",
             unit = "ug/m3 annual mean PM2.5",
             note = "CAMS reanalysis. Reference year NOT confirmed (source code 'avg25')."),
  data.frame(band = "road_density_m_km2", role = "A",   feature = "Transport",
             unit = "m of road per km2",
             note = "GRIP4. This is the 'how roaded is this place' layer."),
  data.frame(band = "transport_land_pct", role = "alt", feature = "Transport",
             unit = "% of cell in CLC class 122",
             note = paste("Land TAKE only (road/rail surfaces), not road presence - road_density_m_km2",
                          "is the 'how roaded' layer. OUT of the analysis set on a MEASURED ground, not",
                          "a preference: it is available on 33.2% of masked cells against ~85% for every",
                          "other Layer-A band, and it is uniquely limiting on 25.0% of them. Including it",
                          "drops complete cases from 56.1% to 31.1%. Promote it back by setting role='A'",
                          "here, and expect to lose half the study area.")),
  data.frame(band = "broadband_mbps",     role = "A",   feature = "Connectivity",
             unit = "Mbit/s, test-weighted fixed broadband",
             note = "Re-weighted by test count on aggregation. Read with broadband_tests."),
  data.frame(band = "mobile_mbps",        role = "A",   feature = "Connectivity",
             unit = "Mbit/s, test-weighted mobile",
             note = "Re-weighted by test count on aggregation. Read with mobile_tests."),
  data.frame(band = "utci_strong_h",      role = "A",   feature = "Heatwaves",
             unit = "hours in 2022 of strong heat stress",
             note = "ERA5-HEAT. Compare only where utci_valid_h is high."),
  data.frame(band = "hw_days",            role = "A",   feature = "Heatwaves",
             unit = "days in 2022 inside a heatwave",
             note = "Perkins-Alexander TX > P90 (1991-2020, +-2 d) for >= 3 consecutive days."),
  data.frame(band = "crop_frac",          role = "A",   feature = "Heatwaves",
             unit = "fraction of cell in cropland (0-1)", note = ""),
  data.frame(band = "bii",                role = "A",   feature = "Biosphere",
             unit = "Biodiversity Intactness Index, PERCENT (0-100)",
             note = paste("NHM v2.1.1, 2020. Source range measured 0.42-99.96, i.e. a 0-100 scale, NOT 0-1;",
                          "the planetary boundary is at 90, not 0.9. 5_bii_planetary_boundary.R already",
                          "treats it as a percent - 0_load_layers.R used to document it as 0-1.",
                          "CC-BY-NC-SA.")),
  data.frame(band = "landchange_freq",    role = "A",   feature = "Biosphere",
             unit = "mean land-use changes 1960-2019",
             note = "HILDA+ v1."),

  data.frame(band = "pop_dens_km2",       role = "B",   feature = "_shared",
             unit = "people per km2",
             note = "GHS-POP 2020, summed then densified. EXPOSURE FILTER - held out of clustering."),
  data.frame(band = "gdp_pc_2022",        role = "B",   feature = "_shared",
             unit = "GDP per capita, PPP, constant USD",
             note = "Kummu et al. ADM2. IE/LU inflated by transfer pricing. Held out of clustering."),

  data.frame(band = "utci_valid_h",       role = "QC",  feature = "Heatwaves",
             unit = "hours of valid UTCI in 2022",
             note = "Masking band: cells below MIN_UTCI_COVERAGE are dropped."),
  data.frame(band = "broadband_tests",    role = "QC",  feature = "Connectivity",
             unit = "n speed tests behind broadband_mbps",
             note = "Never report a speed without it: low counts are unreliable."),
  data.frame(band = "mobile_tests",       role = "QC",  feature = "Connectivity",
             unit = "n speed tests behind mobile_mbps",
             note = "Never report a speed without it: low counts are unreliable."),

  data.frame(band = "landchange_freq_v2", role = "alt", feature = "Biosphere",
             unit = "mean broad-class changes 1960-2019",
             note = paste("HILDA+ v2 recomputation of landchange_freq. Same grid, near-identical",
                          "distribution (medians 0.61 vs 0.64 at source). Carried for comparison,",
                          "OUT of the analysis set: two copies of one gradient would inflate PC1",
                          "and trip FAIL-1 for a purely mechanical reason.")),
  stringsAsFactors = FALSE
)

names(stk) <- band_roles$band
stopifnot(nlyr(stk) == nrow(band_roles))

stk <- mask(stk, vect(europe_land))

# UTCI is not everywhere available; unavailable hours must not read as "no heat".
stk <- mask(stk, stk[["utci_valid_h"]] >= MIN_UTCI_COVERAGE, maskvalues = 0)

writeRaster(stk, file.path(out_dir, "layerA_stack_30km.tif"), overwrite = TRUE)

df <- as.data.frame(stk, cells = TRUE, xy = TRUE, na.rm = FALSE)
write.csv(df, file.path(out_tables, "layerA_stack_30km.csv"), row.names = FALSE)

# 4. REPORT --------------------------------------------------------------------
# The analysis set is read back from the role table, so this can no longer
# disagree with the header the way the previous version did.
layerA_vars <- band_roles$band[band_roles$role == "A"]

in_mask <- rowSums(!is.na(df[, band_roles$band[band_roles$role %in% c("A", "B")]])) > 0
d <- df[in_mask, ]

avail <- data.frame(
  band = band_roles$band,
  role = band_roles$role,
  pct_available = round(100 * vapply(band_roles$band,
                                     function(v) sum(!is.na(d[[v]])), integer(1)) / nrow(d), 1),
  row.names = NULL
)
band_roles$pct_available_in_mask <- avail$pct_available
write.csv(band_roles, file.path(out_tables, "layerA_stack_30km_bands.csv"), row.names = FALSE)

complete_layerA <- complete.cases(d[, layerA_vars])
message(sprintf("30-km cells in mask: %d | complete on all %d Layer-A vars: %d (%.1f%%)",
                nrow(d), length(layerA_vars), sum(complete_layerA),
                100 * sum(complete_layerA) / nrow(d)))
# 2_diagnose_structure_30km.R fails the run below 75%; say so here rather than
# let the next script be the first place anyone notices.
if (sum(complete_layerA) / nrow(d) < 0.75)
  message("  WARNING: below the 75% complete-case floor used as FAIL-2 downstream.")

cat("\n--- BAND AVAILABILITY WITHIN THE MASK ---\n"); print(avail)
cat("\n--- SUMMARY, ANALYSIS SET ONLY ---\n"); print(summary(d[complete_layerA, layerA_vars]))
