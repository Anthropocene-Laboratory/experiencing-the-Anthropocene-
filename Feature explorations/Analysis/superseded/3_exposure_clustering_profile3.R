# =============================================================================
# 3_exposure_clustering_profile3.R
# Profile 3: Resource & Climate Vulnerability (Vulnérabilité & Dépendance matérielle)
#
# Combines 4 Layer A features across Climate, Agriculture & Infrastructure:
#   1. UTCI Thermal Stress (Annual hours >= 26°C, Biosphere A1)
#   2. Cropland Fraction (% surface, Social Org A3 / Agriculture)
#   3. Air Pollution (PM2.5 annual mean ug/m3, Biosphere A1)
#   4. Built Footprint Fraction (% surface, Technosphere A2)
#
# RUN FROM WORKSPACE ROOT:
#   Rscript "Feature explorations/Analysis/3_exposure_clustering_profile3.R"
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
f_utci  <- "Feature explorations/Heatwaves/data_processed/utci_heatstress_hours_2022.nc"
f_crop  <- "Feature explorations/Heatwaves/data_processed/crop_frac_0p1deg.tif"
f_pm25  <- "Feature explorations/Air quality/data_processed/cams_pm25_2024_annual_3km_3035.tif"
f_built <- "Feature explorations/Technosphere/data_processed/eu_fraction_wsf3d_3km.tif"

r_built <- rast(f_built)
r_pm25  <- rast(f_pm25)
r_crop  <- rast(f_crop)
r_utci_nc  <- rast(f_utci)
r_utci_raw <- r_utci_nc[["hours_moderate"]] + r_utci_nc[["hours_strong"]]

# Reproject EPSG:4326 rasters to 3km LAEA Europe grid
r_utci_3035 <- project(r_utci_raw, r_built, method = "bilinear")
r_crop_3035 <- project(r_crop, r_built, method = "bilinear")
r_pm25_res  <- resample(r_pm25, r_built, method = "bilinear")

stk <- c(r_utci_3035, r_crop_3035, r_pm25_res, r_built)
names(stk) <- c("utci_heatstress", "crop_fraction", "pm25", "built_fraction")

# 2. EXTRACT & STANDARDIZE DATA -----------------------------------------------
df <- as.data.frame(stk, xy = TRUE, na.rm = TRUE)

# Log transform skewed variables
df$utci_val  <- log1p(pmax(0, df$utci_heatstress))
df$crop_val  <- df$crop_fraction
df$pm25_val  <- df$pm25
df$built_log <- log1p(df$built_fraction)

# Z-score normalization
df_scaled <- scale(df[, c("utci_val", "crop_val", "pm25_val", "built_log")])

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
profiles <- aggregate(cbind(utci_heatstress, crop_fraction, pm25, built_fraction) ~ cluster, data = df, FUN = mean)
print(profiles)

# 4. SPATIAL MODAL FILTERING & CONTEXT BORDERS --------------------------------
r_clust <- r_built
values(r_clust) <- NA
r_clust[cellFromXY(r_clust, as.matrix(df[, c("x", "y")]))] <- as.numeric(df$cluster)

# 3x3 Focal Modal Filter for smooth continuous regions
r_smooth <- focal(r_clust, w = matrix(1, 3, 3), fun = "modal", na.rm = TRUE)

df_smooth <- as.data.frame(r_smooth, xy = TRUE, na.rm = TRUE)
colnames(df_smooth)[3] <- "cluster"
df_smooth$cluster <- factor(df_smooth$cluster)

win_ext <- c(xmin = 2.5e6, xmax = 6e6, ymin = 1.5e6, ymax = 5.5e6)
win <- st_as_sfc(st_bbox(c(win_ext), crs = 3035))
borders <- st_read(file.path(shared, "CNTR_RG_10M_2024_4326.geojson"), quiet = TRUE) |>
  st_transform(3035) |> st_make_valid() |> st_crop(win)

