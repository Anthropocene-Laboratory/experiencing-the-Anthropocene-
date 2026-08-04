# =============================================================================
# 6_bii_pop_weighted_boundary.R
# POPULATION-weighted version of the BII planetary-boundary story:
# not "how much LAND is beyond the boundary" but "how many PEOPLE live there".
#
# Method: BII (5 arc-min) is resampled ONTO the population grid (GHS-POP 2020,
# 0.1 deg) so that population counts are never resampled/distorted; population
# is then summed by boundary-status class. Population is held at 2020 while BII
# varies by year, so the trajectory isolates the biodiversity signal.
#
# Boundary (Steffen 2015 / Newbold 2016): safe >= 90, risk zone 30-90, beyond < 30.
#
# RUN FROM WORKSPACE ROOT:
#   Rscript "Feature explorations/Biosphere/scripts/6_bii_pop_weighted_boundary.R"
# =============================================================================
suppressMessages(library(terra))
setwd(here::here())

bii_dir <- "Feature explorations/Biosphere/data_raw/biosphere/bii_v2_1_1"
shared  <- "Feature explorations/_shared"
out     <- "Feature explorations/Biosphere/data_processed"
out_maps   <- file.path(out, "maps")
out_tables <- file.path(out, "tables")
dir.create(out_maps,   showWarnings = FALSE, recursive = TRUE)
dir.create(out_tables, showWarnings = FALSE, recursive = TRUE)

STUDY <- c("AT","BE","BG","HR","CY","CZ","DK","EE","FI","FR","DE","EL","HU","IE",
           "IT","LV","LT","LU","MT","NL","PL","PT","RO","SK","SI","ES","SE","UK",
           "IS","LI","NO","CH")
euro <- ext(-25, 45, 34, 72)
cn    <- vect(file.path(shared, "CNTR_RG_10M_2024_4326.geojson"))
study <- crop(cn[cn$CNTR_ID %in% STUDY, ], euro)

# boundary classification
rcl <- rbind(c(90, 101, 1), c(30, 90, 2), c(-1, 30, 3))
lab <- c("Inside safe limit (>= 90%)", "Zone of increasing risk (30-90%)",
         "Beyond the boundary (< 30%)")
pal <- c("#1A9850", "#FDAE61", "#A50026")

# ---- population grid (native; never resampled) -------------------------------
pop <- rast(file.path(shared, "pop2020_0p1deg.tif"))
pop <- mask(crop(pop, study), study)
cat("population grid:\n"); print(pop)

years <- c(2000, 2005, 2010, 2015, 2020)
bii_on_pop <- function(y) {
  r <- rast(file.path(bii_dir, sprintf("bii-%d_v2-1-1.tif", y)))
  resample(crop(r, euro), pop, method = "bilinear")   # BII onto pop grid
}

popv <- values(pop)[, 1]

# per-year population share by boundary status + pop-weighted mean BII
pop_share <- function(y) {
  b  <- bii_on_pop(y)
  bv <- values(b)[, 1]
  st <- values(classify(b, rcl))[, 1]
  k  <- !is.na(popv) & !is.na(bv) & popv > 0
  totP <- sum(popv[k])
  sh <- sapply(1:3, function(i) 100 * sum(popv[k][st[k] == i]) / totP)
  wbii <- sum(popv[k] * bv[k]) / totP
  c(sh, wbii, totP, sum(popv[!is.na(popv)]))   # + total pop matched, total pop all
}

M <- sapply(years, pop_share)
tab <- data.frame(
  year               = years,
  pop_safe_ge90_pct  = round(M[1, ], 1),
  pop_risk_30_90_pct = round(M[2, ], 1),
  pop_beyond_lt30_pct= round(M[3, ], 1),
  pop_wt_mean_bii    = round(M[4, ], 1))
write.csv(tab, file.path(out_tables, "bii_pop_weighted_status_by_year.csv"), row.names = FALSE)

pop_matched <- M[5, 1]; pop_all <- M[6, 1]

