# =============================================================================
# 5_bii_planetary_boundary.R
# BII (NHM v2.1.1) vs the biosphere-integrity PLANETARY BOUNDARY, Europe.
#
# Narrative: Steffen et al. 2015 / Newbold et al. 2016 set the proposed safe
# limit for biosphere integrity at BII = 90%, with a "zone of uncertainty /
# increasing risk" running from 90% down to 30%, and <30% as beyond that zone.
# This maps where European land sits relative to that boundary, and tracks the
# area-share in each status class across 2000 -> 2020.
#
# BII source: De Palma et al. 2024, NHM Data Portal, v2.1.1, CC-BY-NC-SA 4.0
#   (5 arc-min rasters, 0-100%, years 2000/2005/2010/2015/2020).
#
# RUN FROM WORKSPACE ROOT:
#   Rscript "Feature explorations/Biosphere/scripts/5_bii_planetary_boundary.R"
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

# ---- study area (same 32-country frame as the rest of Biosphere) -------------
STUDY <- c("AT","BE","BG","HR","CY","CZ","DK","EE","FI","FR","DE","EL","HU","IE",
           "IT","LV","LT","LU","MT","NL","PL","PT","RO","SK","SI","ES","SE","UK",
           "IS","LI","NO","CH")
euro <- ext(-25, 45, 34, 72)
cn    <- vect(file.path(shared, "CNTR_RG_10M_2024_4326.geojson"))
study <- crop(cn[cn$CNTR_ID %in% STUDY, ], euro)

# ---- planetary-boundary breakpoints ------------------------------------------
# safe >= 90 ; uncertainty zone 30-90 ; beyond < 30   (Steffen 2015 / Newbold 2016)
brk  <- c(90, 30)
lab  <- c("Inside safe limit (BII >= 90%)",
          "Zone of increasing risk (30-90%)",
          "Beyond the boundary (BII < 30%)")
pal  <- c("#1A9850", "#FDAE61", "#A50026")   # green / orange / dark red
# classify() rules: [from, to) -> id
rcl  <- rbind(c(90, 101, 1), c(30, 90, 2), c(-1, 30, 3))

years <- c(2000, 2005, 2010, 2015, 2020)
read_bii <- function(y) {
  r <- rast(file.path(bii_dir, sprintf("bii-%d_v2-1-1.tif", y)))
  mask(crop(r, study), study)
}

cat("reading BII rasters ...\n")
bii <- lapply(years, read_bii); names(bii) <- years
b2015 <- bii[["2015"]]
cat("BII 2015 value range (study area):\n"); print(minmax(b2015))

# ---- MAIN MAP: 2015 boundary-status ------------------------------------------
cls <- classify(b2015, rcl)
levels(cls) <- data.frame(id = 1:3, status = lab)

png(file.path(out_maps, "bii_planetary_boundary_2015.png"),
    width = 2400, height = 2400, res = 230)
par(mar = c(2, 2, 4, 1))
plot(cls, col = pal, type = "classes", axes = TRUE, mar = c(2, 2, 4, 12),
     maxcell = ncell(cls),
     main = "Biosphere integrity vs the planetary boundary\nBII 2015 (NHM v2.1.1), Europe",
     plg = list(cex = 0.95, title = "Status vs BII = 90% boundary"))
lines(study, col = "grey25", lwd = 0.3)
dev.off()
cat("wrote bii_planetary_boundary_2015.png\n")

# ---- also a plain continuous BII 2015 map (for reference) --------------------
png(file.path(out_maps, "bii_value_2015.png"), width = 2400, height = 2400, res = 230)
par(mar = c(2, 2, 4, 1))
plot(b2015, col = rev(hcl.colors(64, "Greens")), type = "continuous",
     axes = TRUE, mar = c(2, 2, 4, 9), maxcell = ncell(b2015),
     main = "Biodiversity Intactness Index 2015 (%)\nNHM v2.1.1, Europe",
     plg = list(title = "BII %"))
lines(study, col = "grey25", lwd = 0.3)
dev.off()
cat("wrote bii_value_2015.png\n")

# ---- TABLE: area-share per boundary class, per year (trajectory) -------------
# area-weighted (cells are 5 arc-min in degrees -> real area shrinks poleward)
area_share <- function(r) {
  a  <- cellSize(r, unit = "km")
  st <- classify(r, rcl)
  va <- values(a)[, 1]; vs <- values(st)[, 1]
  k  <- !is.na(vs) & !is.na(va)
  tot <- sum(va[k])
  sapply(1:3, function(i) 100 * sum(va[k][vs[k] == i]) / tot)
}

mat <- sapply(years, function(y) area_share(bii[[as.character(y)]]))
tab <- data.frame(year = years,
                  safe_ge90_pct      = round(mat[1, ], 1),
                  risk_30_90_pct     = round(mat[2, ], 1),
                  beyond_lt30_pct    = round(mat[3, ], 1),
                  mean_bii_pct       = round(sapply(years, function(y)
                      global(bii[[as.character(y)]], "mean", na.rm = TRUE)[1, 1]), 1))
write.csv(tab, file.path(out_tables, "bii_boundary_status_by_year.csv"), row.names = FALSE)

# ---- console summary ---------------------------------------------------------
cat("\n================ BII vs PLANETARY BOUNDARY - Europe study area ================\n")
cat("Share of land area by status vs the BII=90% boundary (area-weighted):\n\n")
print(tab, row.names = FALSE)
cat(sprintf("\nIn 2015, %.1f%% of European study-area land is INSIDE the safe limit;\n",
            tab$safe_ge90_pct[tab$year == 2015]))
cat(sprintf("%.1f%% sits in the zone of increasing risk and %.1f%% is beyond the boundary.\n",
            tab$risk_30_90_pct[tab$year == 2015], tab$beyond_lt30_pct[tab$year == 2015]))
cat(sprintf("Mean BII fell from %.1f%% (2000) to %.1f%% (2020).\n",
            tab$mean_bii_pct[tab$year == 2000], tab$mean_bii_pct[tab$year == 2020]))
cat("\nWrote: bii_planetary_boundary_2015.png, bii_value_2015.png,\n")
cat("       bii_boundary_status_by_year.csv\n")
