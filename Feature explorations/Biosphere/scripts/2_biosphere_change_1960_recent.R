# =============================================================================
# 2_biosphere_change_1960_recent.R  -- biosphere evolution 1960 -> recent
# 4 maps in NATIVE classes (not harmonised): HILDA+ land-cover (1960, 2019) and
# Anthromes-12K anthrome levels (1960, 2015), + composition-change tables
# + a population-weighted "experienced" map (HILDA+ 2019).
# HILDA+ read windowed from OpenLandMap COGs (no 4.9 GB download).
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
euro  <- ext(-25, 45, 34, 72)

# ---- native class schemes ----------------------------------------------------
# HILDA+ land-cover (6 classes)
hilda_lab <- c("Urban","Cropland","Pasture/rangeland","Forest",
               "Unmanaged grass/shrub","Sparse/no vegetation")
hilda_pal <- c("#A6291F","#E9B44C","#D9CF8C","#1E6B3A","#8FBF6F","#CDBBA0")
hilda_rcl <- rbind(c(11,1),c(22,2),c(33,3),c(44,4),c(55,5),c(66,6))  # others -> NA

# Anthromes-12K anthrome levels (6, natural -> built)
anthro_lab <- c("Wildlands","Semi-natural","Rangelands","Croplands",
                "Villages","Dense settlements")
anthro_pal <- c("#145A32","#7DCEA0","#D5C77A","#E9B44C","#D98A45","#922B21")
anthro_rcl <- rbind(c(61,1),c(62,1),c(63,1),
                    c(51,2),c(52,2),c(53,2),c(54,2),
                    c(41,3),c(42,3),c(43,3),
                    c(31,4),c(32,4),c(33,4),c(34,4),
                    c(21,5),c(22,5),c(23,5),c(24,5),
                    c(11,6),c(12,6))                                  # 70 -> NA

cn    <- vect(file.path(shared, "CNTR_RG_10M_2024_4326.geojson"))
study <- crop(cn[cn$CNTR_ID %in% STUDY, ], euro)

as_cat <- function(x, labs) { levels(x) <- data.frame(id = seq_along(labs), class = labs); x }
hilda_url <- function(y)
  sprintf("/vsicurl/https://s3.openlandmap.org/arco/land.use.land.cover_hilda.plus_c_1km_s_%d0101_%d1231_go_espg.4326_v1.0.tif", y, y)

load_hilda <- function(y) {                            # NATIVE 1 km (no aggregation)
  r <- crop(rast(hilda_url(y)), euro)                 # windowed read over Europe
  r <- classify(r, hilda_rcl, others = NA)
  as_cat(mask(r, study), hilda_lab)
}
load_anthro <- function(f) {
  r <- crop(rast(file.path(bio, "anthromes_12k", f)), euro)
  r <- classify(r, anthro_rcl, others = NA)
  as_cat(mask(r, study), anthro_lab)
}

cat("Loading HILDA+ 1960 / 2019 ...\n"); h60 <- load_hilda(1960); h19 <- load_hilda(2019)
cat("Loading Anthromes 1960 / 2015 ...\n"); a60 <- load_anthro("anthromes1960AD.asc"); a15 <- load_anthro("anthromes2015AD.asc")

# ---- two 2-panel figures at highest native resolution -----------------------
drw <- function(r, pal, ttl, leg)
  { plot(r, col = pal, type = "classes", legend = leg, axes = TRUE,
         mar = c(2.5,2.5,3,9), main = ttl, plg = list(cex = 1.0),
         maxcell = terra::ncell(r)) }                 # no display downsampling

# HILDA+ : native 1 km
png(file.path(out_maps, "biosphere_hilda_1960_2019.png"),
    width = 11000, height = 3600, res = 300)
par(mfrow = c(1,2), oma = c(0,0,3,0))
drw(h60, hilda_pal, "1960", FALSE); lines(study, col = "grey30", lwd = 0.25)
drw(h19, hilda_pal, "2019", TRUE);  lines(study, col = "grey30", lwd = 0.25)
mtext("HILDA+ (observed land cover, native 1 km) - biosphere around Europeans, 1960 -> 2019",
      outer = TRUE, cex = 1.5, font = 2, line = 0.3)
dev.off()
cat("wrote biosphere_hilda_1960_2019.png\n")

# Anthromes-12K : native 5 arcmin
png(file.path(out_maps, "biosphere_anthromes_1960_2015.png"),
    width = 11000, height = 3600, res = 300)
