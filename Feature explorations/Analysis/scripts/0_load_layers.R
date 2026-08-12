# =============================================================================
# 0_load_layers.R
#
# Interactive loader for every data layer behind the maps in this workspace.
# Not a pipeline step: nothing is written, nothing is recomputed. It only points
# R at files that already exist and hands them back as terra / sf / data.frame
# objects so they can be poked at in RStudio.
#
# Run after opening the repository's .Rproj in RStudio:
#     source("Feature explorations/Analysis/scripts/0_load_layers.R")
#
# Then:
#     anth_layers()              # what exists, where, in what units
#     r <- anth("pm25")          # load one layer (cached)
#     anth_plot("pm25")          # quick look
#     L <- anth_all()            # every light layer at once, as a named list
#     anth_tables()              # every CSV written by the mapping scripts
#     t <- anth_table("wealth_age_by_country")
#
# By default, both processed and raw paths are resolved inside this clone.
# `data_raw/` is ignored by git, so downloaded files stay local. If raw files
# are stored on another disk, override their project root before sourcing:
#         options(anth.raw_root = "D:/somewhere/Experiencing the anthropocene")
#     or set the environment variable ANTH_RAW_ROOT.
# =============================================================================

suppressPackageStartupMessages({
  library(terra)
  library(sf)
})

# --- roots -------------------------------------------------------------------

anth_root <- normalizePath(here::here(), winslash = "/", mustWork = TRUE)

raw_override <- getOption("anth.raw_root", NULL)
if (is.null(raw_override) || !length(raw_override) || !nzchar(raw_override[1])) {
  raw_override <- Sys.getenv("ANTH_RAW_ROOT", unset = "")
}
if (!nzchar(raw_override[1])) raw_override <- anth_root
anth_raw_root <- normalizePath(raw_override[1], winslash = "/", mustWork = FALSE)

FE <- "Feature explorations"

# EPSG:3035 as an explicit PROJ string. terra can silently return NA over
# DE/NL/BE/CH/AT when handed the "EPSG:3035" code on this machine (missing PROJ
# grid); the string does not. Use it for any reprojection you do here.
# See Feature explorations/Transport/transport_land_source_note.md.
LAEA_PROJ <- paste0("+proj=laea +lat_0=52 +lon_0=10 +x_0=4321000 +y_0=3210000 ",
                    "+ellps=GRS80 +units=m +no_defs")

# --- the registry ------------------------------------------------------------
# role  : A = experienceable feature, B = exposure filter, analysis, shared
# store : repo (processed/shared path) | raw (data_raw path under anth_raw_root)
# heavy : skipped by anth_all() unless heavy = TRUE is asked for
# kind  : raster | vector

reg <- function(id, feature, role, kind, store, path, unit, note = "", heavy = FALSE)
  data.frame(id, feature, role, kind, store, path, unit, note, heavy,
             stringsAsFactors = FALSE)

