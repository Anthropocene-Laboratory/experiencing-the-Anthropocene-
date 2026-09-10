# =============================================================================
# map_global_pop_gdp.R
# World maps of the two shared Layer-B filters, built from the global 0.1-deg
# layers written by prepare_global_pop_gdp.R.
#
#   1. Population density 2020 (GHS-POP R2023A)  - people / km2
#   2. GDP per capita PPP 2024 (Kummu et al.)    - int$ / capita
#
# Cartographic choices:
#   - Equal Earth (ESRI:54035). A world thematic map needs an equal-area CRS;
#     EPSG:4326 plotted raw inflates high latitudes.
#   - Population uses the gridded-population idiom already adopted in
#     Biosphere/scripts/7_population_map.R: a luminance ramp (Inferno) on a dark
#     canvas, log-scaled, legend labelled in real units. Empty land reads as
#     near-black, which is honest.
#   - DENSITY, not counts. A 0.1-deg cell at 60N covers about half the ground of
#     one at the equator, so mapping counts per cell understates high latitudes.
#   - GDP per capita is already a ratio, so it is safe as a choropleth-style
#     surface; log scale because it spans three orders of magnitude.
#
# Reads the shared global layers written by Analysis/scripts/prepare_global_pop_gdp.R.
#
# RUN FROM WORKSPACE ROOT:
#   & 'C:/Program Files/R/R-4.5.3/bin/Rscript.exe' 'Feature explorations/Analysis/scripts/map_global_pop_gdp.R'
# =============================================================================
suppressMessages({ library(terra); library(sf); library(ggplot2) })

shared   <- "Feature explorations/_shared"
out_maps <- "Feature explorations/Analysis/data_processed/maps"
dir.create(out_maps, showWarnings = FALSE, recursive = TRUE)

EQEARTH  <- "ESRI:54035"
RETRIEVED <- format(Sys.Date())

# ---- shared furniture -------------------------------------------------------
sf_use_s2(FALSE)
cn <- st_read(file.path(shared, "CNTR_RG_10M_2024_4326.geojson"), quiet = TRUE)
cn <- st_make_valid(cn)
# clip at the antimeridian, else Russia/Fiji smear across the projected map
cn <- suppressWarnings(st_crop(cn, st_bbox(c(xmin = -179.99, xmax = 179.99,
                                             ymin = -89.99, ymax = 89.99), crs = 4326)))
cn <- st_transform(cn, EQEARTH)

ring <- rbind(
  cbind(seq(-179.99,  179.99, length.out = 720),  89.99),
  cbind(179.99, seq( 89.99, -89.99, length.out = 360)),
  cbind(seq( 179.99, -179.99, length.out = 720), -89.99),
  cbind(-179.99, seq(-89.99,  89.99, length.out = 360)))
frame <- st_transform(st_sfc(st_polygon(list(rbind(ring, ring[1, ]))), crs = 4326), EQEARTH)

to_df <- function(r, method) {
  p <- project(r, EQEARTH, res = 10000, method = method)
  p <- mask(p, vect(frame))
  d <- as.data.frame(p, xy = TRUE, na.rm = TRUE)
  names(d)[3] <- "v"
  d
}

base_theme <- function(dark) {
  ink  <- if (dark) "grey85" else "grey20"
  mute <- if (dark) "grey55" else "grey40"
  bg   <- if (dark) "#0A0A0A" else "white"
  theme_void(base_size = 9) +
    theme(legend.position = "bottom",
          legend.title    = element_text(face = "bold", size = 8.5, colour = ink, hjust = 0.5),
          legend.text     = element_text(size = 7.5, colour = mute),
          plot.title      = element_text(face = "bold", size = 15, colour = ink),
          plot.subtitle   = element_text(size = 9.5, colour = mute, margin = margin(b = 6)),
          plot.caption    = element_text(size = 6.2, colour = mute, hjust = 0,
                                         lineheight = 1.25, margin = margin(t = 8)),
          plot.background = element_rect(fill = bg, colour = NA),
          plot.margin     = margin(10, 12, 8, 12))
}

# =============================================================================
# 1. POPULATION DENSITY
# =============================================================================
cat("[1/2] population density map...\n")
dens <- rast(file.path(shared, "pop2020_global_0p1deg_density.tif"))
d <- to_df(dens, "bilinear")
d <- d[d$v >= 0.1, ]                     # below 0.1 person/km2 reads as empty
d$lv <- log10(d$v)
cat(sprintf("      cells drawn: %s | density range %.2f - %.0f /km2\n",
            format(nrow(d), big.mark = " "), min(d$v), max(d$v)))

ticks <- c(0.1, 1, 10, 100, 1000, 10000)
cap_lo <- log10(0.1); cap_hi <- log10(20000)
d$lv <- pmin(pmax(d$lv, cap_lo), cap_hi)

