# =============================================================================
# 1_map_technosphere_buildings.R
# Layer-A Technosphere feature: settlement/building intensity across Europe from
# the DLR World Settlement Footprint 3D (WSF3D v02, BuildingHeight, ~90 m global).
# PROVISIONAL exploratory prototype (see Feature explorations/CLAUDE.md) - scope,
# variable (height vs fraction vs volume) and classing are open to revision.
#
# Source (remote COG, NOT downloaded whole - read via /vsicurl/ overviews):
#   https://download.geoservice.dlr.de/WSF3D/files/global/WSF3D_V02_BuildingHeight.tif
# Intermediate raster (warped to 3 km / EPSG:3035) is cached at data_processed/.
#
# RUN FROM WORKSPACE ROOT:
#   Rscript "Feature explorations/Technosphere/scripts/1_map_technosphere_buildings.R"
# =============================================================================
suppressPackageStartupMessages({
  library(sf); library(terra); library(ggplot2); library(ggspatial)
  library(viridis); library(ragg)
})
setwd(here::here())

# Date the source data was retrieved. Fixed on purpose: this is a property of
# the DATA, not of the day the figure happens to be redrawn. Stamping Sys.Date()
# here made every rerun differ from the committed reference for no real reason.
DATA_RETRIEVED <- "2026-07-21"

shared   <- "Feature explorations/_shared"
out      <- "Feature explorations/Technosphere/data_processed"
out_maps <- file.path(out, "maps")
tif      <- file.path(out, "eu_height_wsf3d_3km.tif")   # cached intermediate
dir.create(out_maps, showWarnings = FALSE, recursive = TRUE)

# Europe window (EPSG:3035), matching the other feature maps' framing.
win_ext <- c(xmin = 2.5e6, xmax = 6e6, ymin = 1.5e6, ymax = 5.5e6)

# 1. HARVEST (guarded): warp a European window from the remote COG if not cached -
if (!file.exists(tif)) {
  message("Warping WSF3D European window from remote COG (first run only)...")
  Sys.setenv(GDAL_HTTP_UNSAFESSL = "YES", GDAL_DISABLE_READDIR_ON_OPEN = "EMPTY_DIR",
             VSI_CACHE = "TRUE", GDAL_NUM_THREADS = "ALL_CPUS")
  u <- paste0("/vsicurl/https://download.geoservice.dlr.de/WSF3D/files/global/",
              "WSF3D_V02_BuildingHeight.tif")
  gdal_utils("warp", u, tif, options = c(
    "-t_srs", "EPSG:3035",
    "-te", "2500000", "1500000", "6000000", "5500000",
    "-tr", "3000", "3000", "-r", "average",
    "-srcnodata", "-32767", "-dstnodata", "-9999", "-co", "COMPRESS=LZW"))
}

# 2. LOAD raster, mask non-built (0) so bare land stays transparent -----------
r <- rast(tif)
r[r <= 0] <- NA
df <- as.data.frame(r, xy = TRUE, na.rm = TRUE)
names(df)[3] <- "h"
# Winsorize a tiny tail of artefact cells (a ~280 m *mean* over 3 km is impossible).
cap <- as.numeric(quantile(df$h, 0.995)); n_capped <- sum(df$h > cap)
df$h <- pmin(df$h, cap)
message("built cells: ", nrow(df), " | capped ", n_capped, " outliers at ",
        round(cap, 1), " m")

# 3. CLASSIFY — quantile bins (heavy right skew: dense cores are rare) ---------
brks <- unique(round(classInt::classIntervals(df$h, n = 6, style = "quantile")$brks, 1))
df$hc <- cut(df$h, breaks = brks, include.lowest = TRUE, dig.lab = 4)

# 4. CONTEXT — shared GISCO country borders (rule 3: reuse _shared, no re-download)
win <- st_as_sfc(st_bbox(c(win_ext), crs = 3035))
borders <- st_read(file.path(shared, "CNTR_RG_10M_2024_4326.geojson"), quiet = TRUE) |>
  st_transform(3035) |> st_make_valid() |> st_crop(win)

# 5. BUILD -------------------------------------------------------------------
p <- ggplot() +
  geom_sf(data = borders, fill = "grey96", colour = NA) +
  geom_raster(data = df, aes(x, y, fill = hc)) +
  geom_sf(data = borders, fill = NA, colour = "grey55", linewidth = 0.12) +
  scale_fill_viridis_d(option = "rocket", direction = -1,
                       name = "Mean building\nheight (m)") +
  coord_sf(crs = 3035, xlim = win_ext[c("xmin","xmax")],
           ylim = win_ext[c("ymin","ymax")], expand = FALSE) +
  annotation_scale(location = "br", width_hint = 0.22, text_col = "grey30") +
  labs(
    title = "Where Europe is built up",
    subtitle = "Mean building height per 3 km cell (settlement intensity), WSF3D",
    caption = paste0(
      "Data: DLR World Settlement Footprint 3D v02 (BuildingHeight), retrieved ",
      DATA_RETRIEVED, ". Cells with no building blank; top 0.5% capped at ",
      round(cap, 1), " m.\nResampled to 3 km (average). Projection: LAEA Europe ",
      "(EPSG:3035). Boundaries: Eurostat GISCO CNTR 10M.")
  ) +
  theme_void(base_size = 12) +
  theme(
    plot.title = element_text(face = "bold", size = 15),
    plot.subtitle = element_text(colour = "grey30", margin = margin(b = 6)),
    plot.caption = element_text(colour = "grey45", size = 7, hjust = 0),
    legend.position = "right",          # external — never over the data (SKILL §2/§5)
    legend.key.height = unit(0.7, "cm"),
    plot.margin = margin(6, 6, 6, 6)
  )

# 6. EXPORT 300 dpi ----------------------------------------------------------
ragg::agg_png(file.path(out_maps, "technosphere_building_height.png"),
              width = 9.2, height = 8.4, units = "in", res = 300)
print(p)
invisible(dev.off())
message("Wrote ", file.path(out_maps, "technosphere_building_height.png"))
