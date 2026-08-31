# =============================================================================
# TEST D -- how much of our published churn number is transient flicker?
# New question, new rule; NOT a repair of C2 (which failed on its own terms:
# 69.6% of closed episodes last <= 2 years, 66.5% are <=2-year A->B->A reversals).
#
# METHOD. Apply an explicit temporal filter to each pixel's 60-year broad-class
# sequence, then recount changes:
#   pass 1  A B A     -> A A A   (1-year excursions removed)
#   pass 2  A B B A   -> A A A A (2-year excursions removed)
# Nothing else is touched; episodes of 3 years or more are left as they are, and
# the filter is symmetric so it cannot create changes.
#
# READING RULE, WRITTEN BEFORE RUNNING:
#   Let m_raw and m_flt be the mean number of changes per land pixel 1960-2019,
#   before and after the filter.
#   - If m_flt >= 0.8 * m_raw, the flicker is cosmetic: our published churn map
#     stands as a map of land-use change.
#   - If m_flt <= 0.5 * m_raw, the map is dominated by transient excursions and
#     cannot be presented as land-use change without filtering or relabelling.
#   - Between 0.5 and 0.8: report the number, relabel, claim nothing more.
#
# ALSO REPORTED (descriptive, no rule attached): which class pairs the <=2-year
# reversals run between, and the full closed-episode length histogram, because
# the first run showed an unexplained spike at exactly 11 years.
# =============================================================================
suppressMessages(library(terra))
setwd(here::here())
terraOptions(progress = 0)

sdir   <- "Feature explorations/Biosphere/data_raw/biosphere/hilda_plus_v2/states_wgs84"
shared <- "Feature explorations/_shared"
STUDY <- c("AT","BE","BG","HR","CY","CZ","DK","EE","FI","FR","DE","EL","HU","IE",
           "IT","LV","LT","LU","MT","NL","PL","PT","RO","SK","SI","ES","SE","UK",
           "IS","LI","NO","CH")
YEARS <- 1960:2019; NY <- length(YEARS)
cn    <- vect(file.path(shared, "CNTR_RG_10M_2024_4326.geojson"))
study <- crop(cn[cn$CNTR_ID %in% STUDY, ], ext(-25, 45, 34, 72))
CLASSNAME <- c("urban","cropland","pasture","forest","grass/shrub","sparse")

recode <- rep(NA_integer_, 100)
recode[11+1] <- 1L; recode[c(22,23,24)+1] <- 2L; recode[33+1] <- 3L
recode[c(40,41,42,43,44,45)+1] <- 4L; recode[55+1] <- 5L; recode[66+1] <- 6L
fpath <- function(y) file.path(sdir, sprintf("hilda_plus_states_%d_GLOB-v2_wgs84.tif", y))

NBAND <- 16; lat_edges <- seq(34, 72, length.out = NBAND + 1)
chg_raw <- 0; chg_flt <- 0; n_pix <- 0
pair_tab <- matrix(0, 6, 6, dimnames = list(CLASSNAME, CLASSNAME))
ep_len <- integer(NY)

for (b in seq_len(NBAND)) {
  bex <- ext(-25, 45, lat_edges[b], lat_edges[b+1])
  msk <- try(rasterize(study, crop(rast(fpath(1960)), bex)), silent = TRUE)
  if (inherits(msk, "try-error")) next
  keep <- which(!is.na(values(msk, mat = FALSE)))
  if (!length(keep)) next

  M <- matrix(NA_integer_, nrow = length(keep), ncol = NY)
  for (i in seq_along(YEARS)) M[, i] <- recode[values(crop(rast(fpath(YEARS[i])), bex), mat = FALSE)[keep] + 1L]
  land <- rowSums(!is.na(M)) == NY
  M <- M[land, , drop = FALSE]
  n_pix <- n_pix + nrow(M)

  cnt <- function(X) sum(X[, -1] != X[, -ncol(X)], na.rm = TRUE)
  chg_raw <- chg_raw + cnt(M)

  # descriptive: reversal pairs and episode lengths on the RAW sequence
  cur <- M[,1]; len <- rep(1L, nrow(M)); prevc <- rep(NA_integer_, nrow(M))
  for (t in seq_len(NY-1)) {
    new <- M[, t+1]; chg <- cur != new
    known <- chg & !is.na(prevc)
    if (any(known)) {
      L <- len[known]; ep_len <- ep_len + tabulate(pmin(L, NY), nbins = NY)
      rv <- known & len <= 2 & prevc == new
      if (any(rv)) {
        a <- prevc[rv]; bcl <- cur[rv]
        pair_tab <- pair_tab + matrix(tabulate((bcl - 1L) * 6L + a, nbins = 36), 6, 6)
      }
    }
    prevc[chg] <- cur[chg]; cur[chg] <- new[chg]
    len[chg] <- 1L; len[!chg] <- len[!chg] + 1L
  }

  # --- the filter ---
  F <- M
  for (t in 2:(NY-1)) {                                   # pass 1: A B A
    hit <- F[, t] != F[, t-1] & F[, t-1] == F[, t+1]
    F[hit, t] <- F[hit, t-1]
  }
  for (t in 2:(NY-2)) {                                   # pass 2: A B B A
    hit <- F[, t] != F[, t-1] & F[, t+1] == F[, t] & F[, t+2] == F[, t-1]
    F[hit, t] <- F[hit, t-1]; F[hit, t+1] <- F[hit, t-1]
  }
  chg_flt <- chg_flt + cnt(F)
  cat(sprintf("band %2d/%d (%d stable-land cells)\n", b, NBAND, nrow(M)))
  rm(M, F); gc()
}

m_raw <- chg_raw / n_pix; m_flt <- chg_flt / n_pix
cat(sprintf("\nland pixels analysed: %s\n", format(n_pix, big.mark=",")))
cat(sprintf("changes 1960-2019, RAW      : %s  -> %.3f per pixel\n", format(chg_raw, big.mark=","), m_raw))
cat(sprintf("changes 1960-2019, FILTERED : %s  -> %.3f per pixel\n", format(chg_flt, big.mark=","), m_flt))
cat(sprintf("retained: %.1f%% of the raw count\n", 100*m_flt/m_raw))
cat(sprintf("\nTEST D VERDICT: %s\n",
    if (m_flt >= 0.8*m_raw) "flicker cosmetic, map stands" else
    if (m_flt <= 0.5*m_raw) "MAP DOMINATED BY TRANSIENT EXCURSIONS" else "intermediate - relabel, claim nothing more"))

cat("\n--- <=2-year reversals A -> B -> A, by pair (rows A, cols B) ---\n")
print(pair_tab)
cat("\ntop pairs:\n")
idx <- order(pair_tab, decreasing = TRUE)[1:8]
for (i in idx) {
  r <- ((i-1) %% 6) + 1; cc <- ((i-1) %/% 6) + 1
  cat(sprintf("  %-12s -> %-12s -> back : %s\n", CLASSNAME[r], CLASSNAME[cc],
              format(pair_tab[r,cc], big.mark=",")))
}
cat("\n--- closed-episode length histogram, full ---\n")
print(setNames(ep_len, 1:NY))