# ---- area share (for the land-vs-people contrast) ----------------------------
b2015 <- mask(crop(rast(file.path(bii_dir, "bii-2015_v2-1-1.tif")), study), study)
a  <- cellSize(b2015, unit = "km")
sa <- values(classify(b2015, rcl))[, 1]; av <- values(a)[, 1]
ka <- !is.na(sa) & !is.na(av)
area_sh <- sapply(1:3, function(i) 100 * sum(av[ka][sa[ka] == i]) / sum(av[ka]))
pop_sh_2015 <- as.numeric(tab[tab$year == 2015, 2:4])

# ---- MAP: where the people beyond the boundary live (2015) -------------------
b2015p <- bii_on_pop(2015)
beyond <- classify(b2015p, rbind(c(-1, 30, 1), c(30, 101, NA)))  # 1 where BII<30
pop_beyond <- mask(pop, beyond)                 # population only in "beyond" cells
lp <- pop_beyond; lp[lp < 1] <- NA; lp <- log10(lp)

png(file.path(out_maps, "bii_pop_beyond_boundary_2015.png"),
    width = 2400, height = 2400, res = 230)
par(mar = c(2, 2, 4, 1))
plot(lp, col = rev(hcl.colors(64, "Reds 3")), type = "continuous",
     axes = TRUE, mar = c(2, 2, 4, 9), maxcell = ncell(lp),
     main = "Where Europeans live BEYOND the biosphere boundary\nPopulation in cells with BII < 30% (2015, log10)",
     plg = list(title = "log10(persons/cell)"))
lines(study, col = "grey25", lwd = 0.3)
dev.off()
cat("wrote bii_pop_beyond_boundary_2015.png\n")

# ---- BAR CHART: land-area share vs population share (2015) -------------------
png(file.path(out_maps, "bii_pop_vs_area_share_2015.png"),
    width = 2000, height = 1400, res = 210)
par(mar = c(5, 5, 4, 2))
mm <- rbind(Land = area_sh, People = pop_sh_2015)
bp <- barplot(mm, beside = TRUE, names.arg = c("Safe\n(>=90%)", "Risk\n(30-90%)", "Beyond\n(<30%)"),
              col = c("#8c8c8c", "#c0392b"), border = NA, ylim = c(0, 80),
              ylab = "Share (%)",
              main = "Land area vs population, by biosphere-boundary status (2015)")
legend("topright", c("Share of land area", "Share of population"),
       fill = c("#8c8c8c", "#c0392b"), bty = "n")
text(bp, as.vector(mm) + 2, sprintf("%.0f", as.vector(mm)), cex = 0.9)
dev.off()
cat("wrote bii_pop_vs_area_share_2015.png\n")

# ---- console summary ---------------------------------------------------------
cat("\n============ BII PLANETARY BOUNDARY - POPULATION-WEIGHTED (Europe) ============\n")
cat(sprintf("Population matched to a BII value: %s of %s (%.1f%%)\n",
            format(round(pop_matched), big.mark=","), format(round(pop_all), big.mark=","),
            100*pop_matched/pop_all))
cat("\nShare of PEOPLE by status vs the BII=90% boundary (pop fixed at 2020):\n\n")
print(tab, row.names = FALSE)
cat("\n-- 2015 contrast: LAND share vs PEOPLE share --\n")
ct <- data.frame(status = lab,
                 land_pct = round(area_sh, 1),
                 people_pct = round(pop_sh_2015, 1))
print(ct, row.names = FALSE)
cat(sprintf("\nArea-weighted mean BII 2015: read from script 5. Pop-weighted mean BII 2015: %.1f%%\n",
            tab$pop_wt_mean_bii[tab$year == 2015]))
cat(sprintf("Punchline: %.1f%% of Europeans live BEYOND the boundary (BII<30%%), vs %.1f%% of the land.\n",
            pop_sh_2015[3], area_sh[3]))
cat("\nWrote: bii_pop_beyond_boundary_2015.png, bii_pop_vs_area_share_2015.png,\n")
cat("       bii_pop_weighted_status_by_year.csv\n")
