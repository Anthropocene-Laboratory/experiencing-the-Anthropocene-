# =============================================================================
# 9_wealth_gridded_kummu.R
# Fine-grid WEALTH map (Layer-B filter): GDP per capita PPP downscaled to
# admin-2 and rendered on a ~10 km grid (Kummu et al. 2025, Sci Data), year 2022.
# Unlike the national choropleth (script 8), this shows INTRA-country wealth
# gradients (metropolitan cores vs rural peripheries) - the lived-experience
# texture that a national map flattens.
#
# Source: Kummu et al. 2025, Zenodo 13943886, rast_adm2_gdp_perCapita (5 arcmin).
# CC-BY. File in _shared/gdp_kummu/ (cross-feature reference data).
#
# RUN FROM WORKSPACE ROOT:
#   Rscript "Feature explorations/Biosphere/scripts/9_wealth_gridded_kummu.R"
# =============================================================================
suppressMessages(library(terra))
setwd(here::here())

shared   <- "Feature explorations/_shared"
out      <- "Feature explorations/Biosphere/data_processed"
out_maps <- file.path(out, "maps")
dir.create(out_maps, showWarnings = FALSE, recursive = TRUE)

STUDY <- c("AT","BE","BG","HR","CY","CZ","DK","EE","FI","FR","DE","EL","HU","IE",
           "IT","LV","LT","LU","MT","NL","PL","PT","RO","SK","SI","ES","SE","UK",
           "IS","LI","NO","CH")
euro <- ext(-25, 45, 34, 72)
cn    <- vect(file.path(shared, "CNTR_RG_10M_2024_4326.geojson"))
study <- crop(cn[cn$CNTR_ID %in% STUDY, ], euro)

g <- rast(file.path(shared, "gdp_kummu", "rast_adm2_gdp_perCapita_1990_2022.tif"))["gdp_pc_2022"]
g <- mask(crop(g, study), study)
cat("2022 GDP/capita range (study area):\n"); print(minmax(g))

# robust display range (2-98% quantile) so a few high cells don't wash out
qs <- global(g, fun = function(x) quantile(x, c(.02, .98), na.rm = TRUE))
lo <- round(as.numeric(qs[1]), -3); hi <- round(as.numeric(qs[2]), -3)
cat(sprintf("display range clamped to %s - %s $/capita\n",
            format(lo, big.mark=","), format(hi, big.mark=",")))

pal <- colorRampPalette(c("#f7fcf5","#c7e9c0","#74c476","#238b45","#00441b"))(100)
png(file.path(out_maps, "wealth_gdp_pc_gridded_2022.png"), width = 2400, height = 2400, res = 240)
par(mar = c(2,2,4,1))
plot(g, col = pal, type = "continuous", range = c(lo, hi), maxcell = 4e6,
     mar = c(2,2,4,9), axes = TRUE,
     main = "Wealth, fine grid: GDP per capita (PPP) 2022, ~10 km\nKummu et al. 2025 (admin-2 downscaled) - intra-country gradients",
     plg = list(title = "$ / capita"))
lines(study, col = "grey45", lwd = 0.3)
dev.off()
cat("wrote wealth_gdp_pc_gridded_2022.png\n")
