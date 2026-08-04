# =============================================================================
# 4_change_freq_intensity_hilda.R
# #1  HILDA+ change-frequency map: number of land-use changes per pixel 1960-2019
#     (HILDA+ signature metric; precomputed change-freq layer).
# +   Intensity Analysis (Aldwaik & Pontius 2012) for HILDA 1960 -> 2019.
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
euro <- ext(-25, 45, 34, 72); Tt <- 2019 - 1960
cn    <- vect(file.path(shared, "CNTR_RG_10M_2024_4326.geojson"))
study <- crop(cn[cn$CNTR_ID %in% STUDY, ], euro)

# ---- #1 change-frequency maps (two resolutions) -----------------------------
# The change-freq counts run 0..59 over the study area, but ~10% of the land sits
# at 4+ changes with a long thin tail - so the old flat "4+" class hid a real
# signal in one colour and is dropped. Two complementary renderings instead:
#   - 1 km, LOG colour scale       -> fine analysis, every pixel kept
#   - ~10 km, MEAN changes per cell -> continental communication, reads as regions
# Rationale for aggregating: 6.6M 1 km pixels at continental scale render as
# speckle (the display grid is coarser than the data); aggregating to the map's
# legible unit is the cartographic gold standard (ESRI; Making Effective Maps).
cf0 <- crop(rast(file.path(bio,"hilda_plus","hildap_vGLOB-1.0_change-layers",
                           "HILDAplus_vGLOB-1.0_luc_change-freq_1960-2019_wgs84.tif")), euro)
cf  <- mask(cf0, study)
cat("change-freq value range:\n"); print(minmax(cf))

pal_c <- hcl.colors(100, "YlOrRd", rev = TRUE)

# -- (a) 1 km, log colour scale (fine analysis) --
# stable pixels (0 changes, ~65% of land) show the grey base; 1..max on log10.
lc <- cf; lc[lc == 0] <- NA; lc <- log10(lc)
cmax  <- as.integer(minmax(cf)[2])
ticks <- c(1, 2, 3, 5, 10, 20, 50)
png(file.path(out_maps,"change_freq_hilda_1960_2019_log.png"), width=2600, height=2600, res=250)
par(mar=c(2,2,4,1))
plot(study, col="#ECECEC", border=NA, axes=TRUE, mar=c(2,2,4,10),
     main="Land-use churn 1960-2019: number of changes per pixel (HILDA+)\nlog scale, 1 km - grey = never changed")
plot(lc, col=pal_c, type="continuous", add=TRUE, range=log10(c(1, cmax)), maxcell=ncell(lc),
     plg=list(title="changes\n(log scale)", at=log10(ticks), labels=as.character(ticks)))
lines(study, col="grey35", lwd=0.3)
dev.off(); cat("wrote change_freq_hilda_1960_2019_log.png\n")

# -- (b) ~10 km, mean changes per cell (communication) --
# aggregate on the UNmasked grid so coastal 10x10 blocks stay full, then mask.
# the coarse grid is also written to disk so the 10 km layer is reusable for analysis.
agg <- mask(aggregate(cf0, fact=10, fun="mean", na.rm=TRUE), study)
writeRaster(agg, file.path(out,"hilda_change_freq_10km_mean.tif"), overwrite=TRUE)
hi <- as.numeric(global(agg, fun=function(x) quantile(x, .98, na.rm=TRUE)))  # clamp to 98th pct
png(file.path(out_maps,"change_freq_hilda_1960_2019_10km.png"), width=2600, height=2600, res=250)
par(mar=c(2,2,4,1))
plot(study, col="#ECECEC", border=NA, axes=TRUE, mar=c(2,2,4,10),
     main="Land-use churn 1960-2019: mean changes per ~10 km cell (HILDA+)\nspatially aggregated from 1 km")
plot(agg, col=pal_c, type="continuous", add=TRUE, range=c(0, hi),
     plg=list(title="mean changes\nper ~10 km cell"))
lines(study, col="grey35", lwd=0.4)
dev.off(); cat("wrote change_freq_hilda_1960_2019_10km.png\n")

pctchg <- 100*global(cf>0, "mean", na.rm=TRUE)[1,1]
cat(sprintf("Share of study-area land that changed at least once 1960-2019: %.1f%%\n", pctchg))

# ---- Intensity Analysis (HILDA 6 classes) -----------------------------------
hlab <- c("Urban","Cropland","Pasture/rangeland","Forest","Unmanaged grass/shrub","Sparse/no veg")
hrcl <- rbind(c(11,1),c(22,2),c(33,3),c(44,4),c(55,5),c(66,6))
hurl <- function(y) sprintf("/vsicurl/https://s3.openlandmap.org/arco/land.use.land.cover_hilda.plus_c_1km_s_%d0101_%d1231_go_espg.4326_v1.0.tif", y, y)
lh <- function(y) mask(classify(crop(rast(hurl(y)), euro), hrcl, others=NA), study)
cat("reading HILDA 1960 / 2019 states ...\n"); h60 <- lh(1960); h19 <- lh(2019)

v1 <- values(h60)[,1]; v2 <- values(h19)[,1]; k <- !is.na(v1) & !is.na(v2)
M <- matrix(as.numeric(table(factor(v1[k],1:6), factor(v2[k],1:6))),6,6)
tot <- sum(M); changed <- tot - sum(diag(M)); U <- 100*changed/(Tt*tot)
s1 <- rowSums(M); s2 <- colSums(M); gain <- s2-diag(M); loss <- s1-diag(M)
gain_int <- 100*gain/(Tt*s2); loss_int <- 100*loss/(Tt*s1)

cat(sprintf("\n== HILDA Interval level ==\nNet-different land 1960-2019: %.1f%% of area\nUniform annual intensity U = %.3f %%/yr\n",
            100*changed/tot, U))
ia <- data.frame(class=hlab, size1960_pct=round(100*s1/tot,1), size2019_pct=round(100*s2/tot,1),
                 gain_intensity=round(gain_int,3), loss_intensity=round(loss_int,3),
                 active_gain=ifelse(gain_int>U,"ACTIVE","dormant"),
                 active_loss=ifelse(loss_int>U,"ACTIVE","dormant"))
cat("\n== HILDA Category level ==\n"); print(ia, row.names=FALSE)
write.csv(ia, file.path(out_tables,"intensity_analysis_hilda.csv"), row.names=FALSE)
write.csv(M, file.path(out_tables,"transition_matrix_hilda.csv"))

png(file.path(out_maps,"intensity_analysis_hilda.png"), width=2000, height=1300, res=210)
par(mar=c(8,4,3,1))
mids <- barplot(rbind(loss_int, gain_int), beside=TRUE, names.arg=hlab, las=2,
        col=c("#D73027","#1A9850"), border=NA, ylab="Change intensity (%/yr)",
        main="Intensity Analysis - HILDA+ 1960-2019 (bars above line = ACTIVE)")
abline(h=U, lty=2, lwd=2, col="grey20"); text(max(mids), U, sprintf(" U=%.3f", U), pos=3, col="grey20", cex=0.9)
legend("topright", c("Loss intensity","Gain intensity"), fill=c("#D73027","#1A9850"), bty="n")
dev.off(); cat("wrote intensity_analysis_hilda.png\n")
