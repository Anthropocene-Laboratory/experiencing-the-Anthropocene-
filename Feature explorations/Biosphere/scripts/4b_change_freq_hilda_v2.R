# =============================================================================
# 4b_change_freq_hilda_v2.R
# Recreate the HILDA+ v1 change-frequency map with HILDA+ v2.0.
#
# Comparability rule: v2 categories are first harmonised to the six v1 classes.
# A change is counted only when a pixel changes between those broad classes.
# The analysed interval is kept at 1960-2019 (59 annual transitions), even
# though HILDA+ v2.0 also provides 2020.
#
# Automatic download + analysis:
#   Rscript "Feature explorations/Biosphere/scripts/4b_change_freq_hilda_v2.R"
# Manual ZIP already downloaded elsewhere (do not change the working directory):
#   Rscript "Feature explorations/Biosphere/scripts/4b_change_freq_hilda_v2.R" --archive="D:/Downloads/hildap_vGLOB-2.0_geotiff_wgs84.zip"
# Acquisition only:
#   Rscript "Feature explorations/Biosphere/scripts/4b_change_freq_hilda_v2.R" --download-only
# =============================================================================
suppressMessages(library(terra))

root <- here::here()
setwd(root)

args <- commandArgs(trailingOnly=TRUE)
arg_value <- function(name) {
  hit <- grep(paste0("^", name, "="), args, value=TRUE)
  if (length(hit)) sub(paste0("^", name, "="), "", hit[1]) else ""
}
unknown <- args[!args %in% c("--download-only", "--verify-md5") &
                !grepl("^--(archive|states-dir)=", args)]
if (length(unknown)) {
  stop("Unknown argument(s): ", paste(unknown, collapse=", "),
       "\nValid arguments: --archive=<zip> --states-dir=<folder> ",
       "--download-only --verify-md5", call.=FALSE)
}
download_only <- "--download-only" %in% args
verify_md5    <- "--verify-md5" %in% args

bio        <- "Feature explorations/Biosphere/data_raw/biosphere"
shared     <- "Feature explorations/_shared"
out        <- "Feature explorations/Biosphere/data_processed"
out_maps   <- file.path(out, "maps")
out_tables <- file.path(out, "tables")
v2_dir         <- file.path(bio, "hilda_plus_v2")
default_v2_zip <- file.path(v2_dir, "hildap_vGLOB-2.0_geotiff_wgs84.zip")
archive_arg    <- arg_value("--archive")
if (!nzchar(archive_arg)) archive_arg <- Sys.getenv("HILDA_V2_ARCHIVE", unset="")
v2_zip <- if (nzchar(archive_arg)) {
  normalizePath(path.expand(archive_arg), winslash="/", mustWork=FALSE)
} else {
  default_v2_zip
}
states_arg <- arg_value("--states-dir")
if (nzchar(archive_arg) && nzchar(states_arg)) {
  stop("Use either --archive or --states-dir, not both.", call.=FALSE)
}
states_dir <- if (nzchar(states_arg)) {
  normalizePath(path.expand(states_arg), winslash="/", mustWork=FALSE)
} else {
  file.path(v2_dir, "states_wgs84")
}
v2_url     <- "https://download.pangaea.de/dataset/974335/files/hildap_vGLOB-2.0_geotiff_wgs84.zip"
v2_md5     <- "56fe959df25d8efbc542b90cf971945f"
v2_bytes   <- 3755961841

dir.create(out_maps, showWarnings=FALSE, recursive=TRUE)
dir.create(out_tables, showWarnings=FALSE, recursive=TRUE)
dir.create(v2_dir, showWarnings=FALSE, recursive=TRUE)

YEAR_START <- 1960L
YEAR_END   <- 2019L
years <- YEAR_START:YEAR_END
state_names <- sprintf("hilda_plus_states_%d_GLOB-v2_wgs84.tif", years)
state_files <- file.path(states_dir, state_names)
use_extracted_states <- !nzchar(archive_arg) && all(file.exists(state_files))
if (nzchar(states_arg) && !use_extracted_states) {
  missing_states <- state_names[!file.exists(state_files)]
  stop("The folder supplied with --states-dir is missing ", length(missing_states),
       " required file(s), beginning with: ", paste(head(missing_states, 3), collapse=", "),
       call.=FALSE)
}

