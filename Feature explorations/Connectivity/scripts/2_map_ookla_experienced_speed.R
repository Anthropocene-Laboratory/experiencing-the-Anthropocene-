# =============================================================================
# 2_map_ookla_experienced_speed.R
# Layer-A Connectivity feature, THE "LIVED" LAYER: what people actually get when
# they test their connection, mobile and fixed, over Europe.
#
# TWO PANELS ON PURPOSE. Ookla tiles are self-selected — a tile exists only
# because somebody ran a Speedtest there, and who runs one correlates with income,
# education, age and urbanity. So the speed panel is never shown alone: the right
# panel maps the SAMPLING EFFORT (tests per cell) behind it. Where the right panel
# is dark, the left panel is an estimate resting on a handful of tests, and an
# empty area means "nobody tested", not "no service".
#
# This is a weaker guarantee than the one that licensed the GRIP4 roadedness map.
# There the under-capture ratio was near-constant across countries, so the pattern
# survived. Here the bias is correlated WITH the mapped quantity, so no constant
# correction exists — which is exactly why the effort is mapped instead of assumed
# away. Treat the speed panel as "speed among those who tested", not "speed here".
#
# AGGREGATION: per 5 km cell, TEST-WEIGHTED mean download speed
#   sum(avg_d_kbps * tests) / sum(tests)
# not the plain mean of tile means — tiles range from 1 test to several thousand,
# so an unweighted mean would let a single-test tile outvote a whole city block.
#
# INPUT : data_raw/ookla_{mobile,fixed}_2026Q1_europe.gpkg  (run script 1 first)
# OUTPUT: data_processed/maps/ookla_{mobile,fixed}_speed_and_effort_5km.png
#         data_processed/tables/ookla_speed_by_country.csv
#         data_processed/ookla_{mobile,fixed}_speed_5km.tif   (for the Analysis stack)
#
# RUN FROM WORKSPACE ROOT:
#   Rscript "Feature explorations/Connectivity/scripts/2_map_ookla_experienced_speed.R"
# =============================================================================
suppressPackageStartupMessages({
  library(sf); library(terra); library(ggplot2); library(ggspatial); library(ragg)
  library(patchwork)
})
setwd(here::here())
sf::sf_use_s2(FALSE)

DATA_RETRIEVED <- "2026-08-04"
QUARTER_LABEL  <- "2026 Q1"

shared     <- "Feature explorations/_shared"
raw_dir    <- "Feature explorations/Connectivity/data_raw"
out        <- "Feature explorations/Connectivity/data_processed"
out_maps   <- file.path(out, "maps")
out_tables <- file.path(out, "tables")
dir.create(out_maps,   showWarnings = FALSE, recursive = TRUE)
dir.create(out_tables, showWarnings = FALSE, recursive = TRUE)

CELL    <- 5000
win_ext <- c(xmin = 2.5e6, xmax = 6e6, ymin = 1.5e6, ymax = 5.5e6)  # as other features

# Reproject with the PROJ STRING, never the EPSG code — see the Transport feature
# note: asking for "EPSG:3035" routes through country deformation grids missing
# from this PROJ install and silently blanks DE/NL/BE/CH/AT.
LAEA_PROJ <- paste0("+proj=laea +lat_0=52 +lon_0=10 +x_0=4321000 +y_0=3210000 ",
                    "+ellps=GRS80 +units=m +no_defs")

win     <- st_as_sfc(st_bbox(c(win_ext), crs = 3035))
borders <- st_read(file.path(shared, "CNTR_RG_10M_2024_4326.geojson"), quiet = TRUE) |>
  st_transform(LAEA_PROJ) |> st_make_valid()
# Re-tag only: LAEA_PROJ *is* the EPSG:3035 definition, so no reprojection happens.
suppressWarnings(st_crs(borders) <- 3035)
borders_win <- st_crop(borders, win)

# Shared classifications, identical for mobile and fixed so the two figures compare
SPD_BRK <- c(0, 10, 25, 50, 100, 250, Inf)
SPD_LAB <- c("<10", "10–25", "25–50", "50–100", "100–250", "250+")
EFF_BRK <- c(0, 5, 20, 100, 500, 2000, Inf)
EFF_LAB <- c("1–5", "5–20", "20–100", "100–500", "500–2 000", "2 000+")

