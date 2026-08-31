# =============================================================================
# Does the HILDA+ gap-filling INVENT back-and-forth transitions?
# Follow-up to the no-data test of 2026-08-13, which showed the count cannot be
# inflated by NA but left this mechanism untested.
#
# WHAT THE PRODUCERS SAY (HILDAplus_GLOBv-2.0_documentation.pdf, p.2 and p.4).
# HILDA+ is not a classification; it is a CHANGE ALLOCATION procedure. It starts
# from a 2020 base map and walks backwards, distributing the change demanded by
# FAO forest/cropland/pasture statistics using country-specific transition
# matrices, spatially guided by earth-observation products WHERE THOSE EXIST.
# Their own table dates the EO inputs:
#     GLAD UMD VCF   1982-2016  (earliest global input)
#     ESA CCI LC     1992-2019
#     CORINE         1990, 2000, 2006, 2012, 2018 (Europe)
#     GLC2000        2000 ; NLCD 2001+ ; Copernicus LC100 2015-2019
#     ESA WorldCover 2020 (the base map)
# So 1960-1981 has NO satellite constraint at all: change is allocated from
# statistics alone. 1982, 1990/1992, 2000 and 2015 are DATA-REGIME BOUNDARIES,
# fixed by data availability, not by anything happening on the ground.
#
# ---------------------------------------------------------------------------
# READING RULE, WRITTEN BEFORE THE MEASUREMENT
# ---------------------------------------------------------------------------
# C1 -- ANNUAL CHANGE RATE. Count pixels changing broad class between t-1 and t,
#   for t = 1961..2019, over the European study area.
#   Real land-use change is a slow social process; nothing on the ground happens
#   because a satellite went up. A step at a boundary year is therefore an
#   artefact signature, not a signal.
#   Statistic: ratio of the mean annual change count in the 5 years AFTER each
#   boundary to the mean in the 5 years BEFORE (boundaries 1982, 1990, 2000, 2015).
#   FAILS  (fusion artefact material) if any ratio is > 2.0 or < 0.5.
#   PASSES if all four ratios lie within [0.67, 1.5].
#   INCONCLUSIVE otherwise: report the ratios and claim nothing.
#
# C2 -- SHORT EPISODES. Decompose each pixel's 60-year sequence into runs of
#   constant broad class. At HILDA's thematic breadth (urban / crops / pasture /
#   forest / grass-shrub / sparse) a class held for one or two years is not a land
#   use; it is flicker.
#   Statistics, over episodes whose START is observed (the first and last episodes
#   of each pixel are censored and excluded, as in any dwell-time analysis):
#     (a) share of closed episodes lasting <= 2 years
#     (b) share that are a reversal A -> B -> A with B lasting <= 2 years
#   FAILS  if (a) >= 10% or (b) >= 10%.
#   PASSES if both < 2%.
#   INCONCLUSIVE between 2% and 10%.
#
# CONFOUNDER DECLARED IN ADVANCE. C2 cannot separate "fusion artefact" from
# "genuine short-lived cover" (a clearcut read as sparse for a year before
# regrowth). C2 therefore BOUNDS the magnitude of possible flicker; it cannot
# attribute it. C1 is the test that can attribute, because satellite availability
# has no mechanism to move real land use.
# =============================================================================
suppressMessages(library(terra))
setwd(here::here())
terraOptions(progress = 0)

sdir   <- "Feature explorations/Biosphere/data_raw/biosphere/hilda_plus_v2/states_wgs84"
shared <- "Feature explorations/_shared"
STUDY <- c("AT","BE","BG","HR","CY","CZ","DK","EE","FI","FR","DE","EL","HU","IE",
           "IT","LV","LT","LU","MT","NL","PL","PT","RO","SK","SI","ES","SE","UK",
           "IS","LI","NO","CH")
YEARS <- 1960:2019
NY    <- length(YEARS)
cn    <- vect(file.path(shared, "CNTR_RG_10M_2024_4326.geojson"))
study <- crop(cn[cn$CNTR_ID %in% STUDY, ], ext(-25, 45, 34, 72))

# raw v2 code -> six broad v1 classes; everything else (ocean 00, water 77,
# no data 99) -> NA, exactly as 4b_change_freq_hilda_v2.R does.
recode <- rep(NA_integer_, 100)
recode[11+1] <- 1L
recode[c(22,23,24)+1] <- 2L
recode[33+1] <- 3L
recode[c(40,41,42,43,44,45)+1] <- 4L
recode[55+1] <- 5L
recode[66+1] <- 6L

fpath <- function(y) file.path(sdir, sprintf("hilda_plus_states_%d_GLOB-v2_wgs84.tif", y))

