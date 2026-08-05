#!/usr/bin/env Rscript
# =============================================================================
# download_data.R - fetch every source dataset that can be fetched by code
#
#   Rscript download_data.R                     show the catalogue and what is
#                                               already on disk (downloads nothing)
#   Rscript download_data.R --feature=Transport  fetch one feature's data
#   Rscript download_data.R --id=grip4           fetch one dataset
#   Rscript download_data.R --all                fetch everything scriptable (~23 GB)
#   Rscript download_data.R --all --dry-run      print the commands, run nothing
#   Rscript download_data.R --id=eobs --force    re-download even if present
#
# WHAT THIS SCRIPT CANNOT DO
# It covers the 13 sources that have a machine-readable route. Ten others sit
# behind a login, a browser form or a Cloudflare challenge and no script can
# get them - they are listed at the end of every run, with their landing pages,
# and in full in data_sources.md. Running this to completion does NOT mean you
# have all the data.
#
# Deliberately base R only: this is the step that runs BEFORE renv::restore(),
# on a machine where the package library may not exist yet.
# =============================================================================

# ---- repository root ---------------------------------------------------------
# Resolved from this file's own location rather than getwd(), so the script
# works when launched from anywhere. The .here marker is the check that we
# actually landed on the repository and not on a lookalike directory.
find_root <- function() {
  args <- commandArgs(trailingOnly = FALSE)
  hit  <- grep("^--file=", args, value = TRUE)
  cand <- if (length(hit)) dirname(normalizePath(sub("^--file=", "", hit[1]))) else getwd()
  while (!file.exists(file.path(cand, ".here"))) {
    parent <- dirname(cand)
    if (identical(parent, cand)) {
      stop("Could not find the repository root (no .here marker above ",
           cand, "). Run this script from inside the repository.", call. = FALSE)
    }
    cand <- parent
  }
  normalizePath(cand, winslash = "/")
}
ROOT <- find_root()
FE   <- "Feature explorations"

# ---- interpreters ------------------------------------------------------------
RSCRIPT <- file.path(R.home("bin"), if (.Platform$OS.type == "windows") "Rscript.exe" else "Rscript")

find_python <- function() {
  venv <- if (.Platform$OS.type == "windows") ".venv/Scripts/python.exe" else ".venv/bin/python"
  if (file.exists(file.path(ROOT, venv))) return(file.path(ROOT, venv))
  for (cmd in c("python", "python3")) {
    p <- Sys.which(cmd)
    if (nzchar(p)) return(unname(p))
  }
  ""
}
PYTHON <- find_python()