par(mfrow = c(1,2), oma = c(0,0,3,0))
drw(a60, anthro_pal, "1960", FALSE); lines(study, col = "grey30", lwd = 0.25)
drw(a15, anthro_pal, "2015", TRUE);  lines(study, col = "grey30", lwd = 0.25)
mtext("Anthromes-12K (modelled anthromes, native 5 arcmin) - biosphere around Europeans, 1960 -> 2015",
      outer = TRUE, cex = 1.5, font = 2, line = 0.3)
dev.off()
cat("wrote biosphere_anthromes_1960_2015.png\n")

# ---- composition-change tables (per native class) ---------------------------
comp <- function(r, labs) {
  rr <- r; levels(rr) <- NULL; f <- freq(rr)
  round(100 * f$count[match(seq_along(labs), f$value)] / sum(f$count), 1)
}
cat("\n==== HILDA+ composition (% of study-area land) ====\n")
hc <- data.frame(class = hilda_lab, y1960 = comp(h60, hilda_lab), y2019 = comp(h19, hilda_lab))
hc$change_pp <- round(hc$y2019 - hc$y1960, 1); print(hc, row.names = FALSE)
cat("\n==== Anthromes-12K composition (% of study-area land) ====\n")
ac <- data.frame(class = anthro_lab, y1960 = comp(a60, anthro_lab), y2015 = comp(a15, anthro_lab))
ac$change_pp <- round(ac$y2015 - ac$y1960, 1); print(ac, row.names = FALSE)
write.csv(hc, file.path(out_tables, "biosphere_composition_change_hilda.csv"), row.names = FALSE)
write.csv(ac, file.path(out_tables, "biosphere_composition_change_anthromes.csv"), row.names = FALSE)

# ---- population-weighted "experienced" biosphere (HILDA+ 2019) --------------
b   <- mask(aggregate(classify(crop(rast(hilda_url(2019)), euro), hilda_rcl, others = NA),
                      12, fun = "modal", na.rm = TRUE), study)          # ~0.1 deg
pop <- resample(rast(file.path(shared, "pop2020_0p1deg.tif")), b, method = "bilinear")
bv  <- values(b)[,1]; pv <- values(pop)[,1]; pv[is.na(pv)] <- 0
w   <- log1p(pv); wmax <- as.numeric(quantile(w[w > 0], 0.99, na.rm = TRUE)); w <- pmin(w / wmax, 1)
prgb <- col2rgb(hilda_pal); tmpl <- b; levels(tmpl) <- NULL
R <- G <- B <- rep(NA_real_, length(bv))
for (k in seq_along(hilda_lab)) { idx <- which(bv == k); ww <- w[idx]
  R[idx] <- 255*(1-ww) + prgb[1,k]*ww; G[idx] <- 255*(1-ww) + prgb[2,k]*ww; B[idx] <- 255*(1-ww) + prgb[3,k]*ww }
rgbstack <- c(setValues(tmpl, R), setValues(tmpl, G), setValues(tmpl, B))
png(file.path(out_maps, "biosphere_population_weighted_2019.png"), width = 2000, height = 2000, res = 220)
par(mar = c(2,2,3,1))
plotRGB(rgbstack, r=1, g=2, b=3, colNA = "white", axes = TRUE, mar = c(2,2,3,1),
        main = "Biosphere as experienced (saturation = where people live)  -  HILDA+ 2019 x population")
lines(study, col = "grey40", lwd = 0.4)
legend("bottomleft", legend = hilda_lab, fill = hilda_pal, bty = "n", cex = 0.9,
       title = "HILDA+ land cover (pale = few people)")
dev.off()
cat("\nwrote biosphere_population_weighted_2019.png\n")

# ---- population-weighted composition (share of PEOPLE) -----------------------
popw <- function(r, labs, tag, y) {
  vv <- values(resample(r, pop, method = "near"))[,1]
  ptot <- tapply(pv, vv, sum)
  data.frame(dataset = tag, year = y, class = labs,
             pct_people = round(100 * ptot[as.character(seq_along(labs))] / sum(pv), 1)) }
cat("\n==== Population-weighted composition (share of PEOPLE) ====\n")
ph <- popw(h19, hilda_lab, "HILDA+", 2019); pa <- popw(a15, anthro_lab, "Anthromes", 2015)
print(ph, row.names = FALSE); cat("\n"); print(pa, row.names = FALSE)
write.csv(rbind(ph, pa), file.path(out_tables, "biosphere_composition_popweighted.csv"), row.names = FALSE)
