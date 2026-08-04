# =============================================================================
# 2_diagnose_structure_30km.R
#
# The test that must run BEFORE any clustering.
#
# A typology is only meaningful if the candidate features carry more than one
# independent axis of variation. If they are redundant proxies of a single
# gradient (e.g. several measures of "how urban is this cell"), then k-means
# does not discover archetypes: it cuts one continuum into k slices, and any
# label attached to those slices is decoration.
#
# This script therefore states in advance what would make the clustering plan
# FAIL, and reports it either way:
#
#   FAIL-1 (redundancy)  PC1 explains >= 65% of total variance
#                        -> one gradient; report a gradient, not a typology.
#   FAIL-2 (coverage)    complete-case cells < 75% of masked cells
#                        -> the feature set silently deletes part of Europe.
#   FAIL-3 (no k)        best mean silhouette < 0.25, or the optimum is k = 2
#                        and all features move together across the two centres
#                        -> again a cut gradient, not archetypes.
#
# Run from the workspace ROOT, after 1_build_layerA_stack_30km.R.
# =============================================================================

suppressPackageStartupMessages({
  library(terra); library(ggplot2); library(cluster); library(ragg)
})

root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
out_dir    <- file.path(root, "Feature explorations/Analysis/data_processed")
out_tables <- file.path(out_dir, "tables")
out_maps   <- file.path(out_dir, "maps")
dir.create(out_tables, recursive = TRUE, showWarnings = FALSE)
dir.create(out_maps, recursive = TRUE, showWarnings = FALSE)

stk <- rast(file.path(out_dir, "layerA_stack_30km.tif"))
layerA <- c("built_pct", "light_mcd_m2", "pm25_ug_m3", "utci_strong_h", "hw_days",
            "crop_frac", "bii", "landchange_freq", "pop_dens_km2")

df <- as.data.frame(stk, cells = TRUE, xy = TRUE, na.rm = FALSE)
in_mask <- rowSums(!is.na(df[, layerA])) > 0
d <- df[in_mask, ]

# 1. COVERAGE: which feature costs how much of Europe? -------------------------
cov_tab <- data.frame(
  variable        = layerA,
  n_in_mask       = nrow(d),
  n_available     = vapply(layerA, function(v) sum(!is.na(d[[v]])), integer(1)),
  stringsAsFactors = FALSE
)
cov_tab$pct_available <- round(100 * cov_tab$n_available / cov_tab$n_in_mask, 1)
# Marginal cost: cells lost that ONLY this variable is missing on.
cov_tab$pct_uniquely_limiting <- vapply(layerA, function(v) {
  others <- setdiff(layerA, v)
  round(100 * sum(is.na(d[[v]]) & complete.cases(d[, others])) / nrow(d), 1)
}, numeric(1))
write.csv(cov_tab, file.path(out_tables, "diag_coverage_by_variable.csv"), row.names = FALSE)
cat("\n--- COVERAGE (FAIL-2 test) ---\n"); print(cov_tab)

# 2. TRANSFORM + CORRELATION ---------------------------------------------------
# Heavy right skew on intensities; symmetry matters for Euclidean geometry.
tf <- function(x, how) switch(how,
  log1p = log1p(x), log = log(x), asin = asin(sqrt(pmin(pmax(x, 0), 1))), id = x)
recipe <- c(built_pct = "log1p", light_mcd_m2 = "log1p", pm25_ug_m3 = "log",
            utci_strong_h = "log1p", hw_days = "log1p", crop_frac = "asin",
            bii = "id", landchange_freq = "log1p", pop_dens_km2 = "log1p")

cc <- complete.cases(d[, layerA])
X <- as.data.frame(mapply(function(v, how) tf(d[cc, v], how), layerA, recipe[layerA]))
names(X) <- layerA
Z <- scale(X)

cmat <- cor(X, method = "spearman")
write.csv(round(cmat, 3), file.path(out_tables, "diag_spearman_correlation.csv"))
cat("\n--- SPEARMAN CORRELATION ---\n"); print(round(cmat, 2))

# 3. PCA: how many independent axes? (FAIL-1 test) -----------------------------
pca <- prcomp(Z, center = FALSE, scale. = FALSE)
ev <- pca$sdev^2
var_tab <- data.frame(PC = paste0("PC", seq_along(ev)),
                      variance_pct = round(100 * ev / sum(ev), 1))