# =============================================================================
# THE CATALOGUE
#
# `check` is the path whose existence means "already downloaded". It is a
# specific file, not the folder: an interrupted download leaves the folder
# behind, and a folder test would then report success for missing data.
# =============================================================================
datasets <- list(

  list(id = "grip4", feature = "Transport", size_mb = 4,
       label   = "GRIP4 global road density (5 arcmin, ODbL)",
       url     = "https://www.globio.info/download-grip-dataset",
       creds   = NA,
       runner  = "R", script = file.path(FE, "Transport/scripts/3_acquire_grip4_road_density.R"),
       check   = file.path(FE, "Transport/data_raw/grip4")),

  list(id = "clc122", feature = "Transport", size_mb = 35,
       label   = "CORINE Land Cover 2018 class 122, vector (EEA discomap)",
       url     = "https://image.discomap.eea.europa.eu/arcgis/rest/services/Corine/CLC2018_LAEA/MapServer/0",
       creds   = NA,
       runner  = "R", script = file.path(FE, "Transport/scripts/1_acquire_clc122_transport_land.R"),
       check   = file.path(FE, "Transport/data_raw/clc2018_class122_eea39_3035.geojson"),
       note    = "Windows only as written: shells out to PowerShell Invoke-WebRequest to dodge an SSL failure."),

  list(id = "boundaries_pop_age", feature = "Heatwaves", size_mb = 1400,
       label   = "GISCO boundaries + Eurostat population by age + GHS-POP 1990/1995/2020",
       url     = "https://human-settlement.emergency.copernicus.eu/download.php",
       creds   = NA,
       runner  = "R", script = file.path(FE, "Heatwaves/scripts/1_acquire_boundaries_age_population.R"),
       check   = file.path(FE, "Heatwaves/data_raw/ghsl_pop_30arcsec/GHS_POP_E2020_GLOBE_R2023A_4326_30ss_V1_0.tif")),

  list(id = "hilda_v2", feature = "Biosphere", size_mb = 1800,
       label   = "HILDA+ v2.0 annual land-use states 1960-2019 (PANGAEA 974335)",
       url     = "https://doi.pangaea.de/10.1594/PANGAEA.974335",
       creds   = NA,
       runner  = "R", script = file.path(FE, "Biosphere/scripts/4b_change_freq_hilda_v2.R"),
       check   = file.path(FE, "Biosphere/data_raw/biosphere/hilda_plus_v2/states_wgs84/hilda_plus_states_1960_GLOB-v2_wgs84.tif"),
       note    = "This script downloads AND computes the change-frequency raster; expect it to run long after the download finishes."),

  list(id = "cds_test", feature = "Heatwaves", size_mb = 0,
       label   = "Copernicus CDS connectivity check (run this before the big ones)",
       url     = "https://cds.climate.copernicus.eu",
       creds   = "CDS",
       runner  = "py", script = file.path(FE, "Heatwaves/scripts/1_acquire_test_cds_connection.py"),
       check   = NA),

  list(id = "era5_land", feature = "Heatwaves", size_mb = 20,
       label   = "ERA5-Land daily 2 m temperature, July 1991 (validation month)",
       url     = "https://cds.climate.copernicus.eu/datasets/reanalysis-era5-land",
       creds   = "CDS",
       runner  = "py", script = file.path(FE, "Heatwaves/scripts/1_acquire_era5_land_month.py"),
       args    = c("1991", "7"),
       check   = file.path(FE, "Heatwaves/data_raw/era5_land_daily/era5_land_daily_max_1991-07_europe.nc")),

  list(id = "utci", feature = "Heatwaves", size_mb = 780,
       label   = "ERA5-HEAT UTCI 2022, hourly 0.25 deg, European window",
       url     = "https://cds.climate.copernicus.eu/datasets/derived-utci-historical",
       creds   = "CDS",
       runner  = "py", script = file.path(FE, "Heatwaves/scripts/1_acquire_utci_2022.py"),
       check   = file.path(FE, "Heatwaves/data_raw/utci/utci_202201_europe.zip")),

  list(id = "eobs", feature = "Heatwaves", size_mb = 9440,
       label   = "E-OBS v33.0e daily TX/TN, 1950-2025, 0.1 deg",
       url     = "https://cds.climate.copernicus.eu/datasets/insitu-gridded-observations-europe",
       creds   = "CDS",
       runner  = "py", script = file.path(FE, "Heatwaves/scripts/1_acquire_eobs_full_baseline.py"),
       check   = file.path(FE, "Heatwaves/data_raw/eobs/tx_ens_mean_0.1deg_reg_v33.0e.nc"),
       note    = "Largest single item in the project. Expect hours, and 14 GB on disk once unzipped."),

  list(id = "cams", feature = "Air quality", size_mb = 9900,
       label   = "CAMS European air quality reanalysis, PM2.5, 2024, 12 monthly files",
       url     = "https://ads.atmosphere.copernicus.eu/datasets/cams-europe-air-quality-reanalyses",
       creds   = "ADS",
       runner  = "R", script = file.path(FE, "Air quality/scripts/2_fetch_cams_pm25.R"),
       check   = file.path(FE, "Air quality/data_raw/cams_pm25_2024_12.zip"),
       note    = "One request per month - the ADS cost limit rejects anything larger. Queued server-side, so it can idle for a long time before bytes move.")
)

