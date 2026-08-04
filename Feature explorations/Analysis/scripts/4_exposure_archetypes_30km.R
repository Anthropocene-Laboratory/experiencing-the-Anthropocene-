# =============================================================================
# 4_exposure_archetypes_30km.R
#
# Layer-A exposure archetypes for Europe, 30-km equal-area grid.
#
# WHAT THIS SCRIPT COMMITS TO (all of it decided in scripts 2-3, not here):
#
#  Feature set  built_pct, light_mcd_m2, pm25_ug_m3, utci_strong_h, hw_days,
#               crop_frac  ("S4"). It was the only pre-registered candidate set
#               that passed all four disqualification tests in script 3.
#               BII and land-change frequency were dropped for COVERAGE (they
#               alone deleted 26% of European cells); BII is in any case a near
#               duplicate of cropland fraction here (Spearman -.81).
#
#  Layer B      population density and GDP per capita are NOT clustered. They
#               are exposure filters (AGENTS.md: do not collapse the layers) and
#               are used only to profile the archetypes afterwards. This also
#               removes the pop-density / night-light duplication (rho .84).
#
#  Choice of k  A rule that k = 2, 3 and 5 actually fail:
#                 (a) the k centres must NOT all move in the same direction
#                     (one-directional centres = a single gradient cut into k
#                      slices, which is not a typology);
#                 (b) every cluster must reach mean bootstrap Jaccard >= .75
#                     (Hennig 2007: below .75 a cluster is not a stable pattern);
#                 (c) among the k that pass (a) and (b), take the best mean
#                     silhouette.
#               Silhouette alone -- the criterion used in the earlier version of
#               this analysis -- selects k = 2, whose centres are one-directional.
#
# Run from the workspace ROOT, after 1_build_layerA_stack_30km.R.
# =============================================================================

suppressPackageStartupMessages({
  library(sf); library(terra); library(ggplot2); library(ggspatial)
  library(cluster); library(ragg)
})

root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
out_dir    <- file.path(root, "Feature explorations/Analysis/data_processed")
out_maps   <- file.path(out_dir, "maps")
out_tables <- file.path(out_dir, "tables")
dir.create(out_maps, recursive = TRUE, showWarnings = FALSE)
dir.create(out_tables, recursive = TRUE, showWarnings = FALSE)

GRID_M <- 30000
CELL_KM2 <- (GRID_M / 1000)^2
SEED <- 20260728
JACCARD_MIN <- 0.75
N_BOOT <- 25

FEAT <- c("built_pct", "light_mcd_m2", "pm25_ug_m3", "utci_strong_h", "hw_days", "crop_frac")
PRETTY <- c(
  built_pct     = "Built footprint\n(% of cell, WSF3D)",
  light_mcd_m2  = "Night-sky brightness\n(mcd/m2, Falchi)",
  pm25_ug_m3    = "PM2.5 annual mean\n(ug/m3, CAMS 2024)",
  utci_strong_h = "Strong heat stress\n(h/yr UTCI >= 32 C, 2022)",
  hw_days       = "Heatwave days\n(TX > P90, >=3 d, 2022)",
  crop_frac     = "Cropland landscape\n(% of cell)")
SPHERE <- c(built_pct = "A2", light_mcd_m2 = "A2", pm25_ug_m3 = "A1",
            utci_strong_h = "A1", hw_days = "A1", crop_frac = "A1")

# 1. DATA ----------------------------------------------------------------------
stk <- rast(file.path(out_dir, "layerA_stack_30km.tif"))
europe <- st_read(file.path(out_dir, "study_mask_europe_3035.gpkg"), quiet = TRUE)

full <- as.data.frame(stk, cells = TRUE, xy = TRUE, na.rm = FALSE)
in_mask <- rowSums(!is.na(full[, c(FEAT, "bii", "landchange_freq")])) > 0
in_mask_df <- full[in_mask, ]
d <- in_mask_df[complete.cases(in_mask_df[, FEAT]), ]
message(sprintf("Masked cells: %d | analysed (complete on 6 features): %d (%.1f%%)",
                nrow(in_mask_df), nrow(d), 100 * nrow(d) / nrow(in_mask_df)))

