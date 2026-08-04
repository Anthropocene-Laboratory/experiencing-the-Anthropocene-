# =============================================================================
# 3_exposure_clustering_profile3_corrected.R
#
# Corrected exploratory Layer-A exposure-interface typology for Europe.
# This script leaves original files untouched. It corrects false 3-km precision,
# UTCI-band mismatch, post-hoc smoothing, hard-coded labels and unit labelling.
# It is non-spatial K-means: similar profiles, not contiguous regions nor
# vulnerability classes.
# =============================================================================

suppressPackageStartupMessages({
  library(sf); library(terra); library(ggplot2); library(ggspatial)
  library(cluster); library(ragg)
})

root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
inputs <- c(
  utci = "Feature explorations/Heatwaves/data_processed/utci_heatstress_hours_2022.nc",
  crop = "Feature explorations/Heatwaves/data_processed/crop_frac_0p1deg.tif",
  pm25 = "Feature explorations/Air quality/data_processed/cams_pm25_2024_annual_3km_3035.tif",
  built = "Feature explorations/Technosphere/data_processed/eu_fraction_wsf3d_3km.tif",
  cntr = "Feature explorations/_shared/CNTR_RG_10M_2024_4326.geojson"
)
if (!all(file.exists(file.path(root, inputs)))) stop("Run from the workspace root; required input missing.")

out_dir <- file.path(root, "Feature explorations/Analysis/data_processed")
out_maps <- file.path(out_dir, "maps")
dir.create(out_maps, recursive = TRUE, showWarnings = FALSE)
outputs <- c(
  file.path(out_maps, "profile3_corrected_exposure_typology_europe_30km.png"),
  file.path(out_maps, "profile3_corrected_cluster_profiles_30km.png"),
  file.path(out_maps, "profile3_corrected_k_diagnostics_30km.png"),
  file.path(out_dir, "profile3_corrected_cluster_labels_30km.tif"),
  file.path(out_dir, "profile3_corrected_cluster_profiles_30km.csv"),
  file.path(out_dir, "profile3_corrected_k_diagnostics_30km.csv")
)
if (any(file.exists(outputs))) stop("Corrected outputs exist and will not be overwritten.")

# 1. COMMON SUPPORT ------------------------------------------------------------
# UTCI is 0.25 degree (~27.8 km N-S), so no source is analysed at invented 3 km.
GRID_M <- 30000
YEAR_UTCI <- 2022L
YEAR_PM25 <- 2024L
MIN_UTCI_COVERAGE <- 0.95 * 8760

r_utci_all <- rast(file.path(root, inputs[["utci"]]))
if (!all(c("hours_strong", "hours_valid") %in% names(r_utci_all))) {
  stop("UTCI input must contain hours_strong and hours_valid.")
}
r_heat <- r_utci_all[["hours_strong"]] # documented primary feature: UTCI >=32 C
r_valid <- r_utci_all[["hours_valid"]]
r_crop <- rast(file.path(root, inputs[["crop"]]))
r_pm25 <- rast(file.path(root, inputs[["pm25"]]))
r_built <- rast(file.path(root, inputs[["built"]]))

r_heat_3035 <- project(r_heat, "EPSG:3035", res = GRID_M, method = "average")
template <- rast(ext(r_heat_3035), resolution = GRID_M, crs = "EPSG:3035")

# Inputs are continuous intensities/fractions; averaging preserves areal means.
r_heat_30 <- project(r_heat, template, method = "average")
r_valid_30 <- project(r_valid, template, method = "average")
r_crop_30 <- project(r_crop, template, method = "average")
r_pm25_30 <- project(r_pm25, template, method = "average")
r_built_30 <- project(r_built, template, method = "average")

# Explicit study mask: GISCO EU/EFTA/candidate domain plus UK, Kosovo, European
# microstates and Belarus/Russia. The input UTCI extent limits availability.
countries <- st_read(file.path(root, inputs[["cntr"]]), quiet = TRUE)
europe_ids <- unique(c(
  countries$CNTR_ID[countries$EU_STAT == "T" | countries$EFTA_STAT == "T" | countries$CC_STAT == "T"],
  "UK", "XK", "AD", "BY", "MC", "MD", "RU", "SM", "VA", "FO", "GI"
))
europe_land <- countries[countries$CNTR_ID %in% europe_ids, ] |>
  st_make_valid() |>
  st_transform("EPSG:3035")

stk <- c(r_heat_30, r_crop_30, r_pm25_30, r_built_30)
names(stk) <- c("utci_strong_hours", "cropland_fraction", "pm25_annual_ug_m3", "built_fraction_pct")
stk <- mask(stk, vect(europe_land))

# Do not silently count unavailable UTCI hours as zero heat stress.
coverage_ok <- mask(r_valid_30 >= MIN_UTCI_COVERAGE, vect(europe_land))
stk <- mask(stk, coverage_ok, maskvalues = 0)
df <- as.data.frame(stk, cells = TRUE, xy = TRUE, na.rm = TRUE)
if (nrow(df) < 100) stop("Fewer than 100 complete 30-km cells remain.")