# latitude bands, so 60 years of one band fit in memory at once
NBAND <- 16
lat_edges <- seq(34, 72, length.out = NBAND + 1)

ann_chg   <- numeric(NY - 1)          # C1: changed pixels per transition year
n_closed  <- 0                        # C2 denominator: episodes with observed start
n_short   <- 0
n_rev     <- 0
n_chg_all <- 0                        # every change, censored or not
ep_len_tab <- integer(NY)             # histogram of closed-episode lengths

for (b in seq_len(NBAND)) {
  bex <- ext(-25, 45, lat_edges[b], lat_edges[b + 1])
  msk <- try(rasterize(study, crop(rast(fpath(1960)), bex)), silent = TRUE)
  if (inherits(msk, "try-error")) next
  keep <- which(!is.na(values(msk, mat = FALSE)))
  if (!length(keep)) { cat(sprintf("band %2d: no study cells\n", b)); next }

  M <- matrix(NA_integer_, nrow = length(keep), ncol = NY)
  for (i in seq_along(YEARS)) {
    v <- values(crop(rast(fpath(YEARS[i])), bex), mat = FALSE)[keep]
    M[, i] <- recode[v + 1L]
  }

  cur   <- M[, 1]
  len   <- rep(1L, nrow(M))
  prevc <- rep(NA_integer_, nrow(M))

  for (t in seq_len(NY - 1)) {
    new <- M[, t + 1]
    chg <- !is.na(cur) & !is.na(new) & cur != new
    ann_chg[t] <- ann_chg[t] + sum(chg)
    n_chg_all  <- n_chg_all + sum(chg)

    known <- chg & !is.na(prevc)        # this change closes an episode we saw start
    n_closed <- n_closed + sum(known)
    if (any(known)) {
      L <- len[known]
      ep_len_tab[1:NY] <- ep_len_tab[1:NY] + tabulate(pmin(L, NY), nbins = NY)
      n_short <- n_short + sum(L <= 2)
      n_rev   <- n_rev + sum(L <= 2 & prevc[known] == new[known])
    }
    prevc[chg] <- cur[chg]
    cur[chg]   <- new[chg]
    len[chg]   <- 1L
    len[!chg]  <- len[!chg] + 1L
  }
  cat(sprintf("band %2d/%d done (%d study cells)\n", b, NBAND, nrow(M)))
  rm(M); gc()
}

cat("\n=================== C1: annual change rate ===================\n")
names(ann_chg) <- YEARS[-1]
cat("changed pixels per year:\n")
print(round(ann_chg))

win_mean <- function(y0, y1) mean(ann_chg[as.character(y0:y1)])
cat("\nboundary  before(5y)   after(5y)   ratio\n")
verdict1 <- c()
for (B in c(1982, 1990, 2000, 2015)) {
  bef <- win_mean(B - 5, B - 1); aft <- win_mean(B, B + 4)
  r <- aft / bef
  verdict1 <- c(verdict1, r)
  cat(sprintf("  %d   %10.0f  %10.0f  %6.2f\n", B, bef, aft, r))
}
cat(sprintf("\nC1 VERDICT: %s  (fails if any ratio >2.0 or <0.5; passes if all in [0.67,1.5])\n",
            if (any(verdict1 > 2 | verdict1 < 0.5)) "FAILED" else
            if (all(verdict1 >= 0.67 & verdict1 <= 1.5)) "PASSED" else "INCONCLUSIVE"))

cat("\n=================== C2: episode lengths ===================\n")
cat(sprintf("total changes counted (incl. censored): %s\n", format(n_chg_all, big.mark = ",")))
cat(sprintf("closed episodes with observed start   : %s\n", format(n_closed, big.mark = ",")))
pa <- 100 * n_short / n_closed
pb <- 100 * n_rev   / n_closed
cat(sprintf("  episodes lasting <= 2 years : %s (%.2f%%)\n", format(n_short, big.mark=","), pa))
cat(sprintf("  of which A->B->A reversals  : %s (%.2f%%)\n", format(n_rev, big.mark=","), pb))
cat("\nclosed-episode length histogram (years 1..15):\n")
print(setNames(ep_len_tab[1:15], 1:15))
cat(sprintf("median closed-episode length: %d years\n",
            which(cumsum(ep_len_tab) >= sum(ep_len_tab)/2)[1]))
cat(sprintf("\nC2 VERDICT: %s  (fails if either >=10%%; passes if both <2%%)\n",
            if (pa >= 10 || pb >= 10) "FAILED" else
            if (pa < 2 && pb < 2) "PASSED" else "INCONCLUSIVE"))