anth_registry <- rbind(

  # ---- Layer A: experienceable features, processed ---------------------------
  reg("pm25", "Air quality", "A", "raster", "repo",
      file.path(FE, "Air quality/data_processed/cams_pm25_2024_annual_3km_3035.tif"),
      "ug/m3 annual mean PM2.5",
      "CAMS European reanalysis, 3 km, EPSG:3035. Reference year NOT confirmed (source file code 'avg25')."),

  reg("built_fraction", "Technosphere", "A", "raster", "repo",
      file.path(FE, "Technosphere/data_processed/eu_fraction_wsf3d_3km.tif"),
      "% of cell covered by building footprint",
      "WSF3D, aggregated to 3 km, EPSG:3035. Range 0-46."),

  reg("built_height", "Technosphere", "A", "raster", "repo",
      file.path(FE, "Technosphere/data_processed/eu_height_wsf3d_3km.tif"),
      "m, mean building height",
      "WSF3D, 3 km, EPSG:3035. Long tail (max ~283 m) - cap before mapping."),

  reg("light_pollution", "Technosphere", "A", "raster", "repo",
      file.path(FE, "Technosphere/data_processed/eu_light_pollution_3km.tif"),
      "mcd/m2 artificial night sky brightness",
      "3 km, EPSG:3035."),

  reg("road_density", "Transport", "A", "raster", "repo",
      file.path(FE, "Transport/data_processed/road_density_grip4_8km.tif"),
      "m of road per km2",
      "GRIP4, 8 km, EPSG:3035. This is the 'how roaded is this place' layer."),

  reg("transport_land", "Transport", "A", "raster", "repo",
      file.path(FE, "Transport/data_processed/transport_land_share_10km.tif"),
      "% of cell in CLC class 122",
      "Corine land TAKE only (road/rail surfaces), not road presence. Max ~8.9%."),

  reg("ookla_fixed", "Connectivity", "A", "raster", "repo",
      file.path(FE, "Connectivity/data_processed/ookla_fixed_speed_5km.tif"),
      "band 1 = Mbit/s (test-weighted), band 2 = n tests",
      "Ookla Open Data, 5 km, EPSG:3035."),

  reg("ookla_mobile", "Connectivity", "A", "raster", "repo",
      file.path(FE, "Connectivity/data_processed/ookla_mobile_speed_5km.tif"),
      "band 1 = Mbit/s (test-weighted), band 2 = n tests",
      "Ookla Open Data, 5 km, EPSG:3035."),

  reg("hilda_change_freq", "Biosphere", "A", "raster", "repo",
      file.path(FE, "Biosphere/data_processed/hilda_change_freq_10km_mean.tif"),
      "mean number of land-use changes 1960-2019",
      "HILDA+ v1 change-frequency, aggregated to 0.1 deg, EPSG:4326."),

  reg("hilda_v2_change_freq", "Biosphere", "A", "raster", "repo",
      file.path(FE, "Biosphere/data_processed/hilda_v2_change_freq_1960_2019_10km_mean.tif"),
      "mean number of broad-class changes 1960-2019",
      "HILDA+ v2 recomputation of the same quantity. 0.1 deg, EPSG:4326."),

  reg("heatwave_days", "Heatwaves", "A", "raster", "repo",
      file.path(FE, "Heatwaves/data_processed/heatwave_days_2022_tx_w2.nc"),
      "days in 2022 inside a heatwave",
      "Perkins-Alexander: TX > P90 (1991-2020 baseline, +-2 d window) for >= 3 consecutive days. 0.1 deg."),

  reg("heatwave_days_tn", "Heatwaves", "A", "raster", "repo",
      file.path(FE, "Heatwaves/data_processed/heatwave_days_2022_tn_w2.nc"),
      "days in 2022, night-time (TN) definition",
      "Kept for comparison only; the TX version above is the standard used."),

  reg("heatwave_days_compound", "Heatwaves", "A", "raster", "repo",
      file.path(FE, "Heatwaves/data_processed/heatwave_days_2022_compound_w2.nc"),
      "days in 2022, compound TX+TN definition",
      "SUPERSEDED (2026-06-27): near-zero over 2022. Do not map without saying so."),

  reg("utci_hours", "Heatwaves", "A", "raster", "repo",
      file.path(FE, "Heatwaves/data_processed/utci_heatstress_hours_2022.nc"),
      "hours in 2022 per stress class",
      "ERA5-HEAT, 0.25 deg. 5 bands: moderate / strong / unrecovered / valid / verystrong. Divide by hours_valid before comparing cells."),

  reg("crop_frac", "Heatwaves", "A", "raster", "repo",
      file.path(FE, "Heatwaves/data_processed/crop_frac_0p1deg.tif"),
      "fraction of cell in cropland (0-1)", "0.1 deg, EPSG:4326."),

  # ---- Layer A x population: exposure products -------------------------------
  reg("exposed_person_days", "Heatwaves", "A", "raster", "repo",
      file.path(FE, "Heatwaves/data_processed/exposed_person_days_2022_tx_w2.nc"),
      "person-days of heatwave exposure, 2022",
      "heatwave_days x GHS-POP 2020. Sums to ~9.9 billion person-days over Europe."),

  reg("ghd_weighted_exposure", "Heatwaves", "A", "raster", "repo",
      file.path(FE, "Heatwaves/data_processed/ghd_weighted_exposure_2022_tx.nc"),
      "GHD-weighted person-days, 2022",
      "Person-days reweighted by the age structure of heat vulnerability."),

  # ---- Layer B: exposure filters (held OUT of any clustering) ----------------
  reg("pop2020", "_shared", "B", "raster", "repo",
      file.path(FE, "_shared/pop2020_0p1deg.tif"),
      "people per 0.1 deg cell (count, not density)",
      "GHS-POP 2020 aggregated. SUM when regridding, never average."),

  reg("pop1991", "Heatwaves", "B", "raster", "repo",
      file.path(FE, "Heatwaves/data_processed/pop1991_0p1deg.tif"),
      "people per 0.1 deg cell, 1991", "Only used for baseline-era comparisons."),

  reg("gdp_pc", "_shared", "B", "raster", "repo",
      file.path(FE, "_shared/gdp_kummu/rast_adm2_gdp_perCapita_1990_2022.tif"),
      "GDP per capita, PPP, constant USD",
      "Kummu et al. gridded ADM2, 33 bands gdp_pc_1990..gdp_pc_2022, global 0.083 deg. IE/LU inflated by transfer pricing."),

  # ---- Analysis products ------------------------------------------------------
  reg("layerA_stack", "Analysis", "analysis", "raster", "repo",
      file.path(FE, "Analysis/data_processed/layerA_stack_30km.tif"),
      "11 harmonised bands on a common 30 km grid",
      "built_pct, light_mcd_m2, pm25_ug_m3, utci_strong_h, hw_days, crop_frac, bii, landchange_freq, pop_dens_km2, gdp_pc_2022, utci_valid_h. 30 km because ERA5-HEAT (0.25 deg) is the coarsest input."),

  reg("archetypes", "Analysis", "analysis", "raster", "repo",
      file.path(FE, "Analysis/data_processed/exposure_archetypes_30km.tif"),
      "cluster id 1-4 (categorical)",
      "k-means over 6 Layer-A features at 30 km. Labels in tables/archetypes_profiles_30km.csv."),

  reg("archetypes_profile3", "Analysis", "analysis", "raster", "repo",
      file.path(FE, "Analysis/data_processed/profile3_corrected_cluster_labels_30km.tif"),
      "cluster id 1-2 (categorical)", "Earlier 2-cluster variant, kept for comparison."),

  reg("study_mask", "Analysis", "analysis", "vector", "repo",
      file.path(FE, "Analysis/data_processed/study_mask_europe_3035.gpkg"),
      "study-area polygon, EPSG:3035", "The Europe window every 30 km product is cut to."),

  # ---- Shared boundaries ------------------------------------------------------
  reg("countries", "_shared", "shared", "vector", "repo",
      file.path(FE, "_shared/CNTR_RG_10M_2024_4326.geojson"),
      "country polygons, EPSG:4326", "Eurostat GISCO 10M 2024. The basemap of every map here."),

  reg("nuts", "_shared", "shared", "vector", "repo",
      file.path(FE, "_shared/NUTS_RG_10M_2021_4326.geojson"),
      "NUTS 0-3 polygons, EPSG:4326",
      "Eurostat GISCO 10M 2021. Filter on LEVL_CODE == 3 for the NUTS3 choropleths. UK absent."),

  # ---- Raw layers: local-only, mapped straight from source --------------------
  reg("bii_2020", "Biosphere", "A", "raster", "raw",
      file.path(FE, "Biosphere/data_raw/biosphere/bii_v2_1_1/bii-2020_v2-1-1.tif"),
      "Biodiversity Intactness Index, PERCENT (0-100)",
      paste("NHM v2.1.1, global, ~1 km. Planetary boundary drawn at 90, not 0.9:",
            "the raster is a percent (measured range 0.42-99.96), which this entry",
            "documented as 0-1 until 2026-08-11. CC-BY-NC-SA."), heavy = TRUE),

  reg("bii_2015", "Biosphere", "A", "raster", "raw",
      file.path(FE, "Biosphere/data_raw/biosphere/bii_v2_1_1/bii-2015_v2-1-1.tif"),
      "Biodiversity Intactness Index, PERCENT (0-100)",
      "The year actually mapped in bii_planetary_boundary_2015.png. Same 0-100 scale as bii_2020.", heavy = TRUE),

  reg("anthromes_1960", "Biosphere", "A", "raster", "raw",
      file.path(FE, "Biosphere/data_raw/biosphere/anthromes_12k/anthromes1960AD.asc"),
      "anthrome class (categorical)",
      "Anthromes 12K. Class codes in the mapping script 1_map_biosphere_anthromes.R.", heavy = TRUE),

  reg("anthromes_2015", "Biosphere", "A", "raster", "raw",
      file.path(FE, "Biosphere/data_raw/biosphere/anthromes_12k/anthromes2015AD.asc"),
      "anthrome class (categorical)", "Anthromes 12K.", heavy = TRUE),

  reg("hilda_change_freq_raw", "Biosphere", "A", "raster", "raw",
      file.path(FE, "Biosphere/data_raw/biosphere/hilda_plus/hildap_vGLOB-1.0_change-layers/HILDAplus_vGLOB-1.0_luc_change-freq_1960-2019_wgs84.tif"),
      "number of land-use changes, native ~1 km",
      "Source of hilda_change_freq. Global, large.", heavy = TRUE),

  # ---- Climate baselines: large, rarely needed interactively ------------------
  reg("eobs_tx90", "Heatwaves", "A", "raster", "repo",
      file.path(FE, "Heatwaves/data_processed/eobs_tx90_1991_2020_w2.nc"),
      "degC, day-of-year P90 of TX",
      "365 bands, one per DOY, 1991-2020 baseline, +-2 d window. The threshold field heatwave_days is built against.", heavy = TRUE),

  reg("eobs_tn90", "Heatwaves", "A", "raster", "repo",
      file.path(FE, "Heatwaves/data_processed/eobs_tn90_1991_2020_w2.nc"),
      "degC, day-of-year P90 of TN", "365 bands. Night-time counterpart.", heavy = TRUE)
)

