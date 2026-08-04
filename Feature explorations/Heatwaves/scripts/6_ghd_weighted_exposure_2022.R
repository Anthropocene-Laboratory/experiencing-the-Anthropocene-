# =============================================================================
# 6_ghd_weighted_exposure_2022.R
# Alternative A (raffinement dasymetrique) : redistribue le budget-temps GHD
# sur la grille 0.1 deg via un proxy spatial (population vs cropland fraction),
# puis pondere les heatwave-days TX 2022 par les heures outdoor.
#
# Sortie : exposition "corrigee" (cropland pour categories foncieres) vs
# "naive" (tout pop-pondere), + diagnostic de covariance HW_crop/HW_pop par pays.
#
# RUN FROM WORKSPACE ROOT :
#   Rscript "Feature explorations/Heatwaves/scripts/6_ghd_weighted_exposure_2022.R"
# =============================================================================

suppressMessages(library(terra))
setwd(here::here())
pd     <- "Feature explorations/Heatwaves/data_processed"
raw    <- "Feature explorations/Heatwaves/data_raw"
shared <- "Feature explorations/_shared"
out_tables <- file.path(pd, "tables")
dir.create(out_tables, showWarnings = FALSE, recursive = TRUE)

# ---- 1. Pays d'etude : ISO2 (grille/frontieres) <-> ISO3 (GHD) ---------------
iso <- data.frame(
  iso2 = c("AT","BE","BG","HR","CY","CZ","DK","EE","FI","FR","DE","EL","HU","IE",
           "IT","LV","LT","LU","MT","NL","PL","PT","RO","SK","SI","ES","SE","UK",
           "IS","LI","NO","CH"),
  iso3 = c("AUT","BEL","BGR","HRV","CYP","CZE","DNK","EST","FIN","FRA","DEU","GRC","HUN","IRL",
           "ITA","LVA","LTU","LUX","MLT","NLD","POL","PRT","ROU","SVK","SVN","ESP","SWE","GBR",
           "ISL","LIE","NOR","CHE"),
  stringsAsFactors = FALSE)

# ---- 2. Table categorie -> (poids f_k, proxy spatial) ------------------------
# f_k = coefficient outdoor (Option A binaire : 1 = outdoor, 0.5 = mixte).
# proxy = "crop" (categories foncieres) ou "pop" (categories liees au batî/gens).
cat_tab <- data.frame(
  sub   = c("Food growth & collection","Materials","Inhabited environment",
            "Infrastructure","Buildings","Waste management",
            "Active recreation","Human transportation","Material transportation"),
  f     = c(1.0, 1.0, 0.5,   1.0, 1.0, 1.0,   0.5, 0.5, 0.5),
  proxy = c("crop","crop","crop", "pop","pop","pop", "pop","pop","pop"),
  stringsAsFactors = FALSE)

# ---- 3. Rasters : grille modele (HW TX), population, cropland fraction --------
hw_tx <- rast(file.path(pd, "heatwave_days_2022_tx_w2.nc"))
names(hw_tx) <- "hw_tx"
pop   <- rast(file.path(shared, "pop2020_0p1deg.tif"))

# cropland fraction 0-100 (GLAD/Potapov 1km 2022) -> fraction 0-1 a 0.1 deg
cf_path <- file.path(pd, "crop_frac_0p1deg.tif")
if (!file.exists(cf_path)) {
  cat("Preparing crop_frac_0p1deg.tif from GLAD 1km ...\n")
  cr1k <- rast(file.path(raw, "landcover", "cropland_glad_1km_2022.tif"))
  cr1k <- crop(cr1k, ext(hw_tx))                       # limiter a l'Europe
  fac  <- max(1, round(res(hw_tx)[1] / res(cr1k)[1]))  # ~12
  cr_ag <- aggregate(cr1k, fact = fac, fun = "mean", na.rm = TRUE)
  crop_frac <- resample(cr_ag, hw_tx, method = "bilinear")
  crop_frac <- clamp(crop_frac, 0, 100) / 100          # -> fraction 0-1
  names(crop_frac) <- "crop_frac"
  writeRaster(crop_frac, cf_path, overwrite = TRUE)
} else {
  crop_frac <- rast(cf_path)
}

# aligner pop et crop sur la grille HW
pop       <- resample(pop, hw_tx, method = "bilinear")
crop_frac <- resample(crop_frac, hw_tx, method = "bilinear")

# ---- 4. Frontieres -> raster d'identifiants pays -----------------------------
cn <- vect(file.path(shared, "CNTR_RG_10M_2024_4326.geojson"))
cn <- cn[cn$CNTR_ID %in% iso$iso2, ]
cn$idx  <- match(cn$CNTR_ID, iso$iso2)
cid_r <- rasterize(cn, hw_tx, field = "idx")

# noms anglais (un par pays)
nm <- data.frame(iso2 = cn$CNTR_ID, name = cn$NAME_ENGL, stringsAsFactors = FALSE)
nm <- nm[!duplicated(nm$iso2), ]
iso$name <- nm$name[match(iso$iso2, nm$iso2)]

# ---- 5. GHD : heures/jour par pays x sous-categorie --------------------------
ghd <- read.csv(file.path(raw, "global_human_day", "outputData", "all_countries.csv"),
                stringsAsFactors = FALSE)
ghd <- ghd[ghd$countryISO3 %in% iso$iso3 & ghd$Subcategory %in% cat_tab$sub, ]
# moyenne au cas ou plusieurs lignes region par pays
ghd <- aggregate(hoursPerDayCombined ~ countryISO3 + Subcategory, data = ghd, FUN = mean)

hours_of <- function(iso3, sub) {
  v <- ghd$hoursPerDayCombined[ghd$countryISO3 == iso3 & ghd$Subcategory == sub]
  if (length(v) == 0) NA_real_ else v[1]
}