ink <- "grey80"
base_theme <- theme_void(base_size = 11) +
  theme(
    plot.background  = element_rect(fill = "black", colour = NA),
    panel.background = element_rect(fill = "black", colour = NA),
    legend.key = element_rect(fill = "black", colour = NA),
    plot.title    = element_text(colour = "white", face = "bold", size = 12),
    plot.subtitle = element_text(colour = "grey55", size = 8.5, margin = margin(b = 4)),
    legend.title  = element_text(colour = ink, size = 9),
    legend.text   = element_text(colour = ink, size = 8),
    legend.position = "right", legend.key.height = unit(0.5, "cm"),
    legend.key.width  = unit(0.35, "cm")
  )

panel <- function(df, fillvar, palette, legend_title, title, subtitle, scalebar) {
  p <- ggplot() +
    geom_sf(data = borders_win, fill = NA, colour = "grey30", linewidth = 0.1) +
    geom_tile(data = df, aes(x, y, fill = .data[[fillvar]]),
              width = CELL, height = CELL) +
    scale_fill_viridis_d(option = palette, begin = 0.06, name = legend_title) +
    coord_sf(crs = 3035, xlim = win_ext[c("xmin", "xmax")],
             ylim = win_ext[c("ymin", "ymax")], expand = FALSE) +
    labs(title = title, subtitle = subtitle) +
    base_theme
  if (scalebar)
    p <- p + annotation_scale(location = "br", width_hint = 0.28, text_cex = 0.6,
                              text_col = ink, line_col = ink,
                              bar_cols = c(ink, "grey20"))
  p
}

summary_rows <- list()

