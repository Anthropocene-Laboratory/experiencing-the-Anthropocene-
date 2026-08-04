# Does UTCI missingness bias the heat-stress feature downward where it matters?
#
# THE WORRY. ERA5-HEAT leaves hours empty when inputs fall outside the UTCI
# validity envelope. 3_calculate_utci_heatstress_2022.R skips those hours, i.e.
# counts them as "not heat stress". That is safe ONLY IF missing hours are not
# themselves hot hours. If they concentrate on hot days in hot places, the
# primary index is understated exactly where the feature is supposed to speak.
#
# WHAT WOULD MAKE THIS TEST FAIL (stated before running it, so that some outcome
# can actually indict the index rather than every outcome confirming it):
#   (a) missing hours land on hot days -- i.e. missing_on_hot / missing_total is
#       far above the share of hot days in the year; or
#   (b) the upper bound on the underestimate is material -- assume EVERY missing
#       hour on a hot day was in fact >= 32 C; if that inflates hours_strong by
#       more than a few percent in the hot regions, the index is biased and the
#       skip rule has to be replaced (e.g. by temporal interpolation); or
#   (c) coverage falls with heat -- mean coverage in the top heat decile clearly
#       below the bottom decile.
# If none of the three holds, the skip rule is adequate and can be reported as
# verified. "Hot day" = a day whose maximum valid UTCI in that cell reaches 32 C.
#
# Writes a table to data_processed/tables/ and prints the verdict inputs.
#
# Usage: Rscript "Feature explorations/Heatwaves/scripts/4_validate_utci_missingness.R"

suppressMessages(library(ncdf4))

base_dir <- here::here("Feature explorations", "Heatwaves")
raw_dir  <- file.path(base_dir, "data_raw", "utci")
proc_dir <- file.path(base_dir, "data_processed")
tab_dir  <- file.path(proc_dir, "tables")
dir.create(tab_dir, showWarnings = FALSE, recursive = TRUE)
YEAR <- 2022L

KELVIN   <- 273.15
B_STRONG <- 32

zips <- sort(list.files(raw_dir, pattern = sprintf("^utci_%d\\d{2}_europe\\.zip$", YEAR), full.names = TRUE))
stopifnot(length(zips) == 12)

tmp_dir <- file.path(tempdir(), "utci_unzip_val")
dir.create(tmp_dir, showWarnings = FALSE, recursive = TRUE)

acc <- NULL
for (z in zips) {
  files <- sort(unzip(z, exdir = tmp_dir))
  files <- files[grepl("\\.nc$", files)]
  for (f in files) {
    nc <- nc_open(f)
    utci <- ncvar_get(nc, "utci") - KELVIN
    if (is.null(acc)) {
      lon <- nc$dim$lon$vals; lat <- nc$dim$lat$vals
      nlon <- length(lon); nlat <- length(lat)
      acc <- list(miss_tot = array(0, c(nlon, nlat)),   # missing hours, all days
                  miss_hot = array(0, c(nlon, nlat)),   # missing hours on hot days
                  hot_days = array(0, c(nlon, nlat)),   # days reaching 32 C
                  hrs_str  = array(0, c(nlon, nlat)))   # hours >= 32 C (as computed)
    }
    nc_close(nc)

    na_h   <- apply(is.na(utci), c(1, 2), sum)
    daymax <- apply(utci, c(1, 2), function(x) if (all(is.na(x))) NA_real_ else max(x, na.rm = TRUE))
    hot    <- !is.na(daymax) & daymax >= B_STRONG

    acc$miss_tot <- acc$miss_tot + na_h
    acc$miss_hot <- acc$miss_hot + na_h * hot
    acc$hot_days <- acc$hot_days + hot
    acc$hrs_str  <- acc$hrs_str  + apply(utci >= B_STRONG, c(1, 2), sum, na.rm = TRUE)
  }
  unlink(files)
  cat(sprintf("  %s done\n", basename(z)))
}

cov_frac <- 1 - acc$miss_tot / 8760
land <- acc$hrs_str > 0            # cells that ever reach strong heat stress

# ---- (a) do missing hours land on hot days more than chance? ----
share_hot_days <- sum(acc$hot_days[land]) / (sum(land) * 365)
share_miss_hot <- sum(acc$miss_hot[land]) / max(sum(acc$miss_tot[land]), 1)

# ---- (b) upper bound on the underestimate ----
ub_infl <- 100 * sum(acc$miss_hot[land]) / max(sum(acc$hrs_str[land]), 1)

# ---- (c) coverage across heat deciles ----
q   <- quantile(acc$hrs_str[land], probs = seq(0, 1, 0.1))
dec <- cut(acc$hrs_str[land], unique(q), include.lowest = TRUE, labels = FALSE)
cov_by_dec <- tapply(cov_frac[land], dec, mean)

cat("\n--- UTCI MISSINGNESS DIAGNOSTIC (cells reaching >= 32 C at least once) ---\n")
cat(sprintf("cells considered              : %d\n", sum(land)))
cat(sprintf("mean coverage                 : %.3f%% of hours valid\n", 100 * mean(cov_frac[land])))
cat(sprintf("worst-cell coverage           : %.2f%%\n", 100 * min(cov_frac[land])))
cat(sprintf("(a) share of days that are hot: %.3f\n", share_hot_days))
cat(sprintf("(a) share of missing hours on hot days: %.3f  <- fails if >> the line above\n", share_miss_hot))
cat(sprintf("(b) upper-bound inflation of hours_strong: %.2f%%  <- fails if more than a few %%\n", ub_infl))
cat("(c) mean coverage by decile of hours_strong (1 = coolest .. 10 = hottest):\n")
print(round(100 * cov_by_dec, 3))

out <- data.frame(
  decile          = seq_along(cov_by_dec),
  coverage_pct    = as.numeric(round(100 * cov_by_dec, 4)),
  mean_hours_strong = as.numeric(round(tapply(acc$hrs_str[land], dec, mean), 1)),
  mean_missing_hours_on_hot_days = as.numeric(round(tapply(acc$miss_hot[land], dec, mean), 2))
)
out_f <- file.path(tab_dir, sprintf("utci_missingness_diagnostic_%d.csv", YEAR))
write.csv(out, out_f, row.names = FALSE)
cat(sprintf("\nwritten: %s\n", basename(out_f)))
