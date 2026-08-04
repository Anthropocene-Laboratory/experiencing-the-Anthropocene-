# =============================================================================
# 4b_change_freq_hilda_v2.R
# Recreate the HILDA+ v1 change-frequency map with HILDA+ v2.0.
#
# Comparability rule: v2 categories are first harmonised to the six v1 classes.
# A change is counted only when a pixel changes between those broad classes.
# The analysed interval is kept at 1960-2019 (59 annual transitions), even
# though HILDA+ v2.0 also provides 2020.
# =============================================================================
suppressMessages(library(terra))

root <- here::here()
setwd(root)

bio        <- "Feature explorations/Biosphere/data_raw/biosphere"
shared     <- "Feature explorations/_shared"
out        <- "Feature explorations/Biosphere/data_processed"
out_maps   <- file.path(out, "maps")
out_tables <- file.path(out, "tables")
v2_dir     <- file.path(bio, "hilda_plus_v2")
v2_zip     <- file.path(v2_dir, "hildap_vGLOB-2.0_geotiff_wgs84.zip")
states_dir <- file.path(v2_dir, "states_wgs84")
v2_url     <- "https://download.pangaea.de/dataset/974335/files/hildap_vGLOB-2.0_geotiff_wgs84.zip"
v2_md5     <- "56fe959df25d8efbc542b90cf971945f"

dir.create(out_maps, showWarnings=FALSE, recursive=TRUE)
dir.create(out_tables, showWarnings=FALSE, recursive=TRUE)
dir.create(v2_dir, showWarnings=FALSE, recursive=TRUE)

YEAR_START <- 1960L
YEAR_END   <- 2019L
years <- YEAR_START:YEAR_END
state_names <- sprintf("hilda_plus_states_%d_GLOB-v2_wgs84.tif", years)
state_files <- file.path(states_dir, state_names)
use_extracted_states <- all(file.exists(state_files))

# The local project contains the 60 required state rasters selectively extracted
# from the official 3.5 GB ZIP. A complete ZIP is also supported for portability.
if (!use_extracted_states) {
  if (!file.exists(v2_zip)) {
    message("Downloading HILDA+ v2.0 WGS84 GeoTIFF archive (about 3.5 GB) ...")
    download.file(v2_url, v2_zip, mode="wb", method="libcurl", quiet=FALSE)
  }
  if (file.info(v2_zip)$size != 3755961841) {
    stop("Missing extracted states and HILDA+ v2.0 archive has an unexpected size: ", v2_zip)
  }
}
STUDY <- c("AT","BE","BG","HR","CY","CZ","DK","EE","FI","FR","DE","EL","HU","IE",
           "IT","LV","LT","LU","MT","NL","PL","PT","RO","SK","SI","ES","SE","UK",
           "IS","LI","NO","CH")
euro  <- ext(-25, 45, 34, 72)
cn    <- vect(file.path(shared, "CNTR_RG_10M_2024_4326.geojson"))
study <- crop(cn[cn$CNTR_ID %in% STUDY, ], euro)

state_path <- function(year) {
  name <- sprintf("hilda_plus_states_%d_GLOB-v2_wgs84.tif", year)
  if (use_extracted_states) return(file.path(states_dir, name))
  # GDAL reads individual GeoTIFF members directly from a complete local ZIP.
  zip_slash <- normalizePath(v2_zip, winslash="/", mustWork=TRUE)
  sprintf("/vsizip/%s/hildap_vGLOB-2.0_geotiff_wgs84/states/%s", zip_slash, name)
}

# v2 -> v1 thematic harmonisation:
# urban; all cropland subclasses; pasture; all forest subclasses;
# unmanaged grass/shrub; sparse/no vegetation. Ocean, water and no-data are NA.
v2_to_v1 <- rbind(
  c(11, 1),
  c(22, 2), c(23, 2), c(24, 2),
  c(33, 3),
  c(40, 4), c(41, 4), c(42, 4), c(43, 4), c(44, 4), c(45, 4),
  c(55, 5),
  c(66, 6)
)
broad_state <- function(year) {
  classify(crop(rast(state_path(year)), euro), v2_to_v1, others=NA)
}

