# =============================================================================
# 1_map_air_quality_pm25.R
# Layer-A Air-quality feature: PM2.5 annual mean across Europe, from the EEA
# interpolated air quality product (1 km, EPSG:3035). PROVISIONAL exploratory
# prototype (see Feature explorations/CLAUDE.md).
#
# Classification = WHO 2021 air-quality guideline + interim targets (also the EU
# annual limit at 25). Palette = the conventional semantic air-quality ramp
# (green good -> purple hazardous) on a light canvas, per a prior-art check
# (r-cartographer SKILL §0): air quality has a near-universal colour language, so
# domain convention wins over the project's dark Inferno aesthetic here.
#
# Source (already downloaded, CC-BY 4.0):
#   data_raw/.../pm25_avg25_int.tif  (EEA interpolated PM2.5 annual mean, 1 km, EPSG:3035)
#   NOTE: reference YEAR is ambiguous from the EEA file code "avg25" (2025 release);
#   confirm against the EEA datahub factsheet before using as a dated result.
#
# RUN FROM WORKSPACE ROOT:
#   Rscript "Feature explorations/Air quality/scripts/1_map_air_quality_pm25.R"
# =============================================================================
suppressPackageStartupMessages({
  library(sf); library(terra); library(ggplot2); library(ggspatial); library(ragg)
})
setwd(here::here())

# Date the source data was retrieved. Fixed on purpose: this is a property of
# the DATA, not of the day the figure happens to be redrawn. Stamping Sys.Date()
# here made every rerun differ from the committed reference for no real reason.
DATA_RETRIEVED <- "2026-07-21"

shared   <- "Feature explorations/_shared"
feat     <- "Feature explorations/Air quality"
out_maps <- file.path(feat, "data_processed/maps")
dir.create(out_maps, showWarnings = FALSE, recursive = TRUE)
win_ext  <- c(xmin = 2.5e6, xmax = 6e6, ymin = 1.5e6, ymax = 5.5e6)

# 1. LOAD EEA raster, crop to the standard window, aggregate 1 km -> 3 km ------
src <- list.files(file.path(feat, "data_raw"), pattern = "pm25.*\\.tif$",
                  recursive = TRUE, full.names = TRUE)[1]
r <- rast(src)
r <- crop(r, ext(win_ext["xmin"], win_ext["xmax"], win_ext["ymin"], win_ext["ymax"]))
r <- aggregate(r, fact = 3, fun = "mean", na.rm = TRUE)     # ~3 km, smooth field
df <- as.data.frame(r, xy = TRUE, na.rm = TRUE); names(df)[3] <- "pm"
message("cells: ", nrow(df), " | PM2.5 range: ",
        paste(round(range(df$pm), 1), collapse = "–"), " ug/m3")

# 2. CLASSIFY — WHO 2021 AQG + interim targets (25 = EU annual limit) ----------
brks <- c(0, 5, 10, 15, 25, Inf)
labs <- c("< 5  (WHO guideline)", "5–10", "10–15", "15–25", "> 25  (EU limit)")
df$pmc <- cut(df$pm, breaks = brks, labels = labs, include.lowest = TRUE, right = FALSE)

# semantic air-quality ramp: green good -> yellow -> orange -> red -> purple bad
aqi_cols <- c("#1a9850", "#fee08b", "#fdae61", "#d73027", "#762a83")
names(aqi_cols) <- labs

# 3. CONTEXT — shared GISCO borders (rule 3), cropped to window ---------------
win <- st_as_sfc(st_bbox(c(win_ext), crs = 3035))
borders <- st_read(file.path(shared, "CNTR_RG_10M_2024_4326.geojson"), quiet = TRUE) |>
  st_transform(3035) |> st_make_valid() |> st_crop(win)

# 4. BUILD — light canvas -----------------------------------------------------
p <- ggplot() +
  geom_sf(data = borders, fill = "grey97", colour = NA) +
  geom_raster(data = df, aes(x, y, fill = pmc)) +
  geom_sf(data = borders, fill = NA, colour = "grey55", linewidth = 0.12) +
  scale_fill_manual(values = aqi_cols, name = "PM2.5 annual mean\n(µg/m³)",
                    drop = FALSE, na.translate = FALSE) +
  coord_sf(crs = 3035, xlim = win_ext[c("xmin","xmax")],
           ylim = win_ext[c("ymin","ymax")], expand = FALSE) +
  annotation_scale(location = "br", width_hint = 0.22, text_col = "grey30") +
  labs(
    title = "Fine-particle air pollution across Europe",
    subtitle = "PM2.5 annual mean, WHO guideline bands — EEA interpolated (1 km)",
    caption = paste0(
      "Data: EEA interpolated air quality, PM2.5 annual mean (µg/m³), CC-BY 4.0, ",
      "retrieved ", DATA_RETRIEVED, ". Classes: WHO 2021 AQG (5) + interim targets; ",
      "25 = EU annual limit.\nResampled to 3 km. Projection: LAEA Europe (EPSG:3035). ",
      "Boundaries: Eurostat GISCO CNTR 10M.")
  ) +
  theme_void(base_size = 12) +
  theme(
    plot.title    = element_text(face = "bold", size = 15),
    plot.subtitle = element_text(colour = "grey30", margin = margin(b = 6)),
    plot.caption  = element_text(colour = "grey45", size = 7, hjust = 0),
    legend.position = "right", legend.key.height = unit(0.7, "cm"),
    plot.margin = margin(6, 6, 6, 6)
  )

# 5. EXPORT 300 dpi ----------------------------------------------------------
ragg::agg_png(file.path(out_maps, "air_quality_pm25_annual.png"),
              width = 9.2, height = 8.4, units = "in", res = 300)
print(p)
invisible(dev.off())
message("Wrote ", file.path(out_maps, "air_quality_pm25_annual.png"))