# Sources with a machine-readable route that store nothing locally: they are
# read over the network at map time. Nothing to download, but they are the
# reason a run needs an internet connection even with data_raw/ full.
streamed <- list(
  list(id = "wsf3d",       label = "DLR World Settlement Footprint 3D v02 (building fraction + height)",
       url = "https://download.geoservice.dlr.de/WSF3D/files/global/",
       used_by = "Technosphere/scripts/1_, 2_ - GDAL /vsicurl/"),
  list(id = "hilda_cog",   label = "HILDA+ 1 km cloud-optimised GeoTIFFs via OpenLandMap",
       url = "https://stac.openlandmap.org/land.use.land.cover_hilda.plus/collection.json",
       used_by = "Biosphere/scripts/2_, 4_ - GDAL /vsicurl/"),
  list(id = "worldbank",   label = "World Bank indicator API (GDP per capita PPP, employment in agriculture)",
       url = "https://api.worldbank.org/v2/",
       used_by = "Biosphere/scripts/8_, validation/world_agri_map.R")
)

# Everything a script cannot reach. Printed after every run so that a full,
# successful download is never mistaken for a complete dataset.
manual <- list(
  list(label = "Biodiversity Intactness Index v2.1.1 (CC-BY-NC-SA)",
       url = "https://data.nhm.ac.uk/dataset/bii-developed-by-nhm-v2-1-1-limited-release",
       why = "Cloudflare challenge on the download link"),
  list(label = "World Atlas of Artificial Night Sky Brightness 2015 (Falchi et al.)",
       url = "https://doi.org/10.5880/GFZ.1.4.2016.001",
       why = "FTP access granted through a request form"),
  list(label = "Anthromes v2 (year 2000 raster)",
       url = "https://sedac.ciesin.columbia.edu/data/set/anthromes-anthropogenic-biomes-world-v2-1700/data-download",
       why = "SEDAC/Earthdata login"),
  list(label = "Anthromes 12K (1960 / 2015 slices)",
       url = "https://dataverse.harvard.edu/dataverse/anthromes_12K",
       why = "Dataverse click-through"),
  list(label = "HILDA+ v1.0 change layers",
       url = "https://doi.pangaea.de/10.1594/PANGAEA.921846",
       why = "Bundle selected by hand on the PANGAEA page"),
  list(label = "EEA interpolated PM2.5, 1 km annual mean",
       url = "https://sdi.eea.europa.eu/catalogue/srv/eng/catalog.search#/search?any=interpolated%20pm2.5",
       why = "Datahub download form; reference year still unconfirmed"),
  list(label = "GLAD global cropland 1 km, 2022",
       url = "https://glad.umd.edu/dataset/croplands",
       why = "Tile picker"),
  list(label = "Global Human Day time-use budgets (Fajzel et al. 2023)",
       url = "https://doi.org/10.5281/zenodo.7941615",
       why = "Zenodo bundle, taken once"),
  list(label = "Gridded GDP per capita, admin-2 (Kummu et al. 2025)",
       url = "https://doi.org/10.5281/zenodo.13943886",
       why = "Zenodo bundle, one file of many"),
  list(label = "T.ambient.buildings.nc",
       url = "(unknown - provenance not recorded anywhere in the project)",
       why = "PROVENANCE MISSING: identify it or drop it")
)

# =============================================================================
# helpers
# =============================================================================
# On Windows, R expands "~" to the user's Documents folder - which OneDrive
# commonly redirects - while Python's cdsapi expands it to %USERPROFILE%. A
# check written as path.expand("~/.cdsapirc") therefore reports "no credentials"
# on a machine where the Python downloaders are perfectly happy. Look in the
# real home directory first.
cdsapirc_candidates <- function() {
  unique(c(
    if (nzchar(Sys.getenv("USERPROFILE"))) file.path(Sys.getenv("USERPROFILE"), ".cdsapirc"),
    if (nzchar(Sys.getenv("HOME")))        file.path(Sys.getenv("HOME"), ".cdsapirc"),
    path.expand("~/.cdsapirc")
  ))
}
credentials_path <- function() {
  hit <- cdsapirc_candidates()[file.exists(cdsapirc_candidates())]
  if (length(hit)) hit[1] else NA_character_
}
has_credentials <- function() !is.na(credentials_path())