anth_registry$full_path <- ifelse(anth_registry$store == "repo",
                                  file.path(anth_root, anth_registry$path),
                                  file.path(anth_raw_root, anth_registry$path))
anth_registry$exists <- file.exists(anth_registry$full_path)

# --- accessors ---------------------------------------------------------------

.anth_cache <- new.env(parent = emptyenv())

#' The registry, with availability. Filter on feature / role / store as usual.
anth_layers <- function(role = NULL, feature = NULL, only_available = FALSE) {
  x <- anth_registry
  if (!is.null(role))    x <- x[x$role %in% role, ]
  if (!is.null(feature)) x <- x[x$feature %in% feature, ]
  if (only_available)    x <- x[x$exists, ]
  x[, c("id", "feature", "role", "kind", "store", "unit", "heavy", "exists")]
}

#' Everything the registry knows about one layer, printed.
anth_info <- function(id) {
  row <- anth_registry[anth_registry$id == id, ]
  if (!nrow(row)) stop("Unknown layer id: ", id, ". See anth_layers().")
  cat(row$id, " [", row$feature, " / Layer ", row$role, "]\n", sep = "")
  cat("  unit : ", row$unit, "\n", sep = "")
  cat("  note : ", row$note, "\n", sep = "")
  cat("  file : ", row$full_path, if (!row$exists) "   << MISSING", "\n", sep = "")
  invisible(row)
}