message("Counting broad-class annual changes for 1960-2019 ...")
previous <- broad_state(YEAR_START)
change_freq <- ifel(is.na(previous), 0, 0)
for (year in (YEAR_START + 1L):YEAR_END) {
  message(sprintf("  %d -> %d", year - 1L, year))
  current <- broad_state(year)
  changed <- ifel(is.na(previous) | is.na(current), 0,
                  ifel(previous != current, 1, 0))
  change_freq <- change_freq + changed
  previous <- current
  # Break terra's lazy expression chain before it grows large enough to exhaust
  # memory. Counts fit safely in an unsigned byte (maximum = 59).
  if ((year - YEAR_START) %% 10L == 0L || year == YEAR_END) {
    checkpoint <- file.path(tempdir(), sprintf("hilda_v2_change_freq_%d.tif", year))
    change_freq <- writeRaster(change_freq, checkpoint, overwrite=TRUE,
                               datatype="INT1U",
                               gdal=c("COMPRESS=LZW", "TILED=YES"))
    gc()
  }
}
names(change_freq) <- "broad_class_change_count_1960_2019"

# Apply exactly the original map's spatial logic: aggregate the unmasked WGS84
# crop by 10 x 10 source pixels (0.1 degrees, approximately 10 km), then mask.
cf_study <- mask(change_freq, study)
agg <- mask(aggregate(change_freq, fact=10, fun="mean", na.rm=TRUE), study)
names(agg) <- "mean_broad_class_changes_1960_2019"

out_tif <- file.path(out, "hilda_v2_change_freq_1960_2019_10km_mean.tif")
writeRaster(agg, out_tif, overwrite=TRUE,
            gdal=c("COMPRESS=DEFLATE", "PREDICTOR=3", "TILED=YES"))

hi <- as.numeric(global(agg, fun=function(x) quantile(x, .98, na.rm=TRUE)))
pal_c <- hcl.colors(100, "YlOrRd", rev=TRUE)
out_png <- file.path(out_maps, "change_freq_hilda_v2_1960_2019_10km.png")
png(out_png, width=2600, height=2600, res=250)
par(mar=c(2,2,4,1))
plot(study, col="#ECECEC", border=NA, axes=TRUE, mar=c(2,2,4,10),
     main="Land-use churn 1960-2019: mean changes per ~10 km cell (HILDA+ v2.0)\nspatially aggregated from 1 km; harmonised to six v1 classes")
plot(agg, col=pal_c, type="continuous", add=TRUE, range=c(0, hi),
     plg=list(title="mean changes\nper ~10 km cell"))
lines(study, col="grey35", lwd=0.4)
dev.off()

# Numerical QA and direct comparison with the existing v1 layer.
v1_path <- file.path(bio, "hilda_plus", "hildap_vGLOB-1.0_change-layers",
                     "HILDAplus_vGLOB-1.0_luc_change-freq_1960-2019_wgs84.tif")
v1_cf <- crop(rast(v1_path), euro)
v1_study <- mask(v1_cf, study)
v1_agg <- mask(aggregate(v1_cf, fact=10, fun="mean", na.rm=TRUE), study)

pair <- values(c(v1_agg, agg), mat=TRUE)
pair <- pair[complete.cases(pair), , drop=FALSE]
qa <- data.frame(
  metric=c(
    "source_doi", "input_mode", "input_file_count", "input_total_bytes",
    "source_archive_md5_expected",
    "period_start", "period_end", "annual_transitions",
    "v2_1km_min", "v2_1km_max", "v2_share_changed_pct",
    "v1_10km_p98", "v2_10km_p98", "v1_10km_mean", "v2_10km_mean",
    "v2_minus_v1_10km_mean", "v2_vs_v1_10km_mae", "v2_vs_v1_10km_pearson_r"
  ),
  value=c(
    "10.1594/PANGAEA.974335",
    if (use_extracted_states) "60 extracted WGS84 state GeoTIFFs" else "official WGS84 ZIP",
    if (use_extracted_states) length(state_files) else 1,
    if (use_extracted_states) sum(file.info(state_files)$size) else file.info(v2_zip)$size,
    v2_md5,
    YEAR_START, YEAR_END, YEAR_END - YEAR_START,
    as.numeric(global(cf_study, "min", na.rm=TRUE)[1,1]),
    as.numeric(global(cf_study, "max", na.rm=TRUE)[1,1]),
    100 * as.numeric(global(cf_study > 0, "mean", na.rm=TRUE)[1,1]),
    as.numeric(global(v1_agg, fun=function(x) quantile(x, .98, na.rm=TRUE))),
    hi,
    mean(pair[,1]), mean(pair[,2]), mean(pair[,2] - pair[,1]),
    mean(abs(pair[,2] - pair[,1])), cor(pair[,1], pair[,2])
  )
)
write.csv(qa, file.path(out_tables, "change_freq_hilda_v2_1960_2019_qa.csv"), row.names=FALSE)

message("Wrote: ", out_png)
message("Wrote: ", out_tif)
message("Wrote numerical QA table; expected source MD5: ", v2_md5)