var_tab$cumulative_pct <- cumsum(var_tab$variance_pct)
write.csv(var_tab, file.path(out_tables, "diag_pca_variance.csv"), row.names = FALSE)
load_tab <- round(pca$rotation[, 1:3], 3)
write.csv(load_tab, file.path(out_tables, "diag_pca_loadings.csv"))
cat("\n--- PCA (FAIL-1 test) ---\n"); print(var_tab); cat("\nLoadings PC1-PC3:\n"); print(load_tab)

# 4. K DIAGNOSTIC, INCLUDING THE "ALL FEATURES MOVE TOGETHER" CHECK ------------
set.seed(20260728)
n_sil <- min(5000L, nrow(Z))
idx <- sample.int(nrow(Z), n_sil)
Zs <- Z[idx, , drop = FALSE]
dZ <- dist(Zs)
kdiag <- do.call(rbind, lapply(2:8, function(k) {
  fit <- kmeans(Zs, centers = k, nstart = 50, iter.max = 100)
  data.frame(k = k, mean_silhouette = mean(silhouette(fit$cluster, dZ)[, "sil_width"]),
             withinss = fit$tot.withinss)
}))
best_k <- kdiag$k[which.max(kdiag$mean_silhouette)]
fit_best <- kmeans(Zs, centers = best_k, nstart = 50, iter.max = 100)
centres <- fit_best$centers
# If every feature has the same sign in every centre, the solution is one axis.
same_sign <- all(apply(sign(centres), 1, function(r) length(unique(r)) == 1))
kdiag$selected <- kdiag$k == best_k
write.csv(kdiag, file.path(out_tables, "diag_k_silhouette.csv"), row.names = FALSE)
cat("\n--- K DIAGNOSTIC (FAIL-3 test) ---\n"); print(kdiag)
cat("\nStandardised centres at best k:\n"); print(round(centres, 2))

# 5. VERDICT -------------------------------------------------------------------
fail1 <- var_tab$variance_pct[1] >= 65
fail2 <- (100 * sum(cc) / nrow(d)) < 75
fail3 <- max(kdiag$mean_silhouette) < 0.25 || (best_k == 2 && same_sign)
verdict <- data.frame(
  test = c("FAIL-1 redundancy (PC1 >= 65%)",
           "FAIL-2 coverage (complete cases < 75% of mask)",
           "FAIL-3 no archetypes (silhouette < .25, or k=2 with one-directional centres)"),
  observed = c(sprintf("PC1 = %.1f%%", var_tab$variance_pct[1]),
               sprintf("%.1f%% complete (%d / %d cells)", 100 * sum(cc) / nrow(d), sum(cc), nrow(d)),
               sprintf("best k = %d, silhouette = %.3f, one-directional centres = %s",
                       best_k, max(kdiag$mean_silhouette), same_sign)),
  failed = c(fail1, fail2, fail3))
write.csv(verdict, file.path(out_tables, "diag_verdict.csv"), row.names = FALSE)
cat("\n--- VERDICT ---\n"); print(verdict, right = FALSE)

# 6. FIGURE --------------------------------------------------------------------
cor_long <- as.data.frame(as.table(cmat)); names(cor_long) <- c("a", "b", "rho")
p_cor <- ggplot(cor_long, aes(a, b, fill = rho)) +
  geom_tile(colour = "white") +
  geom_text(aes(label = sprintf("%.2f", rho)), size = 2.9,
            colour = ifelse(abs(cor_long$rho) > .6, "white", "grey15")) +
  scale_fill_gradient2(limits = c(-1, 1), low = "#2166AC", mid = "white", high = "#B2182B",
                       name = "Spearman") +
  labs(title = "Are the candidate Layer-A features independent?",
       subtitle = sprintf("30-km equal-area cells (n = %s complete). PC1 = %.0f%% of variance.",
                          format(sum(cc), big.mark = ","), var_tab$variance_pct[1]),
       x = NULL, y = NULL) +
  theme_minimal(base_size = 10) +
  theme(axis.text.x = element_text(angle = 40, hjust = 1),
        plot.title = element_text(face = "bold"), panel.grid = element_blank())
agg_png(file.path(out_maps, "diag_feature_redundancy_30km.png"), width = 8, height = 6.6,
        units = "in", res = 300)
print(p_cor); invisible(dev.off())

message("Diagnostics written. Consult diag_verdict.csv before clustering.")
