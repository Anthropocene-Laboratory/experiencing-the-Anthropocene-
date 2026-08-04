# World choropleth — Employment in agriculture (% of total employment), World Bank
# Follows the r-cartographer skill workflow. Reproducible (Voie A).
suppressPackageStartupMessages({
  library(sf); library(ggplot2); library(rnaturalearth)
  library(viridis); library(ragg); library(dplyr)
})

# Date the source data was retrieved. Fixed on purpose: this is a property of
# the DATA, not of the day the figure happens to be redrawn. Stamping Sys.Date()
# here made every rerun differ from the committed reference for no real reason.
DATA_RETRIEVED <- "2026-07-21"

out_png <- here::here("validation", "world_agri_employment.png")

# 1. LOAD DATA (harvested locally from World Bank bulk CSV) -------------------
csv <- list.files(here::here("validation", "wb_data"),
                  pattern = "^API_SL.AGR.EMPL.ZS.*\\.csv$", full.names = TRUE)[1]
wb <- read.csv(csv, skip = 4, check.names = FALSE, stringsAsFactors = FALSE)

# take each country's most recent non-NA year to maximise coverage
year_cols <- grep("^[0-9]{4}$", names(wb), value = TRUE)
latest <- apply(wb[, year_cols], 1, function(r) {
  v <- suppressWarnings(as.numeric(r)); idx <- which(!is.na(v))
  if (length(idx) == 0) return(NA_real_)
  v[max(idx)]
})

latest_year <- apply(wb[, year_cols], 1, function(r) {
  v <- suppressWarnings(as.numeric(r)); idx <- which(!is.na(v))
  if (length(idx) == 0) return(NA) else year_cols[max(idx)]
})

wb_clean <- data.frame(iso_a3 = wb$`Country Code`, agri = latest, yr = latest_year)
message("Countries with a value: ", sum(!is.na(wb_clean$agri)),
        " | year range used: ", paste(range(as.numeric(wb_clean$yr), na.rm = TRUE), collapse = "–"))

# 2. BOUNDARIES + JOIN -------------------------------------------------------
world <- ne_countries(scale = 50, returnclass = "sf")
world <- world[world$admin != "Antarctica", ]
# rnaturalearth stores ISO-3 in iso_a3 (some -99); fall back to iso_a3_eh
world$iso3 <- ifelse(world$iso_a3 == "-99", world$iso_a3_eh, world$iso_a3)
world <- left_join(world, wb_clean, by = c("iso3" = "iso_a3"))
message("Joined polygons with data: ", sum(!is.na(world$agri)), " / ", nrow(world))

# 3. REPROJECT to Equal Earth (world thematic, equal-area) -------------------
world <- st_transform(world, "ESRI:54035")

# 4. CLASSIFY — fixed, interpretable % breaks (comparable across maps) --------
brks <- c(0, 5, 10, 20, 40, 60, 100)
labs <- c("0–5", "5–10", "10–20", "20–40", "40–60", "60+")
world$agri_class <- cut(world$agri, breaks = brks, labels = labs,
                        include.lowest = TRUE, right = FALSE)

# graticule for context on a small-scale map
grat <- st_graticule(lat = seq(-60, 80, 20), lon = seq(-150, 150, 30)) |>
  st_transform("ESRI:54035")

# 5. BUILD -------------------------------------------------------------------
p <- ggplot() +
  geom_sf(data = grat, colour = "grey88", linewidth = 0.2) +
  geom_sf(data = world, aes(fill = agri_class), colour = "grey40", linewidth = 0.08) +
  scale_fill_viridis_d(option = "rocket", direction = -1, na.value = "grey92",
                       name = "% of employment", drop = FALSE) +
  labs(title = "Employment in agriculture, worldwide",
       subtitle = "Share of total employment, latest available year (modelled ILO estimate)",
       caption = paste0(
         "Data: World Bank, World Development Indicators (SL.AGR.EMPL.ZS), ",
         "retrieved ", DATA_RETRIEVED, "; values 2021–2025. Grey = no data.\n",
         "Projection: Equal Earth (ESRI:54035). Boundaries: Natural Earth 1:50m.")) +
  coord_sf(crs = "ESRI:54035", datum = NA, expand = FALSE) +
  theme_void(base_size = 12) +
  theme(
    plot.title = element_text(face = "bold", size = 15),
    plot.subtitle = element_text(colour = "grey30", margin = margin(b = 6)),
    plot.caption = element_text(colour = "grey45", size = 8),
    legend.position = c(0.5, 0.06), legend.direction = "horizontal",
    legend.key.height = unit(0.35, "cm"), legend.key.width = unit(1.1, "cm"),
    legend.title = element_text(size = 9, vjust = 1),
    plot.margin = margin(8, 8, 8, 8)
  ) +
  guides(fill = guide_legend(nrow = 1, label.position = "bottom",
                             title.position = "left"))

# 6. EXPORT 300 dpi ----------------------------------------------------------
ragg::agg_png(out_png, width = 10, height = 5.6, units = "in", res = 300)
print(p)
invisible(dev.off())
message("Wrote ", normalizePath(out_png))