# 5. BUILD CLUSTER MAP ---------------------------------------------------------
ink <- "grey20"
# Nature Methods / Okabe-Ito Palette
palette_clusters <- c("1" = "#009E73", "2" = "#E69F00", "3" = "#0072B2")
cluster_labels   <- c("1" = "1. Intensive Agricultural Plain (High PM2.5 & Crop)", 
                      "2" = "2. Boreal / Alpine Cool Low-Strain Zone", 
                      "3" = "3. Southern Thermal Strain & Coastal Density")

p_map <- ggplot() +
  geom_raster(data = df_smooth, aes(x, y, fill = cluster)) +
  geom_sf(data = borders, fill = NA, colour = "grey35", linewidth = 0.2) +
  scale_fill_manual(
    name = "Exposure Archetype",
    values = palette_clusters,
    labels = cluster_labels,
    na.value = "transparent"
  ) +
  coord_sf(crs = 3035, xlim = win_ext[c("xmin","xmax")],
           ylim = win_ext[c("ymin","ymax")], expand = FALSE) +
  annotation_scale(location = "bl", width_hint = 0.22, text_col = ink, line_col = ink) +
  labs(
    title = "Profile 3: Resource & Climate Vulnerability Archetypes across Europe",
    subtitle = paste0("Spatial Clustering (K-Means + Focal Smoothing, k=", best_k, ") of Heat Stress, Cropland, PM2.5 & Built Footprint"),
    caption = "Data: ERA5-Land UTCI (2022), Cropland Fraction, CAMS PM2.5 (2024), WSF3D. Resampled to 3 km LAEA Europe (EPSG:3035)."
  ) +
  theme_void(base_size = 12) +
  theme(
    plot.background  = element_rect(fill = "white", colour = NA),
    panel.background = element_rect(fill = "#dceeff", colour = NA),
    plot.title       = element_text(face = "bold", size = 14, colour = "black"),
    plot.subtitle    = element_text(colour = "grey30", margin = margin(b = 6), size = 10),
    plot.caption     = element_text(colour = "grey50", size = 7, hjust = 0),
    legend.position  = "right",
    legend.title     = element_text(face = "bold"),
    plot.margin      = margin(6, 6, 6, 6)
  )

# 6. EXPORT MAP ----------------------------------------------------------------
agg_png(file.path(out_maps, "profile3_resource_climate_vulnerability_europe.png"),
        width = 9.2, height = 8.4, units = "in", res = 300)
print(p_map)
invisible(dev.off())
message("Wrote ", file.path(out_maps, "profile3_resource_climate_vulnerability_europe.png"))

# 7. BUILD CLUSTER PROFILES BARPLOT --------------------------------------------
df_long <- data.frame(
  cluster = rep(profiles$cluster, 4),
  variable = rep(c("utci_heatstress", "crop_fraction", "pm25", "built_fraction"), each = nrow(profiles)),
  value = c(profiles$utci_heatstress, profiles$crop_fraction, profiles$pm25, profiles$built_fraction)
)
df_long$variable_name <- factor(df_long$variable, 
                                labels = c("UTCI Heat Stress (Hours/yr)", "Cropland Fraction (%)", 
                                           "PM2.5 (µg/m³)", "Built Fraction (%)"))

p_profile <- ggplot(df_long, aes(x = cluster, y = value, fill = cluster)) +
  geom_col(show.legend = FALSE) +
  facet_wrap(~variable_name, scales = "free_y", ncol = 2) +
  scale_fill_manual(values = palette_clusters) +
  scale_x_discrete(labels = c("1" = "Agri-Plain", "2" = "Boreal/Cool", "3" = "South Thermal")) +
  labs(
    title = "Profile 3: Characteristics of Resource & Climate Vulnerability Archetypes",
    subtitle = "Mean attribute values per cluster",
    x = "Exposure Archetype",
    y = "Mean Value"
  ) +
  theme_minimal(base_size = 11) +
  theme(
    plot.title = element_text(face = "bold"),
    strip.text = element_text(face = "bold")
  )

agg_png(file.path(out_maps, "profile3_cluster_summary.png"),
        width = 9.0, height = 6.0, units = "in", res = 300)
print(p_profile)
invisible(dev.off())
message("Wrote ", file.path(out_maps, "profile3_cluster_summary.png"))
