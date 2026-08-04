# Compute local calendar-day P90 thresholds for E-OBS TX and TN over the
# 1991-2020 reference period, for the Phase 3 heatwave-exposure prototype.
#
# Method: for each grid cell and each calendar day, the threshold is the 90th
# percentile of all baseline values within a centered +/- W day calendar window
# (W=2 = ETCCDI 5-day window). Leap days map onto a fixed 365-day calendar
# (Feb 29 -> doy 59).
#
# READ STRATEGY (why batched). The E-OBS netCDFs are chunked one full lon/lat
# plane per timestep, deflate-compressed, so any read decompresses whole planes.
# We process the target days in BATCHES: for a batch we read, once per baseline
# year, the single contiguous block of days covering the batch's window, into a
# [cell, day, year] cube; every target day's threshold is then computed from that
# cube with no extra reads. This cuts decompressions ~10x vs reading each day's
# window separately, so the run finishes in ~30-60 min instead of hours.
#
# OUTPUT / DOWNSTREAM WARNING. Full mode computes the WARM SEASON ONLY
# (doy 105-289 by default); other days and all sea cells stay at _FillValue
# (-9999). Detection MUST only evaluate days in valid_doy_range and treat -9999/NA
# as no-data (see detect_heatwaves_2022.R). valid_doy_range is stamped on the file.
#
# Usage:
#   Rscript compute_p90_thresholds.R [W] [mode] [eobs_dir] [doy_min] [doy_max] [batch]
#     mode  "test" -> one small batch, no file written ; "full" (default) -> write
#     batch number of target days per read batch (default 6; raise if RAM allows)

suppressMessages(library(ncdf4))
suppressMessages(library(matrixStats))

args     <- commandArgs(trailingOnly = TRUE)
W        <- if (length(args) >= 1) as.integer(args[1]) else 2L
MODE     <- if (length(args) >= 2) args[2] else "full"
TEST     <- identical(MODE, "test")
base_dir <- here::here("Feature explorations", "Heatwaves")
eobs_dir <- if (length(args) >= 3 && nzchar(args[3])) args[3] else file.path(base_dir, "data_raw", "eobs")
out_dir  <- file.path(base_dir, "data_processed")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
DOY_MIN  <- if (length(args) >= 4) as.integer(args[4]) else 105L
DOY_MAX  <- if (length(args) >= 5) as.integer(args[5]) else 289L
NB       <- if (length(args) >= 6) as.integer(args[6]) else 6L

BASE_START <- as.Date("1991-01-01"); BASE_END <- as.Date("2020-12-31")
PROB <- 0.90; P <- 365L

doy365 <- function(d) {
  y <- as.integer(format(d, "%Y")); m <- as.integer(format(d, "%m"))
  dd <- as.integer(format(d, "%d")); j <- as.integer(format(d, "%j"))
  leap <- (y %% 4 == 0 & (y %% 100 != 0 | y %% 400 == 0))
  j[leap & m > 2] <- j[leap & m > 2] - 1L
  j[leap & m == 2 & dd == 29] <- 59L
  j
}

vars <- list(
  list(file = "tn_ens_mean_0.1deg_reg_v33.0e.nc", var = "tn",
       out = sprintf("eobs_tn90_1991_2020_w%d.nc", W), thr = "tn90")
)

nc0 <- nc_open(file.path(eobs_dir, vars[[1]]$file))
torigin <- as.Date(substr(sub(".*since ", "", nc0$dim$time$units), 1, 10))
dates <- torigin + ncvar_get(nc0, "time")
lon <- nc0$dim$longitude$vals; lat <- nc0$dim$latitude$vals
nlon <- length(lon); nlat <- length(lat); ncell <- nlon * nlat
nc_close(nc0)

abs_base  <- which(dates >= BASE_START & dates <= BASE_END)
base_doy  <- doy365(dates[abs_base])
base_year <- as.integer(format(dates[abs_base], "%Y"))
years <- sort(unique(base_year)); nyear <- length(years)

doy_seq <- if (TEST) 194:196 else DOY_MIN:DOY_MAX
batches <- split(doy_seq, ceiling(seq_along(doy_seq) / NB))

