# =============================================================================
# 3_change_rate_anthromes.R
# #4  Rate/direction of transformation, Anthromes-12K 1960 -> 2015, on the
#     ordinal 6-level scale (1 Wildlands ... 6 Dense settlements):
#     delta = level(2015) - level(1960)  (>0 anthropisation, <0 renaturation)
# +   Intensity Analysis (Aldwaik & Pontius 2012): interval- and category-level.
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
euro <- ext(-25, 45, 34, 72); T <- 2015 - 1960
labs <- c("Wildlands","Semi-natural","Rangelands","Croplands","Villages","Dense settlements")
rcl  <- rbind(c(61,1),c(62,1),c(63,1), c(51,2),c(52,2),c(53,2),c(54,2),
              c(41,3),c(42,3),c(43,3), c(31,4),c(32,4),c(33,4),c(34,4),
              c(21,5),c(22,5),c(23,5),c(24,5), c(11,6),c(12,6))        # 70 -> NA

cn    <- vect(file.path(shared, "CNTR_RG_10M_2024_4326.geojson"))
study <- crop(cn[cn$CNTR_ID %in% STUDY, ], euro)
lvl <- function(f) mask(classify(crop(rast(file.path(bio,"anthromes_12k",f)), euro), rcl, others=NA), study)
l60 <- lvl("anthromes1960AD.asc"); l15 <- lvl("anthromes2015AD.asc")

# ---- #4 rate/direction map ---------------------------------------------------
delta <- l15 - l60
dcl <- rbind(c(-9,-1.5,1), c(-1.5,-0.5,2), c(-0.5,0.5,3), c(0.5,1.5,4), c(1.5,9,5))
dmap <- classify(delta, dcl)
dlab <- c("Renatured (-2 or more)","Toward nature (-1)","Stable (0)",
          "Toward built (+1)","Built up (+2 or more)")
dpal <- c("#1A9850","#A6D96A","#F2F2F2","#FDAE61","#D73027")
levels(dmap) <- data.frame(id=1:5, change=dlab)

png(file.path(out_maps, "change_rate_anthromes_1960_2015.png"), width=2200, height=2200, res=220)
par(mar=c(2,2,3,1))
plot(dmap, col=dpal, type="classes", axes=TRUE, mar=c(2,2,3,9), maxcell=ncell(dmap),
     main="Anthropisation of the biosphere, 1960 -> 2015 (Anthromes level change)",
     plg=list(cex=0.9, title="direction & magnitude"))
lines(study, col="grey30", lwd=0.3)
dev.off(); cat("wrote change_rate_anthromes_1960_2015.png\n")

# ---- Intensity Analysis ------------------------------------------------------
v1 <- values(l60)[,1]; v2 <- values(l15)[,1]; k <- !is.na(v1) & !is.na(v2)
M  <- table(factor(v1[k],1:6), factor(v2[k],1:6)); M <- matrix(as.numeric(M),6,6)
tot <- sum(M); changed <- tot - sum(diag(M))
U <- 100*changed/(T*tot)                                   # uniform annual intensity (%/yr)
s1 <- rowSums(M); s2 <- colSums(M)
gain <- s2 - diag(M); loss <- s1 - diag(M)
gain_int <- 100*gain/(T*s2); loss_int <- 100*loss/(T*s1)   # %/yr of category area

cat(sprintf("\n== Interval level ==\nStudy-area land changed 1960-2015: %.1f%% of area\nUniform annual change intensity U = %.3f %%/yr\n",
            100*changed/tot, U))
ia <- data.frame(class=labs, size1960_pct=round(100*s1/tot,1), size2015_pct=round(100*s2/tot,1),
                 gain_intensity=round(gain_int,3), loss_intensity=round(loss_int,3),
                 active_gain=ifelse(gain_int>U,"ACTIVE","dormant"),
                 active_loss=ifelse(loss_int>U,"ACTIVE","dormant"))
cat("\n== Category level (intensity vs uniform U) ==\n"); print(ia, row.names=FALSE)
write.csv(ia, file.path(out_tables,"intensity_analysis_anthromes.csv"), row.names=FALSE)
write.csv(M, file.path(out_tables,"transition_matrix_anthromes.csv"))

png(file.path(out_maps, "intensity_analysis_anthromes.png"), width=2000, height=1300, res=210)
par(mar=c(7,4,3,1))
mids <- barplot(rbind(loss_int, gain_int), beside=TRUE, names.arg=labs, las=2,
        col=c("#D73027","#1A9850"), border=NA, ylab="Change intensity (%/yr)",
        main="Intensity Analysis - Anthromes 1960-2015 (bars above line = ACTIVE)")
abline(h=U, lty=2, lwd=2, col="grey20"); text(max(mids), U, sprintf(" uniform U=%.3f", U), pos=3, col="grey20", cex=0.9)
legend("topleft", c("Loss intensity","Gain intensity"), fill=c("#D73027","#1A9850"), bty="n")
dev.off(); cat("wrote intensity_analysis_anthromes.png\n")