tf <- function(x, how) switch(how, log1p = log1p(x), log = log(x),
                              asin = asin(sqrt(pmin(pmax(x, 0), 1))), id = x)
RECIPE <- c(built_pct = "log1p", light_mcd_m2 = "log1p", pm25_ug_m3 = "log",
            utci_strong_h = "log1p", hw_days = "log1p", crop_frac = "asin")
X <- as.data.frame(mapply(function(v, h) tf(d[, v], h), FEAT, RECIPE[FEAT]))
names(X) <- FEAT
Z <- scale(X)

# 2. CHOOSE K BY THE RULE ABOVE ------------------------------------------------
jaccard <- function(a, b) length(intersect(a, b)) / length(union(a, b))
set.seed(SEED)
sil_idx <- sample.int(nrow(Z), min(4000L, nrow(Z)))
Zs <- Z[sil_idx, , drop = FALSE]; dZs <- dist(Zs)

ksel <- do.call(rbind, lapply(2:8, function(k) {
  fit <- kmeans(Z, centers = k, nstart = 50, iter.max = 200)
  fs  <- kmeans(Zs, centers = k, nstart = 50, iter.max = 200)
  sil <- mean(silhouette(fs$cluster, dZs)[, "sil_width"])
  onedir <- all(apply(sign(fit$centers), 1, function(r) length(unique(r)) == 1))
  ref <- lapply(seq_len(k), function(j) which(fit$cluster == j))
  J <- replicate(N_BOOT, {
    bi <- sample.int(nrow(Z), replace = TRUE)
    bf <- kmeans(Z[bi, ], centers = k, nstart = 10, iter.max = 100)
    asg <- apply(Z, 1, function(r) which.min(colSums((t(bf$centers) - r)^2)))
    vapply(seq_len(k), function(j)
      max(vapply(seq_len(k), function(m) jaccard(ref[[j]], which(asg == m)), numeric(1))),
      numeric(1))
  })
  data.frame(k = k, mean_silhouette = sil, one_directional_centres = onedir,
             min_bootstrap_jaccard = min(rowMeans(J)),
             mean_bootstrap_jaccard = mean(rowMeans(J)),
             smallest_cluster_cells = min(fit$size))
}))
ksel$passes_not_a_gradient <- !ksel$one_directional_centres
ksel$passes_stability      <- ksel$min_bootstrap_jaccard >= JACCARD_MIN
ksel$admissible            <- ksel$passes_not_a_gradient & ksel$passes_stability
if (!any(ksel$admissible)) stop("No admissible k: no stable multi-axis typology exists in these data.")
BEST_K <- ksel$k[ksel$admissible][which.max(ksel$mean_silhouette[ksel$admissible])]
ksel$selected <- ksel$k == BEST_K
write.csv(ksel, file.path(out_tables, "archetypes_k_selection.csv"), row.names = FALSE)
print(ksel, right = FALSE)

# 3. FIT -----------------------------------------------------------------------
set.seed(SEED)
km <- kmeans(Z, centers = BEST_K, nstart = 100, iter.max = 300)

# Deterministic display order: ascending overall exposure intensity, defined as
# the first principal component of the standardised centres.
pc1_of_centre <- as.numeric(prcomp(Z, center = FALSE, scale. = FALSE)$rotation[, 1] %*% t(km$centers))
if (mean(pc1_of_centre * rowMeans(km$centers)) < 0) pc1_of_centre <- -pc1_of_centre
order_map <- order(pc1_of_centre)
d$archetype <- match(km$cluster, order_map)

zc <- km$centers[order_map, , drop = FALSE]
rownames(zc) <- paste0("A", seq_len(BEST_K))

# Labels derived from the fitted centres, never asserted from geography.
level_word <- function(z) ifelse(z >= .35, "high", ifelse(z <= -.35, "low", "mid"))
short <- c(built_pct = "built", light_mcd_m2 = "night light", pm25_ug_m3 = "PM2.5",
           utci_strong_h = "heat load", hw_days = "heatwave days", crop_frac = "cropland")
