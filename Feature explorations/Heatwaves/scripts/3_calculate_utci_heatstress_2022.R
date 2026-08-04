# Build the human-anchored heat feature for 2022 from hourly UTCI (ERA5-HEAT).
#
# WHY THIS REPLACES THE P90 INDEX. The P90 index thresholds each cell against its
# OWN 1991-2020 climate. By construction ~10% of reference days exceed the
# threshold everywhere, so the absolute difference in heat between places is
# normalised to zero, and the human enters only later, via the population
# weighting. That is an Anthropocene component, not a Layer A experienceable
# feature. UTCI bands are calibrated on the physiological response of the body
# and are identical everywhere -- the structural analogue of the WHO bands
# already used in the Air quality feature.
#
# UNIT = HOURS, not days. The feature is a dose actually undergone by the body,
# which plugs straight into the Global Human Day exposure operator (minutes/day)
# with no invented conversion. The Perkins-Alexander ">=3 consecutive days" rule
# is therefore dropped: on the P90 index its surviving signal was mostly
# atmospheric persistence (blocking highs, soil-moisture feedback), i.e. a
# property of the atmosphere, not of the experience.
#
# PRIMARY INDEX   hours_strong  : hours/year with UTCI >= 32 C (strong heat stress)
# SECONDARY BANDS hours_moderate: 26-32 C ; hours_verystrong: >= 38 C
# SECONDARY INDEX hours_unrecovered : hours >= 32 C occurring on a day whose
#   DAILY MINIMUM UTCI never returns below 26 C (upper bound of the "no thermal
#   stress" band). Rationale: the epidemiological literature shows compound
#   day-night heat raises mortality with no apparent adaptation threshold,
#   because the body does not recover overnight -- a physiological mechanism,
#   unlike the 3-day rule. 26 C introduces no new anchor: it is the same UTCI
#   scale read in reverse.
#
# WHY DAILY MINIMUM RATHER THAN A FIXED NIGHT WINDOW. The domain spans -25 to
# 45 E, i.e. ~4.7 h of solar time either side of UTC, so a fixed UTC night window
# would mean different local hours in Ireland and in Russia. The diurnal minimum
# falls at night everywhere, so using it sidesteps the problem entirely.
#
# CAVEAT TO CARRY INTO THE METHODS DOC. UTCI is an OUTDOOR index. hours_unrecovered
# measures whether the outdoor environment allowed cooling, not what happened in
# the bedroom. It is a proxy and must be presented as one.
#
# MISSING HOURS. ERA5-HEAT returns no value where the inputs fall outside the UTCI
# validity envelope; this is TRANSIENT, not a land/sea mask. On 1 Jan 2022, 1466 to
# 2358 cells per hour are missing, 5231 cells are missing in at least one hour, but
# only 103 are missing in all 24. Letting NA propagate through an annual sum
# therefore destroys the whole cell for the year -- a first run wiped 46% of the
# domain that way. Missing hours are instead skipped (na.rm), i.e. counted as "not
# an hour of heat stress", and the count of VALID hours is written out as its own
# layer (hours_valid) so the reader can check whether missingness concentrates in
# the hot regions, which would bias the primary index downward. Do not treat that
# check as done: it has not been run yet.
#
# Usage: Rscript "Feature explorations/Heatwaves/scripts/3_calculate_utci_heatstress_2022.R"

suppressMessages(library(ncdf4))

base_dir <- here::here("Feature explorations", "Heatwaves")
raw_dir  <- file.path(base_dir, "data_raw", "utci")
proc_dir <- file.path(base_dir, "data_processed")
YEAR     <- 2022L

KELVIN     <- 273.15
B_MODERATE <- 26        # UTCI C -- upper bound of "no thermal stress"
B_STRONG   <- 32        # UTCI C -- onset of strong heat stress
B_VSTRONG  <- 38        # UTCI C -- onset of very strong heat stress

zips <- sort(list.files(raw_dir, pattern = sprintf("^utci_%d\\d{2}_europe\\.zip$", YEAR), full.names = TRUE))
stopifnot(length(zips) == 12)

tmp_dir <- file.path(tempdir(), "utci_unzip")
dir.create(tmp_dir, showWarnings = FALSE, recursive = TRUE)

acc <- NULL   # accumulators, allocated once the grid is known
ndays_seen <- 0L

