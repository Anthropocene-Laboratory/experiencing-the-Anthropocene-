# Stage 1 inputs for the heatwave population-exposure prototype.
# Run from the workspace root with:
#   & 'C:/Program Files/R/R-4.5.3/bin/Rscript.exe' 'Feature explorations/Heatwaves/scripts/download_stage1_inputs.R'
#
# Set DOWNLOAD_GHSL=1 to download GHS-POP epoch archives (about 443 MB each).
# Example (PowerShell):
#   $env:DOWNLOAD_GHSL='1'; $env:GHSL_EPOCHS='1990'; & 'C:/Program Files/R/R-4.5.3/bin/Rscript.exe' 'Feature explorations/Heatwaves/scripts/download_stage1_inputs.R'
# Note: the country boundary file is a cross-feature file, shared with Biosphere -
# it is downloaded to Feature explorations/_shared, not to this feature's own data_raw.

project_dir <- normalizePath(file.path("Feature explorations", "Heatwaves"), mustWork = TRUE)
raw_dir    <- file.path(project_dir, "data_raw")
shared_dir <- normalizePath(file.path("Feature explorations", "_shared"), mustWork = TRUE)
dir.create(raw_dir, recursive = TRUE, showWarnings = FALSE)

download_once <- function(url, destination) {
  if (file.exists(destination) && file.info(destination)$size > 0) {
    message("Already present: ", basename(destination))
    return(invisible(destination))
  }
  message("Downloading: ", basename(destination))
  download.file(url, destination, mode = "wb", method = "libcurl", quiet = FALSE)
  invisible(destination)
}

# GISCO provides the country polygons needed to clip the study area and build
# country-year summaries. The project-specific country selection happens later.
boundary_url <- paste0(
  "https://gisco-services.ec.europa.eu/distribution/v2/countries/geojson/",
  "CNTR_RG_10M_2024_4326.geojson"
)
download_once(boundary_url, file.path(shared_dir, "CNTR_RG_10M_2024_4326.geojson"))

# Eurostat B3 source. Keep one raw annual age-group response per country so
# every derived 65+ or 75+ statistic remains auditable.
country_codes <- c(
  "AT", "BE", "BG", "HR", "CY", "CZ", "DK", "EE", "FI", "FR", "DE", "EL",
  "HU", "IE", "IT", "LV", "LT", "LU", "MT", "NL", "PL", "PT", "RO", "SK",
  "SI", "ES", "SE", "UK", "IS", "LI", "NO", "CH"
)
age_dir <- file.path(raw_dir, "eurostat_demo_pjangroup")
dir.create(age_dir, recursive = TRUE, showWarnings = FALSE)
for (country in country_codes) {
  age_url <- paste0(
    "https://ec.europa.eu/eurostat/api/dissemination/statistics/1.0/data/",
    "demo_pjangroup?geo=", country, "&sex=T&unit=NR"
  )
  download_once(age_url, file.path(age_dir, paste0(country, ".json")))
}

# GHS-POP R2023A is the B1 source. Each 30-arcsec global epoch archive is
# roughly 443 MB. Download only requested epoch(s); retaining global archives
# allows the European crop to remain reproducible.
if (identical(Sys.getenv("DOWNLOAD_GHSL"), "1")) {
  epoch_text <- Sys.getenv("GHSL_EPOCHS", unset = "1990")
  epochs <- as.integer(trimws(strsplit(epoch_text, ",", fixed = TRUE)[[1]]))
  valid_epochs <- c(1990L, 1995L, 2000L, 2005L, 2010L, 2015L, 2020L)
  if (!all(epochs %in% valid_epochs)) {
    stop("GHSL_EPOCHS must be one or more of: ", paste(valid_epochs, collapse = ", "))
  }
  ghsl_dir <- file.path(raw_dir, "ghsl_pop_30arcsec")
  dir.create(ghsl_dir, recursive = TRUE, showWarnings = FALSE)
  for (epoch in epochs) {
    product <- sprintf("GHS_POP_E%d_GLOBE_R2023A_4326_30ss_V1_0", epoch)
    ghsl_url <- paste0(
      "https://cidportal.jrc.ec.europa.eu/ftp/jrc-opendata/GHSL/GHS_POP_GLOBE_R2023A/",
      sprintf("GHS_POP_E%d_GLOBE_R2023A_4326_30ss/V1-0/", epoch), product, ".zip"
    )
    download_once(ghsl_url, file.path(ghsl_dir, paste0(product, ".zip")))
  }
} else {
  message("GHS-POP download staged but not started. Set DOWNLOAD_GHSL=1 when ready.")
}

# ERA5-Land must be requested from the Copernicus Climate Data Store with a
# registered user account and API credentials. No request is sent here because
# the local CDS credential file is not configured yet.
message("ERA5-Land is staged conceptually; CDS credentials are still required.")