cat(sprintf("Mode=%s | W=%d | NB=%d | baseline %d days, %d years | days:%d | dir=%s\n",
            MODE, W, NB, length(abs_base), nyear, length(doy_seq), eobs_dir))

for (v in vars) {
  t0 <- Sys.time()
  nc <- nc_open(file.path(eobs_dir, v$file))
  ncout <- NULL
  if (!TEST) {
    dlon <- ncdim_def("longitude", "degrees_east", lon)
    dlat <- ncdim_def("latitude", "degrees_north", lat)
    ddoy <- ncdim_def("doy", "calendar_day_1_365", seq_len(P))
    ovar <- ncvar_def(v$thr, "Celsius", list(dlon, dlat, ddoy), -9999,
                      longname = sprintf("E-OBS %s local P90, 1991-2020, +/-%d day window", v$var, W),
                      prec = "float")
    ncout <- nc_create(file.path(out_dir, v$out), list(ovar))
  }

  for (chunk in batches) {
    lo <- max(1L, min(chunk) - W); hi <- min(P, max(chunk) + W); nd <- hi - lo + 1L
    cube <- array(NA_real_, dim = c(ncell, nd, nyear))   # [cell, day, year]
    for (yi in seq_along(years)) {
      m <- base_year == years[yi] & base_doy >= lo & base_doy <= hi
      sa <- abs_base[m]; sd <- base_doy[m]
      if (!length(sa)) next
      a <- ncvar_get(nc, v$var, start = c(1, 1, sa[1]), count = c(nlon, nlat, length(sa)))
      cube[, sd - lo + 1L, yi] <- matrix(a, ncell, length(sa))
    }
    for (d in chunk) {
      cols <- (d - W - lo + 1L):(d + W - lo + 1L)
      mat  <- matrix(cube[, cols, , drop = FALSE], ncell, length(cols) * nyear)
      # na.rm=FALSE uses the fast C path (~350x faster); E-OBS land cells are
      # gap-free so this is exact there, sea cells (all-NA) stay NA. Any rare
      # partial-NA land cell is then corrected with the slow path on those rows only.
      q <- rowQuantiles(mat, probs = PROB, na.rm = FALSE, type = 8)
      bad <- which(is.na(q) & rowSums(!is.na(mat)) > 0L)
      if (length(bad)) q[bad] <- rowQuantiles(mat[bad, , drop = FALSE], probs = PROB, na.rm = TRUE, type = 8)
      if (TEST) {
        cat(sprintf("  %s doy %d: nval=%d p90=[%.1f, %.1f] NAfrac=%.2f\n",
                    v$var, d, ncol(mat), min(q, na.rm = TRUE), max(q, na.rm = TRUE), mean(is.na(q))))
      } else {
        ncvar_put(ncout, v$thr, matrix(q, nlon, nlat), start = c(1, 1, d), count = c(nlon, nlat, 1))
      }
    }
    rm(cube); gc(FALSE)
    if (!TEST) cat(sprintf("  %s doy %d-%d done (%.0fs)\n", v$var, min(chunk), max(chunk),
                           as.numeric(difftime(Sys.time(), t0, units = "secs"))))
  }
  nc_close(nc)
  if (!TEST) {
    ncatt_put(ncout, 0, "method",
              sprintf("calendar-day P90 over 1991-2020, centered +/-%d day window, quantile type 8", W))
    ncatt_put(ncout, 0, "valid_doy_range", sprintf("%d-%d", min(doy_seq), max(doy_seq)))
    ncatt_put(ncout, 0, "fill_note",
              "value -9999 = no data: calendar days outside valid_doy_range, or sea cells. Mask before any threshold comparison.")
    ncatt_put(ncout, 0, "source", sprintf("E-OBS ensemble_mean v33.0e 0.1deg (%s)", v$var))
    nc_close(ncout)
    cat(sprintf("Wrote %s (%.0fs)\n", v$out, as.numeric(difftime(Sys.time(), t0, units = "secs"))))
  }
}
cat("P90 THRESHOLDS DONE\n")
