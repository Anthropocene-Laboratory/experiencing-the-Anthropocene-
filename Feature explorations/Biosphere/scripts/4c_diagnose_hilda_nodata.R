# =============================================================================
# Can a no-data / cloud gap inflate the HILDA+ change-frequency count?
# Question posed by Denis, 2026-08-13: would NA-forest-cloud-forest-NA be
# counted as four changes?
#
# READING RULE, WRITTEN BEFORE RUNNING:
#
# TEST A (HILDA+ v2, 60 annual state rasters, local, study area).
#   Measure: per pixel, the number of years in which the pixel carries a class we
#   map to NA (raw codes 0 ocean/no-data, 77 water, 99 other). A pixel "flickers"
#   if that count is neither 0 (always land) nor 60 (never land).
#   PASSES (the worry is unfounded) if flickering pixels = 0: an NA can then never
#   sit between two valid land states, so the NA-forest-NA-forest sequence does
#   not exist in the data at all.
#   FAILS if flickering pixels > 0 -- then the sequence exists and the counting
#   rule matters. Report the count, its share of land, and where it is.
#
# TEST B (HILDA+ v1, the version actually behind our published map).
#   Our v1 map does not count anything itself: it displays the change-freq layer
#   precomputed by Winkler et al. So the rule is theirs, not ours, and must be
#   tested against their own annual states.
#   Measure: over a small window chosen for its land/water interleaving (Dutch
#   delta, lon 3-6 E, lat 51-53.5 N), read all 60 v1 annual states, count NA, and
#   recount changes with an explicit NA-safe rule (a transition into or out of NA
#   scores 0). Compare that recount, pixel by pixel, with the precomputed layer.
#   PASSES if the two agree exactly: the producers' rule is NA-safe too.
#   FAILS if the precomputed layer is systematically HIGHER than the NA-safe
#   recount -- that would be the signature of NA transitions being counted.
#   NULL (decides nothing) if the v1 states contain no NA at all in the window:
#   the two rules cannot then be told apart, and the test must be redone on a
#   window that does contain NA, or abandoned as unanswerable from this product.
# =============================================================================
suppressMessages(library(terra))
setwd(here::here())
terraOptions(progress = 0)

bio    <- "Feature explorations/Biosphere/data_raw/biosphere"
sdir   <- file.path(bio, "hilda_plus_v2", "states_wgs84")
shared <- "Feature explorations/_shared"
STUDY <- c("AT","BE","BG","HR","CY","CZ","DK","EE","FI","FR","DE","EL","HU","IE",
           "IT","LV","LT","LU","MT","NL","PL","PT","RO","SK","SI","ES","SE","UK",
           "IS","LI","NO","CH")
euro  <- ext(-25, 45, 34, 72)
cn    <- vect(file.path(shared, "CNTR_RG_10M_2024_4326.geojson"))
study <- crop(cn[cn$CNTR_ID %in% STUDY, ], euro)

LAND <- c(11, 22, 23, 24, 33, 40, 41, 42, 43, 44, 45, 55, 66)  # the v1-mapped set
YEARS <- 1960:2019

# ---------------- TEST A ------------------------------------------------------
cat("== TEST A: does any pixel move between land and no-data across 1960-2019? ==\n")
n_land <- NULL
for (y in YEARS) {
  r <- crop(rast(file.path(sdir, sprintf("hilda_plus_states_%d_GLOB-v2_wgs84.tif", y))), euro)
  isl <- r %in% LAND
  n_land <- if (is.null(n_land)) isl else n_land + isl
  if (y %% 10 == 0 || y == max(YEARS)) {
    n_land <- writeRaster(n_land, file.path(tempdir(), sprintf("nland_%d.tif", y)),
                          overwrite = TRUE, datatype = "INT1U")
    cat(sprintf("  ... %d\n", y)); gc()
  }
}
n_land_s <- mask(n_land, study)
v <- values(n_land_s, mat = FALSE); v <- v[!is.na(v)]
always <- sum(v == length(YEARS)); never <- sum(v == 0); flick <- sum(v > 0 & v < length(YEARS))
cat(sprintf("\ncells in the study-area mask: %d\n", length(v)))
cat(sprintf("  land in all 60 years : %d (%.4f%%)\n", always, 100*always/length(v)))
cat(sprintf("  land in no year      : %d (%.4f%%)\n", never,  100*never /length(v)))
cat(sprintf("  FLICKERING           : %d (%.4f%%)\n", flick,  100*flick /length(v)))
if (flick > 0) {
  cat("\n  distribution of years-as-land among flickering cells:\n")
  print(table(cut(v[v > 0 & v < length(YEARS)], breaks = c(0,1,5,15,30,45,59), right = TRUE)))
}

# ---------------- TEST B ------------------------------------------------------
cat("\n== TEST B: does the v1 PRECOMPUTED layer count no-data transitions? ==\n")
win <- ext(3, 6, 51, 53.5)   # Dutch delta: maximal land/water interleaving
hurl <- function(y) sprintf("/vsicurl/https://s3.openlandmap.org/arco/land.use.land.cover_hilda.plus_c_1km_s_%d0101_%d1231_go_espg.4326_v1.0.tif", y, y)

ok <- TRUE
prev <- NULL; recount <- NULL; na_years <- NULL
for (y in YEARS) {
  r <- try(crop(rast(hurl(y)), win), silent = TRUE)
  if (inherits(r, "try-error")) { cat("  network read failed at", y, "\n"); ok <- FALSE; break }
  isna <- is.na(r)
  na_years <- if (is.null(na_years)) isna else na_years + isna
  if (!is.null(prev)) {
    ch <- ifel(is.na(prev) | is.na(r), 0, ifel(prev != r, 1, 0))
    recount <- if (is.null(recount)) ch else recount + ch
  }
  prev <- r
  if (y %% 20 == 0) cat(sprintf("  ... %d\n", y))
}

if (ok) {
  nav <- values(na_years, mat = FALSE)
  cat(sprintf("\n  v1 window cells: %d | cells NA in >=1 year: %d | NA in all 60: %d\n",
              length(nav), sum(nav > 0), sum(nav == length(YEARS))))
  cat(sprintf("  cells FLICKERING in and out of NA: %d\n", sum(nav > 0 & nav < length(YEARS))))

  pre <- crop(rast(file.path(bio, "hilda_plus", "hildap_vGLOB-1.0_change-layers",
                             "HILDAplus_vGLOB-1.0_luc_change-freq_1960-2019_wgs84.tif")), win)
  pair <- values(c(pre, recount), mat = TRUE)
  colnames(pair) <- c("precomputed", "na_safe_recount")
  k <- complete.cases(pair)
  cat(sprintf("\n  comparable cells: %d\n", sum(k)))
  d <- pair[k, 1] - pair[k, 2]
  cat(sprintf("  precomputed minus NA-safe recount: mean %+.4f | max %+d | min %+d | cells differing %d (%.4f%%)\n",
              mean(d), as.integer(max(d)), as.integer(min(d)), sum(d != 0), 100*mean(d != 0)))
  cat(sprintf("  mean precomputed %.3f | mean NA-safe recount %.3f\n",
              mean(pair[k,1]), mean(pair[k,2])))
  # what does the precomputed layer say where v1 is NA in every year (open sea)?
  sea <- nav == length(YEARS)
  pv <- values(pre, mat = FALSE)
  cat(sprintf("  precomputed value on cells that are NA in all 60 v1 states: n=%d, NA=%d, nonzero=%d\n",
              sum(sea), sum(is.na(pv[sea])), sum(pv[sea] > 0, na.rm = TRUE)))
}
cat("\nDONE\n")
