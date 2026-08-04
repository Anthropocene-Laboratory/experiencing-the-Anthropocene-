# =============================================================================
# 3_compare_feature_sets_30km.R
#
# Script 2 showed the 9-variable candidate pool fails on COVERAGE (only 56% of
# masked European cells are complete) and contains two near-duplicate pairs
# (pop_dens ~ light, rho = .84; crop_frac ~ BII, rho = -.81).
#
# This script does not pick a feature set by taste. It scores explicit,
# pre-registered candidate sets on four criteria that can each disqualify a set:
#
#   coverage_pct     % of masked cells complete on all features of the set
#   max_abs_rho      largest |Spearman| between any two features (redundancy)
#   pc1_pct          % variance on PC1 (is it one gradient in disguise?)
#   best_silhouette  best mean silhouette over k = 2..8
#   n_spheres        how many Layer-A spheres (A1/A2) the set spans
#
# Layer-B variables (population density, GDP per capita) are deliberately
# EXCLUDED from every set: AGENTS.md forbids collapsing an exposure filter into
# the feature layer. They are used in script 4 to profile the result instead.
#
# Run from the workspace ROOT, after 1_build_layerA_stack_30km.R.
# =============================================================================

suppressPackageStartupMessages({ library(terra); library(cluster) })

root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
out_dir    <- file.path(root, "Feature explorations/Analysis/data_processed")
out_tables <- file.path(out_dir, "tables")

stk <- rast(file.path(out_dir, "layerA_stack_30km.tif"))
layerA_pool <- c("built_pct", "light_mcd_m2", "pm25_ug_m3", "utci_strong_h",
                 "hw_days", "crop_frac", "bii", "landchange_freq")

df <- as.data.frame(stk, cells = TRUE, xy = TRUE, na.rm = FALSE)
d <- df[rowSums(!is.na(df[, layerA_pool])) > 0, ]

sphere <- c(built_pct = "A2", light_mcd_m2 = "A2", pm25_ug_m3 = "A1",
            utci_strong_h = "A1", hw_days = "A1", crop_frac = "A1",
            bii = "A1", landchange_freq = "A1")
recipe <- c(built_pct = "log1p", light_mcd_m2 = "log1p", pm25_ug_m3 = "log",
            utci_strong_h = "log1p", hw_days = "log1p", crop_frac = "asin",
            bii = "id", landchange_freq = "log1p")
tf <- function(x, how) switch(how, log1p = log1p(x), log = log(x),
                              asin = asin(sqrt(pmin(pmax(x, 0), 1))), id = x)

# Pre-registered candidate sets, each with the reason it exists ---------------
sets <- list(
  `S0 Gemini profile 1` = c("built_pct", "light_mcd_m2", "pm25_ug_m3"),
  `S1 full pool`        = layerA_pool,
  `S2 drop BII`         = setdiff(layerA_pool, "bii"),
  `S3 drop churn`       = setdiff(layerA_pool, "landchange_freq"),
  `S4 drop BII+churn`   = setdiff(layerA_pool, c("bii", "landchange_freq")),
  `S5 keep BII not crop`= setdiff(layerA_pool, c("crop_frac", "landchange_freq")),
  `S6 one heat only`    = setdiff(layerA_pool, c("bii", "hw_days")),
  `S7 minimal 4`        = c("built_pct", "pm25_ug_m3", "utci_strong_h", "crop_frac")
)

score_set <- function(vars) {
  cc <- complete.cases(d[, vars])
  X <- as.data.frame(mapply(function(v, how) tf(d[cc, v], how), vars, recipe[vars]))
  names(X) <- vars
  Z <- scale(X)
  cm <- cor(X, method = "spearman"); diag(cm) <- 0
  ev <- prcomp(Z, center = FALSE, scale. = FALSE)$sdev^2
  set.seed(20260728)
  idx <- sample.int(nrow(Z), min(4000L, nrow(Z)))
  Zs <- Z[idx, , drop = FALSE]; dZ <- dist(Zs)
  sil <- vapply(2:8, function(k) {
    fit <- kmeans(Zs, centers = k, nstart = 30, iter.max = 100)
    mean(silhouette(fit$cluster, dZ)[, "sil_width"])
  }, numeric(1))
  data.frame(
    n_features      = length(vars),
    n_spheres       = length(unique(sphere[vars])),
    coverage_pct    = round(100 * sum(cc) / nrow(d), 1),
    max_abs_rho     = round(max(abs(cm)), 2),
    pc1_pct         = round(100 * ev[1] / sum(ev), 1),
    pc1_pc2_pct     = round(100 * sum(ev[1:2]) / sum(ev), 1),
    best_k          = (2:8)[which.max(sil)],
    best_silhouette = round(max(sil), 3),
    features        = paste(vars, collapse = "+")
  )
}

res <- do.call(rbind, lapply(sets, score_set))
res <- cbind(set = rownames(res), res); rownames(res) <- NULL

# Disqualification rules, stated before looking at the numbers.
res$fail_coverage   <- res$coverage_pct < 75
res$fail_redundancy <- res$max_abs_rho > 0.75
res$fail_onegradient<- res$pc1_pct >= 65
res$fail_nostructure<- res$best_silhouette < 0.25
res$admissible <- !(res$fail_coverage | res$fail_redundancy |
                    res$fail_onegradient | res$fail_nostructure)

write.csv(res, file.path(out_tables, "diag_feature_set_comparison.csv"), row.names = FALSE)
print(res[, c("set", "n_features", "n_spheres", "coverage_pct", "max_abs_rho",
              "pc1_pct", "best_k", "best_silhouette", "admissible")], right = FALSE)
cat("\nAdmissible sets:\n"); print(res$set[res$admissible])