#' Load one layer by id. Rasters come back as SpatRaster (terra reads lazily,
#' so this is cheap even for the heavy ones), vectors as sf. Cached per session.
anth <- function(id, refresh = FALSE) {
  row <- anth_registry[anth_registry$id == id, ]
  if (!nrow(row)) stop("Unknown layer id: ", id, ". See anth_layers().")
  if (!row$exists) {
    stop("Not on disk: ", row$full_path,
         if (row$store == "raw")
           "\n  This is a raw layer. Download it into this clone or set options(anth.raw_root = ...)."
         else "")
  }
  if (!refresh && !is.null(.anth_cache[[id]])) return(.anth_cache[[id]])
  obj <- switch(row$kind,
    raster = terra::rast(row$full_path),
    vector = sf::st_read(row$full_path, quiet = TRUE),
    stop("Unhandled kind: ", row$kind))
  .anth_cache[[id]] <- obj
  obj
}

#' Load many at once into a named list. Heavy layers (global rasters, 365-band
#' baselines) are skipped unless heavy = TRUE.
anth_all <- function(role = NULL, feature = NULL, heavy = FALSE) {
  x <- anth_registry[anth_registry$exists, ]
  if (!is.null(role))    x <- x[x$role %in% role, ]
  if (!is.null(feature)) x <- x[x$feature %in% feature, ]
  if (!heavy)            x <- x[!x$heavy, ]
  out <- lapply(x$id, anth)
  names(out) <- x$id
  out
}

