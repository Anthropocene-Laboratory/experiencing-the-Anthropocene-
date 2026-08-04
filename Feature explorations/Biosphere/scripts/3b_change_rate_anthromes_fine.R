# =============================================================================
# 3b_change_rate_anthromes_fine.R
# B4 refined: same "toward built / toward nature" arrow as 3_change_rate, but on
# a FINER ordinal scale built from the 20 native anthrome classes.
#
# Principle: the 20 classes are NOT a single ranked ladder. They cross
#   (a) an INTENSITY axis (residential > populated > remote), which IS ordinal;
#   (b) a land-use TYPE axis (rice / irrigated / rainfed village; woodland /
#       dryland / ice), which is NOT ordinal.
# So we refine the 6 levels ONLY along axis (a): within a level, the
# residential/populated/remote population-density gradient breaks the tie;
# classes that differ only by TYPE keep the SAME rank (ties preserved).
# Result: a 13-step natural -> built scale instead of 6.
#   delta = rank(2015) - rank(1960)   (>0 anthropisation, <0 renaturation)
# =============================================================================
suppressMessages(library(terra))
setwd(here::here())
bio    <- "Feature explorations/Biosphere/data_raw/biosphere"
shared <- "Feature explorations/_shared"
out    <- "Feature explorations/Biosphere/data_processed"
out_maps   <- file.path(out, "maps")
out_tables <- file.path(out, "tables")
dir.create(out_maps, showWarnings = FALSE, recursive = TRUE)
dir.create(out_tables, showWarnings = FALSE, recursive = TRUE)

STUDY <- c("AT","BE","BG","HR","CY","CZ","DK","EE","FI","FR","DE","EL","HU","IE",
           "IT","LV","LT","LU","MT","NL","PL","PT","RO","SK","SI","ES","SE","UK",
           "IS","LI","NO","CH")
euro <- ext(-25, 45, 34, 72); Tt <- 2015 - 1960

# ---- 20 native classes -> 13-step ordinal rank (natural=1 ... built=13) ------
# level               native codes            rank   (ties = TYPE-only splits)
# Wildlands           61 wild wood, 62 wild dry, 63 ice        -> 1
# Semi-natural        53 remote wood ->2 ; 52 pop wood,54 inhab dry ->3 ; 51 resid wood ->4
# Rangelands          43 remote ->5 ; 42 populated ->6 ; 41 residential ->7
# Croplands           34 remote ->8 ; 33 populated ->9 ; 32 resid rainfed,31 resid irrig ->10
# Villages            21 rice,22 irrig,23 rainfed,24 pastoral  -> 11  (type only)
# Dense settlements   12 mixed ->12 ; 11 urban ->13
frcl <- rbind(
  c(61,1), c(62,1), c(63,1),
  c(53,2),
  c(52,3), c(54,3),
  c(51,4),
  c(43,5),
  c(42,6),
  c(41,7),
  c(34,8),
  c(33,9),
  c(32,10), c(31,10),
  c(21,11), c(22,11), c(23,11), c(24,11),
  c(12,12),
  c(11,13))                                                     # 70 -> NA

# fine rank -> coarse 6-level (to separate within-level moves from level crossings)
coarse_of_rank <- c(1,2,2,2,3,3,3,4,4,4,5,6,6)                  # length 13

cn    <- vect(file.path(shared, "CNTR_RG_10M_2024_4326.geojson"))
study <- crop(cn[cn$CNTR_ID %in% STUDY, ], euro)
rnk <- function(f) mask(classify(crop(rast(file.path(bio,"anthromes_12k",f)), euro), frcl, others=NA), study)
r60 <- rnk("anthromes1960AD.asc"); r15 <- rnk("anthromes2015AD.asc")

# ---- B4 (fine) map -----------------------------------------------------------
delta <- r15 - r60
dcl <- rbind(c(-99,-1.5,1), c(-1.5,-0.5,2), c(-0.5,0.5,3), c(0.5,1.5,4), c(1.5,99,5))
dmap <- classify(delta, dcl)
dlab <- c("Toward nature (-2 or more)","Slightly toward nature (-1)","Stable (0)",
          "Slightly toward built (+1)","Toward built (+2 or more)")
dpal <- c("#1A9850","#A6D96A","#F2F2F2","#FDAE61","#D73027")
levels(dmap) <- data.frame(id=1:5, change=dlab)

png(file.path(out_maps, "change_rate_anthromes_fine_1960_2015.png"), width=2200, height=2200, res=220)
par(mar=c(2,2,3,1))
plot(dmap, col=dpal, type="classes", axes=TRUE, mar=c(2,2,3,9), maxcell=ncell(dmap),
     main="Anthropisation of the biosphere, 1960 -> 2015 (13-step anthrome scale)",
     plg=list(cex=0.9, title="direction & magnitude"))
lines(study, col="grey30", lwd=0.3)
dev.off(); cat("wrote change_rate_anthromes_fine_1960_2015.png\n")

# ---- how much extra signal does the finer scale reveal? ----------------------
v1 <- values(r60)[,1]; v2 <- values(r15)[,1]; k <- !is.na(v1) & !is.na(v2)
v1 <- v1[k]; v2 <- v2[k]; n <- length(v1)
c1 <- coarse_of_rank[v1]; c2 <- coarse_of_rank[v2]
moved_fine   <- v1 != v2
moved_coarse <- c1 != c2
within_level <- moved_fine & !moved_coarse                     # invisible to 6-level B4
cat(sprintf("\nPixels moving on the FINE scale : %.2f%% of land\n", 100*mean(moved_fine)))
cat(sprintf("Pixels moving on the 6-LEVEL scale: %.2f%% of land\n", 100*mean(moved_coarse)))
cat(sprintf("Extra moves seen ONLY by the fine scale (within-level intensity shifts): %.2f%% of land\n",
            100*mean(within_level)))
cat(sprintf("  -> the finer scale detects %.0f%% more moving pixels than the 6-level map\n",
            100*(mean(moved_fine)/mean(moved_coarse) - 1)))

# composition of the fine map
rr <- dmap; levels(rr) <- NULL; f <- freq(rr)
cat("\nFine-scale change map composition (% of study-area land):\n")
comp <- data.frame(class=dlab, pct=round(100*f$count[match(1:5, f$value)]/sum(f$count),1))
print(comp, row.names=FALSE)
write.csv(comp, file.path(out_tables,"change_rate_anthromes_fine_composition.csv"), row.names=FALSE)
