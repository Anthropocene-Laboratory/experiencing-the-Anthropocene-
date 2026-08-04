# =============================================================================
# 2_fetch_cams_pm25.R
# Fetch CAMS European air quality REANALYSIS, PM2.5, for a CAMS-vs-EEA comparison.
# Ensemble median, surface, 2024, all months, 6-hourly (00/06/12/18) to keep the
# annual-mean download feasible (~10 km, hourly is too heavy). PROVISIONAL.
#
# Needs an ADS (Atmosphere Data Store) account with the CAMS licence accepted; uses
# the existing ECMWF Personal Access Token in ~/.cdsapirc (read at runtime, never printed).
# 2024 is too recent for the "validated" reanalysis, so we use "interim_reanalysis".
#
# RUN FROM WORKSPACE ROOT (long, async ADS job):
#   Rscript "Feature explorations/Air quality/scripts/2_fetch_cams_pm25.R"
# =============================================================================
suppressPackageStartupMessages(library(ecmwfr))
setwd(here::here())
raw <- "Feature explorations/Air quality/data_raw"
dir.create(raw, showWarnings = FALSE, recursive = TRUE)

# PAT from existing .cdsapirc (works for ADS on the unified ECMWF infra)
lines <- readLines("~/.cdsapirc", warn = FALSE)
key <- trimws(sub("^key:", "", grep("^key:", lines, value = TRUE)))
wf_set_key(key = key)

# ADS enforces a per-request cost limit that caps at ~1 month here (multi-month
# requests were rejected 403 "too large"). So download ONE MONTH per request (12 jobs);
# 3_map_cams_pm25.R then averages them into the annual mean.
for (m in sprintf("%02d", 1:12)) {
  tgt <- sprintf("cams_pm25_2024_%s.zip", m)
  if (file.exists(file.path(raw, tgt))) { cat("skip (exists):", tgt, "\n"); next }
  req <- list(
    dataset_short_name = "cams-europe-air-quality-reanalyses",
    variable = "particulate_matter_2.5um",
    model    = "ensemble", level = "0", type = "interim_reanalysis",
    year     = "2024", month = m,
    time     = c("00:00", "06:00", "12:00", "18:00"),
    data_format = "netcdf_zip", target = tgt
  )
  cat("Submitting CAMS PM2.5 2024-", m, " ...\n", sep = "")
  ok <- tryCatch({ wf_request(request = req, transfer = TRUE, path = raw,
                              time_out = 5 * 3600, verbose = TRUE); TRUE },
                 error = function(e) { cat("FAILED", m, ":", conditionMessage(e), "\n"); FALSE })
  cat(if (ok) paste("OK", m) else paste("SKIPPED", m), "\n")
}
cat("ALL MONTHS ATTEMPTED.\n")