#' Quick look. Rasters are drawn with the country outlines on top, in the
#' raster's own CRS - a sanity check, not a figure. The publication maps are
#' made by the numbered scripts in each feature's scripts/ folder.
anth_plot <- function(id, band = 1, ...) {
  row <- anth_registry[anth_registry$id == id, ]
  obj <- anth(id)
  if (row$kind == "vector") return(plot(sf::st_geometry(obj), ...))
  r <- obj[[band]]
  terra::plot(r, main = paste0(id, " (", names(r), ")"), ...)
  cn <- try(anth("countries"), silent = TRUE)
  if (!inherits(cn, "try-error")) {
    cn <- sf::st_transform(cn, terra::crs(r))
    plot(sf::st_geometry(cn), add = TRUE, border = "grey30", lwd = 0.4)
  }
  invisible(r)
}

# --- tables ------------------------------------------------------------------

#' Every CSV written by the mapping scripts, discovered rather than hardcoded.
anth_tables <- function() {
  dirs <- Sys.glob(file.path(anth_root, FE, "*", "data_processed", "tables"))
  files <- list.files(dirs, pattern = "\\.csv$", full.names = TRUE)
  if (!length(files)) return(data.frame())
  data.frame(
    name    = tools::file_path_sans_ext(basename(files)),
    feature = basename(dirname(dirname(dirname(files)))),
    path    = files,
    stringsAsFactors = FALSE
  )
}

#' Read one of them by name (basename without .csv).
anth_table <- function(name) {
  tb <- anth_tables()
  hit <- tb[tb$name == name, ]
  if (nrow(hit) == 0) stop("Unknown table: ", name, ". See anth_tables().")
  if (nrow(hit) > 1)  stop("Ambiguous name in features: ",
                           paste(hit$feature, collapse = ", "))
  utils::read.csv(hit$path, encoding = "UTF-8", check.names = FALSE)
}

# --- session banner ----------------------------------------------------------

local({
  ok <- sum(anth_registry$exists)
  n  <- nrow(anth_registry)
  cat("\nExperiencing the Anthropocene - data layers\n")
  cat("  workspace : ", anth_root, "\n", sep = "")
  cat("  raw root  : ", anth_raw_root,
      if (!dir.exists(anth_raw_root)) "   << NOT FOUND", "\n", sep = "")
  cat("  layers    : ", ok, "/", n, " on disk", sep = "")
  miss <- anth_registry$id[!anth_registry$exists]
  if (length(miss)) cat("   (missing: ", paste(miss, collapse = ", "), ")", sep = "")
  cat("\n  tables    : ", nrow(anth_tables()), " CSVs\n", sep = "")
  cat("\n  anth_layers()  anth_info(id)  anth(id)  anth_plot(id)  anth_all()\n")
  cat("  anth_tables()  anth_table(name)\n\n")
})
