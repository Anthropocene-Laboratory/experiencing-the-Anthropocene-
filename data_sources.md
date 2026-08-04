# Data sources

No source data is stored in this repository. The `data_raw/` folders are empty in a
fresh clone (~40 GB in total on a working machine) and every dataset below is either
downloaded by a script or obtained by hand from the provider.

**How to read this file.** Each entry gives the dataset, its provider, the licence, the
size, and one of two acquisition routes:

- **scripted** — run the named script; it fetches the file for you.
- **manual** — the provider requires a login, a click-through licence, or a browser
  form, so the file cannot be fetched from code. Follow the steps and check the
  SHA-256 so you know you have the same file that produced the figures in this repo.

Verify a download on Windows with

```bash
certutil -hashfile "<file>" SHA256
```

or, on macOS/Linux, `shasum -a 256 "<file>"`.

> **Status.** This is exploratory work (see `Feature explorations/CLAUDE.md`). Dataset
> versions were chosen to answer "what can we do with this feature", not to build a
> frozen release. Where a reference year or version is uncertain, it says so.

---

## Credentials

Two Copernicus accounts are needed for the climate and air-quality downloads. Both are
free; neither is stored in this repository.

| Service | Register | Used by |
|---|---|---|
| Climate Data Store (CDS) | https://cds.climate.copernicus.eu | ERA5-Land, ERA5-HEAT (UTCI), E-OBS |
| Atmosphere Data Store (ADS) | https://ads.atmosphere.copernicus.eu | CAMS European air quality reanalysis |

Put your Personal Access Token in `~/.cdsapirc` (on Windows:
`C:\Users\<you>\.cdsapirc`), the standard location both the Python `cdsapi` client and
the R `ecmwfr` package read at runtime:

```
url: https://cds.climate.copernicus.eu/api
key: <your-personal-access-token>
```

No script in this repository contains a key, prints one, or writes one to disk.
`Air quality/scripts/2_fetch_cams_pm25.R` reads this file and hands the token straight
to `ecmwfr::wf_set_key()`. Accepting each dataset's licence on the Copernicus site
(once, in the browser) is a precondition for the API to return data.

---

## Layer A — Heatwaves

### E-OBS daily temperature (TX / TN), v33.0e

| | |
|---|---|
| Provider | ECMWF Copernicus CDS, dataset `insitu-gridded-observations-europe` |
| Version / period | v33.0e, 1950-2025, 0.1° regular grid |
| Size | 9.4 GB zip → 4.7 GB `tx_ens_mean` + 4.7 GB `tn_ens_mean` NetCDF |
| Licence | E-OBS / ECA&D terms — free for research, attribution required |
| Route | **scripted**: `Feature explorations/Heatwaves/scripts/1_acquire_eobs_full_baseline.py` |
| Target | `Heatwaves/data_raw/eobs/` |

`1_acquire_eobs_chunk_legacy.py` is the earlier chunked downloader, kept for reference.
The 1991-2020 P90 baseline is derived from this by `scripts/compute_p90_thresholds.R`.

### ERA5-HEAT — Universal Thermal Climate Index (UTCI), 2022

| | |
|---|---|
| Provider | Copernicus CDS, `derived-utci-historical` |
| Coverage | 2022, hourly, 0.25°, European window |
| Size | ~66 MB per month × 12 |
| Licence | Copernicus licence (free, attribution) |
| Route | **scripted**: `Heatwaves/scripts/1_acquire_utci_2022.py` |
| Target | `Heatwaves/data_raw/utci/utci_2022MM_europe.zip` |

0.25° (~28 km) is the coarsest analytic input in the project and is what sets the 30 km
grid used by `Analysis/` — see the header of `Analysis/scripts/1_build_layerA_stack_30km.R`.

### ERA5-Land daily 2 m temperature (test month)

| | |
|---|---|
| Provider | Copernicus CDS, `reanalysis-era5-land` |
| Coverage | 1991-07, European window (validation only) |
| Route | **scripted**: `Heatwaves/scripts/1_acquire_era5_land_month.py YYYY [MM]` |
| Target | `Heatwaves/data_raw/era5_land_daily/` |

Used by `4_validate_era5_alignment_test.R`, not by any published map.
`1_acquire_test_cds_connection.py` is a 30-second connectivity check — run it first.

### GHS-POP population grid, R2023A

| | |
|---|---|
| Provider | JRC Global Human Settlement Layer, `GHS_POP_GLOBE_R2023A` |
| Epochs used | 1990, 1995, 2020 — 30 arcsec, EPSG:4326 |
| Size | ~450 MB per epoch (zip) |
| Licence | CC-BY 4.0 |
| Route | **scripted**: `Heatwaves/scripts/1_acquire_boundaries_age_population.R` (`https://cidportal.jrc.ec.europa.eu/ftp/jrc-opendata/GHSL/`) |
| Target | `Heatwaves/data_raw/ghsl_pop_30arcsec/` |