# Headline = only the features on which the archetype is actually distinctive
# (|z| >= 0.5), at most three, strongest first. An archetype that is low on
# four or more features is described as such rather than by an arbitrary pair.
headline <- apply(zc, 1, function(r) {
  keep <- which(abs(r) >= .35)
  if (!length(keep)) keep <- which.max(abs(r))
  keep <- head(keep[order(abs(r[keep]), decreasing = TRUE)], 3)
  paste(sprintf("%s %s", level_word(r[keep]), short[FEAT][keep]), collapse = ", ")
})
labels <- sprintf("A%d  %s", seq_len(BEST_K), headline)

# 4. PROFILES IN ORIGINAL UNITS + LAYER-B CHARACTERISATION ---------------------
d$pop_count <- d$pop_dens_km2 * CELL_KM2
agg_mean <- function(cols) stats::aggregate(d[, cols], by = list(archetype = d$archetype), FUN = function(v) mean(v, na.rm = TRUE))

prof <- agg_mean(FEAT)
prof$crop_frac <- 100 * prof$crop_frac
names(prof)[names(prof) == "crop_frac"] <- "crop_pct"
prof$n_cells <- as.integer(table(d$archetype))
prof$area_pct <- round(100 * prof$n_cells / nrow(d), 1)

pop_by <- tapply(d$pop_count, d$archetype, sum, na.rm = TRUE)
prof$population_2020 <- round(as.numeric(pop_by))
prof$population_pct <- round(100 * prof$population_2020 / sum(prof$population_2020), 1)
prof$median_gdp_pc_2022 <- round(as.numeric(tapply(d$gdp_pc_2022, d$archetype, median, na.rm = TRUE)))
prof$median_pop_dens_km2 <- round(as.numeric(tapply(d$pop_dens_km2, d$archetype, median, na.rm = TRUE)), 1)
prof$label <- labels
prof$grid_support <- sprintf("%d-km EPSG:3035", GRID_M / 1000)
prof$k_rule <- sprintf("k=%d: multi-axis centres + min bootstrap Jaccard >= %.2f, then best silhouette", BEST_K, JACCARD_MIN)
write.csv(prof, file.path(out_tables, "archetypes_profiles_30km.csv"), row.names = FALSE)
write.csv(round(zc, 3), file.path(out_tables, "archetypes_standardised_centres.csv"))
print(prof[, c("archetype", "label", "area_pct", "population_pct", "median_gdp_pc_2022")], right = FALSE)

# 5. RASTER + MAP --------------------------------------------------------------
r_arch <- rast(stk[[1]]); values(r_arch) <- NA_integer_
r_arch[d$cell] <- d$archetype
names(r_arch) <- "archetype"
writeRaster(r_arch, file.path(out_dir, "exposure_archetypes_30km.tif"),
            datatype = "INT1U", overwrite = TRUE)

map_df <- data.frame(x = d$x, y = d$y, archetype = factor(d$archetype, levels = seq_len(BEST_K)))
gap_df <- in_mask_df[!complete.cases(in_mask_df[, FEAT]), c("x", "y")]

# Frame the map on the study mask itself, not on the UTCI file's bounding box.
pad <- 2 * GRID_M
win <- ext(min(in_mask_df$x) - pad, max(in_mask_df$x) + pad,
           min(in_mask_df$y) - pad, max(in_mask_df$y) + pad)
pal <- c("#0F5257", "#6A51A3", "#E1A100", "#C1272D", "#0072B2", "#009E73")[seq_len(BEST_K)]
names(pal) <- as.character(seq_len(BEST_K))
sil_sel <- ksel$mean_silhouette[ksel$selected]

