# =============================================================================
# 2_map_technosphere_built_fraction.R
# Layer-A Technosphere feature: how BUILT-UP Europe is, from WSF3D BuildingFraction
# (% of each cell covered by buildings). Chosen over BuildingHeight after a prior-art
# check (SKILL §0): "fraction" is the field's direct measure of settlement extent and
# matches the map's question, whereas mean height mixes tall + dense. PROVISIONAL.
#
# Visual idiom deliberately mirrors Biosphere/scripts/7_population_map.R: a luminance
# ramp (Inferno) on a DARK canvas — low fraction is near-black and blends into the
# background (few buildings = dark = honest), dense cores glow bright.
#
# Source COG (read via /vsicurl/ overviews; Byte, NoData=255, values = % built):
#   https://download.geoservice.dlr.de/WSF3D/files/global/WSF3D_V02_BuildingFraction.tif
#
# RUN FROM WORKSPACE ROOT:
#   Rscript "Feature explorations/Technosphere/scripts/2_map_technosphere_built_fraction.R"
# =============================================================================
suppressPackageStartupMessages({
  library(sf); library(terra); library(ggplot2); library(ggspatial); library(ragg)
})
setwd(here::here())

shared   <- "Feature explorations/_shared"
out      <- "Feature explorations/Technosphere/data_processed"
out_maps <- file.path(out, "maps")
tif      <- file.path(out, "eu_fraction_wsf3d_3km.tif")
dir.create(out_maps, showWarnings = FALSE, recursive = TRUE)
win_ext  <- c(xmin = 2.5e6, xmax = 6e6, ymin = 1.5e6, ymax = 5.5e6)

# 1. HARVEST (guarded): warp European window from remote COG if not cached ----
if (!file.exists(tif)) {
  message("Warping WSF3D BuildingFraction from remote COG (first run only)...")
  Sys.setenv(GDAL_HTTP_UNSAFESSL = "YES", GDAL_DISABLE_READDIR_ON_OPEN = "EMPTY_DIR",
             VSI_CACHE = "TRUE", GDAL_NUM_THREADS = "ALL_CPUS")
  u <- paste0("/vsicurl/https://download.geoservice.dlr.de/WSF3D/files/global/",
              "WSF3D_V02_BuildingFraction.tif")
  gdal_utils("warp", u, tif, options = c(
    "-t_srs", "EPSG:3035", "-te", "2500000", "1500000", "6000000", "5500000",
    "-tr", "3000", "3000", "-r", "average", "-ot", "Float32",
    "-srcnodata", "255", "-dstnodata", "-9999", "-co", "COMPRESS=LZW"))  # 255 = NoData
}

# 2. LOAD raster; non-built (0) -> NA (stays dark on the black canvas) ---------
r <- rast(tif); r[r <= 0] <- NA
df <- as.data.frame(r, xy = TRUE, na.rm = TRUE); names(df)[3] <- "f"

# 3. CLASSIFY — FIXED interpretable % bands (doubling scale suits the skew) ----
brks <- c(0, 1, 2, 4, 8, 16, 100)
labs <- c("0–1", "1–2", "2–4", "4–8", "8–16", "16+")
df$fc <- cut(df$f, breaks = brks, labels = labs, include.lowest = TRUE, right = TRUE)

# 4. CONTEXT — shared GISCO borders, subtle on the dark canvas ----------------
win <- st_as_sfc(st_bbox(c(win_ext), crs = 3035))
borders <- st_read(file.path(shared, "CNTR_RG_10M_2024_4326.geojson"), quiet = TRUE) |>
  st_transform(3035) |> st_make_valid() |> st_crop(win)

# 5. BUILD — dark canvas + Inferno luminance ---------------------------------
ink <- "grey80"
p <- ggplot() +
  geom_sf(data = borders, fill = NA, colour = "grey30", linewidth = 0.12) +
  geom_raster(data = df, aes(x, y, fill = fc)) +
  scale_fill_viridis_d(option = "inferno", name = "Built-up area\n(% of 3 km cell)") +
  coord_sf(crs = 3035, xlim = win_ext[c("xmin","xmax")],
           ylim = win_ext[c("ymin","ymax")], expand = FALSE) +
  annotation_scale(location = "br", width_hint = 0.22,
                   text_col = ink, line_col = ink, bar_cols = c(ink, "grey20")) +
  labs(
    title = "Where Europe is built up",
    subtitle = "Building footprint as a share of each 3 km cell, WSF3D",
    caption = paste0(
      "Data: DLR World Settlement Footprint 3D v02 (BuildingFraction), retrieved ",
      format(Sys.Date()), ". Cells with no building are dark.\nResampled to 3 km ",
      "(average). Projection: LAEA Europe (EPSG:3035). Boundaries: Eurostat GISCO CNTR 10M.")
  ) +
  theme_void(base_size = 12) +
  theme(
    plot.background  = element_rect(fill = "black", colour = NA),
    panel.background = element_rect(fill = "black", colour = NA),
    legend.key = element_rect(fill = "black", colour = NA),
    plot.title    = element_text(face = "bold", size = 15, colour = "white"),
    plot.subtitle = element_text(colour = ink, margin = margin(b = 6)),
    plot.caption  = element_text(colour = "grey55", size = 7, hjust = 0),
    legend.title  = element_text(colour = ink),
    legend.text   = element_text(colour = ink),
    legend.position = "right", legend.key.height = unit(0.7, "cm"),
    plot.margin = margin(6, 6, 6, 6)
  )

# 6. EXPORT 300 dpi ----------------------------------------------------------
ragg::agg_png(file.path(out_maps, "technosphere_built_fraction.png"),
              width = 9.2, height = 8.4, units = "in", res = 300, background = "black")
print(p)
invisible(dev.off())
message("Wrote ", file.path(out_maps, "technosphere_built_fraction.png"))
