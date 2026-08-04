# =============================================================================
# 3_acquire_grip4_road_density.R
# Layer-A Transport feature, HARVEST step 2: GRIP4 road DENSITY grids.
#
# WHY: CLC class 122 (scripts 1-2) maps the LAND wide transport corridors take,
# which is not "how roaded is this place" — it misses every ordinary road
# (0.07 % of Europe vs a real footprint of 1-2 %; see transport_land_source_note.md).
# GRIP4 measures the thing directly: metres of road per km2 of land, per cell.
#
# SOURCE: Global Roads Inventory Project v4 (Meijer et al. 2018, PBL/GLOBIO),
#   https://www.globio.info/download-grip-dataset  (ODbL, open)
#   Rasters are 5 arcmin (~8 km at the equator; ~9 km N-S x ~5-6 km E-W in Europe).
#   total = all classes; tp1..tp5 = highways, primary, secondary, tertiary, local.
#
# Fetch via PowerShell: R's libcurl SSL-fails on several of this project's hosts.
#
# RUN FROM WORKSPACE ROOT:
#   Rscript "Feature explorations/Transport/scripts/3_acquire_grip4_road_density.R"
# =============================================================================
suppressPackageStartupMessages({ library(terra) })
setwd(here::here())

raw_dir <- "Feature explorations/Transport/data_raw/grip4"
dir.create(raw_dir, showWarnings = FALSE, recursive = TRUE)

BASE  <- "https://dataportaal.pbl.nl/downloads/GRIP4/"
LAYERS <- c(total = "GRIP4_density_total.zip",   # all road types
            tp1   = "GRIP4_density_tp1.zip",     # 1 highways
            tp2   = "GRIP4_density_tp2.zip",     # 2 primary
            tp3   = "GRIP4_density_tp3.zip",     # 3 secondary
            tp4   = "GRIP4_density_tp4.zip",     # 4 tertiary
            tp5   = "GRIP4_density_tp5.zip")     # 5 local

fetch_ps <- function(url, dest) {
  ps <- sprintf(paste0("$ProgressPreference='SilentlyContinue'; ",
                       "Invoke-WebRequest -Uri '%s' -OutFile '%s' ",
                       "-UseBasicParsing -TimeoutSec 600"),
                url, gsub("\\\\", "/", dest))
  system2("powershell", c("-NoProfile", "-Command", shQuote(ps)),
          stdout = TRUE, stderr = TRUE)
  if (!file.exists(dest) || file.size(dest) < 1000) stop("fetch failed: ", url)
  invisible(dest)
}

for (nm in names(LAYERS)) {
  zf <- file.path(raw_dir, LAYERS[[nm]])
  if (!file.exists(zf)) {
    message("Downloading ", LAYERS[[nm]], " ...")
    fetch_ps(paste0(BASE, LAYERS[[nm]]), zf)
  }
  # unzip only if its .asc/.tif is not already extracted
  inside <- utils::unzip(zf, list = TRUE)$Name
  if (!all(file.exists(file.path(raw_dir, inside))))
    utils::unzip(zf, exdir = raw_dir)
}

# Inspect what we got --------------------------------------------------------
files <- list.files(raw_dir, pattern = "\\.(asc|tif)$", full.names = TRUE)
message("\nExtracted grids:")
for (f in files) {
  r <- rast(f)
  message(sprintf("  %-34s %d x %d  res %.4f  crs %s",
                  basename(f), nrow(r), ncol(r), res(r)[1],
                  ifelse(crs(r) == "", "UNSET", crs(r, describe = TRUE)$code)))
}

# Distribution over the European window, on the TOTAL layer -----------------
tot <- files[grepl("total", files, ignore.case = TRUE)][1]
r <- rast(tot)
if (crs(r) == "") crs(r) <- "EPSG:4326"           # GRIP4 ASCII grids ship CRS-less
eu <- crop(r, ext(-25, 45, 34, 72))
v  <- values(eu, mat = FALSE); v <- v[!is.na(v)]
message(sprintf("\nGRIP4 total density over Europe window: n=%d cells, %d are 0",
                length(v), sum(v == 0)))
print(round(quantile(v[v > 0], c(0, .05, .25, .5, .75, .9, .95, .99, 1)), 1))
message("unit: metres of road per km2 of land")
