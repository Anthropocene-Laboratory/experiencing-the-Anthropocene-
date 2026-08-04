# =============================================================================
# 2_map_transport_land_share.R
# Layer-A Transport feature: how much of each 10 km cell of Europe is taken up by
# "road and rail networks and associated land" (CORINE Land Cover 2018, class 122).
#
# ** CAVEAT — READ BEFORE INTERPRETING THIS MAP. PROVISIONAL. **
# CLC has a 25 ha minimum mapping unit and a 100 m minimum width for linear
# elements. A normal 2-lane road (10-20 m wide) is therefore NEVER in class 122;
# what is mapped is wide transport LAND — motorway carriageways plus verges and
# interchanges, large rail yards, airport/port access corridors. Measured here:
# class 122 covers 4 143 km2 of EEA39, i.e. ~0.07 % of Europe's land surface,
# whereas the real road+rail footprint is on the order of 1-2 %. So this map is
# an honest map of BIG transport infrastructure, NOT of road network density.
# For network density the comparable options are GRIP4 (8 km) or OSM-derived
# road length per cell — see the source shortlist in the feature notes.
#
# METHOD: exact geometric intersection of the class-122 polygons with a 10 km
# EPSG:3035 grid, so each cell gets the true covered area (no rasterization
# quantization — terra's rasterize(cover=TRUE) snaps to 1 %, which is coarser
# than most of the signal here).
#
# GRID = 10 km: at 5 km the pattern breaks into isolated pixels; at 25 km the
# corridors smear out. 10 km leaves 2 468 non-empty cells, enough to read the
# motorway/rail spine of Europe.
#
# Visual idiom deliberately mirrors Technosphere/scripts/2_map_technosphere_built_fraction.R
# (dark canvas + Inferno luminance, fixed doubling breaks) so the Layer-A maps
# stay mutually comparable.
#
# INPUT : data_raw/clc2018_class122_eea39_3035.geojson  (run script 1 first)
# OUTPUT: data_processed/maps/transport_land_share_10km.png
#         data_processed/tables/transport_land_share_by_country.csv
#         data_processed/transport_land_share_10km.tif
#
# RUN FROM WORKSPACE ROOT:
#   Rscript "Feature explorations/Transport/scripts/2_map_transport_land_share.R"
# =============================================================================
suppressPackageStartupMessages({
  library(sf); library(terra); library(ggplot2); library(ggspatial); library(ragg)
})
setwd(here::here())
sf::sf_use_s2(FALSE)   # planar CRS (3035): s2 not applicable

shared     <- "Feature explorations/_shared"
out        <- "Feature explorations/Transport/data_processed"
out_maps   <- file.path(out, "maps")
out_tables <- file.path(out, "tables")
in_gj      <- "Feature explorations/Transport/data_raw/clc2018_class122_eea39_3035.geojson"
tif        <- file.path(out, "transport_land_share_10km.tif")
dir.create(out_maps,   showWarnings = FALSE, recursive = TRUE)
dir.create(out_tables, showWarnings = FALSE, recursive = TRUE)

CELL    <- 10000                                                    # metres
win_ext <- c(xmin = 2.5e6, xmax = 6e6, ymin = 1.5e6, ymax = 5.5e6)  # as other features

# 1. LOAD class-122 polygons -------------------------------------------------
clc <- st_read(in_gj, quiet = TRUE) |> st_make_valid()
stopifnot(st_crs(clc)$epsg == 3035)
message(sprintf("class 122: %d polygons, %.0f km2 (EEA39 total)",
                nrow(clc), as.numeric(sum(st_area(clc))) / 1e6))

# 2. EXACT covered area per 10 km cell ---------------------------------------
#    Build the grid, keep only cells that actually touch class 122, then
#    intersect: 4 839 polygons x ~2 500 cells is cheap and exact.
win  <- st_as_sfc(st_bbox(c(win_ext), crs = 3035))
grid <- st_make_grid(win, cellsize = CELL, what = "polygons")
grid <- st_sf(cell = seq_along(grid), geometry = grid)
message("grid cells in window: ", nrow(grid))

hit <- st_filter(grid, clc, .predicate = st_intersects)
message("cells touching class 122: ", nrow(hit))

inter <- st_intersection(hit, st_union(st_geometry(clc)))
inter$area_m2 <- as.numeric(st_area(inter))
per_cell <- aggregate(area_m2 ~ cell, data = st_drop_geometry(inter), FUN = sum)
per_cell$pct <- 100 * per_cell$area_m2 / CELL^2

message(sprintf("area accounted for in window: %.0f km2 (%.1f%% of EEA39 total)",
                sum(per_cell$area_m2) / 1e6,
                100 * sum(per_cell$area_m2) / as.numeric(sum(st_area(clc)))))
message("distribution of non-zero cell shares (%):")
print(round(quantile(per_cell$pct, c(0, .25, .5, .75, .9, .95, .99, 1)), 2))

# 3. To raster (regular grid -> geom_raster, and a .tif for the Analysis stack)
r <- rast(ext(win_ext[["xmin"]], win_ext[["xmax"]], win_ext[["ymin"]], win_ext[["ymax"]]),
          resolution = CELL, crs = "EPSG:3035")
values(r) <- NA_real_
# st_make_grid numbers cells left->right, BOTTOM->top; terra numbers top->bottom.
nc <- ncol(r); nr <- nrow(r)
row_from_bottom <- ceiling(per_cell$cell / nc)
col            <- per_cell$cell - (row_from_bottom - 1) * nc
r[cbind(nr - row_from_bottom + 1, col)] <- per_cell$pct
names(r) <- "transport_land_pct"
writeRaster(r, tif, overwrite = TRUE, gdal = "COMPRESS=LZW")

