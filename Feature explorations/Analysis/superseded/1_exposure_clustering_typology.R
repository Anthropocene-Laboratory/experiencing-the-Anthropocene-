# =============================================================================
# 1_exposure_clustering_typology.R
# Profile 1: Sensory & Bodily Burden (Pression sensorielle et corporelle)
#
# Combines 4 Layer A features across Technosphere & Biosphere/Climate:
#   1. Built Fraction (% surface, Technosphere A2)
#   2. Light Pollution (Artificial Sky Brightness mcd/m2, Technosphere A2)
#   3. Air Pollution (PM2.5 annual mean ug/m3, Biosphere A1)
#   4. UTCI Thermal Stress (Annual hours >= 26°C, Biosphere A1)
#
# RUN FROM WORKSPACE ROOT:
#   Rscript "Feature explorations/Analysis/1_exposure_clustering_typology.R"
# =============================================================================
suppressPackageStartupMessages({
  library(sf); library(terra); library(ggplot2); library(ggspatial); library(cluster); library(ragg)
})
setwd(here::here())

out_dir  <- "Feature explorations/Analysis/data_processed"
out_maps <- file.path(out_dir, "maps")
dir.create(out_maps, showWarnings = FALSE, recursive = TRUE)

shared   <- "Feature explorations/_shared"

# 1. LOAD AND STACK RASTERS ---------------------------------------------------
f_built <- "Feature explorations/Technosphere/data_processed/eu_fraction_wsf3d_3km.tif"
f_light <- "Feature explorations/Technosphere/data_processed/eu_light_pollution_3km.tif"
f_pm25  <- "Feature explorations/Air quality/data_processed/cams_pm25_2024_annual_3km_3035.tif"
f_utci  <- "Feature explorations/Heatwaves/data_processed/utci_heatstress_hours_2022.nc"

r_built <- rast(f_built)
r_light <- rast(f_light)
r_pm25  <- rast(f_pm25)

# Calculate total UTCI heatstress hours (moderate + strong)
r_utci_nc  <- rast(f_utci)
r_utci_raw <- r_utci_nc[["hours_moderate"]] + r_utci_nc[["hours_strong"]]

# Reproject UTCI (EPSG:4326) and resample all to matching 3km LAEA grid
r_utci_3035 <- project(r_utci_raw, r_built, method = "bilinear")
r_light_res <- resample(r_light, r_built, method = "bilinear")
r_pm25_res  <- resample(r_pm25, r_built, method = "bilinear")

stk <- c(r_built, r_light_res, r_pm25_res, r_utci_3035)
names(stk) <- c("built_fraction", "light_pollution", "pm25", "utci_heatstress")

# 2. EXTRACT & STANDARDIZE DATA -----------------------------------------------
df <- as.data.frame(stk, xy = TRUE, na.rm = TRUE)

# Log transform skewed variables for numerical stability
df$built_log <- log1p(df$built_fraction)
df$light_log <- log1p(pmax(0, df$light_pollution))
df$pm25_val  <- df$pm25
df$utci_val  <- log1p(pmax(0, df$utci_heatstress))

# Z-score normalization across all 4 variables
df_scaled <- scale(df[, c("built_log", "light_log", "pm25_val", "utci_val")])

# 3. K-MEANS CLUSTERING & SILHOUETTE EVALUATION -------------------------------
set.seed(42)
sample_idx <- sample(1:nrow(df_scaled), min(10000, nrow(df_scaled)))
sample_data <- df_scaled[sample_idx, ]

sil_scores <- c()
ks <- 3:6
for (k in ks) {
  km <- kmeans(sample_data, centers = k, nstart = 10)
  ss <- silhouette(km$cluster, dist(sample_data))
  sil_scores <- c(sil_scores, mean(ss[, 3]))
}

best_k <- ks[which.max(sil_scores)]
message("Optimal number of clusters (Silhouette peak): k = ", best_k)

# Final K-means model on entire dataset
km_final <- kmeans(df_scaled, centers = best_k, nstart = 20)
df$cluster <- factor(km_final$cluster)

# Calculate cluster profile means
profiles <- aggregate(cbind(built_fraction, light_pollution, pm25, utci_heatstress) ~ cluster, data = df, FUN = mean)
print(profiles)

