# =============================================================================
# 1_acquire_ookla_tiles.R
# Layer-A Connectivity feature, HARVEST step 1: Speedtest by Ookla open tiles,
# European window, fixed + mobile.
#
# WHAT THIS IS: measured network performance where people actually ran a test —
# average download/upload speed, latency, AND the number of tests and devices
# behind each tile. Zoom-16 web-mercator tiles (~610 m at the equator), EPSG:4326,
# quarterly since 2019Q1.
#
# SOURCE: https://github.com/teamookla/ookla-open-data
#   s3://ookla-open-data/shapefiles/performance/type={fixed|mobile}/year=YYYY/quarter=Q/
#   LICENCE: CC BY-NC-SA 4.0 — non-commercial AND share-alike. Same constraint
#   family as the BII layer; any derivative distributed from these tiles inherits it.
#
# WHY SHAPEFILES AND NOT PARQUET: no arrow/nanoparquet/duckdb in this renv and
# GDAL 3.12.1 here has no Parquet driver. The zipped shapefile is smaller anyway
# (117 MB mobile / 229 MB fixed vs 167/333 MB) and sf can spatially filter it on
# read with wkt_filter, so only European tiles are ever materialised in memory.
#
# THE TESTS COLUMN IS NOT OPTIONAL. Ookla tiles are self-selected: a tile exists
# only because somebody ran a test there. An empty area means "nobody tested",
# NOT "no service", and participation correlates with income, education, age and
# urbanity — i.e. with the very variables this feature will be crossed against.
# `tests` and `devices` are carried through every downstream step so the sampling
# effort can be mapped next to the speed rather than hidden behind it.
#
# RUN FROM WORKSPACE ROOT:
#   Rscript "Feature explorations/Connectivity/scripts/1_acquire_ookla_tiles.R"
# =============================================================================
suppressPackageStartupMessages({ library(sf) })
setwd(here::here())

QUARTER_YEAR  <- 2026L      # latest completed quarter published by Ookla
QUARTER_N     <- 1L
DATA_RETRIEVED <- "2026-08-04"

raw_dir <- "Feature explorations/Connectivity/data_raw"
dir.create(raw_dir, showWarnings = FALSE, recursive = TRUE)

# European window in lon/lat, generous enough to cover the EPSG:3035 map window
EU_BBOX <- c(xmin = -25, ymin = 34, xmax = 45, ymax = 72)
eu_wkt  <- sf::st_as_text(sf::st_as_sfc(sf::st_bbox(EU_BBOX, crs = 4326)))

q_month <- c("01", "04", "07", "10")[QUARTER_N]
s3_base <- "https://ookla-open-data.s3.amazonaws.com/shapefiles/performance"

fetch_ps <- function(url, dest) {           # R's libcurl SSL-fails on several of
  ps <- sprintf(paste0(                     # this project's hosts; PowerShell is
    "$ProgressPreference='SilentlyContinue'; ",   # the established workaround
    "Invoke-WebRequest -Uri '%s' -OutFile '%s' -UseBasicParsing -TimeoutSec 1800"),
    url, gsub("\\\\", "/", dest))
  system2("powershell", c("-NoProfile", "-Command", shQuote(ps)),
          stdout = TRUE, stderr = TRUE)
  if (!file.exists(dest) || file.size(dest) < 1e6) stop("fetch failed: ", url)
  invisible(dest)
}

for (type in c("mobile", "fixed")) {
  stem <- sprintf("%d-%s-01_performance_%s_tiles", QUARTER_YEAR, q_month, type)
  zf   <- file.path(raw_dir, paste0(stem, ".zip"))
  out  <- file.path(raw_dir, sprintf("ookla_%s_%dQ%d_europe.gpkg",
                                     type, QUARTER_YEAR, QUARTER_N))
  if (file.exists(out)) { message("Cached: ", out); next }

  if (!file.exists(zf)) {
    url <- sprintf("%s/type=%s/year=%d/quarter=%d/%s.zip",
                   s3_base, type, QUARTER_YEAR, QUARTER_N, stem)
    message("Downloading ", basename(url), " ...")
    fetch_ps(url, zf)
    message("  ", round(file.size(zf) / 1e6), " MB")
  }

  # The .shp inside is NOT named after the zip (it is gps_{type}_tiles.shp), so
  # discover it rather than assume.
  shp <- grep("\\.shp$", utils::unzip(zf, list = TRUE)$Name, value = TRUE)[1]
  if (is.na(shp)) stop("no .shp inside ", zf)

  # Spatial filter on read: only European tiles come back.
  message("Reading European tiles from ", basename(zf), "/", shp, " ...")
  g <- sf::st_read(sprintf("/vsizip/%s/%s", normalizePath(zf, winslash = "/"), shp),
                   wkt_filter = eu_wkt, quiet = TRUE)
  message(sprintf("  %s: %d European tiles, %s tests, %s devices",
                  type, nrow(g), format(sum(g$tests), big.mark = " "),
                  format(sum(g$devices), big.mark = " ")))
  sf::st_write(g, out, delete_dsn = TRUE, quiet = TRUE)
  message("Wrote ", out)
}

# Report ---------------------------------------------------------------------
for (type in c("mobile", "fixed")) {
  f <- file.path(raw_dir, sprintf("ookla_%s_%dQ%d_europe.gpkg",
                                  type, QUARTER_YEAR, QUARTER_N))
  g <- sf::st_read(f, quiet = TRUE)
  message(sprintf("\n%s | %d tiles | crs %s | cols: %s", toupper(type), nrow(g),
                  sf::st_crs(g)$epsg, paste(setdiff(names(g), "geom"), collapse = ", ")))
  message("  download Mbps: ", paste(round(quantile(g$avg_d_kbps / 1000,
          c(.05, .25, .5, .75, .95)), 1), collapse = " / "), "  (p5/q1/med/q3/p95)")
  message("  tests per tile: ", paste(quantile(g$tests, c(.5, .9, .99, 1)),
          collapse = " / "), "  (med/p90/p99/max)")
}
