# =============================================================================
# 7_population_map.R
# Base map of the population layer (shared Layer-B). Rendered from the NATIVE
# GHS-POP R2023A source at 30 arc-seconds (~1 km) - the aggregated 0.1 deg
# _shared/pop2020_0p1deg.tif is a downsampled derivative used for grid-matched
# BII/heatwave weighting; for the visual map we use the full ~1 km resolution.
# Finer resolution improves the picture only; it does NOT change the BII stats.
#
# Native source (already local, no download):
#   Heatwaves/data_raw/ghsl_pop_30arcsec/GHS_POP_E2020_GLOBE_R2023A_4326_30ss_V1_0.tif
#
# RUN FROM WORKSPACE ROOT:
#   Rscript "Feature explorations/Biosphere/scripts/7_population_map.R"
# =============================================================================
suppressMessages(library(terra))
setwd(here::here())

shared   <- "Feature explorations/_shared"
pop_src  <- "Feature explorations/Heatwaves/data_raw/ghsl_pop_30arcsec/GHS_POP_E2020_GLOBE_R2023A_4326_30ss_V1_0.tif"
out      <- "Feature explorations/Biosphere/data_processed"
out_maps <- file.path(out, "maps")
dir.create(out_maps, showWarnings = FALSE, recursive = TRUE)

STUDY <- c("AT","BE","BG","HR","CY","CZ","DK","EE","FI","FR","DE","EL","HU","IE",
           "IT","LV","LT","LU","MT","NL","PL","PT","RO","SK","SI","ES","SE","UK",
           "IS","LI","NO","CH")
euro <- ext(-25, 45, 34, 72)
cn    <- vect(file.path(shared, "CNTR_RG_10M_2024_4326.geojson"))
study <- crop(cn[cn$CNTR_ID %in% STUDY, ], euro)

pop <- rast(pop_src)                 # global ~1 km
pop <- crop(pop, euro)               # windowed read -> Europe only
pop <- mask(pop, study)
cat("native population grid (cropped):\n"); print(pop)

tot <- global(pop, "sum", na.rm = TRUE)[1, 1]
cat(sprintf("Total study-area population (GHS-POP 2020, ~1 km): %s\n",
            format(round(tot), big.mark = ",")))

# Gold-standard gridded-population idiom (Kontur / Alasdair Rae / "night-lights"):
# a perceptually-uniform LUMINANCE ramp on a DARK canvas. Population is heavily
# skewed, so we log-transform; the low end of Inferno is near-black and BLENDS
# into the black background (few people = dark = ~empty, which is honest), while
# dense cities glow bright yellow. This removes the misleading light-background /
# dark-low-density clash of the previous version: there is no white background to
# fight the dark low end any more.
lp <- pop; lp[lp < 1] <- NA; lp <- log10(lp)
pal   <- hcl.colors(64, "Inferno")               # low = near-black, high = bright yellow
ticks <- c(1, 10, 100, 1000, 10000)              # legend in PERSONS, not log units

png(file.path(out_maps, "population_2020.png"), width = 3200, height = 3200, res = 270, bg = "black")
par(mar = c(2, 2, 4, 11), bg = "black", fg = "grey80",
    col.axis = "grey80", col.lab = "grey80", col.main = "white")
plot(lp, col = pal, type = "continuous", colNA = "black", axes = TRUE, maxcell = 8e6,
     range = log10(c(1, 15000)), main = "",
     plg = list(title = "persons /\n~1 km cell", title.cex = 0.9, at = log10(ticks),
                labels = format(ticks, big.mark = ",")),
     pax = list(col.axis = "grey80"))
lines(study, col = "grey60", lwd = 0.5)          # country borders, kept subtle on the dark canvas
title(main = "Where Europeans live\nResident population 2020 (GHS-POP, ~1 km)",
      col.main = "white")
dev.off()
cat("wrote population_2020.png (~1 km, dark luminance gold-standard)\n")
