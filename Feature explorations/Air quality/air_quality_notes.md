# Air quality — PM2.5 (PROVISIONAL)

Exploratory prototype, not a settled finding (see `../CLAUDE.md`). Layer-A atmospheric
feature: fine-particle air pollution as an experienceable exposure across Europe.

## Current state — TWO separate maps (EEA and CAMS), same conventions
Both: WHO 2021 AQG (5) + interim targets (10/15/25, 25=EU limit); semantic air-quality
palette (green→purple) on a light canvas; LAEA 3035; GISCO borders; land-only.

- **EEA map (obs-interpolated, 1 km):** `data_processed/maps/air_quality_pm25_annual.png`.
  Source: EEA interpolated PM2.5 annual mean, native EPSG:3035, CC-BY 4.0 (`data_raw/pm25_avg25_int.tif`).
  Aggregated 1 km→3 km. Script `1_map_air_quality_pm25.R`.
- **CAMS map (modelled ensemble reanalysis, ~10 km, 2024):**
  `data_processed/maps/air_quality_pm25_cams_2024.png`. Source: Copernicus CAMS European air
  quality *interim reanalysis*, PM2.5, ensemble, 2024, via the ADS API (`ecmwfr`, PAT from
  `~/.cdsapirc`). Fetched as 12 monthly NetCDFs (`data_raw/cams_pm25_2024_MM.zip`, ~10 GB),
  averaged (hours-weighted) → annual mean, reprojected WGS84→3035, **masked to land**, cached
  at `data_processed/cams_pm25_2024_annual_3km_3035.tif`. Scripts `2_fetch_cams_pm25.R` (download)
  + `3_map_cams_pm25.R` (map). CAMS reads smoother than EEA (coarser + modelled).

### CAMS build gotchas (documented so we don't relearn them)
- ADS **cost limit ≈ 1 month/request** → download month-by-month (multi-month = 403 "too large").
- The ADS `time` subset was **ignored** → files are full hourly (744/month), ~10 GB total (more
  accurate than the intended 6-hourly, just heavier).
- CAMS outputs **over sea too** → must `mask()` to land or the oceans flood the map.

## ⚠️ Open / to confirm
- **Reference YEAR is unresolved.** The EEA file code is `avg25` (2025 release cycle). The
  plan asked for 2023; the ETC HE 2025 report maps the 2023 reference year, but the file code
  reads "25". **Confirm the exact reference year from the EEA datahub factsheet** before citing
  this as a dated result. The map deliberately does NOT print a year in the figure for now.
- **Coverage:** EEA domain only — Ukraine, Belarus, W. Russia, most of Türkiye render as
  no-data (grey), which is correct, not a gap in our processing.

## Decisions (2026-07-21, via r-cartographer SKILL §0 prior-art check + user review)
- **Data:** EEA interpolated (regional authority) over ACAG global.
- **Palette:** semantic air-quality colours on light background — domain convention beats the
  project's dark-Inferno aesthetic here, because air-quality colour language is near-universal
  and Inferno would invert it (bright = bad).
- **Folder:** its own `Air quality/` feature (a distinct experienceable feature), not folded
  into Biosphere or Technosphere.

## Open questions / likely revisions
- **Scope.** Pan-European window; align to the STUDY country set if this advances past exploration.
- **Layer B.** No exposure filter linked yet (Layer A only).
