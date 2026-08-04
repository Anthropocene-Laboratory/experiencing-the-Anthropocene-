# Detect heatwave days in 2022 from E-OBS, using the local calendar-day P90
# thresholds from compute_p90_thresholds.R, for the Phase 3 exposure prototype.
#
# STANDARD (Perkins & Alexander 2013, the most-used heatwave framework): a
# heatwave day = daily maximum temperature (TX) above its local calendar-day
# 90th percentile for at least MINDUR (default 3) consecutive days. TX-only is
# the PRIMARY index. We also compute, as SEPARATE secondary indices, the same
# rule on TN (night) and on the compound TX-and-TN (day+night) criterion. The
# three are written to separate files -- the standard reports them side by side,
# it does not require day and night simultaneously.
#
# GUARD. Thresholds exist only for warm-season days (valid_doy_range) and sea
# cells are _FillValue. ncdf4 reads -9999 as NA; NA comparisons give NA, which we
# force to FALSE, so winter/sea can never be falsely flagged.
#
# Usage: Rscript 3_calculate_detect_heatwaves_2022.R [W] [MINDUR] [eobs_dir]

suppressMessages(library(ncdf4))

args     <- commandArgs(trailingOnly = TRUE)
W        <- if (length(args) >= 1) as.integer(args[1]) else 2L
MINDUR   <- if (length(args) >= 2) as.integer(args[2]) else 3L
base_dir <- here::here("Feature explorations", "Heatwaves")
eobs_dir <- if (length(args) >= 3 && nzchar(args[3])) args[3] else file.path(base_dir, "data_raw", "eobs")
proc_dir <- file.path(base_dir, "data_processed")
YEAR     <- 2022L

doy365 <- function(d) {
  y <- as.integer(format(d, "%Y")); m <- as.integer(format(d, "%m"))
  dd <- as.integer(format(d, "%d")); j <- as.integer(format(d, "%j"))
  leap <- (y %% 4 == 0 & (y %% 100 != 0 | y %% 400 == 0))
  j[leap & m > 2] <- j[leap & m > 2] - 1L
  j[leap & m == 2 & dd == 29] <- 59L
  j
}

tx90_f <- file.path(proc_dir, sprintf("eobs_tx90_1991_2020_w%d.nc", W))
tn90_f <- file.path(proc_dir, sprintf("eobs_tn90_1991_2020_w%d.nc", W))
stopifnot(file.exists(tx90_f), file.exists(tn90_f))

nctx90 <- nc_open(tx90_f)
lon <- nctx90$dim$longitude$vals; lat <- nctx90$dim$latitude$vals
nlon <- length(lon); nlat <- length(lat); ncell <- nlon * nlat
vdr <- ncatt_get(nctx90, 0, "valid_doy_range")$value
dr  <- as.integer(strsplit(vdr, "-")[[1]]); dmin <- dr[1]; dmax <- dr[2]
ndays <- dmax - dmin + 1L
cat(sprintf("W=%d | MINDUR=%d | valid doy %d-%d (%d days) | grid %dx%d\n",
            W, MINDUR, dmin, dmax, ndays, nlon, nlat))

tx90 <- ncvar_get(nctx90, "tx90", start = c(1, 1, dmin), count = c(nlon, nlat, ndays)); nc_close(nctx90)
nctn90 <- nc_open(tn90_f)
tn90 <- ncvar_get(nctn90, "tn90", start = c(1, 1, dmin), count = c(nlon, nlat, ndays)); nc_close(nctn90)
landmask <- !is.na(matrix(tx90, ncell, ndays)[, 1])

read_year_block <- function(file, vn) {
  nc <- nc_open(file)
  dates <- as.Date(substr(sub(".*since ", "", nc$dim$time$units), 1, 10)) + ncvar_get(nc, "time")
  doy <- doy365(dates)
  sel <- which(as.integer(format(dates, "%Y")) == YEAR & doy >= dmin & doy <= dmax)
  stopifnot(length(sel) == ndays, all(diff(sel) == 1))
  a <- ncvar_get(nc, vn, start = c(1, 1, sel[1]), count = c(nlon, nlat, ndays)); nc_close(nc)
  a
}
tx <- read_year_block(file.path(eobs_dir, "tx_ens_mean_0.1deg_reg_v33.0e.nc"), "tx")
tn <- read_year_block(file.path(eobs_dir, "tn_ens_mean_0.1deg_reg_v33.0e.nc"), "tn")

txExc <- tx > tx90; tnExc <- tn > tn90
rm(tx, tn); gc(FALSE)

# ---- count days that belong to a run of >= MINDUR consecutive exceedance days ----
# vectorised over cells: forward/backward consecutive-true counts, run length = f+b-1
count_hw <- function(exc) {                      # exc: logical [ncell, ndays]
  exc[is.na(exc)] <- FALSE
  exc <- matrix(exc, ncell, ndays)
  f <- matrix(0L, ncell, ndays); b <- matrix(0L, ncell, ndays)
  e <- exc * 1L
  f[, 1] <- e[, 1]
  for (j in 2:ndays) f[, j] <- (f[, j - 1L] + 1L) * e[, j]
  b[, ndays] <- e[, ndays]
  for (j in (ndays - 1L):1) b[, j] <- (b[, j + 1L] + 1L) * e[, j]
  hw <- exc & ((f + b - 1L) >= MINDUR)
  cnt <- rowSums(hw)
  cnt[!landmask] <- NA
  cnt
}

write_index <- function(cnt, tag, longname) {
  dlon <- ncdim_def("longitude", "degrees_east", lon)
  dlat <- ncdim_def("latitude", "degrees_north", lat)
  ovar <- ncvar_def("hw_days", "days", list(dlon, dlat), -9999, longname = longname, prec = "float")
  out_f <- file.path(proc_dir, sprintf("heatwave_days_%d_%s_w%d.nc", YEAR, tag, W))
  ncout <- nc_create(out_f, list(ovar))
  ncvar_put(ncout, ovar, matrix(cnt, nlon, nlat))
  ncatt_put(ncout, 0, "method", longname)
  ncatt_put(ncout, 0, "fill_note", "value -9999 = sea / no data")
  nc_close(ncout)
  cat(sprintf("  %-8s: max=%d, mean(land)=%.2f, land cells>0=%.1f%% -> %s\n",
              tag, max(cnt, na.rm = TRUE), mean(cnt[landmask]),
              100 * mean(cnt[landmask] > 0), basename(out_f)))
}

cat(sprintf("Heatwave-day counts (P90, +/-%d day window, >=%d consecutive days, 2022):\n", W, MINDUR))
write_index(count_hw(txExc), "tx",
            sprintf("2022 TX heatwave days (Perkins-Alexander standard): TX>P90, >=%d consec., w%d", MINDUR, W))
write_index(count_hw(tnExc), "tn",
            sprintf("2022 TN heatwave days (secondary): TN>P90, >=%d consec., w%d", MINDUR, W))
write_index(count_hw(txExc & tnExc), "compound",
            sprintf("2022 compound heatwave days (secondary): TX&TN>P90, >=%d consec., w%d", MINDUR, W))
cat("HEATWAVE DETECTION DONE (primary index = tx)\n")