df <- as.data.frame(r, xy = TRUE, na.rm = TRUE); names(df)[3] <- "pct"

# 4. CLASSIFY — fixed doubling bands, anchored on the measured quartiles -----
#    (non-zero cells: Q1 0.27, median 0.49, Q3 1.02, p99 3.35, max 8.9 %)
brks <- c(0, 0.25, 0.5, 1, 2, 4, 100)
labs <- c("0–0.25", "0.25–0.5", "0.5–1", "1–2", "2–4", "4+")
df$pc <- cut(df$pct, breaks = brks, labels = labs, include.lowest = TRUE, right = TRUE)

# 5. CONTEXT — shared GISCO borders, subtle on the dark canvas ----------------
borders <- st_read(file.path(shared, "CNTR_RG_10M_2024_4326.geojson"), quiet = TRUE) |>
  st_transform(3035) |> st_make_valid() |> st_crop(win)

# 6. BUILD -------------------------------------------------------------------
ink <- "grey80"
p <- ggplot() +
  geom_sf(data = borders, fill = NA, colour = "grey30", linewidth = 0.12) +
  # geom_tile (not geom_raster): only ~5 000 of 140 000 cells carry data, so the
  # x/y sequence is gappy and geom_raster mis-infers the pixel pitch.
  geom_tile(data = df, aes(x, y, fill = pc), width = CELL, height = CELL) +
  # begin = 0.10: keeps the low end dark, but NOT pure black — otherwise the
  # lowest band is indistinguishable from the empty (no class-122) background
  # both on the map and in the legend key.
  scale_fill_viridis_d(option = "inferno", begin = 0.10,
                       name = "Road & rail land\n(% of 10 km cell)") +
  coord_sf(crs = 3035, xlim = win_ext[c("xmin", "xmax")],
           ylim = win_ext[c("ymin", "ymax")], expand = FALSE) +
  annotation_scale(location = "br", width_hint = 0.22,
                   text_col = ink, line_col = ink, bar_cols = c(ink, "grey20")) +
  labs(
    title = "Where transport infrastructure takes the land",
    subtitle = "Road and rail corridors as a share of each 10 km cell, CORINE Land Cover 2018",
    caption = paste0(
      "Data: Copernicus/EEA CORINE Land Cover 2018, class 122 'Road and rail networks and ",
      "associated land' (4,839 polygons, 4,143 km²), retrieved ", format(Sys.Date()),
      " from the EEA discomap CLC2018_LAEA service.\nExact polygon-grid intersection; ",
      "the map window holds 93 % of the EEA39 class-122 area (Turkey, Iceland and the ",
      "outermost regions fall outside it).\nCells with no class-122 land are dark. CLC's ",
      "25 ha minimum mapping unit and 100 m ",
      "minimum width mean only WIDE corridors are mapped — ordinary roads are absent, so ",
      "this is\nbig transport infrastructure, not road-network density. Projection: LAEA ",
      "Europe (EPSG:3035). Boundaries: Eurostat GISCO CNTR 10M. PROVISIONAL exploration.")
  ) +
  theme_void(base_size = 12) +
  theme(
    plot.background  = element_rect(fill = "black", colour = NA),
    panel.background = element_rect(fill = "black", colour = NA),
    legend.key = element_rect(fill = "black", colour = NA),
    plot.title    = element_text(face = "bold", size = 15, colour = "white"),
    plot.subtitle = element_text(colour = ink, margin = margin(b = 6)),
    plot.caption  = element_text(colour = "grey55", size = 6.2, hjust = 0),
    legend.title  = element_text(colour = ink),
    legend.text   = element_text(colour = ink),
    legend.position = "right", legend.key.height = unit(0.7, "cm"),
    plot.margin = margin(6, 6, 6, 6)
  )

ragg::agg_png(file.path(out_maps, "transport_land_share_10km.png"),
              width = 9.2, height = 8.8, units = "in", res = 300, background = "black")
print(p)
invisible(dev.off())
message("Wrote ", file.path(out_maps, "transport_land_share_10km.png"))

# 7. TABLE — class-122 land as a share of each country's territory -----------
cntr <- st_read(file.path(shared, "CNTR_RG_10M_2024_4326.geojson"), quiet = TRUE) |>
  st_transform(3035) |> st_make_valid()
cntr$land_km2 <- as.numeric(st_area(cntr)) / 1e6

ci <- st_intersection(cntr[, c("CNTR_ID", "NAME_ENGL", "land_km2")],
                      st_union(st_geometry(clc)))
ci$t_km2 <- as.numeric(st_area(ci)) / 1e6
tab <- aggregate(t_km2 ~ CNTR_ID + NAME_ENGL + land_km2, data = st_drop_geometry(ci),
                 FUN = sum)
tab$pct_of_country <- 100 * tab$t_km2 / tab$land_km2
tab <- tab[order(-tab$pct_of_country),
           c("CNTR_ID", "NAME_ENGL", "land_km2", "t_km2", "pct_of_country")]
tab$land_km2 <- round(tab$land_km2); tab$t_km2 <- round(tab$t_km2, 1)
tab$pct_of_country <- round(tab$pct_of_country, 4)
write.csv(tab, file.path(out_tables, "transport_land_share_by_country.csv"), row.names = FALSE)
message("Wrote ", file.path(out_tables, "transport_land_share_by_country.csv"))
print(utils::head(tab, 12))
