# Improved maps for the 2022 heatwave-exposure prototype (TX-based standard).
# Fixes vs the quick draft: (1) sequential palette 0=pale -> high=dark red (not
# inverted); (2) clipped to the European study area; (3) both the hazard (TX
# heatwave days) and the exposure (person-days) are mapped; (4) country totals.
#
# Usage: Rscript 5_visualize_maps_2022.R [W]

suppressMessages(library(terra))
args <- commandArgs(trailingOnly = TRUE)
W <- if (length(args) >= 1) as.integer(args[1]) else 2L

proc_dir   <- normalizePath(file.path("Feature explorations", "Heatwaves", "data_processed"), mustWork = TRUE)
raw_dir    <- normalizePath(file.path("Feature explorations", "Heatwaves", "data_raw"), mustWork = TRUE)
shared_dir <- normalizePath(file.path("Feature explorations", "_shared"), mustWork = TRUE)
out_maps   <- file.path(proc_dir, "maps")
dir.create(out_maps, showWarnings = FALSE, recursive = TRUE)

STUDY <- c("AT","BE","BG","HR","CY","CZ","DK","EE","FI","FR","DE","EL","HU","IE",
           "IT","LV","LT","LU","MT","NL","PL","PT","RO","SK","SI","ES","SE","UK",
           "IS","LI","NO","CH")
cn <- vect(file.path(shared_dir, "CNTR_RG_10M_2024_4326.geojson"))
study <- cn[cn$CNTR_ID %in% STUDY, ]

hw  <- rast(file.path(proc_dir, sprintf("heatwave_days_2022_tx_w%d.nc", W)))
exp <- rast(file.path(proc_dir, sprintf("exposed_person_days_2022_tx_w%d.nc", W)))

# clip to study area
hw_s  <- mask(crop(hw,  study), study)
exp_s <- mask(crop(exp, study), study)

pal <- rev(hcl.colors(64, "YlOrRd"))       # 0 = pale, high = dark red

# --- map 1: TX heatwave days ---
png(file.path(out_maps, "heatwave_map_2022_tx.png"), width = 1200, height = 1050, res = 150)
plot(hw_s, col = pal, type = "continuous",
     main = "Jours de canicule (TX > P90, >=3 j) - Europe, ete 2022",
     plg = list(title = "jours"), axes = TRUE)
plot(study, add = TRUE, border = "gray40", lwd = 0.4)
dev.off()

# --- map 2: person-days exposed (log10 scale; 0 shown as background) ---
le <- exp_s; le[le <= 0] <- NA; le <- log10(le)
png(file.path(out_maps, "exposure_map_2022_tx.png"), width = 1200, height = 1050, res = 150)
plot(le, col = pal, type = "continuous",
     main = "Personne-jours de canicule exposes - Europe, 2022 (echelle log10)",
     plg = list(title = "log10(pers.-jours)"), axes = TRUE)
plot(study, add = TRUE, border = "gray40", lwd = 0.4)
dev.off()

# --- country totals (sanity check) ---
tot <- extract(exp, study, fun = sum, na.rm = TRUE, ID = FALSE)[, 1]
ct  <- data.frame(country = study$NAME_ENGL, person_days = round(tot))
ct  <- ct[order(-ct$person_days), ]
cat("Total study-area heatwave person-days 2022:",
    format(sum(ct$person_days, na.rm = TRUE), big.mark = ","), "\n\n")
cat("Top 12 countries by heatwave person-days exposed (2022):\n")
print(head(ct, 12), row.names = FALSE)
cat("\nWrote heatwave_map_2022_tx.png and exposure_map_2022_tx.png\n")