for (z in zips) {
  files <- unzip(z, exdir = tmp_dir)
  files <- sort(files[grepl("\\.nc$", files)])

  for (f in files) {
    nc <- nc_open(f)
    utci <- ncvar_get(nc, "utci") - KELVIN            # [lon, lat, 24]
    if (is.null(acc)) {
      lon <- nc$dim$lon$vals; lat <- nc$dim$lat$vals
      nlon <- length(lon); nlat <- length(lat)
      acc <- list(moderate   = array(0, c(nlon, nlat)),
                  strong     = array(0, c(nlon, nlat)),
                  vstrong    = array(0, c(nlon, nlat)),
                  unrecov    = array(0, c(nlon, nlat)),
                  valid      = array(0, c(nlon, nlat)))
      cat(sprintf("grid %d x %d (0.25 deg) | lon %.2f..%.2f | lat %.2f..%.2f\n",
                  nlon, nlat, min(lon), max(lon), min(lat), max(lat)))
    }
    nc_close(nc)
    stopifnot(dim(utci)[3] == 24)

    # na.rm throughout: a missing hour is not an hour of heat stress (see header)
    h_mod  <- apply(utci >= B_MODERATE & utci < B_STRONG, c(1, 2), sum, na.rm = TRUE)
    h_str  <- apply(utci >= B_STRONG,  c(1, 2), sum, na.rm = TRUE)
    h_vst  <- apply(utci >= B_VSTRONG, c(1, 2), sum, na.rm = TRUE)
    h_val  <- apply(!is.na(utci), c(1, 2), sum)
    # diurnal minimum = night proxy; a day with no valid hour cannot be judged
    daymin <- apply(utci, c(1, 2), function(x) if (all(is.na(x))) NA_real_ else min(x, na.rm = TRUE))
    no_recovery <- !is.na(daymin) & daymin >= B_MODERATE

    acc$moderate <- acc$moderate + h_mod
    acc$strong   <- acc$strong   + h_str
    acc$vstrong  <- acc$vstrong  + h_vst
    acc$valid    <- acc$valid    + h_val
    acc$unrecov  <- acc$unrecov  + h_str * no_recovery

    ndays_seen <- ndays_seen + 1L
  }
  unlink(files)
  cat(sprintf("  %s -> %d days cumulated\n", basename(z), ndays_seen))
}
stopifnot(ndays_seen == 365L)

# ---- write one netCDF holding the four indices ----
dlon <- ncdim_def("longitude", "degrees_east", lon)
dlat <- ncdim_def("latitude", "degrees_north", lat)
mkvar <- function(nm, ln) ncvar_def(nm, "hours", list(dlon, dlat), -9999, longname = ln, prec = "float")

vars <- list(
  mkvar("hours_strong",      "2022 hours with UTCI >= 32 C (strong heat stress) -- PRIMARY"),
  mkvar("hours_moderate",    "2022 hours with UTCI 26-32 C (moderate heat stress)"),
  mkvar("hours_verystrong",  "2022 hours with UTCI >= 38 C (very strong heat stress)"),
  mkvar("hours_unrecovered", "2022 hours with UTCI >= 32 C on days whose daily minimum UTCI stayed >= 26 C (no overnight recovery)"),
  mkvar("hours_valid",       "2022 hours with a valid UTCI value (out of 8760) -- coverage layer for the missingness caveat")
)
out_f <- file.path(proc_dir, sprintf("utci_heatstress_hours_%d.nc", YEAR))
ncout <- nc_create(out_f, vars)
ncvar_put(ncout, vars[[1]], acc$strong)
ncvar_put(ncout, vars[[2]], acc$moderate)
ncvar_put(ncout, vars[[3]], acc$vstrong)
ncvar_put(ncout, vars[[4]], acc$unrecov)
ncvar_put(ncout, vars[[5]], acc$valid)
ncatt_put(ncout, 0, "source", "ERA5-HEAT (derived-utci-historical v1.1, consolidated), Copernicus CDS")
ncatt_put(ncout, 0, "bands", "UTCI: 9-26 no stress, 26-32 moderate, 32-38 strong, 38-46 very strong, >46 extreme")
ncatt_put(ncout, 0, "unit_rationale", "hours, not days -- dose undergone by the body, joins Global Human Day (minutes/day)")
ncatt_put(ncout, 0, "recovery_rule", "daily minimum UTCI used as the night proxy; domain spans ~4.7 h of solar time so a fixed UTC night window would not be comparable across it")
ncatt_put(ncout, 0, "caveat", "UTCI is an outdoor index; hours_unrecovered describes the outdoor environment's capacity to allow cooling, not indoor/bedroom conditions")
ncatt_put(ncout, 0, "missing_hours", "hours with no valid UTCI are skipped, not propagated; see hours_valid for coverage")
nc_close(ncout)

for (nm in c("strong", "moderate", "vstrong", "unrecov", "valid")) {
  a <- acc[[nm]]
  cat(sprintf("  %-9s: max=%.0f h, mean=%.1f h, cells>0=%.1f%%\n",
              nm, max(a, na.rm = TRUE), mean(a, na.rm = TRUE), 100 * mean(a > 0, na.rm = TRUE)))
}
cat(sprintf("  coverage : %.2f%% of cell-hours valid (8760 h/cell expected)\n",
            100 * mean(acc$valid) / 8760))
cat(sprintf("UTCI HEAT-STRESS FEATURE DONE -> %s\n", basename(out_f)))