# 2. FIT AND DIAGNOSE K-MEANS --------------------------------------------------
# Transform skew before standardised Euclidean distance. Reporting stays in
# original units, below.
df$x_heat <- log1p(df$utci_strong_hours)
df$x_crop <- asin(sqrt(pmin(pmax(df$cropland_fraction, 0), 1)))
df$x_pm25 <- log(df$pm25_annual_ug_m3)
df$x_built <- log1p(df$built_fraction_pct)
x <- scale(df[, c("x_heat", "x_crop", "x_pm25", "x_built")])

set.seed(20260728)
n_sil <- min(5000L, nrow(x))
x_sil <- x[sample.int(nrow(x), n_sil), , drop = FALSE]
k_values <- 2:6
diagnostics <- do.call(rbind, lapply(k_values, function(k) {
  fit <- kmeans(x_sil, centers = k, nstart = 100, iter.max = 100)
  ss <- silhouette(fit$cluster, dist(x_sil))
  data.frame(k = k, mean_silhouette = mean(ss[, "sil_width"]), withinss = fit$tot.withinss)
}))
best_k <- diagnostics$k[which.max(diagnostics$mean_silhouette)]
set.seed(20260728)
km <- kmeans(x, centers = best_k, nstart = 100, iter.max = 100)

# Stable display IDs, without changing the fitted solution.
raw_by_cluster <- stats::aggregate(
  df[, c("utci_strong_hours", "cropland_fraction", "pm25_annual_ug_m3", "built_fraction_pct")],
  by = list(km_cluster = km$cluster), FUN = mean
)
centre_order <- raw_by_cluster$km_cluster[order(
  raw_by_cluster$utci_strong_hours, raw_by_cluster$pm25_annual_ug_m3,
  raw_by_cluster$cropland_fraction, raw_by_cluster$built_fraction_pct
)]
df$profile_id <- match(km$cluster, centre_order)
profiles <- stats::aggregate(
  df[, c("utci_strong_hours", "cropland_fraction", "pm25_annual_ug_m3", "built_fraction_pct")],
  by = list(profile_id = df$profile_id), FUN = mean
)
profiles$cropland_percent <- 100 * profiles$cropland_fraction
profiles$raw_kmeans_cluster <- centre_order[profiles$profile_id]

# Data-derived labels: no unsupported labels such as "coastal density".
z_profiles <- scale(profiles[, c("utci_strong_hours", "cropland_fraction", "pm25_annual_ug_m3", "built_fraction_pct")])
level_word <- function(z) ifelse(z >= .40, "high", ifelse(z <= -.40, "low", "mid"))
feature_words <- c("strong heat", "cropland", "PM2.5", "built share")
profile_labels <- vapply(seq_len(nrow(profiles)), function(i) {
  paste0("P", profiles$profile_id[i], ": ", paste(paste(level_word(z_profiles[i, ]), feature_words), collapse = "; "))
}, character(1))
names(profile_labels) <- as.character(profiles$profile_id)
profiles$profile_label <- profile_labels[as.character(profiles$profile_id)]
profiles$utci_definition <- sprintf("Hours in %d with UTCI >=32 C", YEAR_UTCI)
profiles$pm25_definition <- sprintf("Annual PM2.5 mean (%d; ug/m3)", YEAR_PM25)
profiles$grid_support <- sprintf("%d-km equal-area grid", GRID_M / 1000)
profiles$coverage_rule <- sprintf("UTCI valid hours >= %.0f", MIN_UTCI_COVERAGE)
write.csv(profiles, file.path(out_dir, "profile3_corrected_cluster_profiles_30km.csv"), row.names = FALSE)

diagnostics$selected <- diagnostics$k == best_k
diagnostics$n_complete_cells <- nrow(df)
diagnostics$n_silhouette_sample <- n_sil
write.csv(diagnostics, file.path(out_dir, "profile3_corrected_k_diagnostics_30km.csv"), row.names = FALSE)

# 3. MAP FITTED ASSIGNMENTS: NO FOCAL SMOOTHING --------------------------------
r_clusters <- rast(template)
values(r_clusters) <- NA_integer_
r_clusters[df$cell] <- df$profile_id
names(r_clusters) <- "profile_id"
writeRaster(r_clusters, file.path(out_dir, "profile3_corrected_cluster_labels_30km.tif"), datatype = "INT1U")
map_df <- as.data.frame(r_clusters, xy = TRUE, na.rm = TRUE)
names(map_df)[3] <- "profile_id"
map_df$profile_id <- factor(map_df$profile_id, levels = profiles$profile_id)

window <- st_as_sfc(st_bbox(ext(template), crs = st_crs(3035)))
borders <- st_crop(europe_land, window)
palette <- c("#0072B2", "#E69F00", "#009E73", "#CC79A7", "#D55E00", "#56B4E9")[seq_len(best_k)]
names(palette) <- as.character(profiles$profile_id)
sil_peak <- diagnostics$mean_silhouette[diagnostics$k == best_k]
sil_note <- if (sil_peak < .25) "Low separation: descriptive segmentation, not natural regions." else "Exploratory segmentation; silhouettes support relative, not categorical, separation."