exists_on_disk <- function(d) {
  if (is.na(d$check)) return(NA)          # nothing to test (connectivity check)
  file.exists(file.path(ROOT, d$check))
}

fmt_size <- function(mb) {
  if (mb == 0) return("  0 MB")
  if (mb < 1000) sprintf("%4d MB", as.integer(mb)) else sprintf("%4.1f GB", mb / 1024)
}

status_of <- function(d) {
  ok <- exists_on_disk(d)
  if (is.na(ok)) "  -  " else if (ok) "present" else "MISSING"
}

rule <- function(ch = "-") cat(strrep(ch, 78), "\n", sep = "")

# =============================================================================
# catalogue printout
# =============================================================================
print_catalogue <- function() {
  cat("\nExperiencing the Anthropocene - source data\n")
  cat("repository root: ", ROOT, "\n", sep = "")
  cat("credentials    : ",
      if (has_credentials()) paste0(credentials_path(), "\n")
      else "NO .cdsapirc FOUND - the CDS/ADS datasets will be skipped\n", sep = "")
  rule("=")
  cat(sprintf("%-19s %-12s %-8s %-8s %s\n", "id", "feature", "size", "status", "dataset"))
  rule()
  for (d in datasets) {
    cat(sprintf("%-19s %-12s %-8s %-8s %s\n",
                d$id, d$feature, fmt_size(d$size_mb), status_of(d), d$label))
    if (!is.null(d$note)) cat(sprintf("%-51s^ %s\n", "", d$note))
  }
  rule()

  missing <- Filter(function(d) isTRUE(!exists_on_disk(d)), datasets)
  total   <- sum(vapply(missing, function(d) d$size_mb, numeric(1)))
  if (!length(missing)) {
    cat("All ", length(datasets), " download jobs already satisfied - nothing to fetch.\n", sep = "")
  } else {
    cat(sprintf("%d of %d download jobs outstanding, %s to fetch\n",
                length(missing), length(datasets), fmt_size(total)))
  }
  cat("(", length(datasets), " jobs cover 10 datasets - one job pulls GISCO boundaries,\n",
      " Eurostat population by age and GHS-POP together.)\n", sep = "")
  cat("\nNo download started. Pick a scope:\n")
  cat("  Rscript download_data.R --feature=Transport   (smallest feature, no credentials)\n")
  cat("  Rscript download_data.R --id=<id>\n")
  cat("  Rscript download_data.R --all\n")
}

print_streamed <- function() {
  cat("\nRead over the network at map time - nothing to download, but you need\n")
  cat("to be online when the map scripts run:\n")
  for (s in streamed) cat(sprintf("  %-14s %s\n                 %s\n", s$id, s$label, s$url))
}

print_manual <- function() {
  cat("\n")
  rule("=")
  cat("STILL MISSING AFTER THIS SCRIPT - no code can fetch these ", length(manual), " datasets\n", sep = "")
  rule("=")
  for (m in manual) {
    cat(sprintf("  %s\n    %s\n    why manual: %s\n", m$label, m$url, m$why))
  }
  cat("\nFull provenance, licences and SHA-256 checksums: data_sources.md\n")
  cat("Verify a manual download with:  certutil -hashfile <file> SHA256   (Windows)\n")
  cat("                               shasum -a 256 <file>               (macOS/Linux)\n")
}