Resampled to the 0.1° analysis grid by `prepare_population_2020.R` →
`Feature explorations/_shared/pop2020_0p1deg.tif`. **That one derived file is committed**
(0.7 MB), because several features depend on it and re-deriving it costs a 450 MB download.

### GLAD global cropland, 2022

| | |
|---|---|
| Provider | GLAD, University of Maryland |
| File | `cropland_glad_1km_2022.tif` (39.5 MB) |
| SHA-256 | `33c0147cc059cb5c2e94e95a3aba3000c6cbf8998e87a0aa53e3fd8d91aadd40` |
| Route | **manual** |
| Target | `Heatwaves/data_raw/landcover/` |

Used as the dasymetric proxy for land-based time use in
`6_ghd_weighted_exposure_2022.R` (via `crop_frac_0p1deg.tif`).

### Global Human Day (time-use budgets)

| | |
|---|---|
| Provider | Fajzel, Ellis et al. — the "Global Human Day" / MOOGAL release |
| File | `GlobalHumanDay.zip` (7.7 MB), unpacked to `inputData/`, `MOOGALdefs/`, `outputData/`, `scripts/` |
| SHA-256 | `73e2fffd88e24d0bfd6ed2b4e9b18cc9671f0ab3c3d8ce6059e7a830000e8ee8` |
| Route | **manual** |
| Target | `Heatwaves/data_raw/global_human_day/` |

The bundled `scripts/` are the authors' own notebooks, kept unmodified as provenance;
they are not part of this project's pipeline. See `Heatwaves/ghd_heatwave_linkage.md`
for how the budgets are joined — that linkage was revised more than once and the note
is the authoritative account.

### Building ambient temperature

| | |
|---|---|
| File | `T.ambient.buildings.nc` (2.5 MB) |
| SHA-256 | `08eeaf49230a09b1e6ad235d2a7b8fc991e34c4984545b0087ae14d440523e2a` |
| Route | **manual** |
| Target | `Heatwaves/data_raw/technosphere/` |

### Eurostat population by age group

| | |
|---|---|
| Provider | Eurostat dissemination API, `demo_pjangroup` |
| Route | **scripted**: `Heatwaves/scripts/1_acquire_boundaries_age_population.R` |
| Target | `Heatwaves/data_raw/eurostat_demo_pjangroup/<ISO2>.json` |

---

## Layer A — Air quality (PM2.5)

### EEA interpolated PM2.5, annual mean, 1 km

| | |
|---|---|
| Provider | European Environment Agency, `eea_r_3035_1_km_aq-interpolated-pm25_p_2025_v00_r00` |
| Size | 74.6 MB zip |
| SHA-256 | `41d7a7d89a516d84135e791c902783c94242dab2821dc942b4eff5d840f64bbe` |
| CRS | native EPSG:3035 |
| Licence | CC-BY 4.0 |
| Route | **manual** (EEA datahub download form) |
| Target | `Air quality/data_raw/` |

⚠️ **The reference year is unresolved.** The file code reads `avg25` (2025 release
cycle); the plan asked for 2023. Confirm against the EEA datahub factsheet before citing
this as a dated result — the published figure deliberately prints no year. See
`Air quality/air_quality_notes.md`.

### CAMS European air quality interim reanalysis, PM2.5, 2024

| | |
|---|---|
| Provider | Copernicus ADS, ensemble reanalysis |
| Size | ~10 GB (12 monthly zips, ~810 MB each) |
| Licence | Copernicus licence |
| Route | **scripted**: `Air quality/scripts/2_fetch_cams_pm25.R` |
| Target | `Air quality/data_raw/cams_pm25_2024_MM.zip` |

Three things the script already handles, documented so nobody rediscovers them:
the ADS cost limit is about one month per request (multi-month returns 403); the `time`
subset is ignored, so files come back full-hourly and heavier than requested; and CAMS
outputs over sea, so the raster must be masked to land or the oceans flood the map.

---

## Layer A — Biosphere

### Anthromes v2 (year 2000)

| | |
|---|---|
| Provider | Ellis & Ramankutty, "Anthropogenic Biomes of the World" v2 |
| File | `anthromes_2_GeoTIFF.zip` (1.7 MB) → per-year folders 1700…2000 |
| SHA-256 | `3bec60bfb3d404d33814f4473e54276c30c7e9e4096dda05307e9eb765b78f70` |
| Route | **manual** |
| Target | `Biosphere/data_raw/biosphere/anthromes_v2/` |

