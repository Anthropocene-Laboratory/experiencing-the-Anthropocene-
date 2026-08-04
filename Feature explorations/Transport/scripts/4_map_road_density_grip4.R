# =============================================================================
# 4_map_road_density_grip4.R
# Layer-A Transport feature, THE ROADEDNESS MAP: metres of road per km2 of land,
# GRIP4 (all road classes), over Europe.
#
# This is the map that answers "how roaded is this place" — the question CLC
# class 122 (scripts 1-2) cannot answer, because CLC's 100 m minimum width
# excludes every ordinary road (it recovers ~0.07 % of Europe's surface against a
# real road+rail footprint of 1-2 %). GRIP4 measures road LENGTH per unit area,
# which is the quantity "roadedness" actually means.
#
# HOW COMPLETE IS GRIP4? (validation in the source note, run before trusting this)
#   GRIP4 total road length recovers ~0.5-0.7 of published national network
#   length: DE 0.68, FR 0.48, IT 0.52, SE 0.55, NL 0.55, PL 0.53. The shortfall
#   is municipal/local roads (class tp5 has a median of 0 m/km2 across European
#   land cells — over half of Europe has no local road recorded). What matters
#   for a map is that the ratio is NEARLY CONSTANT across six countries with
#   independent road administrations: absolute values are roughly half of true,
#   but the spatial PATTERN is not an artefact of national data availability.
#   The observation that would have indicted the layer — ratios scattered from
#   0.2 to 1.5 across comparably-defined countries — is not what we see.
#   (Spain reads 1.58 because the reference figure used there excludes municipal
#   roads, a definitional mismatch in the reference, not a GRIP excess.)
#
# SOURCE: GRIP4, Meijer et al. 2018 (PBL/GLOBIO), ODbL. Native 5 arcmin
#   (~55 km2 per cell at 50 degN), resampled to 8 km EPSG:3035 (bilinear).
#
# INPUT : data_raw/grip4/*.asc  (run script 3 first)
# OUTPUT: data_processed/maps/road_density_grip4_8km.png
#         data_processed/tables/road_density_by_country.csv
#         data_processed/road_density_grip4_8km.tif   (for the Analysis stack)
#
# RUN FROM WORKSPACE ROOT:
#   Rscript "Feature explorations/Transport/scripts/4_map_road_density_grip4.R"
# =============================================================================
suppressPackageStartupMessages({
  library(sf); library(terra); library(ggplot2); library(ggspatial); library(ragg)
})
setwd(here::here())
sf::sf_use_s2(FALSE)

shared     <- "Feature explorations/_shared"
raw        <- "Feature explorations/Transport/data_raw/grip4"
out        <- "Feature explorations/Transport/data_processed"
out_maps   <- file.path(out, "maps")
out_tables <- file.path(out, "tables")
tif        <- file.path(out, "road_density_grip4_8km.tif")
dir.create(out_maps,   showWarnings = FALSE, recursive = TRUE)
dir.create(out_tables, showWarnings = FALSE, recursive = TRUE)

CELL    <- 8000
win_ext <- c(xmin = 2.5e6, xmax = 6e6, ymin = 1.5e6, ymax = 5.5e6)  # as other features

lay <- function(n) { r <- rast(file.path(raw, n)); if (crs(r) == "") crs(r) <- "EPSG:4326"; r }

# 1. LOAD density + land-area grids; mask sea via land area ------------------
dens <- lay("grip4_total_dens_m_km2.asc")
area <- lay("grip4_area_land_km2.asc")
dens <- mask(dens, area, maskvalues = c(NA, 0))   # sea/no-land -> NA

# 2. REPROJECT to LAEA Europe (density is a continuous field -> bilinear) ----
#
# !! DO NOT replace LAEA_PROJ with "EPSG:3035" here. Asking PROJ for EPSG:3035 by
# code makes it build a WGS84->ETRS89 pipeline through country-specific
# deformation / tinshift grids (de_*, nl_*, ch_*, fi_nls_ykj_etrs35fin.json).
# Those grids are absent from this PROJ install, and terra does NOT error — it
# silently returns NA, punching a hole in the map exactly over Germany, the
# Netherlands, Belgium, Switzerland and Austria. Measured: 106 806 non-NA cells
# with "EPSG:3035" vs 113 870 with the PROJ string below (PROJ_NETWORK=ON does
# not help). The grids would move coordinates by centimetres — irrelevant at 8 km.
LAEA_PROJ <- paste0("+proj=laea +lat_0=52 +lon_0=10 +x_0=4321000 +y_0=3210000 ",
                    "+ellps=GRS80 +units=m +no_defs")   # == EPSG:3035 definition
tmpl <- rast(ext(win_ext[["xmin"]], win_ext[["xmax"]], win_ext[["ymin"]], win_ext[["ymax"]]),
             resolution = CELL, crs = LAEA_PROJ)