# =============================================================================
# runner
# =============================================================================
run_one <- function(d, dry_run) {
  interp <- if (d$runner == "R") RSCRIPT else PYTHON
  args   <- c(d$script, if (!is.null(d$args)) d$args)

  cat("\n"); rule("=")
  cat("[", d$id, "] ", d$label, "\n", sep = "")
  cat("  ", basename(interp), " \"", d$script, "\"",
      if (!is.null(d$args)) paste0(" ", paste(d$args, collapse = " ")) else "", "\n", sep = "")
  rule()

  if (!nzchar(interp)) {
    cat("  SKIPPED: no ", if (d$runner == "R") "Rscript" else "python",
        " interpreter found.\n", sep = "")
    if (d$runner == "py")
      cat("  Create the environment first: python -m venv .venv && pip install -r requirements.txt\n")
    return("no interpreter")
  }
  if (!is.na(d$creds) && !has_credentials()) {
    cat("  SKIPPED: ", d$creds, " credentials needed but ~/.cdsapirc is absent.\n", sep = "")
    cat("  See the credentials section of data_sources.md.\n")
    return("no credentials")
  }
  if (dry_run) { cat("  (dry run - not executed)\n"); return("dry run") }

  t0     <- Sys.time()
  status <- system2(interp, args = shQuote(args))
  mins   <- as.numeric(difftime(Sys.time(), t0, units = "mins"))

  if (identical(status, 0L)) {
    landed <- exists_on_disk(d)
    if (isTRUE(!landed)) {
      # The script returned success but the file it was supposed to produce is
      # not there. Reporting "ok" here is how a broken pipeline stays hidden.
      cat(sprintf("\n  WARNING: exit code 0 but %s is still absent (%.1f min).\n",
                  d$check, mins))
      return("no output")
    }
    cat(sprintf("\n  done (%.1f min)\n", mins))
    return("ok")
  }
  cat(sprintf("\n  FAILED: exit code %s (%.1f min)\n", status, mins))
  "failed"
}

# =============================================================================
# main
# =============================================================================
argv     <- commandArgs(trailingOnly = TRUE)
opt      <- function(name) any(argv == name)
opt_val  <- function(name) {
  hit <- grep(paste0("^", name, "="), argv, value = TRUE)
  if (length(hit)) sub(paste0("^", name, "="), "", hit[1]) else NULL
}

dry_run <- opt("--dry-run")
force   <- opt("--force")
feature <- opt_val("--feature")
only_id <- opt_val("--id")

unknown <- setdiff(argv, c("--all", "--dry-run", "--force",
                           grep("^--(feature|id)=", argv, value = TRUE)))
if (length(unknown)) {
  cat("Unrecognised argument(s): ", paste(unknown, collapse = " "), "\n\n", sep = "")
  cat("Valid: --all  --feature=<name>  --id=<id>  --dry-run  --force\n")
  quit(status = 2)
}

if (!opt("--all") && is.null(feature) && is.null(only_id)) {
  print_catalogue(); print_streamed(); print_manual()
  quit(status = 0)
}

selected <- datasets
if (!is.null(feature)) {
  selected <- Filter(function(d) tolower(d$feature) == tolower(feature), selected)
  if (!length(selected)) {
    cat("No dataset for feature '", feature, "'. Known features: ",
        paste(unique(vapply(datasets, function(d) d$feature, character(1))), collapse = ", "),
        "\n", sep = "")
    quit(status = 2)
  }
}
if (!is.null(only_id)) {
  selected <- Filter(function(d) d$id == only_id, selected)
  if (!length(selected)) {
    cat("No dataset with id '", only_id, "'. Run without arguments to see the catalogue.\n", sep = "")
    quit(status = 2)
  }
}

todo <- if (force) selected else Filter(function(d) !isTRUE(exists_on_disk(d)), selected)
skipped <- length(selected) - length(todo)

cat("\nrepository root: ", ROOT, "\n", sep = "")
cat(length(todo), " dataset(s) to fetch",
    if (skipped) paste0(", ", skipped, " already present (use --force to redo)") else "",
    " - ", fmt_size(sum(vapply(todo, function(d) d$size_mb, numeric(1)))), "\n", sep = "")
if (dry_run) cat("DRY RUN: nothing will be executed.\n")

results <- character(0)
for (d in todo) results[d$id] <- run_one(d, dry_run)

cat("\n"); rule("=")
cat("SUMMARY\n")
rule("=")
if (!length(results)) {
  cat("  nothing to do - everything selected is already on disk.\n")
} else {
  for (id in names(results)) cat(sprintf("  %-19s %s\n", id, results[[id]]))
}
bad <- results[results %in% c("failed", "no output")]
if (length(bad)) {
  cat("\n", length(bad), " dataset(s) did not complete. Re-run just those with --id=<id>.\n", sep = "")
}

print_manual()
quit(status = if (length(bad)) 1 else 0)
