# =============================================================================
# map_anthromes.R  -- Layer A feature "biosphere around us"
# Anthromes v2 (year 2000, Ellis & Ramankutty) grouped into 6 ordered levels
# (wild -> semi-natural -> rangelands -> croplands -> villages -> dense settl.)
# masked to the 32 study countries, styled like the heatwave maps.
# =============================================================================
suppressMessages(library(terra))
setwd(here::here())

anthro_tif <- "Feature explorations/Biosphere/data_raw/biosphere/anthromes_v2/2000/anthro2_a2000.tif"
cntr_geo   <- "Feature explorations/_shared/CNTR_RG_10M_2024_4326.geojson"
outdir     <- "Feature explorations/Biosphere/data_processed"
out_maps   <- file.path(outdir, "maps")
out_tables <- file.path(outdir, "tables")
dir.create(out_maps, showWarnings = FALSE, recursive = TRUE)
dir.create(out_tables, showWarnings = FALSE, recursive = TRUE)

STUDY <- c("AT","BE","BG","HR","CY","CZ","DK","EE","FI","FR","DE","EL","HU","IE",
           "IT","LV","LT","LU","MT","NL","PL","PT","RO","SK","SI","ES","SE","UK",
           "IS","LI","NO","CH")

# ---- code (11-62) -> level (1-6) --------------------------------------------
# 6 wild, 5 semi-natural, 4 rangelands, 3 croplands, 2 villages, 1 dense settl.
lvl_of <- function(code) {
  grp <- floor(code / 10)            # 1..6 (settlements..wild)
  # map anthrome first-digit group to ordered natural->built level
  # 6x wild(61,62), 5x seminat(51-54), 4x range(41-43), 3x crop(31-34),
  # 2x village(21-24), 1x settle(11,12)
  c(NA,1,2,3,4,5,6)[grp + 1L]        # grp 1->1(settle)...6->6(wild)? invert below
}
# We want level 1 = most natural (wild). Build explicit lookup:
code2lvl <- rbind(
  c(61,1), c(62,1),                                  # Wildlands
  c(51,2), c(52,2), c(53,2), c(54,2),                # Semi-natural
  c(41,3), c(42,3), c(43,3),                         # Rangelands
  c(31,4), c(32,4), c(33,4), c(34,4),                # Croplands
  c(21,5), c(22,5), c(23,5), c(24,5),                # Villages
  c(11,6), c(12,6))                                  # Dense settlements

labels <- c("Wildlands","Semi-natural","Rangelands","Croplands",
            "Villages","Dense settlements")
pal <- c("#145A32","#7DCEA0","#D5C77A","#E9B44C","#D98A45","#922B21")

# ---- data -------------------------------------------------------------------
r  <- rast(anthro_tif)
cn <- vect(cntr_geo)
study <- cn[cn$CNTR_ID %in% STUDY, ]

# focus on the European window (drop overseas territories that stretch the frame)
euro  <- ext(-25, 45, 34, 72)
study <- crop(study, euro)

r <- crop(r, euro)
r <- mask(r, study)

# reclassify to levels
rl <- classify(r, code2lvl, others = NA)
levels(rl) <- data.frame(value = 1:6, level = labels)
names(rl) <- "biosphere"

# ---- map --------------------------------------------------------------------
png(file.path(out_maps, "anthromes_2000_europe.png"), width = 2000, height = 2000, res = 220)
par(mar = c(2,2,3,1))
plot(rl, col = pal, type = "classes", axes = TRUE, mar = c(2,2,3,8),
     plg = list(cex = 0.9, title = "Biosphere around us"),
     main = "What biosphere surrounds Europeans? (Anthromes v2, year 2000)")
lines(study, col = "grey25", lwd = 0.4)
dev.off()
cat("wrote anthromes_2000_europe.png\n")

# ---- composition (share of study-area land in each level) -------------------
rln <- rl; levels(rln) <- NULL       # drop categories so freq returns 1..6
fr <- freq(rln)                      # value, count
fr$label <- labels[fr$value]
fr$pct   <- round(100 * fr$count / sum(fr$count), 1)
fr <- fr[order(fr$value), c("value","label","count","pct")]
write.csv(fr, file.path(out_tables, "anthromes_composition_2000.csv"), row.names = FALSE)

cat("\n==== Biosphere composition of the study area (2000) ====\n")
print(fr[, c("label","pct")], row.names = FALSE)
natural <- sum(fr$pct[fr$value %in% 1:2])
serving <- sum(fr$pct[fr$value %in% 3:4])
built   <- sum(fr$pct[fr$value %in% 5:6])
cat(sprintf("\nUnaltered/near-natural (wild + semi-natural): %.1f%%\n", natural))
cat(sprintf("Human-serving land (rangelands + croplands):  %.1f%%\n", serving))
cat(sprintf("Settlements (villages + dense):               %.1f%%\n", built))
