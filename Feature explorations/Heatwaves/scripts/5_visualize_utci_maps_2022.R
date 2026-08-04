# Maps of the human-anchored heat feature: hours of UTCI heat stress, Europe 2022.
#
# WHAT IS MAPPED, AND WHY IT IS NOT THE USUAL UTCI MAP. The field normally maps the
# UTCI VALUE (a feels-like temperature in C) with the C3S stress-band palette. Our
# variable is different: hours per year spent at or above a stress band, i.e. a
# magnitude on a count scale, so the band palette does not apply and a sequential
# ramp with interpretable round breaks is used instead. The band thresholds still
# do the conceptual work -- they define what counts as an hour of stress.
#
# Two figures:
#   1. hours >= 32 C (strong heat stress)   -- the primary Layer A feature
#   2. hours >= 38 C (very strong)          -- the tail, same fixed breaks logic
# Both use CLASSIFIED breaks at round values rather than a continuous ramp: readers
# can name a threshold ("more than 500 hours") instead of interpolating a colour.
#
# Projection EPSG:3035 (LAEA Europe), the standard equal-area CRS for European maps.
#
# Usage: Rscript "Feature explorations/Heatwaves/scripts/5_visualize_utci_maps_2022.R"

suppressMessages({library(terra); library(sf); library(ggplot2); library(ggspatial); library(ragg)})

base_dir   <- here::here("Feature explorations")
proc_dir   <- file.path(base_dir, "Heatwaves", "data_processed")
shared_dir <- file.path(base_dir, "_shared")
out_maps   <- file.path(proc_dir, "maps")
dir.create(out_maps, showWarnings = FALSE, recursive = TRUE)

STUDY <- c("AT","BE","BG","HR","CY","CZ","DK","EE","FI","FR","DE","EL","HU","IE",
           "IT","LV","LT","LU","MT","NL","PL","PT","RO","SK","SI","ES","SE","UK",
           "IS","LI","NO","CH")
cn    <- st_read(file.path(shared_dir, "CNTR_RG_10M_2024_4326.geojson"), quiet = TRUE)
study <- cn[cn$CNTR_ID %in% STUDY, ]
study_3035 <- st_transform(study, 3035)

r <- rast(file.path(proc_dir, "utci_heatstress_hours_2022.nc"))
cat("input CRS:", crs(r, describe = TRUE)$name, "| ext:", as.vector(ext(r)), "\n")
if (is.na(crs(r)) || crs(r) == "") crs(r) <- "EPSG:4326"

BREAKS <- c(0, 1, 50, 100, 250, 500, 1000, 2000, Inf)
LABELS <- c("0", "1-50", "50-100", "100-250", "250-500", "500-1000", "1000-2000", ">2000")
PAL    <- c("#f7f7f7", rev(hcl.colors(length(LABELS) - 1, "YlOrRd")))

make_map <- function(varname, title, subtitle, outfile) {
  x <- r[[varname]]
  x <- mask(crop(project(x, "EPSG:3035", method = "bilinear"), vect(study_3035)), vect(study_3035))

  df <- as.data.frame(x, xy = TRUE, na.rm = TRUE)
  names(df)[3] <- "hours"
  df$class <- cut(df$hours, breaks = BREAKS, labels = LABELS, include.lowest = TRUE, right = FALSE)

  p <- ggplot() +
    geom_raster(data = df, aes(x = x, y = y, fill = class)) +
    geom_sf(data = study_3035, fill = NA, colour = "grey35", linewidth = 0.18) +
    scale_fill_manual(values = setNames(PAL, LABELS), drop = FALSE,
                      name = "hours per year", guide = guide_legend(reverse = TRUE)) +
    coord_sf(crs = 3035, xlim = c(2400000, 6600000), ylim = c(1400000, 5500000), expand = FALSE) +
    annotation_scale(location = "bl", width_hint = 0.22, text_cex = 0.6,
                     pad_x = unit(0.35, "cm"), pad_y = unit(0.35, "cm")) +
    labs(title = title, subtitle = subtitle,
         caption = paste0(
           "Data: ERA5-HEAT, UTCI hourly (derived-utci-historical v1.1, consolidated), ",
           "Copernicus CDS, retrieved 2026-07-22; reference year 2022.\n",
           "Boundaries: Eurostat GISCO CNTR_RG_10M_2024. Projection: ETRS89-LAEA (EPSG:3035). ",
           "Grey-white = 0 hours; no cell in the study area lacks data (99.1% hourly coverage).\n",
           "Provisional exploratory output -- see 'Heatwave exposure mapping methods.docx', section 3b.")) +
    theme_minimal(base_size = 11) +
    theme(panel.grid = element_blank(),
          axis.title = element_blank(), axis.text = element_blank(), axis.ticks = element_blank(),
          plot.title = element_text(face = "bold", size = 13),
          plot.subtitle = element_text(size = 10, colour = "grey25"),
          plot.caption = element_text(size = 6.5, colour = "grey35", hjust = 0),
          legend.position = "right", legend.key.height = unit(0.55, "cm"))

  agg_png(file.path(out_maps, outfile), width = 8, height = 8.2, units = "in", res = 300)
  print(p)
  invisible(dev.off())
  cat(sprintf("  wrote %s | mapped cells: %d | max: %.0f h\n", outfile, nrow(df), max(df$hours)))
}

make_map("hours_strong",
         "Hours of strong heat stress, Europe 2022",
         "Hours with UTCI at or above 32 C (strong heat stress on the physiological scale)",
         "utci_hours_strong_2022.png")

make_map("hours_verystrong",
         "Hours of very strong heat stress, Europe 2022",
         "Hours with UTCI at or above 38 C (very strong heat stress on the physiological scale)",
         "utci_hours_verystrong_2022.png")

cat("UTCI MAPS DONE\n")