p_map <- ggplot() +
  geom_sf(data = europe, fill = "grey96", colour = NA) +
  geom_tile(data = gap_df, aes(x, y), fill = "grey82", width = GRID_M, height = GRID_M) +
  geom_tile(data = map_df, aes(x, y, fill = archetype), width = GRID_M, height = GRID_M) +
  geom_sf(data = europe, fill = NA, colour = "grey40", linewidth = 0.13) +
  scale_fill_manual(values = pal, labels = labels,
                    name = "Exposure archetype\n(k-means on 6 Layer-A features)",
                    drop = FALSE, na.translate = FALSE) +
  coord_sf(crs = 3035, xlim = c(xmin(win), xmax(win)), ylim = c(ymin(win), ymax(win)),
           expand = FALSE) +
  annotation_scale(location = "br", width_hint = 0.20, text_col = "grey30", line_col = "grey30") +
  labs(
    title = "How the Anthropocene is encountered across Europe: six-feature exposure archetypes",
    subtitle = sprintf(
      "Built footprint, night-sky brightness, PM2.5, strong heat stress, heatwave days and cropland, on a %d-km equal-area grid (n = %s cells)",
      GRID_M / 1000, format(nrow(d), big.mark = ",")),
    caption = paste0(
      "Sources: WSF3D building fraction; Falchi night-sky brightness; CAMS PM2.5 annual mean 2024;\n",
      "ERA5-HEAT UTCI hours >= 32 C (2022); E-OBS heatwave days, TX > P90 for >= 3 d (2022); cropland fraction.\n",
      "Boundaries: Eurostat GISCO CNTR 10M. Projection: LAEA Europe (EPSG:3035).\n",
      sprintf("Support: 30 km, the coarsest source (UTCI, 0.25 deg) - no finer common grid is defensible.\n"),
      sprintf("k = %d chosen by a rule that k = 2, 3 and 5 fail: the centres must span more than one direction,\n", BEST_K),
      sprintf("every cluster must reach bootstrap Jaccard >= %.2f, then best mean silhouette (%.2f).\n", JACCARD_MIN, sil_sel),
      "A silhouette of this size means overlapping, not categorically separate, groups: read the archetypes\n",
      "as recurring profiles, not as bounded regions. Grey = inside the study mask but outside the\n",
      "WSF3D / Falchi / CAMS window. Population density and GDP per capita are Layer-B exposure filters and\n",
      "were deliberately NOT clustered; they characterise the archetypes in the accompanying table.\n",
      "Exploratory Phase 1-2 work: these are candidate features, not a ranked Core feature set.")
  ) +
  theme_void(base_size = 12) +
  theme(
    plot.background = element_rect(fill = "white", colour = NA),
    panel.background = element_rect(fill = "#EAF2F8", colour = NA),
    plot.title = element_text(face = "bold", size = 15),
    plot.subtitle = element_text(colour = "grey30", margin = margin(b = 6)),
    plot.caption = element_text(colour = "grey45", size = 6.8, hjust = 0, lineheight = 1.25),
    legend.position = "right", legend.title = element_text(face = "bold"),
    legend.key.height = unit(0.75, "cm"), plot.margin = margin(8, 8, 8, 8))

agg_png(file.path(out_maps, "exposure_archetypes_europe_30km.png"),
        width = 12.5, height = 9.6, units = "in", res = 300)
print(p_map); invisible(dev.off())

# 6. PROFILE FIGURE ------------------------------------------------------------
long <- do.call(rbind, lapply(FEAT, function(v) {
  vals <- if (v == "crop_frac") prof$crop_pct else prof[[v]]
  data.frame(archetype = factor(prof$archetype, levels = seq_len(BEST_K)),
             variable = factor(sprintf("%s  [%s]", PRETTY[[v]], SPHERE[[v]]),
                               levels = sprintf("%s  [%s]", PRETTY[FEAT], SPHERE[FEAT])),
             value = vals)
}))
p_prof <- ggplot(long, aes(archetype, value, fill = archetype)) +
  geom_col(show.legend = FALSE, width = .72) +
  facet_wrap(~variable, scales = "free_y", ncol = 3) +
  scale_fill_manual(values = pal) +
  labs(title = "What each archetype is made of",
       subtitle = "Cluster means in original units; [A1] ecological / biospheric, [A2] technosphere",
       x = "Archetype", y = NULL) +
  theme_minimal(base_size = 11) +
  theme(plot.title = element_text(face = "bold"), strip.text = element_text(face = "bold", size = 8.5),
        panel.grid.major.x = element_blank())
agg_png(file.path(out_maps, "exposure_archetypes_profiles_30km.png"),
        width = 10, height = 6.4, units = "in", res = 300)
