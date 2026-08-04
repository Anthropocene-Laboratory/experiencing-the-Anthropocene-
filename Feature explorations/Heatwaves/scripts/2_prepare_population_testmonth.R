# Population preparation + count-conservation test for the 1991 test.
#
# Steps:
#   1. Build the target 0.1-degree grid from the local ERA5-Land test file.
#   2. Unzip + crop GHS-POP 1990 and 1995 (EPSG:4326, 30 arcsec) to the box.
#   3. Linearly interpolate population counts to 1991.
#   4. Aggregate the 1991 fine grid to the 0.1-degree grid by area-weighted SUM
#      (exactextractr), which conserves counts across the resolution change.
#   5. Report conservation: fine total vs aggregated total.
#
# Run:
#   & 'C:/Program Files/R/R-4.5.3/bin/Rscript.exe' 'Feature explorations/Heatwaves/scripts/prepare_population_testmonth.R'

suppressMessages({
  library(terra)
  library(sf)
  library(exactextractr)
})

t0 <- Sys.time()
proj_dir <- normalizePath(file.path("Feature explorations", "Heatwaves"), mustWork = TRUE)
raw_dir  <- file.path(proj_dir, "data_raw")
out_dir  <- file.path(proj_dir, "data_processed")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

# ---- 1. Target 0.1-degree grid from E-OBS P90 thresholds ---------------------
eobs_ref <- file.path(out_dir, "eobs_tx90_1991_2020_w2.nc")
stopifnot(file.exists(eobs_ref))
template <- rast(eobs_ref)[[1]]
template[] <- NA  # geometry only
cat(sprintf("Target grid: %d x %d cells, res %.3f deg, ext [%g,%g,%g,%g]\n",
            nrow(template), ncol(template), res(template)[1],
            ext(template)[1], ext(template)[2], ext(template)[3], ext(template)[4]))

box <- ext(template)

# ---- 2. Unzip + crop GHS-POP epochs -----------------------------------------
ghs_dir <- file.path(raw_dir, "ghsl_pop_30arcsec")
unzip_epoch <- function(epoch) {
  zipf <- file.path(ghs_dir, sprintf("GHS_POP_E%d_GLOBE_R2023A_4326_30ss_V1_0.zip", epoch))
  stopifnot(file.exists(zipf))
  tif_name <- sprintf("GHS_POP_E%d_GLOBE_R2023A_4326_30ss_V1_0.tif", epoch)
  tif_path <- file.path(ghs_dir, tif_name)
  if (!file.exists(tif_path)) {
    cat("Unzipping", basename(zipf), "...\n")
    utils::unzip(zipf, files = tif_name, exdir = ghs_dir)
  }
  stopifnot(file.exists(tif_path))
  tif_path
}

crop_epoch <- function(epoch) {
  r <- rast(unzip_epoch(epoch))
  rc <- crop(r, box, snap = "out")
  names(rc) <- paste0("pop", epoch)
  rc
}

cat("Loading + cropping GHS-POP 1990 and 1995...\n")
pop1990 <- crop_epoch(1990L)
pop1995 <- crop_epoch(1995L)
# GHS NoData is negative; clamp to 0 so sums are meaningful.
pop1990 <- classify(pop1990, cbind(-Inf, 0, 0))
pop1995 <- classify(pop1995, cbind(-Inf, 0, 0))

# ---- 3. Linear interpolation to 1991 ----------------------------------------
# pop1991 = pop1990 + (1991-1990)/(1995-1990) * (pop1995 - pop1990)
w <- (1991 - 1990) / (1995 - 1990)
pop1991 <- pop1990 + w * (pop1995 - pop1990)
names(pop1991) <- "pop1991"
fine_total <- as.numeric(global(pop1991, "sum", na.rm = TRUE))
cat(sprintf("Interpolated 1991 fine-grid total population (box): %.0f\n", fine_total))

# ---- 4. Count-conserving aggregation to 0.1 deg (exactextractr) -------------
cat("Building target grid polygons + area-weighted sum (exactextractr)...\n")
grid_poly <- st_as_sf(as.polygons(template, dissolve = FALSE, na.rm = FALSE))
grid_poly$cell <- seq_len(nrow(grid_poly))
grid_poly$pop1991 <- exact_extract(pop1991, grid_poly, "sum", progress = FALSE)

pop1991_01 <- rasterize(vect(grid_poly), template, field = "pop1991")
names(pop1991_01) <- "pop1991_0p1deg"
writeRaster(pop1991_01, file.path(out_dir, "pop1991_0p1deg.tif"), overwrite = TRUE)

# ---- 5. Conservation report -------------------------------------------------
agg_total <- sum(grid_poly$pop1991, na.rm = TRUE)
cat("\n==================== CONSERVATION REPORT ====================\n")
cat(sprintf("Fine-grid total (30 arcsec, 1991): %15.0f\n", fine_total))
cat(sprintf("Aggregated total (0.1 deg, 1991):  %15.0f\n", agg_total))
cat(sprintf("Difference:                        %15.0f  (%.4f%%)\n",
            agg_total - fine_total, 100 * (agg_total - fine_total) / fine_total))
cat(sprintf("Output raster: %s\n", file.path(out_dir, "pop1991_0p1deg.tif")))
cat(sprintf("Elapsed: %.1f s\n", as.numeric(difftime(Sys.time(), t0, units = "secs"))))
cat("=============================================================\n")
