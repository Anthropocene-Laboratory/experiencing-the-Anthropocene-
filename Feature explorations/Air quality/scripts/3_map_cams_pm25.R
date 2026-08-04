# =============================================================================
# 3_map_cams_pm25.R
# CAMS European air quality reanalysis PM2.5 -> annual-mean map for 2024, as a
# STANDALONE alternative to the EEA map (1_...). Same conventions (WHO bands,
# semantic air-quality palette, LAEA 3035) so the two read on the same terms.
# PROVISIONAL. CAMS = modelled ensemble reanalysis (~10 km), vs EEA = obs-interpolated
# (1 km); expect CAMS to look smoother and to differ where monitoring is sparse.
#
# Inputs: 12 monthly zips in data_raw (cams_pm25_2024_MM.zip), each a NetCDF with ~744
# hourly layers (var pm2p5, µg/m³, 0.1° WGS84). The heavy 12-month aggregation is cached
# to data_processed/cams_pm25_2024_annual_3km_3035.tif; delete that file to force a rebuild.
#
# RUN FROM WORKSPACE ROOT (after 2_fetch_cams_pm25.R finishes):
#   Rscript "Feature explorations/Air quality/scripts/3_map_cams_pm25.R"
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
raw      <- file.path(feat, "data_raw")
out_maps <- file.path(feat, "data_processed/maps")
ann_tif  <- file.path(feat, "data_processed/cams_pm25_2024_annual_3km_3035.tif")
tmpd     <- file.path(tempdir(), "cams_nc"); dir.create(tmpd, showWarnings = FALSE)
win_ext  <- c(xmin = 2.5e6, xmax = 6e6, ymin = 1.5e6, ymax = 5.5e6)

# Country polygons (shared GISCO) — used both to MASK the raster to land and to draw borders
land <- st_read(file.path(shared, "CNTR_RG_10M_2024_4326.geojson"), quiet = TRUE) |>
  st_transform(3035) |> st_make_valid()
win     <- st_as_sfc(st_bbox(c(win_ext), crs = 3035))
borders <- st_crop(land, win)

# 1-3. Annual mean (cached). Build once from the 12 monthly files, else load ----
if (file.exists(ann_tif)) {
  ann3035 <- rast(ann_tif); names(ann3035) <- "pm25"
  message("loaded cached annual raster.")
} else {
  zips <- sort(list.files(raw, pattern = "cams_pm25_2024_[0-9]{2}\\.zip$", full.names = TRUE))
  stopifnot(length(zips) > 0)
  message("CAMS monthly files: ", length(zips), if (length(zips) < 12) "  (< 12 — partial!)" else "")
  mlist <- list(); wts <- numeric(0)
  for (z in zips) {
    nc <- unzip(z, exdir = tmpd); nc <- nc[grepl("\\.nc$", nc)][1]
    r  <- rast(nc)
    mlist[[length(mlist) + 1]] <- mean(r, na.rm = TRUE)   # monthly mean
    wts <- c(wts, nlyr(r)); file.remove(nc)               # weight = n hourly layers
    message("  ", basename(z), " -> monthly mean (", nlyr(r), " hrs)")
  }
  ann <- app(rast(mlist) * (wts / sum(wts)), sum); names(ann) <- "pm25"   # weighted annual
  ann3035 <- project(ann, "EPSG:3035", res = 3000, method = "bilinear")
  ann3035 <- crop(ann3035, ext(win_ext["xmin"], win_ext["xmax"], win_ext["ymin"], win_ext["ymax"]))
  ann3035 <- mask(ann3035, vect(land))    # CAMS outputs over sea too -> keep LAND only
  writeRaster(ann3035, ann_tif, overwrite = TRUE)
}
df <- as.data.frame(ann3035, xy = TRUE, na.rm = TRUE); names(df)[3] <- "pm"
message("mapped land cells: ", nrow(df), " | PM2.5 range: ",
        paste(round(range(df$pm), 1), collapse = "–"), " ug/m3")

# 4. CLASSIFY — WHO bands, identical to the EEA map --------------------------
brks <- c(0, 5, 10, 15, 25, Inf)
labs <- c("< 5  (WHO guideline)", "5–10", "10–15", "15–25", "> 25  (EU limit)")
df$pmc <- cut(df$pm, breaks = brks, labels = labs, include.lowest = TRUE, right = FALSE)
aqi_cols <- c("#1a9850", "#fee08b", "#fdae61", "#d73027", "#762a83"); names(aqi_cols) <- labs

# 5. BUILD (light canvas, same as EEA) ---------------------------------------
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
    title = "Fine-particle air pollution across Europe (CAMS)",
    subtitle = "PM2.5 annual mean 2024, WHO guideline bands — CAMS ensemble reanalysis (~10 km)",
    caption = paste0(
      "Data: Copernicus CAMS European air quality interim reanalysis, PM2.5, ensemble, ",
      "annual mean 2024 (from hourly), retrieved ", DATA_RETRIEVED, ".\nClasses: WHO 2021 ",
      "AQG (5) + interim targets; 25 = EU annual limit. Projection: LAEA Europe (EPSG:3035). ",
      "Boundaries: Eurostat GISCO CNTR 10M.")
  ) +
  theme_void(base_size = 12) +
  theme(
    plot.title = element_text(face = "bold", size = 15),
    plot.subtitle = element_text(colour = "grey30", margin = margin(b = 6)),
    plot.caption = element_text(colour = "grey45", size = 7, hjust = 0),
    legend.position = "right", legend.key.height = unit(0.7, "cm"),
    plot.margin = margin(6, 6, 6, 6)
  )

ragg::agg_png(file.path(out_maps, "air_quality_pm25_cams_2024.png"),
              width = 9.2, height = 8.4, units = "in", res = 300)
print(p); invisible(dev.off())
message("Wrote ", file.path(out_maps, "air_quality_pm25_cams_2024.png"))
