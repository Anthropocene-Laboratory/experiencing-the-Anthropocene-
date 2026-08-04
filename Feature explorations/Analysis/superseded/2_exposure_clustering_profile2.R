# =============================================================================
# 2_exposure_clustering_profile2.R
# Profile 2: Techno-Ecological Disconnection (Déconnexion techno-écologique)
#
# Combines 4 Layer A/B features across Biosphere, Technosphere & Social Org:
#   1. Land-Use Change Frequency (HILDA+ 1960-2019, Biosphere A1)
#   2. Built Footprint Fraction (% surface, Technosphere A2)
#   3. Light Pollution (Artificial Sky Brightness mcd/m2, Technosphere A2)
#   4. Population Density (Habitants/km2, Social Organization A3)
#
# RUN FROM WORKSPACE ROOT:
#   Rscript "Feature explorations/Analysis/2_exposure_clustering_profile2.R"
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
f_hilda <- "Feature explorations/Biosphere/data_processed/hilda_change_freq_10km_mean.tif"
f_built <- "Feature explorations/Technosphere/data_processed/eu_fraction_wsf3d_3km.tif"
f_light <- "Feature explorations/Technosphere/data_processed/eu_light_pollution_3km.tif"
f_pop   <- "Feature explorations/Heatwaves/data_processed/pop1991_0p1deg.tif"

r_built <- rast(f_built)
r_light <- rast(f_light)
r_hilda <- rast(f_hilda)
r_pop   <- rast(f_pop)

# Reproject EPSG:4326 rasters (HILDA & Population) and resample all to 3km LAEA Europe grid
r_hilda_3035 <- project(r_hilda, r_built, method = "bilinear")
r_pop_3035   <- project(r_pop, r_built, method = "bilinear")
r_light_res  <- resample(r_light, r_built, method = "bilinear")

stk <- c(r_hilda_3035, r_built, r_light_res, r_pop_3035)
names(stk) <- c("land_change", "built_fraction", "light_pollution", "pop_density")

# 2. EXTRACT & STANDARDIZE DATA -----------------------------------------------
df <- as.data.frame(stk, xy = TRUE, na.rm = TRUE)

# Log transform highly skewed variables for numerical stability
df$hilda_val <- df$land_change
df$built_log <- log1p(df$built_fraction)
df$light_log <- log1p(pmax(0, df$light_pollution))
df$pop_log   <- log1p(pmax(0, df$pop_density))

# Z-score normalization across all 4 variables
df_scaled <- scale(df[, c("hilda_val", "built_log", "light_log", "pop_log")])

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
profiles <- aggregate(cbind(land_change, built_fraction, light_pollution, pop_density) ~ cluster, data = df, FUN = mean)
print(profiles)

# 4. SPATIAL SMOOTHING & CONTEXT BORDERS ----------------------------------------
# Convert cluster vector back to raster for spatial modal filtering (removes noise)
r_clust <- r_built
values(r_clust) <- NA
r_clust[cellFromXY(r_clust, as.matrix(df[, c("x", "y")]))] <- as.numeric(df$cluster)

# 3x3 Focal Modal Filter to create clean, continuous geographical regions
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
# Nature Methods / Okabe-Ito Gold Standard Qualitative Palette
palette_clusters <- c("1" = "#009E73", "2" = "#E69F00", "3" = "#0072B2", "4" = "#D55E00")
cluster_labels   <- c("1" = "1. Natural / Stable Wild", 
                      "2" = "2. Rural Agricultural", 
                      "3" = "3. Dense Urban Core", 
                      "4" = "4. Land Transformation Zone")

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
    title = "Profile 2: Techno-Ecological Disconnection Archetypes across Europe",
    subtitle = paste0("Spatial Clustering (K-Means + Focal Smoothing, k=", best_k, ") of Land-Use, Built Footprint & Light"),
    caption = "Data: HILDA+ (1960-2019), WSF3D, Falchi et al. (2016), Population Density. Resampled to 3 km LAEA Europe (EPSG:3035)."
  ) +
  theme_void(base_size = 12) +
  theme(
    plot.background  = element_rect(fill = "white", colour = NA),
    panel.background = element_rect(fill = "#dceeff", colour = NA), # Professional ocean blue
    plot.title       = element_text(face = "bold", size = 14, colour = "black"),
    plot.subtitle    = element_text(colour = "grey30", margin = margin(b = 6), size = 10),
    plot.caption     = element_text(colour = "grey50", size = 7, hjust = 0),
    legend.position  = "right",
    legend.title     = element_text(face = "bold"),
    plot.margin      = margin(6, 6, 6, 6)
  )

# 6. EXPORT MAP ----------------------------------------------------------------
agg_png(file.path(out_maps, "profile2_techno_ecological_disconnection_europe.png"),
        width = 9.2, height = 8.4, units = "in", res = 300)
print(p_map)
invisible(dev.off())
message("Wrote ", file.path(out_maps, "profile2_techno_ecological_disconnection_europe.png"))

# 7. BUILD CLUSTER PROFILES BARPLOT --------------------------------------------
df_long <- data.frame(
  cluster = rep(profiles$cluster, 4),
  variable = rep(c("land_change", "built_fraction", "light_pollution", "pop_density"), each = nrow(profiles)),
  value = c(profiles$land_change, profiles$built_fraction, profiles$light_pollution, profiles$pop_density)
)
df_long$variable_name <- factor(df_long$variable, 
                                labels = c("Land-Use Change Freq (1960-2019)", "Built Fraction (%)", 
                                           "Light Pollution (mcd/m²)", "Population Density (hab/cell)"))

p_profile <- ggplot(df_long, aes(x = cluster, y = value, fill = cluster)) +
  geom_col(show.legend = FALSE) +
  facet_wrap(~variable_name, scales = "free_y", ncol = 2) +
  scale_fill_manual(values = palette_clusters) +
  scale_x_discrete(labels = c("1" = "Natural", "2" = "Rural", "3" = "Urban", "4" = "Land Transf.")) +
  labs(
    title = "Profile 2: Characteristics of Techno-Ecological Disconnection Archetypes",
    subtitle = "Mean attribute values per cluster",
    x = "Exposure Archetype",
    y = "Mean Value"
  ) +
  theme_minimal(base_size = 11) +
  theme(
    plot.title = element_text(face = "bold"),
    strip.text = element_text(face = "bold")
  )

agg_png(file.path(out_maps, "profile2_cluster_summary.png"),
        width = 9.0, height = 6.0, units = "in", res = 300)
print(p_profile)
invisible(dev.off())
message("Wrote ", file.path(out_maps, "profile2_cluster_summary.png"))
