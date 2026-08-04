# =============================================================================
# 3_map_technosphere_light_pollution.R
# Layer-A Technosphere feature: Perception of starry sky (Artificial Sky Brightness)
# Data: World Atlas of Artificial Night Sky Brightness (Falchi et al. 2016)
#
# Mirroring the layout of the built fraction map (dark canvas, Inferno palette)
# to maintain consistency across the Technosphere exploration.
#
# RUN FROM WORKSPACE ROOT:
#   Rscript "Feature explorations/Technosphere/scripts/3_map_technosphere_light_pollution.R"
# =============================================================================
suppressPackageStartupMessages({
  library(sf); library(terra); library(ggplot2); library(ggspatial); library(ragg)
})
setwd(here::here())

shared   <- "Feature explorations/_shared"
out      <- "Feature explorations/Technosphere/data_processed"
out_maps <- file.path(out, "maps")
dir.create(out_maps, showWarnings = FALSE, recursive = TRUE)

# The raw downloaded file
raw_tif <- "Feature explorations/Technosphere/data_raw/World_Atlas_2015/World_Atlas_2015.tif"
tif     <- file.path(out, "eu_light_pollution_3km.tif")
win_ext <- c(xmin = 2.5e6, xmax = 6e6, ymin = 1.5e6, ymax = 5.5e6)

# 1. HARVEST (Warp to EU window) -----------------------------------------------
if (!file.exists(tif)) {
  message("Warping Falchi 2015 dataset to European window...")
  # We use 'average' resampling to get the mean brightness for the 3km cell
  # The source is a global 30-arcsecond (~1km) raster
  gdal_utils("warp", raw_tif, tif, options = c(
    "-t_srs", "EPSG:3035", "-te", "2500000", "1500000", "6000000", "5500000",
    "-tr", "3000", "3000", "-r", "average", "-ot", "Float32",
    "-co", "COMPRESS=LZW"))
}

# 2. LOAD RASTER ---------------------------------------------------------------
r <- rast(tif)
# Light pollution values are in mcd/m2.
# We map very low values (<= 0) to NA so they stay dark/black on the canvas.
r[r <= 0.01] <- NA
df <- as.data.frame(r, xy = TRUE, na.rm = TRUE)
names(df)[3] <- "val"

# 3. CLASSIFY ------------------------------------------------------------------
# Light perception is logarithmic. We use logarithmic breaks.
brks <- c(0, 0.1, 1, 10, 100, 1000, 10000)
labs <- c("< 0.1", "0.1–1", "1–10", "10–100", "100–1000", "> 1000")
df$cls <- cut(df$val, breaks = brks, labels = labs, include.lowest = TRUE, right = FALSE)

# 4. CONTEXT BORDERS -----------------------------------------------------------
win <- st_as_sfc(st_bbox(c(win_ext), crs = 3035))
borders <- st_read(file.path(shared, "CNTR_RG_10M_2024_4326.geojson"), quiet = TRUE) |>
  st_transform(3035) |> st_make_valid() |> st_crop(win)

# 5. BUILD PLOT ----------------------------------------------------------------
ink <- "grey80"
p <- ggplot() +
  geom_raster(data = df, aes(x, y, fill = cls)) +
  geom_sf(data = borders, fill = NA, colour = "grey50", linewidth = 0.15) +
  scale_fill_manual(
    name = "Artificial Sky Brightness\n(mcd/m²)",
    values = c("< 0.1" = "#000000", "0.1–1" = "#0020FF", "1–10" = "#00CC00", 
               "10–100" = "#FFCC00", "100–1000" = "#FF0000", "> 1000" = "#FFFFFF")
  ) +
  coord_sf(crs = 3035, xlim = win_ext[c("xmin","xmax")],
           ylim = win_ext[c("ymin","ymax")], expand = FALSE) +
  annotation_scale(location = "bl", width_hint = 0.22,
                   text_col = ink, line_col = ink, bar_cols = c(ink, "grey20")) +
  labs(
    title = "Perception of the starry sky",
    subtitle = "Artificial night sky brightness (Falchi et al., 2016)",
    caption = paste0(
      "Data: World Atlas of Artificial Night Sky Brightness (Falchi et al. 2016), GFZ Data Services.\n",
      "Resampled to 3 km (average). Grey/Black indicates unpolluted natural sky.\n",
      "Projection: LAEA Europe (EPSG:3035). Boundaries: Eurostat GISCO CNTR 10M."
    )
  ) +
  theme_void(base_size = 12) +
  theme(
    plot.background  = element_rect(fill = "black", colour = NA),
    panel.background = element_rect(fill = "black", colour = NA),
    legend.key       = element_rect(fill = "black", colour = "grey50", linewidth = 0.3),
    plot.title       = element_text(face = "bold", size = 15, colour = "white"),
    plot.subtitle    = element_text(colour = ink, margin = margin(b = 6)),
    plot.caption     = element_text(colour = "grey55", size = 7, hjust = 0),
    legend.title     = element_text(colour = ink),
    legend.text      = element_text(colour = ink),
    legend.position  = "right",
    legend.key.height= unit(0.7, "cm"),
    plot.margin      = margin(6, 6, 6, 6)
  )

# 6. EXPORT --------------------------------------------------------------------
ragg::agg_png(file.path(out_maps, "technosphere_light_pollution.png"),
              width = 9.2, height = 8.4, units = "in", res = 300, background = "black")
print(p)
invisible(dev.off())
message("Wrote ", file.path(out_maps, "technosphere_light_pollution.png"))

# Return plot object for validation
p