r <- project(dens, tmpl, method = "bilinear")
crs(r) <- "EPSG:3035"      # same definition, now properly tagged for downstream use
names(r) <- "road_density_m_km2"
stopifnot(global(!is.na(r), "sum")[1, 1] > 110000)   # guard against the hole coming back
writeRaster(r, tif, overwrite = TRUE, gdal = "COMPRESS=LZW")

df <- as.data.frame(r, xy = TRUE, na.rm = TRUE); names(df)[3] <- "d"
message(sprintf("mapped cells: %d | median %.0f | p95 %.0f | max %.0f m/km2",
                nrow(df), median(df$d), quantile(df$d, .95), max(df$d)))

# 3. CLASSIFY — roadless split out, then a doubling ramp (density is skewed) --
brks <- c(-1, 0, 100, 250, 500, 1000, 2000, Inf)
labs <- c("0 (roadless)", "1–100", "100–250", "250–500", "500–1 000",
          "1 000–2 000", "2 000+")
df$dc <- cut(df$d, breaks = brks, labels = labs, right = TRUE)

# 4. CONTEXT ----------------------------------------------------------------
win <- st_as_sfc(st_bbox(c(win_ext), crs = 3035))
borders <- st_read(file.path(shared, "CNTR_RG_10M_2024_4326.geojson"), quiet = TRUE) |>
  st_transform(3035) |> st_make_valid() |> st_crop(win)

# 5. BUILD — same dark-canvas Inferno idiom as the other Layer-A maps --------
ink <- "grey80"
p <- ggplot() +
  geom_sf(data = borders, fill = NA, colour = "grey30", linewidth = 0.12) +
  # geom_tile, not geom_raster: sea cells are dropped, so the x/y sequence is
  # gappy along coastlines and geom_raster mis-infers the pixel pitch.
  geom_tile(data = df, aes(x, y, fill = dc), width = CELL, height = CELL) +
  scale_fill_viridis_d(option = "inferno", begin = 0.04,
                       name = "Road density\n(m of road per km² of land)") +
  coord_sf(crs = 3035, xlim = win_ext[c("xmin", "xmax")],
           ylim = win_ext[c("ymin", "ymax")], expand = FALSE) +
  annotation_scale(location = "br", width_hint = 0.22,
                   text_col = ink, line_col = ink, bar_cols = c(ink, "grey20")) +
  labs(
    title = "How roaded Europe is",
    subtitle = "Metres of road per km² of land, all road classes, GRIP4",
    caption = paste0(
      "Data: Global Roads Inventory Project v4 (Meijer et al. 2018, PBL/GLOBIO, ODbL), ",
      "total road density, retrieved ", format(Sys.Date()), ".\nNative 5 arcmin (~55 km² ",
      "per cell at 50°N) reprojected to 8 km, bilinear. Sea masked with GRIP4's land-area ",
      "grid; the darkest band is land with no road recorded.\nCompleteness: GRIP4 recovers ",
      "~0.5–0.7 of published national network length (municipal roads are the gap), but the ",
      "ratio is near-constant across six countries,\nso absolute values read low while the ",
      "spatial pattern holds. Projection: LAEA Europe (EPSG:3035). Boundaries: Eurostat ",
      "GISCO CNTR 10M. PROVISIONAL exploration.")
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

ragg::agg_png(file.path(out_maps, "road_density_grip4_8km.png"),
              width = 9.2, height = 8.8, units = "in", res = 300, background = "black")
print(p)
invisible(dev.off())
message("Wrote ", file.path(out_maps, "road_density_grip4_8km.png"))

# 6. TABLE — national mean density + GRIP length vs published network -------
len_km <- lay("grip4_total_dens_m_km2.asc") * area / 1000     # km of road per cell
# GISCO CNTR is GLOBAL — keep only countries inside the map window, otherwise the
# ranking is topped by Macau, Gibraltar and Caribbean islands.
cn <- st_read(file.path(shared, "CNTR_RG_10M_2024_4326.geojson"), quiet = TRUE) |>
  st_transform(3035) |> st_make_valid() |> st_filter(win, .predicate = st_intersects) |>
  st_transform(4326)
message("countries in window: ", nrow(cn))
cn_v <- vect(cn)
tab <- data.frame(
  CNTR_ID   = cn$CNTR_ID,
  NAME_ENGL = cn$NAME_ENGL,
  grip_len_km  = terra::extract(len_km, cn_v, fun = sum, na.rm = TRUE)[, 2],
  land_km2     = terra::extract(area,   cn_v, fun = sum, na.rm = TRUE)[, 2]
)
tab <- tab[!is.na(tab$grip_len_km) & tab$land_km2 > 0, ]
tab$density_m_km2 <- 1000 * tab$grip_len_km / tab$land_km2
tab <- tab[order(-tab$density_m_km2), ]
tab$grip_len_km  <- round(tab$grip_len_km)
tab$land_km2     <- round(tab$land_km2)
tab$density_m_km2 <- round(tab$density_m_km2)
write.csv(tab, file.path(out_tables, "road_density_by_country.csv"), row.names = FALSE)
message("Wrote ", file.path(out_tables, "road_density_by_country.csv"))
print(utils::head(tab, 12))