p_map <- ggplot() +
  geom_raster(data = map_df, aes(x, y, fill = profile_id)) +
  geom_sf(data = borders, fill = NA, colour = "grey30", linewidth = .2) +
  scale_fill_manual(name = "Data-derived profiles", values = palette, labels = profile_labels, drop = FALSE) +
  coord_sf(crs = 3035, xlim = c(xmin(template), xmax(template)), ylim = c(ymin(template), ymax(template)), expand = FALSE) +
  annotation_scale(location = "bl", width_hint = .20, text_col = "grey20", line_col = "grey20") +
  labs(
    title = "Profile 3 (corrected): Layer-A exposure-interface typology",
    subtitle = sprintf("K-means of strong UTCI heat, cropland landscape, PM2.5 and built share; %d-km equal-area support; k = %d", GRID_M / 1000, best_k),
    caption = paste0("Inputs: ERA5-HEAT UTCI strong heat (hours >=32 C, 2022), cropland fraction, CAMS PM2.5 annual mean (2024), WSF3D building fraction. ",
      "All continuous layers aggregated to 30 km in EPSG:3035; UTCI coverage >=95%. ", sil_note, "\n",
      "Classes are fitted assignments, not smoothed regionalisation; colours/numbers do not imply vulnerability. Borders: Eurostat GISCO.")
  ) +
  theme_void(base_size = 11) + theme(
    plot.background = element_rect(fill = "white", colour = NA), panel.background = element_rect(fill = "#DCEEFF", colour = NA),
    plot.title = element_text(face = "bold", size = 14), plot.subtitle = element_text(colour = "grey25", margin = margin(b = 6)),
    plot.caption = element_text(colour = "grey40", size = 7, hjust = 0), legend.position = "right",
    legend.title = element_text(face = "bold"), legend.key.height = grid::unit(.6, "cm"), plot.margin = margin(6, 6, 6, 6)
  )
agg_png(file.path(out_maps, "profile3_corrected_exposure_typology_europe_30km.png"), width = 11, height = 8.4, units = "in", res = 300)
print(p_map); invisible(dev.off())

# Correct unit reporting: cropland source is 0--1, WSF3D is already percent.
profile_long <- rbind(
  data.frame(profile_id = profiles$profile_id, variable = "Strong UTCI heat\n(hours/year >=32 C)", value = profiles$utci_strong_hours),
  data.frame(profile_id = profiles$profile_id, variable = "Cropland landscape\n(% of cell)", value = profiles$cropland_percent),
  data.frame(profile_id = profiles$profile_id, variable = "PM2.5 annual mean\n(ug/m3)", value = profiles$pm25_annual_ug_m3),
  data.frame(profile_id = profiles$profile_id, variable = "Built footprint\n(% of cell)", value = profiles$built_fraction_pct)
)
profile_long$profile_id <- factor(profile_long$profile_id, levels = profiles$profile_id)
p_profiles <- ggplot(profile_long, aes(profile_id, value, fill = profile_id)) +
  geom_col(show.legend = FALSE) + facet_wrap(~variable, scales = "free_y", ncol = 2) +
  scale_fill_manual(values = palette) +
  labs(title = "Corrected Profile 3: cluster means in original units",
       subtitle = sprintf("%d-km equal-area cells; labels are derived from fitted centres", GRID_M / 1000), x = "Profile", y = "Mean") +
  theme_minimal(base_size = 11) + theme(plot.title = element_text(face = "bold"), strip.text = element_text(face = "bold"))
agg_png(file.path(out_maps, "profile3_corrected_cluster_profiles_30km.png"), width = 9.2, height = 6.2, units = "in", res = 300)
print(p_profiles); invisible(dev.off())

p_diag <- ggplot(diagnostics, aes(factor(k), mean_silhouette, fill = selected)) +
  geom_col(show.legend = FALSE) + geom_hline(yintercept = .25, linetype = "dashed", colour = "grey40") +
  scale_fill_manual(values = c("FALSE" = "grey75", "TRUE" = "#0072B2")) +
  labs(title = "K-selection diagnostic (corrected Profile 3)",
       subtitle = sprintf("Mean silhouette on a fixed random sample of %s equal-area cells", format(n_sil, big.mark = ",")),
       x = "Number of clusters (k)", y = "Mean silhouette width",
       caption = "Dashed line (0.25) is a cautious interpretive threshold, not a formal test.") +
  theme_minimal(base_size = 11) + theme(plot.title = element_text(face = "bold"))
agg_png(file.path(out_maps, "profile3_corrected_k_diagnostics_30km.png"), width = 7.4, height = 4.8, units = "in", res = 300)
print(p_diag); invisible(dev.off())

message("Corrected Profile 3 complete. k = ", best_k, "; mean silhouette = ", round(sil_peak, 3), "; complete 30-km cells = ", nrow(df))

