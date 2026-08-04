# =============================================================================
# 1_build_layerA_stack_30km.R
#
# Builds ONE harmonised 30-km EPSG:3035 stack of every gridded Layer-A feature
# currently available in this workspace, plus the Layer-B filters held OUT of
# any clustering (AGENTS.md: "do not collapse the layers").
#
# 30 km is not a style choice: the coarsest analytic input (ERA5-HEAT UTCI) is
# 0.25 degrees (~28 km N-S). Any finer common grid would invent precision.
#
# Run from the workspace ROOT.
# Writes: data_processed/layerA_stack_30km.tif
#         data_processed/tables/layerA_stack_30km.csv
# =============================================================================

suppressPackageStartupMessages({
  library(sf); library(terra)
})

root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
GRID_M <- 30000
MIN_UTCI_COVERAGE <- 0.95 * 8760

inputs <- c(
  utci  = "Feature explorations/Heatwaves/data_processed/utci_heatstress_hours_2022.nc",
  hwd   = "Feature explorations/Heatwaves/data_processed/heatwave_days_2022_tx_w2.nc",
  crop  = "Feature explorations/Heatwaves/data_processed/crop_frac_0p1deg.tif",
  pm25  = "Feature explorations/Air quality/data_processed/cams_pm25_2024_annual_3km_3035.tif",
  built = "Feature explorations/Technosphere/data_processed/eu_fraction_wsf3d_3km.tif",
  light = "Feature explorations/Technosphere/data_processed/eu_light_pollution_3km.tif",
  bii   = "Feature explorations/Biosphere/data_raw/biosphere/bii_v2_1_1/bii-2020_v2-1-1.tif",
  hilda = "Feature explorations/Biosphere/data_processed/hilda_change_freq_10km_mean.tif",
  pop   = "Feature explorations/_shared/pop2020_0p1deg.tif",
  gdp   = "Feature explorations/_shared/gdp_kummu/rast_adm2_gdp_perCapita_1990_2022.tif",
  cntr  = "Feature explorations/_shared/CNTR_RG_10M_2024_4326.geojson"
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

# Every input is a continuous intensity, fraction or count density, so an areal
# mean ("average") is the correct aggregator. Population is the exception: it is
# a count, summed first at source resolution then converted to a density.
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
r_hilda       <- to_grid(inputs[["hilda"]])

# BII and GDP are global; crop to the European window before projecting.
win_4326 <- ext(project(as.polygons(ext(template), crs = "EPSG:3035"), "EPSG:4326"))
r_bii <- project(crop(rast(file.path(root, inputs[["bii"]])), win_4326), template, method = "average")
r_gdp_all <- rast(file.path(root, inputs[["gdp"]]))
r_gdp <- project(crop(r_gdp_all[["gdp_pc_2022"]], win_4326), template, method = "average")

# Population: counts must be summed, not averaged, before densifying.
r_pop_cnt <- project(rast(file.path(root, inputs[["pop"]])), template, method = "sum")
r_popdens <- r_pop_cnt / ((GRID_M / 1000)^2)   # people per km2

# 2. STUDY MASK ----------------------------------------------------------------
countries <- st_read(file.path(root, inputs[["cntr"]]), quiet = TRUE)
europe_ids <- unique(c(
  countries$CNTR_ID[countries$EU_STAT == "T" | countries$EFTA_STAT == "T" | countries$CC_STAT == "T"],
  "UK", "XK", "AD", "BY", "MC", "MD", "SM", "VA", "FO", "GI"
))
europe_land <- st_transform(st_make_valid(countries[countries$CNTR_ID %in% europe_ids, ]), 3035)
st_write(europe_land, file.path(out_dir, "study_mask_europe_3035.gpkg"),
         delete_dsn = TRUE, quiet = TRUE)

stk <- c(r_built, r_light, r_pm25, r_utci_strong, r_hwdays, r_crop, r_bii, r_hilda,
         r_popdens, r_gdp, r_utci_valid)
names(stk) <- c("built_pct", "light_mcd_m2", "pm25_ug_m3", "utci_strong_h", "hw_days",
                "crop_frac", "bii", "landchange_freq", "pop_dens_km2",
                "gdp_pc_2022", "utci_valid_h")
stk <- mask(stk, vect(europe_land))

# UTCI is not everywhere available; unavailable hours must not read as "no heat".
stk <- mask(stk, stk[["utci_valid_h"]] >= MIN_UTCI_COVERAGE, maskvalues = 0)

writeRaster(stk, file.path(out_dir, "layerA_stack_30km.tif"), overwrite = TRUE)

df <- as.data.frame(stk, cells = TRUE, xy = TRUE, na.rm = FALSE)
write.csv(df, file.path(out_tables, "layerA_stack_30km.csv"), row.names = FALSE)

complete_layerA <- complete.cases(df[, c("built_pct", "light_mcd_m2", "pm25_ug_m3",
                                         "utci_strong_h", "hw_days", "crop_frac",
                                         "bii", "landchange_freq", "pop_dens_km2")])
message(sprintf("30-km cells in mask: %d | complete on all 9 Layer-A vars: %d",
                sum(!is.na(df$built_pct) | !is.na(df$bii)), sum(complete_layerA)))
print(summary(df[complete_layerA, names(stk)]))