# ---- 6. Vecteurs pleine grille -----------------------------------------------
cid  <- values(cid_r)[, 1]
hwv  <- values(hw_tx)[, 1]
popv <- values(pop)[, 1];  popv[is.na(popv)] <- 0
crv  <- values(crop_frac)[, 1]; crv[is.na(crv)] <- 0

exp_corr <- rep(NA_real_, length(hwv))   # exposition redistribuee (proxy mixte)
exp_naiv <- rep(NA_real_, length(hwv))   # exposition tout-pop-ponderee

res_rows <- list()

for (k in seq_len(nrow(iso))) {
  sel <- which(cid == k & !is.na(hwv))
  if (length(sel) == 0) next
  i3 <- iso$iso3[k]

  p  <- popv[sel]; cr <- crv[sel]; hw <- hwv[sel]
  PopC <- sum(p)
  # poids spatiaux (normalises a 1) ; repli sur pop si pas de cropland/pop
  w_pop  <- if (PopC > 0)      p  / PopC      else rep(1/length(sel), length(sel))
  crmass <- sum(cr * p)   # cropland pondere par presence humaine (ou cr seul ?)
  # NB : on veut OU se fait l'activite agricole -> fraction cropland pure
  crsum  <- sum(cr)
  w_crop <- if (crsum > 0) cr / crsum else w_pop

  # heures outdoor par cellule (corrige : proxy selon categorie ; naif : tout pop)
  oh_corr <- numeric(length(sel))
  oh_naiv <- numeric(length(sel))
  ghd_missing <- FALSE
  for (r in seq_len(nrow(cat_tab))) {
    h <- hours_of(i3, cat_tab$sub[r])
    if (is.na(h)) { ghd_missing <- TRUE; next }
    contrib <- cat_tab$f[r] * h * PopC          # personne-heures/jour nationales
    w <- if (cat_tab$proxy[r] == "crop") w_crop else w_pop
    oh_corr <- oh_corr + contrib * w
    oh_naiv <- oh_naiv + contrib * w_pop
  }
  exp_corr[sel] <- hw * oh_corr
  exp_naiv[sel] <- hw * oh_naiv

  # diagnostic covariance : HW moyen pondere cropland vs population
  hw_pop  <- sum(w_pop  * hw)
  hw_crop <- if (crsum > 0) sum(w_crop * hw) else NA_real_
  res_rows[[k]] <- data.frame(
    iso2 = iso$iso2[k], name = iso$name[k],
    pop = round(PopC),
    exp_naive_ph  = sum(exp_naiv[sel]),
    exp_corr_ph   = sum(exp_corr[sel]),
    pct_change    = 100 * (sum(exp_corr[sel]) - sum(exp_naiv[sel])) / sum(exp_naiv[sel]),
    hw_pop = round(hw_pop, 2),
    hw_crop = round(hw_crop, 2),
    hw_ratio = round(hw_crop / hw_pop, 3),
    ghd_missing = ghd_missing,
    stringsAsFactors = FALSE)
}

df <- do.call(rbind, res_rows)
df <- df[order(-df$exp_corr_ph), ]

# ---- 7. Sorties --------------------------------------------------------------
out_corr <- setValues(hw_tx, exp_corr); names(out_corr) <- "ghd_exp_tx_ph"
writeRaster(out_corr, file.path(pd, "ghd_weighted_exposure_2022_tx.nc"), overwrite = TRUE)

df$exp_naive_ph <- round(df$exp_naive_ph)
df$exp_corr_ph  <- round(df$exp_corr_ph)
df$pct_change   <- round(df$pct_change, 1)
write.csv(df, file.path(out_tables, "ghd_weighted_exposure_2022_tx.csv"), row.names = FALSE)

# ---- 8. Resume console -------------------------------------------------------
fmt <- function(x) format(round(x), big.mark = ",")
cat("\n================ GHD-WEIGHTED EXPOSURE 2022 (TX outdoor) ================\n")
cat(sprintf("Total outdoor heatwave person-HOURS  (naif, tout pop) : %s\n", fmt(sum(df$exp_naive_ph))))
cat(sprintf("Total outdoor heatwave person-HOURS  (corrige cropland): %s\n", fmt(sum(df$exp_corr_ph))))
cat(sprintf("Effet net de la redistribution        : %+.1f%%\n\n",
            100*(sum(df$exp_corr_ph)-sum(df$exp_naive_ph))/sum(df$exp_naive_ph)))

cat("-- Top 12 pays par personne-heures outdoor (corrige) --\n")
show <- head(df[, c("name","exp_corr_ph","pct_change","hw_ratio")], 12)
print(show, row.names = FALSE)

cat("\n-- Diagnostic covariance : hw_ratio = HW(cropland) / HW(population) --\n")
cat("   > 1  => cropland dans zones plus chaudes => la redistribution AUGMENTE l'expo agricole\n")
cat("   < 1  => l'inverse\n")
dd <- df[!is.na(df$hw_ratio), ]
dd <- dd[order(-dd$hw_ratio), ]
print(head(dd[, c("name","hw_ratio","pct_change")], 8), row.names = FALSE)
cat("   ... bas de tableau ...\n")
print(tail(dd[, c("name","hw_ratio","pct_change")], 5), row.names = FALSE)

if (any(df$ghd_missing)) {
  cat(sprintf("\n[!] GHD manquant pour : %s (categories ignorees pour ces pays)\n",
              paste(df$iso2[df$ghd_missing], collapse = ", ")))
}
cat("\nEcrit : ghd_weighted_exposure_2022_tx.nc + ghd_weighted_exposure_2022_tx.csv\n")
