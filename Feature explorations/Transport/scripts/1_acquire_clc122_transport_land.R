# =============================================================================
# 1_acquire_clc122_transport_land.R
# Layer-A Transport feature, HARVEST step: CORINE Land Cover 2018 class 122
# ("Road and rail networks and associated land") for EEA39, as vector polygons.
#
# WHY THE VECTOR SERVICE AND NOT THE 100 m RASTER: the official CLC2018 100 m
# GeoTIFF is behind a Copernicus Land (CLMS) login, so it cannot be fetched
# reproducibly from a script. The EEA discomap ArcGIS service exposes the SAME
# CLC2018 product as an open, un-authenticated vector layer already in
# EPSG:3035 — and class 122 is only 4 839 polygons EEA39-wide, so the whole
# class downloads in 5 paginated requests.
#
#   https://image.discomap.eea.europa.eu/arcgis/rest/services/Corine/CLC2018_LAEA/MapServer/0
#
# NOTE ON FETCHING: R's libcurl fails with "SSL connect error" on this host
# (same problem already known for Eurostat/GISCO in this project), so requests
# are shelled out to PowerShell's Invoke-WebRequest. Do not "simplify" this
# back to download.file().
#
# ** PROVISIONAL — read the CAVEAT in 2_map_transport_land_share.R before using
#    this as a "road network" layer. CLC's 25 ha minimum mapping unit and 100 m
#    minimum width mean class 122 captures only WIDE transport corridors. **
#
# RUN FROM WORKSPACE ROOT:
#   Rscript "Feature explorations/Transport/scripts/1_acquire_clc122_transport_land.R"
# =============================================================================
suppressPackageStartupMessages({ library(sf) })
setwd(here::here())

raw_dir <- "Feature explorations/Transport/data_raw"
dir.create(raw_dir, showWarnings = FALSE, recursive = TRUE)
out_gj  <- file.path(raw_dir, "clc2018_class122_eea39_3035.geojson")

SERVICE <- paste0("https://image.discomap.eea.europa.eu/arcgis/rest/services/",
                  "Corine/CLC2018_LAEA/MapServer/0/query")
PAGE    <- 1000   # service maxRecordCount

# Fetch one URL to a file via PowerShell (R's libcurl SSL-fails on this host) --
fetch_ps <- function(url, dest, min_bytes = 10) {   # {"count":4839} is 14 bytes
  ps <- sprintf(paste0("$ProgressPreference='SilentlyContinue'; ",
                       "Invoke-WebRequest -Uri '%s' -OutFile '%s' ",
                       "-UseBasicParsing -TimeoutSec 300"),
                url, gsub("\\\\", "/", dest))
  system2("powershell", c("-NoProfile", "-Command", shQuote(ps)),
          stdout = TRUE, stderr = TRUE)
  if (!file.exists(dest) || file.size(dest) < min_bytes)
    stop("fetch failed: ", url)
  invisible(dest)
}

if (file.exists(out_gj)) {
  message("Cached: ", out_gj, " — skipping download.")
} else {
  # 1. How many class-122 polygons are there? (sanity check + page count) -----
  cnt_f <- tempfile(fileext = ".json")
  fetch_ps(paste0(SERVICE, "?where=Code_18%3D%27122%27&returnCountOnly=true&f=json"),
           cnt_f)
  n_tot <- jsonlite::fromJSON(cnt_f)$count
  message("Class 122 polygons on the service: ", n_tot)

  # 2. Paginated download, ordered by OBJECTID so pages don't overlap --------
  pages <- list()
  off   <- 0
  repeat {
    u <- sprintf(paste0("%s?where=Code_18%%3D%%27122%%27&outFields=Code_18,Area_Ha",
                        "&returnGeometry=true&outSR=3035&orderByFields=OBJECTID",
                        "&resultOffset=%d&resultRecordCount=%d&f=geojson"),
                 SERVICE, off, PAGE)
    f <- tempfile(fileext = ".geojson")
    fetch_ps(u, f)
    g <- sf::st_read(f, quiet = TRUE)
    message(sprintf("  offset %6d -> %4d features", off, nrow(g)))
    if (nrow(g) == 0) break
    pages[[length(pages) + 1]] <- g
    off <- off + nrow(g)
    if (off >= n_tot) break
  }

  clc122 <- do.call(rbind, pages)
  stopifnot(nrow(clc122) == n_tot, sf::st_crs(clc122)$epsg == 3035)

  sf::st_write(clc122, out_gj, delete_dsn = TRUE, quiet = TRUE)
  message("Wrote ", out_gj, " (", nrow(clc122), " polygons)")
}

# 3. Report what we got ------------------------------------------------------
clc122 <- sf::st_read(out_gj, quiet = TRUE)
message(sprintf(paste0("CLC2018 class 122, EEA39: %d polygons, %.0f km2 total, ",
                       "median %.0f ha, max %.0f ha"),
                nrow(clc122), sum(clc122$Area_Ha) / 100,
                median(clc122$Area_Ha), max(clc122$Area_Ha)))