# The 60 state rasters may be extracted, or the official ZIP may be read in
# place. An explicit --archive path takes precedence over the repository cache.
if (!use_extracted_states) {
  if (!file.exists(v2_zip)) {
    if (nzchar(archive_arg)) {
      stop("The archive supplied with --archive or HILDA_V2_ARCHIVE does not exist: ",
           v2_zip, call.=FALSE)
    }
    message("Downloading HILDA+ v2.0 WGS84 GeoTIFF archive (about 3.5 GB) ...")
    part <- paste0(v2_zip, ".part")
    curl_bin <- Sys.which("curl")
    if (file.exists(part) && file.info(part)$size == v2_bytes) {
      message("Complete .part file found; finalising it without downloading again.")
    } else if (nzchar(curl_bin)) {
      status <- system2(unname(curl_bin), c(
        "--fail", "--location", "--retry", "3", "--continue-at", "-",
        "--output", shQuote(part), shQuote(v2_url)))
      if (!identical(status, 0L)) {
        stop("HILDA+ download failed (curl exit code ", status,
             "). The partial file was kept for a resumable retry: ", part,
             call.=FALSE)
      }
    } else {
      download.file(v2_url, part, mode="wb", method="libcurl", quiet=FALSE)
    }
    if (!file.exists(part) || file.info(part)$size != v2_bytes) {
      stop("The HILDA+ download is incomplete: ", part,
           "\nExpected ", v2_bytes, " bytes; found ",
           if (file.exists(part)) file.info(part)$size else 0,
           ". Re-run the command to resume it.", call.=FALSE)
    }
    if (!file.rename(part, v2_zip)) {
      stop("Download completed, but the temporary file could not be renamed to: ",
           v2_zip, call.=FALSE)
    }
    verify_md5 <- TRUE
  }
  if (file.info(v2_zip)$size != v2_bytes) {
    stop("The HILDA+ archive has an unexpected size: ", v2_zip,
         "\nExpected ", v2_bytes, " bytes; found ", file.info(v2_zip)$size,
         ". This is often an HTML error page or an incomplete download.", call.=FALSE)
  }
  if (verify_md5) {
    message("Verifying HILDA+ archive MD5 (this reads the full 3.5 GB file) ...")
    actual_md5 <- unname(tools::md5sum(v2_zip))
    if (!identical(tolower(actual_md5), v2_md5)) {
      stop("HILDA+ archive MD5 mismatch. Expected ", v2_md5,
           "; found ", actual_md5, ". File: ", v2_zip, call.=FALSE)
    }
  }
}

if (download_only) {
  message("HILDA+ input is ready: ",
          if (use_extracted_states) states_dir else v2_zip)
} else {
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

# Numerical QA. The direct v1 comparison is optional because HILDA+ v1 is a
# separate manual-only download; absence of v1 must not invalidate the v2 run.
v1_path <- file.path(bio, "hilda_plus", "hildap_vGLOB-1.0_change-layers",
                     "HILDAplus_vGLOB-1.0_luc_change-freq_1960-2019_wgs84.tif")
v1_p98 <- v1_mean <- difference_mean <- comparison_mae <- comparison_r <- NA_real_
comparison_status <- "skipped: HILDA+ v1 change layer not found (optional manual input)"
v2_values <- values(agg, mat=FALSE)
v2_mean <- mean(v2_values, na.rm=TRUE)
if (file.exists(v1_path)) {
  v1_cf <- crop(rast(v1_path), euro)
  v1_agg <- mask(aggregate(v1_cf, fact=10, fun="mean", na.rm=TRUE), study)
  pair <- values(c(v1_agg, agg), mat=TRUE)
  pair <- pair[complete.cases(pair), , drop=FALSE]
  v1_p98 <- as.numeric(global(v1_agg, fun=function(x) quantile(x, .98, na.rm=TRUE)))
  v1_mean <- mean(pair[,1])
  v2_mean <- mean(pair[,2])
  difference_mean <- mean(pair[,2] - pair[,1])
  comparison_mae <- mean(abs(pair[,2] - pair[,1]))
  comparison_r <- cor(pair[,1], pair[,2])
  comparison_status <- "completed"
} else {
  message("Optional v1 comparison skipped; missing: ", v1_path)
}
qa <- data.frame(
  metric=c(
    "source_doi", "input_mode", "input_file_count", "input_total_bytes",
    "source_archive_md5_expected",
    "period_start", "period_end", "annual_transitions",
    "v2_1km_min", "v2_1km_max", "v2_share_changed_pct",
    "v1_10km_p98", "v2_10km_p98", "v1_10km_mean", "v2_10km_mean",
    "v2_minus_v1_10km_mean", "v2_vs_v1_10km_mae", "v2_vs_v1_10km_pearson_r",
    "v1_comparison_status"
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
    v1_p98, hi, v1_mean, v2_mean, difference_mean, comparison_mae, comparison_r,
    comparison_status
  )
)
write.csv(qa, file.path(out_tables, "change_freq_hilda_v2_1960_2019_qa.csv"), row.names=FALSE)

message("Wrote: ", out_png)
message("Wrote: ", out_tif)
message("Wrote numerical QA table; expected source MD5: ", v2_md5)
}
