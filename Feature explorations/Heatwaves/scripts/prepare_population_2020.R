# Population preparation for GHS-POP 2020.
#
# Steps:
#   1. Load the target 0.1-degree E-OBS template grid.
#   2. Unzip + crop GHS-POP 2020 (EPSG:4326, 30 arcsec) to the template extent.
#   3. Clamp negative values (NoData) to 0.
#   4. Aggregate the fine grid to the 0.1-degree grid by area-weighted SUM
#      (exactextractr) to conserve counts.
#   5. Save the aggregated population raster.
#
# Run:
#   & 'C:/Program Files/R/R-4.5.3/bin/Rscript.exe' 'Feature explorations/Heatwaves/scripts/prepare_population_2020.R'
# Note: pop2020_0p1deg.tif is a cross-feature file, shared with Biosphere - it is
# written to Feature explorations/_shared, not to this feature's own data_processed.

suppressMessages({
  library(terra)
  library(sf)
  library(exactextractr)
})

t0 <- Sys.time()
proj_dir  <- normalizePath(file.path("Feature explorations", "Heatwaves"), mustWork = TRUE)
raw_dir   <- file.path(proj_dir, "data_raw")
out_dir   <- file.path(proj_dir, "data_processed")
shared_dir <- normalizePath(file.path("Feature explorations", "_shared"), mustWork = TRUE)

# ---- 1. Target grid from E-OBS P90 thresholds --------------------------------
eobs_ref <- file.path(out_dir, "eobs_tx90_1991_2020_w2.nc")
stopifnot(file.exists(eobs_ref))
template <- rast(eobs_ref)[[1]]
template[] <- NA  # geometry only
box <- ext(template)

cat(sprintf("Target grid: %d x %d cells, ext [%g,%g,%g,%g]\n",
            nrow(template), ncol(template), box[1], box[2], box[3], box[4]))

# ---- 2. Unzip + crop GHS-POP 2020 --------------------------------------------
ghs_dir <- file.path(raw_dir, "ghsl_pop_30arcsec")
zipf <- file.path(ghs_dir, "GHS_POP_E2020_GLOBE_R2023A_4326_30ss_V1_0.zip")
tif_name <- "GHS_POP_E2020_GLOBE_R2023A_4326_30ss_V1_0.tif"
tif_path <- file.path(ghs_dir, tif_name)

if (!file.exists(tif_path)) {
  cat("Unzipping", basename(zipf), "...\n")
  utils::unzip(zipf, files = tif_name, exdir = ghs_dir)
}
stopifnot(file.exists(tif_path))

cat("Loading and cropping GHS-POP 2020...\n")
pop2020 <- rast(tif_path)
pop2020_crop <- crop(pop2020, box, snap = "out")
pop2020_crop <- classify(pop2020_crop, cbind(-Inf, 0, 0)) # GHS NoData is negative

fine_total <- as.numeric(global(pop2020_crop, "sum", na.rm = TRUE))
cat(sprintf("Fine-grid total population (box): %.0f\n", fine_total))

# ---- 3. Count-conserving aggregation to 0.1 deg ------------------------------
cat("Building target grid polygons + area-weighted sum (exactextractr)...\n")
grid_poly <- st_as_sf(as.polygons(template, dissolve = FALSE, na.rm = FALSE))
grid_poly$cell <- seq_len(nrow(grid_poly))
grid_poly$pop2020 <- exact_extract(pop2020_crop, grid_poly, "sum", progress = FALSE)

pop2020_01 <- rasterize(vect(grid_poly), template, field = "pop2020")
names(pop2020_01) <- "pop2020_0p1deg"

out_raster <- file.path(shared_dir, "pop2020_0p1deg.tif")
writeRaster(pop2020_01, out_raster, overwrite = TRUE)

# ---- 4. Conservation report --------------------------------------------------
agg_total <- sum(grid_poly$pop2020, na.rm = TRUE)
cat("\n==================== CONSERVATION REPORT ====================\n")
cat(sprintf("Fine-grid total (30 arcsec, 2020): %15.0f\n", fine_total))
cat(sprintf("Aggregated total (0.1 deg, 2020):  %15.0f\n", agg_total))
cat(sprintf("Difference:                        %15.0f  (%.4f%%)\n",
            agg_total - fine_total, 100 * (agg_total - fine_total) / fine_total))
cat(sprintf("Output raster: %s\n", out_raster))
cat(sprintf("Elapsed: %.1f s\n", as.numeric(difftime(Sys.time(), t0, units = "secs"))))
cat("=============================================================\n")