Used by `1_map_biosphere_anthromes.R` (`2000/anthro2_a2000.tif`) and
`2b_anthromes_detailed_figure.R`.

### Anthromes 12K (1960 / 2015 slices)

| | |
|---|---|
| Provider | Ellis et al., Anthromes 12K DGG (HYDE 3.2 based) |
| Files | `anthromes_12K_full.zip` (45.3 MB), plus extracted `anthromes1960AD.asc` / `anthromes2015AD.asc` |
| SHA-256 (full zip) | `845a1fc9b227e216306a6b5939fbbd6a44246fb51d4bb3ae90de5bf7a34a5e06` |
| Route | **manual** |
| Target | `Biosphere/data_raw/biosphere/anthromes_12k/` |

### HILDA+ land-use change, v1.0 (change layers)

| | |
|---|---|
| Provider | Winkler et al., HILDA+ |
| File | `change-layers.zip` (47.6 MB) → `HILDAplus_vGLOB-1.0_luc_change-freq_1960-2019_wgs84.tif` and companions |
| SHA-256 | `a538d1bdd31681510c39393c5d08ebb39ce437e2e772d2192f9d30a7aaf96ac7` |
| Route | **manual** |
| Target | `Biosphere/data_raw/biosphere/hilda_plus/` |

### HILDA+ land-use states, v2.0 (1960-2019 annual)

| | |
|---|---|
| Provider | PANGAEA, dataset 974335 |
| URL | `https://download.pangaea.de/dataset/974335/files/hildap_vGLOB-2.0_geotiff_wgs84.zip` |
| Size | 60 annual GeoTIFFs, ~29.5 MB each (~1.8 GB) |
| Route | **scripted**: `Biosphere/scripts/4b_change_freq_hilda_v2.R` (downloads on first run) |
| Target | `Biosphere/data_raw/biosphere/hilda_plus_v2/states_wgs84/` |

v2.0 also provides 2020, but the analysed interval is deliberately held at 1960-2019
(59 annual transitions) so v1 and v2 stay comparable.

### HILDA+ via OpenLandMap (streamed, nothing stored)

`Biosphere/scripts/2_` and `4_` read the 1 km HILDA+ cloud-optimised GeoTIFFs directly
over HTTP with GDAL's `/vsicurl/`
(`https://s3.openlandmap.org/arco/land.use.land.cover_hilda.plus_...`). No download step,
no disk footprint — but an internet connection is required at run time.

### Biodiversity Intactness Index (BII) v2.1.1

| | |
|---|---|
| Provider | De Palma et al. 2024, Natural History Museum Data Portal |
| Files | `bii-{2000,2005,2010,2015,2020}_v2-1-1.tif`, 5 arc-min, values 0-100 % |
| SHA-256 (`bii-2015`) | `97a0733bfc95a0db1c28f80c0624694e9b6718692bc71489842c3b00d9bc7b96` |
| Licence | **CC-BY-NC-SA 4.0** |
| Route | **manual** — the portal download is behind a Cloudflare challenge and cannot be scripted |
| Target | `Biosphere/data_raw/biosphere/bii_v2_1_1/` |

⚠️ The non-commercial / share-alike terms travel to anything derived from this layer.
See the licence section of the README before reusing `Biosphere/data_processed/maps/bii_*.png`
or the archetype maps that include BII as an input.

---

## Layer A — Technosphere

### World Settlement Footprint 3D v02 (streamed, nothing stored)

| | |
|---|---|
| Provider | DLR, `https://download.geoservice.dlr.de/WSF3D/files/global/` |
| Layers | `WSF3D_V02_BuildingFraction.tif`, `WSF3D_V02_BuildingHeight.tif` (~90 m global COGs) |
| Route | **streamed** via GDAL `/vsicurl/` overviews — `Technosphere/scripts/1_` and `2_` |

`BuildingFraction` is Byte with **NoData = 255**, not -32767. Getting that wrong silently
turns empty land into 255 % built.

### World Atlas of Artificial Night Sky Brightness (2015)

| | |
|---|---|
| Provider | Falchi et al. 2016 |
| File | `World_Atlas_2015.zip` (652.6 MB) → 2.9 GB GeoTIFF + `.tpk` |
| SHA-256 | `9c6a624427463c40717efbca7696e3c6bb0f332c26d1b039e7a91e0dbc831fbf` |
| Route | **manual** |
| Target | `Technosphere/data_raw/World_Atlas_2015/` |

---

## Layer A — Transport

### GRIP4 global roads — the roadedness layer