# 4. CONTEXT BORDERS -----------------------------------------------------------
win_ext <- c(xmin = 2.5e6, xmax = 6e6, ymin = 1.5e6, ymax = 5.5e6)
win <- st_as_sfc(st_bbox(c(win_ext), crs = 3035))
borders <- st_read(file.path(shared, "CNTR_RG_10M_2024_4326.geojson"), quiet = TRUE) |>
  st_transform(3035) |> st_make_valid() |> st_crop(win)

# 5. BUILD CLUSTER MAP ---------------------------------------------------------
ink <- "grey30"
palette_clusters <- c("#2b83ba", "#abdda4", "#fdae61", "#d7191c", "#998ec3", "#e66101")[1:best_k]

p_map <- ggplot() +
  geom_raster(data = df, aes(x, y, fill = cluster)) +
  geom_sf(data = borders, fill = NA, colour = "grey40", linewidth = 0.15) +
  scale_fill_manual(
    name = "Exposure Archetype",
    values = palette_clusters,
    labels = paste("Type", 1:best_k)
  ) +
  coord_sf(crs = 3035, xlim = win_ext[c("xmin","xmax")],
           ylim = win_ext[c("ymin","ymax")], expand = FALSE) +
  annotation_scale(location = "bl", width_hint = 0.22, text_col = ink, line_col = ink) +
  labs(
    title = "Profile 1: Sensory & Bodily Burden Archetypes across Europe",
    subtitle = paste0("Spatial Clustering (K-Means, k=", best_k, ") of Built Footprint, Light, Air Pollution & Heat Stress"),
    caption = "Data: WSF3D, Falchi et al. (2016), CAMS PM2.5 (2024), ERA5-Land UTCI (2022). Resampled to 3 km LAEA Europe (EPSG:3035)."
  ) +
  theme_void(base_size = 12) +
  theme(
    plot.background  = element_rect(fill = "white", colour = NA),
    panel.background = element_rect(fill = "grey95", colour = NA),
    plot.title       = element_text(face = "bold", size = 14, colour = "black"),
    plot.subtitle    = element_text(colour = "grey30", margin = margin(b = 6), size = 10),
    plot.caption     = element_text(colour = "grey50", size = 7, hjust = 0),
    legend.position  = "right",
    plot.margin      = margin(6, 6, 6, 6)
  )

# 6. EXPORT MAP ----------------------------------------------------------------
agg_png(file.path(out_maps, "profile1_sensory_bodily_burden_europe.png"),
        width = 9.2, height = 8.4, units = "in", res = 300)
print(p_map)
invisible(dev.off())
message("Wrote ", file.path(out_maps, "profile1_sensory_bodily_burden_europe.png"))

# 7. BUILD CLUSTER PROFILES BARPLOT --------------------------------------------
df_long <- data.frame(
  cluster = rep(profiles$cluster, 4),
  variable = rep(c("built_fraction", "light_pollution", "pm25", "utci_heatstress"), each = nrow(profiles)),
  value = c(profiles$built_fraction, profiles$light_pollution, profiles$pm25, profiles$utci_heatstress)
)
df_long$variable_name <- factor(df_long$variable, 
                                labels = c("Built Fraction (%)", "Light Pollution (mcd/m²)", 
                                           "PM2.5 (µg/m³)", "UTCI Heat Stress (Hours/yr)"))

p_profile <- ggplot(df_long, aes(x = cluster, y = value, fill = cluster)) +
  geom_col(show.legend = FALSE) +
  facet_wrap(~variable_name, scales = "free_y", ncol = 2) +
  scale_fill_manual(values = palette_clusters) +
  labs(
    title = "Profile 1: Characteristics of Sensory & Bodily Burden Archetypes",
    subtitle = "Mean attribute values per cluster",
    x = "Exposure Archetype",
    y = "Mean Value"
  ) +
  theme_minimal(base_size = 11) +
  theme(
    plot.title = element_text(face = "bold"),
    strip.text = element_text(face = "bold")
  )

agg_png(file.path(out_maps, "profile1_cluster_summary.png"),
        width = 9.0, height = 6.0, units = "in", res = 300)
print(p_profile)
invisible(dev.off())
message("Wrote ", file.path(out_maps, "profile1_cluster_summary.png"))