p1 <- ggplot() +
  geom_sf(data = frame, fill = "#0A0A0A", colour = NA) +
  geom_sf(data = cn, fill = "#141414", colour = NA) +
  geom_tile(data = d, aes(x, y, fill = lv), width = 10000, height = 10000) +
  geom_sf(data = cn, fill = NA, colour = "grey35", linewidth = 0.1) +
  geom_sf(data = frame, fill = NA, colour = "grey45", linewidth = 0.3) +
  scale_fill_gradientn(
    colours = hcl.colors(64, "Inferno"), limits = c(cap_lo, cap_hi),
    breaks = log10(ticks), labels = format(ticks, big.mark = " ", trim = TRUE, scientific = FALSE),
    name = "Residents per km²  (log scale)",
    guide = guide_colourbar(barwidth = unit(80, "mm"), barheight = unit(3.5, "mm"),
                            title.position = "top", ticks.colour = "grey30")) +
  coord_sf(crs = EQEARTH, expand = FALSE) +
  labs(title = "Where people live",
       subtitle = "Resident population density, 2020 — 7.84 billion people on a 0.1° grid",
       caption = paste(
         sprintf("Data: GHS-POP R2023A, epoch 2020, EPSG:4326 30 arc-second, resampled count-conserving to a 0.1° grid. Retrieved %s.", RETRIEVED),
         "European Commission JRC, Global Human Settlement Layer; reuse authorised with acknowledgement. Boundaries: Eurostat GISCO CNTR_RG_10M_2024.",
         "Projection: Equal Earth (ESRI:54035). Density, not counts per cell: cell ground area varies with latitude. Cells below 0.1 residents/km² not drawn; scale capped at 20 000.",
         sep = "\n")) +
  base_theme(dark = TRUE)

ragg::agg_png(file.path(out_maps, "global_population_density_2020.png"),
              width = 10, height = 6.2, units = "in", res = 300)
print(p1); invisible(dev.off())
cat("      wrote global_population_density_2020.png\n")

# =============================================================================
# 2. GDP PER CAPITA
# =============================================================================
cat("[2/2] GDP per capita map...\n")
gdp <- rast(file.path(shared, "gdp_kummu", "gdp_pc_2024_global_0p1deg.tif"))
g <- to_df(gdp, "near")
g$lv <- log10(g$v)
qs <- quantile(g$v, c(0.001, 0.999), na.rm = TRUE)
cat(sprintf("      cells drawn: %s | 0.1-99.9%% range %.0f - %.0f int$\n",
            format(nrow(g), big.mark = " "), qs[1], qs[2]))

# Discrete classes, not a continuous log ramp. On a continuous ramp every rich
# region (North America, Europe, Australia) collapses into one indistinguishable
# dark tone, hiding exactly the variation worth reading. Round thresholds happen
# to track the deciles of WORLD POPULATION closely (pop-weighted: 1% = 1 030,
# 10% = 3 399, 50% = 14 394, 75% = 32 305, 90% = 60 849 int$), so each class
# holds a meaningful share of humanity rather than a share of land.
g_brk <- c(-Inf, 1000, 3000, 10000, 30000, 60000, Inf)
g_lab <- c("< 1 000", "1 000 – 3 000", "3 000 – 10 000",
           "10 000 – 30 000", "30 000 – 60 000", "≥ 60 000")
g$class <- cut(g$v, breaks = g_brk, labels = g_lab, right = FALSE)
g_pal <- c("#ffffcc", "#c7e9b4", "#7fcdbb", "#41b6c4", "#2c7fb8", "#253494")
print(table(g$class))

p2 <- ggplot() +
  geom_sf(data = frame, fill = "#EAF0F4", colour = NA) +
  geom_sf(data = cn, fill = "grey88", colour = NA) +
  geom_tile(data = g, aes(x, y, fill = class), width = 10000, height = 10000) +
  geom_sf(data = cn, fill = NA, colour = "white", linewidth = 0.12) +
  geom_sf(data = frame, fill = NA, colour = "grey40", linewidth = 0.3) +
  scale_fill_manual(
    values = g_pal, drop = FALSE,
    name = "GDP per capita, PPP  (international $)",
    guide = guide_legend(nrow = 1, title.position = "top",
                         keyheight = unit(4, "mm"), keywidth = unit(15, "mm"))) +
  coord_sf(crs = EQEARTH, expand = FALSE) +
  labs(title = "Where wealth is",
       subtitle = "GDP per capita at purchasing power parity, 2024 — 43 501 admin-2 units; classes track world-population deciles",
       caption = paste(
         sprintf("Data: Kummu, M., Kosonen, M. & Masoumzadeh Sayyar, S. (2025) Sci Data 12:178; dataset Zenodo 10.5281/zenodo.18429133 (1990–2024 release). CC BY 4.0. Retrieved %s.", RETRIEVED),
         "Admin-2 values downscaled from reported subnational data (89 countries, 2 708 subnational units); nearest-neighbour to a 0.1° grid preserves reported unit values. Boundaries: Eurostat GISCO CNTR_RG_10M_2024.",
         "Projection: Equal Earth (ESRI:54035). Grey land = no estimate. Values are uniform within each admin-2 unit, so within-unit variation is not shown. Class breaks are round values that track",
         "the deciles of world population. Regional GDP is booked where output is produced, not where people live: extraction regions with few residents (e.g. Yamalo-Nenets and Khanty-Mansi, Russia) exceed 500 000 int$/capita.",
         sep = "\n")) +
  base_theme(dark = FALSE)

ragg::agg_png(file.path(out_maps, "global_gdp_pc_ppp_2024.png"),
              width = 10, height = 6.2, units = "in", res = 300)
print(p2); invisible(dev.off())
cat("      wrote global_gdp_pc_ppp_2024.png\n")
cat("\ndone.\n")
