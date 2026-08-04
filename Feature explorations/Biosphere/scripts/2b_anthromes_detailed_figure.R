# =============================================================================
# 2b_anthromes_detailed_figure.R
# Anthromes-12K in its FULL native 20-class scheme (official ArcGIS palette from
# the anthromes R package, Gauthier / Ellis et al. 2020), 1960 vs 2015,
# masked to the 32 study countries. High-resolution 2-panel figure.
# =============================================================================
suppressMessages(library(terra))
setwd(here::here())
bio    <- "Feature explorations/Biosphere/data_raw/biosphere"
shared <- "Feature explorations/_shared"
out    <- "Feature explorations/Biosphere/data_processed"
out_maps <- file.path(out, "maps")
dir.create(out_maps, showWarnings = FALSE, recursive = TRUE)

STUDY <- c("AT","BE","BG","HR","CY","CZ","DK","EE","FI","FR","DE","EL","HU","IE",
           "IT","LV","LT","LU","MT","NL","PL","PT","RO","SK","SI","ES","SE","UK",
           "IS","LI","NO","CH")
euro <- ext(-25, 45, 34, 72)

# ---- official 20-class key + palette (from anthromes::anthrome_colors('class'))
code <- c(11,12,21,22,23,24,31,32,33,34,41,42,43,51,52,53,54,61,62,63)  # 70 -> NA
labs <- c("Urban","Mixed settlements","Rice villages","Irrigated villages",
          "Rainfed villages","Pastoral villages","Residential irrigated croplands",
          "Residential rainfed croplands","Populated croplands","Remote croplands",
          "Residential rangelands","Populated rangelands","Remote rangelands",
          "Residential woodlands","Populated woodlands","Remote woodlands",
          "Inhabited drylands","Wild woodlands","Wild drylands","Ice")
pal  <- c("#A80000","#FF0000","#0070FF","#00A9E6","#A900E6","#FF73DF","#00FFC5",
          "#E6E600","#FFFF73","#FFFFBE","#E69800","#FFD37F","#FFEBAF","#38A800",
          "#A5F57A","#D3FFB2","#D9BD75","#DAF2EA","#E1E1E1","#FAFFFF")
rcl  <- cbind(code, seq_along(code))                       # code -> id 1..20 ; 70 -> NA

cn    <- vect(file.path(shared, "CNTR_RG_10M_2024_4326.geojson"))
study <- crop(cn[cn$CNTR_ID %in% STUDY, ], euro)

load_detail <- function(f) {
  r <- crop(rast(file.path(bio, "anthromes_12k", f)), euro)
  r <- classify(r, rcl, others = NA)
  r <- mask(r, study)
  levels(r) <- data.frame(id = seq_along(labs), class = labs)  # full 20-class table
  r
}
a60 <- load_detail("anthromes1960AD.asc")
a15 <- load_detail("anthromes2015AD.asc")

png(file.path(out_maps, "biosphere_anthromes_detailed_1960_2015.png"),
    width = 11000, height = 3600, res = 300)
par(mfrow = c(1,2), oma = c(0,0,3,0))
drw <- function(r, ttl, leg)
  { plot(r, col = pal, type = "classes", legend = leg, axes = TRUE,
         mar = c(2.5,2.5,3,14), main = ttl, plg = list(cex = 0.95),
         maxcell = terra::ncell(r))
    lines(study, col = "grey30", lwd = 0.25) }
drw(a60, "1960", FALSE)
drw(a15, "2015", TRUE)
mtext("Anthromes-12K - full 20-class native scheme (official palette) - biosphere around Europeans, 1960 -> 2015",
      outer = TRUE, cex = 1.5, font = 2, line = 0.3)
dev.off()
cat("wrote biosphere_anthromes_detailed_1960_2015.png\n")

# composition in the 20 detailed classes (2015)
rr <- a15; levels(rr) <- NULL; f <- freq(rr)
comp <- data.frame(class = labs, pct_2015 = round(100*f$count[match(seq_along(labs), f$value)]/sum(f$count),2))
print(comp[order(-comp$pct_2015),], row.names = FALSE)