| | |
|---|---|
| Provider | Meijer et al. 2018, PBL/GLOBIO |
| URL | `https://dataportaal.pbl.nl/downloads/GRIP4/` (landing page: `https://www.globio.info/download-grip-dataset`) |
| Size | 3.5 MB for total density; per-class grids tp1-tp5 also fetched |
| Resolution | 5 arcmin (~55 km² per cell at 50 °N), reprojected to 8 km LAEA |
| Licence | ODbL |
| Route | **scripted**: `Transport/scripts/3_acquire_grip4_road_density.R` |

GRIP recovers roughly **half** the published national road length (ratio 0.48-0.68 across
six countries), the gap being municipal roads. Absolute values read low by about a factor
of two; the relative pattern holds. Full argument in `Transport/transport_land_source_note.md`.

### CORINE Land Cover 2018, class 122 — the land-take layer

| | |
|---|---|
| Provider | EEA discomap ArcGIS REST, `Corine/CLC2018_LAEA` MapServer layer 0 |
| Size | 35 MB GeoJSON, 4 839 polygons EEA39-wide, already in EPSG:3035 |
| Route | **scripted**: `Transport/scripts/1_acquire_clc122_transport_land.R` |
| Target | `Transport/data_raw/clc2018_class122_eea39_3035.geojson` |

The official CLC2018 100 m GeoTIFF sits behind a Copernicus Land login; the discomap
*vector* service serves the same product without authentication. R's libcurl fails the
SSL handshake against that host (the same issue this project hits on Eurostat and GISCO),
so the five paginated requests are shelled out to PowerShell `Invoke-WebRequest` — which
makes this script Windows-only as written.

⚠️ CLC's 25 ha minimum mapping unit means an ordinary 2-lane road is never in class 122.
This layer under-captures the transport footprint by roughly a factor of 20. It is an
honest map of *visible transport land take*; it is **not** road-network density.

---

## Layer B — exposure filters, and shared reference data

### Gridded GDP per capita (Kummu et al. 2025)

| | |
|---|---|
| Provider | Kummu et al. 2025, *Scientific Data* — Zenodo record 13943886 |
| File | `rast_adm2_gdp_perCapita_1990_2022.tif` (108.6 MB), admin-2 downscaled, 5 arcmin |
| SHA-256 | `7e86399f157c38dd6821337457b7b04a75141c3a3e23f5c2e2d4c4317560a387` |
| Licence | CC-BY |
| Route | **manual** |
| Target | `Feature explorations/_shared/gdp_kummu/` |

### World Bank indicators (national GDP per capita PPP)

Fetched live from `https://api.worldbank.org/v2/country/all/indicator/...` by
`Biosphere/scripts/8_wealth_age_choropleths.R`. Nothing stored.

### Eurostat median age by NUTS3 (2023)

`demo_r_pjanind3`, indicator `MEDAGEPOP`, via the dissemination API →
`Feature explorations/_shared/eurostat_medage_nuts3_2023.json` (**committed**, 0.1 MB).
`Biosphere/scripts/10_age_median_nuts3.R` documents the manual refresh as a commented
`Invoke-WebRequest` one-liner, because R's libcurl SSL-fails against Eurostat.

Known gaps in the resulting map: UK NUTS3 is absent (post-Brexit reporting), and IE/LU
per-capita GDP is inflated by corporate accounting rather than household income.

### GISCO administrative boundaries — **committed**

| File | Size | Source |
|---|---|---|
| `_shared/CNTR_RG_10M_2024_4326.geojson` | 3.7 MB | GISCO countries 1:10M, 2024 |
| `_shared/NUTS_RG_10M_2021_4326.geojson` | 5.1 MB | GISCO NUTS 1:10M, 2021 |

© EuroGeographics for the administrative boundaries. Committed because every map needs
them, they are small, and the GISCO host is the one that breaks R's libcurl.
Re-fetched if needed by `Heatwaves/scripts/1_acquire_boundaries_age_population.R`.

---

## Provenance still to pin down

Honest list of what a reader could not currently verify from this file alone. None of it
blocks re-running the pipeline; all of it should be closed before any publication.

- **Persistent identifiers (DOI / accession) for the manual downloads**: Anthromes v2,
  Anthromes 12K, HILDA+ v1 change layers, BII v2.1.1, World Atlas 2015, GLAD cropland,
  Global Human Day, `T.ambient.buildings.nc`. Author, year and version are recorded above
  and in the script headers; the exact landing-page URL and DOI are not, because they were
  obtained through a browser and never written down. Add them from the provider pages.
- **`T.ambient.buildings.nc`** has no provenance anywhere in the repository beyond the
  filename. Identify it or drop it.
- **EEA PM2.5 reference year** (see above).
- **Exact acquisition dates** for the manual files. The SHA-256 values pin the *bytes*,
  which is the part that matters for reproducibility, but not the release date.
