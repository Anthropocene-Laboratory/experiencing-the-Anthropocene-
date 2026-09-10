# =============================================================================
# prepare_global_pop_gdp.R
# Build the GLOBAL 0.1-degree companions to the Europe-cropped shared layers.
#
# Why this exists: _shared/pop2020_0p1deg.tif is cropped to the E-OBS European
# box (-25/45.5, 25/71.5). Kummu GDP is already global. For world maps we need
# both on one global 0.1-deg grid.
#
# Grid choice: exact 0.1-deg grid on [-180,180]x[-90,90] (3600 x 1800). This
# aligns cell-for-cell with the Sherman et al. (2026) downscaled HDI grid.
#
# Note on alignment: GHS-POP R2023A in EPSG:4326 is NOT on a 0.1-deg-divisible
# origin (its extent is -180.0079..180.0087, -89.100..89.100, 43202 x 21384
# cells). A plain aggregate(fact=12) would inherit that offset, so we resample
# onto the explicit target grid with method="sum", which conserves counts.
#
# Sources:
#   Population - GHS-POP R2023A, epoch 2020, 4326 30 arcsec (Copernicus/JRC).
#     Reuse authorised with acknowledgement of the source.
#   GDP        - Kummu, M., Kosonen, M. & Masoumzadeh Sayyar, S. (2025).
#     Downscaled gridded global dataset for GDP per capita PPP over 1990-2024.
#     Scientific Data 12:178. https://doi.org/10.1038/s41597-025-04487-x
#     Data: Zenodo 10.5281/zenodo.18429133 (2026-03-13 release, 1990-2024).
#     CC BY 4.0.
#
# Outputs land in Feature explorations/_shared/ because they are cross-feature
# reference data; this script lives in Analysis/ because it serves no single feature.
#
# RUN FROM WORKSPACE ROOT:
#   & 'C:/Program Files/R/R-4.5.3/bin/Rscript.exe' 'Feature explorations/Analysis/scripts/prepare_global_pop_gdp.R'
# =============================================================================
suppressMessages({ library(terra); library(sf) })
terraOptions(memfrac = 0.55, progress = 0)

t0     <- Sys.time()
shared <- "Feature explorations/_shared"
ghs    <- "Feature explorations/Heatwaves/data_raw/ghsl_pop_30arcsec/GHS_POP_E2020_GLOBE_R2023A_4326_30ss_V1_0.tif"
kummu  <- file.path(shared, "gdp_kummu", "rast_adm2_gdp_perCapita_1990_2024.tif")
stopifnot(file.exists(ghs), file.exists(kummu))

GDP_YEAR <- "gdp_pc_2024"

# ---- 0. target grid ---------------------------------------------------------
target <- rast(xmin = -180, xmax = 180, ymin = -90, ymax = 90,
               resolution = 0.1, crs = "EPSG:4326")
cat(sprintf("Target grid: %d x %d cells at %g deg\n",
            nrow(target), ncol(target), res(target)[1]))

# ---- 1. population: count-conserving resample to 0.1 deg --------------------
cat("\n[1/4] Resampling GHS-POP 2020 (30 arcsec -> 0.1 deg, sum)...\n")
pop_src <- rast(ghs)
fine_total <- as.numeric(global(pop_src, "sum", na.rm = TRUE))
cat(sprintf("      source total (global, 30 arcsec): %s\n",
            format(round(fine_total), big.mark = " ", scientific = FALSE)))

# Two-step, because neither one-shot route survives a 933M-cell source:
#   - terra::resample(method="sum") materialises the whole warp in memory (stalls);
#   - gdalwarp -r sum picks one chunk covering the entire source (std::bad_alloc),
#     since the 3600x1800 target easily "fits" in its warp memory budget.
# Step A: integer aggregation by a factor of 12 (30 arcsec * 12 = 0.1 deg). terra
# streams this block by block. The result has the right cell SIZE but inherits the
# source's off-grid origin (-180.0079).
# Step B: resample that small grid (6.4M cells) onto the exact target. Cheap, and
# "sum" redistributes counts across the ~8% cell offset without losing people.
pop_out <- file.path(shared, "pop2020_global_0p1deg.tif")
tmp_agg <- file.path(tempdir(), "ghs_pop_agg12.tif")