for (type in c("mobile", "fixed")) {
  gpkg <- file.path(raw_dir, sprintf("ookla_%s_2026Q1_europe.gpkg", type))
  message("\n=== ", toupper(type), " ===")
  g <- st_read(gpkg, quiet = TRUE)

  # 1. Tile centroids -> LAEA. Tiles are ~610 m against a 5 km grid, so assigning
  #    a tile to the cell containing its centroid is accurate enough.
  pts <- suppressWarnings(st_centroid(st_geometry(g)))
  pts <- st_transform(pts, LAEA_PROJ)
  xy  <- st_coordinates(pts)

  # as.numeric is load-bearing: kbps and tests both come back as integers and
  # kbps * tests overflows .Machine$integer.max on busy tiles, silently -> NA.
  d <- data.frame(x = xy[, 1], y = xy[, 2],
                  kbps    = as.numeric(g$avg_d_kbps),
                  tests   = as.numeric(g$tests),
                  devices = as.numeric(g$devices))
  d <- d[d$x >= win_ext[["xmin"]] & d$x < win_ext[["xmax"]] &
         d$y >= win_ext[["ymin"]] & d$y < win_ext[["ymax"]] & d$tests > 0, ]

  # 2. Snap to the 5 km grid and aggregate, TEST-WEIGHTED -------------------
  d$cx <- floor((d$x - win_ext[["xmin"]]) / CELL)
  d$cy <- floor((d$y - win_ext[["ymin"]]) / CELL)
  key  <- d$cy * 1e4 + d$cx
  num  <- tapply(d$kbps * d$tests, key, sum)
  den  <- tapply(d$tests, key, sum)
  ndev <- tapply(d$devices, key, sum)

  cells <- data.frame(
    key   = as.numeric(names(den)),
    mbps  = as.numeric(num) / as.numeric(den) / 1000,
    tests = as.numeric(den),
    devices = as.numeric(ndev))
  cells$cx <- cells$key %% 1e4
  cells$cy <- (cells$key - cells$cx) / 1e4
  cells$x  <- win_ext[["xmin"]] + (cells$cx + 0.5) * CELL
  cells$y  <- win_ext[["ymin"]] + (cells$cy + 0.5) * CELL

  message(sprintf("  %d tiles -> %d cells of %d km | %s tests total",
                  nrow(d), nrow(cells), CELL / 1000,
                  format(sum(cells$tests), big.mark = " ")))
  message("  weighted Mbps  p5/q1/med/q3/p95: ",
          paste(round(quantile(cells$mbps, c(.05, .25, .5, .75, .95)), 1), collapse = " / "))
  message("  tests per cell med/p90/p99/max: ",
          paste(round(quantile(cells$tests, c(.5, .9, .99, 1))), collapse = " / "))
  message(sprintf("  cells resting on <5 tests: %.1f %%",
                  100 * mean(cells$tests < 5)))

  # 3. Raster for the Analysis stack ---------------------------------------
  r <- rast(ext(win_ext[["xmin"]], win_ext[["xmax"]], win_ext[["ymin"]], win_ext[["ymax"]]),
            resolution = CELL, crs = LAEA_PROJ)
  rs <- rt <- r
  values(rs) <- NA_real_; values(rt) <- NA_real_
  nr <- nrow(r); nc <- ncol(r)
  idx <- cbind(nr - cells$cy, cells$cx + 1)       # grid counts y from the bottom
  rs[idx] <- cells$mbps
  rt[idx] <- cells$tests
  st <- c(rs, rt); names(st) <- c("mbps_test_weighted", "tests")
  crs(st) <- "EPSG:3035"
  writeRaster(st, file.path(out, sprintf("ookla_%s_speed_5km.tif", type)),
              overwrite = TRUE, gdal = "COMPRESS=LZW")

  # 4. Two-panel figure -----------------------------------------------------
  cells$spd <- cut(cells$mbps,  breaks = SPD_BRK, labels = SPD_LAB, right = TRUE)
  cells$eff <- cut(cells$tests, breaks = EFF_BRK, labels = EFF_LAB, right = TRUE)

  p1 <- panel(cells, "spd", "inferno", "Mbps",
              sprintf("What people get — %s", type),
              "test-weighted mean download speed per 5 km cell", TRUE)
  p2 <- panel(cells, "eff", "mako", "Speedtests",
              "How much that rests on",
              sprintf("number of Speedtests per 5 km cell, %s", QUARTER_LABEL), FALSE)

  fig <- (p1 | p2) +
    plot_annotation(
      title = sprintf("Measured %s internet performance, and the sampling behind it",
                      type),
      subtitle = paste0("Speedtest by Ookla open tiles, ", QUARTER_LABEL,
                        " — Europe. Read the two panels together."),
      caption = paste0(
        "Data: Speedtest® by Ookla® Global Fixed and Mobile Network Performance Maps, ",
        QUARTER_LABEL, ", retrieved ", DATA_RETRIEVED, ". Licensed CC BY-NC-SA 4.0. ",
        "Zoom-16 tiles (~610 m) aggregated to 5 km,\ndownload speed weighted by the ",
        "number of tests in each tile. SELF-SELECTED SAMPLE: a cell exists only ",
        "because someone ran a test there — blank does NOT mean no service, and ",
        "participation\ncorrelates with income, education, age and urbanity. Read the ",
        "left panel as 'speed among those who tested', not 'speed here'. ",
        "Projection: LAEA Europe (EPSG:3035).\nBoundaries: Eurostat GISCO CNTR 10M. ",
        "PROVISIONAL exploration."),
      theme = theme(
        plot.background = element_rect(fill = "black", colour = NA),
        plot.title    = element_text(colour = "white", face = "bold", size = 15),
        plot.subtitle = element_text(colour = ink, size = 10, margin = margin(b = 6)),
        plot.caption  = element_text(colour = "grey55", size = 6, hjust = 0)))

  png_out <- file.path(out_maps,
                       sprintf("ookla_%s_speed_and_effort_5km.png", type))
  ragg::agg_png(png_out, width = 14, height = 8.2, units = "in", res = 300,
                background = "black")
  print(fig)
  invisible(dev.off())
  message("Wrote ", png_out)

  # 5. Per-country summary (test-weighted, so big cities do not get one vote) --
  cp <- st_as_sf(cells, coords = c("x", "y"), crs = 3035)
  j  <- st_join(cp, borders[, c("CNTR_ID", "NAME_ENGL")], join = st_intersects)
  jj <- st_drop_geometry(j)
  jj <- jj[!is.na(jj$CNTR_ID), ]
  agg <- do.call(rbind, lapply(split(jj, jj$CNTR_ID), function(s) data.frame(
    CNTR_ID = s$CNTR_ID[1], NAME_ENGL = s$NAME_ENGL[1], type = type,
    cells = nrow(s), tests = sum(s$tests),
    mbps_test_weighted = round(sum(s$mbps * s$tests) / sum(s$tests), 1),
    pct_cells_under_5_tests = round(100 * mean(s$tests < 5), 1))))
  summary_rows[[type]] <- agg
}

tab <- do.call(rbind, summary_rows)
tab <- tab[order(tab$type, -tab$mbps_test_weighted), ]
write.csv(tab, file.path(out_tables, "ookla_speed_by_country.csv"), row.names = FALSE)
message("\nWrote ", file.path(out_tables, "ookla_speed_by_country.csv"))
print(utils::head(tab[tab$type == "mobile" & tab$tests > 20000, ], 10))