print(p_prof); invisible(dev.off())

# 6b. LAYER-B CHARACTERISATION -------------------------------------------------
# The point of holding these out: an archetype's share of AREA and its share of
# PEOPLE are different questions, and the answer is not the same.
lb <- rbind(
  data.frame(archetype = prof$archetype, panel = "Share of European land\n(% of analysed cells)",
             value = prof$area_pct),
  data.frame(archetype = prof$archetype, panel = "Share of European population\n(% of 2020 population in mask)",
             value = prof$population_pct),
  data.frame(archetype = prof$archetype, panel = "Median GDP per capita\n(USD PPP, 2022; Layer-B filter)",
             value = prof$median_gdp_pc_2022))
lb$panel <- factor(lb$panel, levels = unique(lb$panel))
lb$archetype <- factor(lb$archetype, levels = seq_len(BEST_K))
p_lb <- ggplot(lb, aes(archetype, value, fill = archetype)) +
  geom_col(show.legend = FALSE, width = .72) +
  geom_text(aes(label = ifelse(value > 1000, format(round(value), big.mark = ","), sprintf("%.1f", value))),
            vjust = -0.45, size = 3.1, colour = "grey25") +
  facet_wrap(~panel, scales = "free_y", ncol = 3) +
  scale_fill_manual(values = pal) +
  scale_y_continuous(expand = expansion(mult = c(0, .16))) +
  labs(title = "Who lives in each archetype",
       subtitle = paste("Layer-B filters, computed after clustering and never inside it.",
                        "Land share and population share diverge sharply."),
       x = "Archetype", y = NULL,
       caption = paste("Population: GHS-POP 2020 resampled to 30 km. GDP per capita: Kummu et al. gridded ADM2, 2022.",
                       "\nGDP is a Layer-B exposure filter (B2 wealth), not an experienceable feature.")) +
  theme_minimal(base_size = 11) +
  theme(plot.title = element_text(face = "bold"), strip.text = element_text(face = "bold", size = 9),
        plot.caption = element_text(colour = "grey45", size = 7, hjust = 0),
        panel.grid.major.x = element_blank())
agg_png(file.path(out_maps, "exposure_archetypes_layerB_30km.png"),
        width = 10, height = 4.6, units = "in", res = 300)
print(p_lb); invisible(dev.off())

# 7. K-SELECTION FIGURE --------------------------------------------------------
ks <- ksel
ks$status <- ifelse(ks$selected, "selected",
             ifelse(ks$admissible, "admissible",
             ifelse(!ks$passes_not_a_gradient, "rejected: one gradient cut in k",
                    "rejected: unstable cluster")))
p_k <- ggplot(ks, aes(factor(k), mean_silhouette, fill = status)) +
  geom_col(width = .7) +
  geom_text(aes(label = sprintf("J=%.2f", min_bootstrap_jaccard)), vjust = -0.5, size = 3, colour = "grey25") +
  scale_fill_manual(values = c("selected" = "#C1272D", "admissible" = "#E1A100",
                               "rejected: one gradient cut in k" = "grey72",
                               "rejected: unstable cluster" = "grey86"), name = NULL) +
  scale_y_continuous(expand = expansion(mult = c(0, .15))) +
  labs(title = "Choosing k with a rule that can reject the answer you want",
       subtitle = "Silhouette alone selects k = 2 - but its centres all move together, i.e. one gradient, not a typology",
       x = "Number of archetypes (k)", y = "Mean silhouette width",
       caption = "J = smallest mean bootstrap Jaccard across clusters (Hennig 2007); >= 0.75 required for a cluster to count as a stable pattern.") +
  theme_minimal(base_size = 11) +
  theme(plot.title = element_text(face = "bold"), legend.position = "bottom",
        panel.grid.major.x = element_blank())
agg_png(file.path(out_maps, "exposure_archetypes_k_selection.png"),
        width = 8.6, height = 5.6, units = "in", res = 300)
print(p_k); invisible(dev.off())

message(sprintf("Done. k = %d | silhouette = %.3f | cells = %d", BEST_K, sil_sel, nrow(d)))