cat("      step A: aggregate(fact=12, sum), streamed to disk...\n")
pop_agg <- aggregate(pop_src, fact = 12, fun = "sum", na.rm = TRUE,
                     filename = tmp_agg, overwrite = TRUE,
                     wopt = list(datatype = "FLT8S"))
cat(sprintf("      aggregated grid: %d x %d, origin x = %.4f\n",
            nrow(pop_agg), ncol(pop_agg), xmin(pop_agg)))
agg_only <- as.numeric(global(pop_agg, "sum", na.rm = TRUE))
cat(sprintf("      total after aggregation: %s (%+.4f%%)\n",
            format(round(agg_only), big.mark = " ", scientific = FALSE),
            100 * (agg_only - fine_total) / fine_total))

cat("      step B: resample onto the exact 0.1-deg target...\n")
pop_glob <- resample(pop_agg, target, method = "sum",
                     filename = pop_out, overwrite = TRUE,
                     wopt = list(datatype = "FLT8S", gdal = c("COMPRESS=DEFLATE", "TILED=YES")))
names(pop_glob) <- "pop2020"

agg_total <- as.numeric(global(pop_glob, "sum", na.rm = TRUE))
cat(sprintf("      aggregated total (0.1 deg)      : %s\n",
            format(round(agg_total), big.mark = " ", scientific = FALSE)))
cat(sprintf("      conservation error              : %+.4f%%\n",
            100 * (agg_total - fine_total) / fine_total))

# ---- 2. population DENSITY --------------------------------------------------
# A 0.1-deg cell at 60N has about half the ground area of one at the equator, so
# a count-per-cell raster understates high latitudes on a world map. Density is
# the quantity that is safe to map with colour.
cat("\n[2/4] Deriving population density (people per km2)...\n")
area_km2 <- cellSize(pop_glob, unit = "km")
dens <- pop_glob / area_km2
names(dens) <- "pop_density_2020"
dens_out <- file.path(shared, "pop2020_global_0p1deg_density.tif")
writeRaster(dens, dens_out, overwrite = TRUE)
cat(sprintf("      cell area range: %.1f - %.1f km2 (equator vs pole)\n",
            as.numeric(global(area_km2, "min", na.rm = TRUE)),
            as.numeric(global(area_km2, "max", na.rm = TRUE))))
cat(sprintf("      density max    : %.0f people/km2\n",
            as.numeric(global(dens, "max", na.rm = TRUE))))

# ---- 3. GDP per capita onto the same grid -----------------------------------
# Kummu per-capita rasters are piecewise-constant within each admin-2 unit, so
# nearest-neighbour preserves the reported unit values exactly. Averaging
# (bilinear) would invent intermediate values that no admin unit holds.
cat(sprintf("\n[3/4] Resampling Kummu %s (5 arcmin -> 0.1 deg, near)...\n", GDP_YEAR))
gdp_src <- rast(kummu)[[GDP_YEAR]]
gdp_glob <- resample(gdp_src, target, method = "near")
names(gdp_glob) <- GDP_YEAR
gdp_out <- file.path(shared, "gdp_kummu", sprintf("%s_global_0p1deg.tif", GDP_YEAR))
writeRaster(gdp_glob, gdp_out, overwrite = TRUE)

qs <- as.numeric(global(gdp_glob, fun = function(x)
  quantile(x, c(0, .01, .5, .99, 1), na.rm = TRUE)))
cat(sprintf("      quantiles 0/1/50/99/100%%: %s\n",
            paste(format(round(qs), big.mark = " "), collapse = " | ")))

# ---- 4. verify the three grids are cell-aligned -----------------------------
cat("\n[4/4] Grid alignment check\n")
chk <- function(a, b, lab) cat(sprintf("      %-28s %s\n", lab,
  if (compareGeom(a, b, stopOnError = FALSE, messages = FALSE)) "ALIGNED" else "MISMATCH"))
chk(pop_glob, dens,     "population vs density")
chk(pop_glob, gdp_glob, "population vs GDP")

cat("\n---- written ----\n")
for (f in c(pop_out, dens_out, gdp_out))
  cat(sprintf("  %-62s %6.1f MB\n", f, file.size(f) / 1e6))
cat(sprintf("Elapsed: %.1f min\n", as.numeric(difftime(Sys.time(), t0, units = "mins"))))
