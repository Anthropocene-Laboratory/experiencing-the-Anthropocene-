# Getting started on a new computer

[Documentation index](README.md) · [Workflow map](workflows.md) · [Troubleshooting](troubleshooting.md)

This guide starts from a fresh clone. The key distinction is:

- `scripts/download-data.R` acquires source data;
- the numbered feature scripts transform source data and create maps or tables;
- `0_load_layers.R` only opens files that are already on disk. It never downloads or computes data.

Do not change `setwd()` or paste a personal `C:/Users/...` path into a script. When launched from the RStudio project or any directory inside the clone, the scripts locate the repository through its `.here` marker and put files into that clone.

## 1. Clone and open the project

```powershell
git clone https://github.com/Anthropocene-Laboratory/experiencing-the-Anthropocene-.git
cd experiencing-the-Anthropocene-
```

The simplest RStudio workflow is to open `experiencing-the-anthropocene.Rproj`. This makes the clone the active project and activates `renv`.

## 2. Install the R environment once

From the RStudio Console:

```r
renv::restore()
```

Or from PowerShell, while inside the clone:

```powershell
Rscript -e "renv::restore()"
```

If Windows says that `Rscript` is not recognised, run commands from the RStudio
Console without guessing an installation path:

```r
rscript <- file.path(R.home("bin"), "Rscript.exe")
system2(rscript, c("scripts/download-data.R", "--id=ookla"))
```

Use R 4.5.x if possible. The exact R packages are recorded in `renv.lock`; GDAL and PROJ come from the local R installation and can still differ between computers.

Python is only required for the Copernicus acquisition scripts:

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
```

## 3. Understand where the files go

A fresh clone contains scripts, documentation, and selected final outputs, but not the large source datasets. Each feature follows this layout:

```text
Feature explorations/<Feature>/
  data_raw/          downloaded or manually supplied source files; ignored by git
  data_processed/    intermediate rasters plus final maps and tables
  scripts/           numbered acquisition, processing, and mapping scripts
```

Keep manually downloaded files in the exact target path stated in [`data-sources.md`](data-sources.md). Do not change the working directory to the Downloads folder: doing so can make relative code create a second folder tree in the wrong place.

The one intentional exception is HILDA+ v2: its script accepts an archive anywhere on the computer with `--archive=...`, so the 3.5 GB ZIP does not need to be copied.

## 4. Inspect and acquire data

This command is a status report and downloads nothing:

```powershell
Rscript scripts/download-data.R
```

Choose a dataset or feature explicitly:

```powershell
Rscript scripts/download-data.R --id=ookla
Rscript scripts/download-data.R --feature=Transport
Rscript scripts/download-data.R --id=hilda_v2 --dry-run
```

Use `--all` only after reviewing the catalogue: it represents about 25 GB of downloads, and some inputs still require credentials or manual browser access. Re-running a completed job is safe because existing inputs are skipped; add `--force` only when a fresh download is genuinely required.

## 5. Connectivity example

Acquire the two Ookla archives and retain their European tiles:

```powershell
Rscript scripts/download-data.R --id=ookla
```

Expected local inputs:

```text
Feature explorations/Connectivity/data_raw/ookla_mobile_2026Q1_europe.gpkg
Feature explorations/Connectivity/data_raw/ookla_fixed_2026Q1_europe.gpkg
```

Then create the 5 km rasters, figures, and country table:

```powershell
Rscript "Feature explorations/Connectivity/scripts/2_map_ookla_experienced_speed.R"
```

Outputs are written under `Feature explorations/Connectivity/data_processed/`. The downloaded data are files on disk, not objects permanently stored “in R”; each new R session reads them again from those paths.

## 6. HILDA+ v2 example

### Automatic route

Download or detect the official input without starting the long calculation:

```powershell
Rscript scripts/download-data.R --id=hilda_v2
```

The archive is stored at:

```text
Feature explorations/Biosphere/data_raw/biosphere/hilda_plus_v2/hildap_vGLOB-2.0_geotiff_wgs84.zip
```

An interrupted automatic download is kept as a `.part` file. Re-run the same command to resume it. Once the input is ready, calculate the 1960-2019 change-frequency layer:

```powershell
Rscript "Feature explorations/Biosphere/scripts/4b_change_freq_hilda_v2.R"
```

### ZIP downloaded manually

The official file is `hildap_vGLOB-2.0_geotiff_wgs84.zip`, 3,755,961,841 bytes, MD5 `56fe959df25d8efbc542b90cf971945f`. Either copy it to the target path above, or leave it where it is and pass its full path:

```powershell
Rscript "Feature explorations/Biosphere/scripts/4b_change_freq_hilda_v2.R" --archive="C:/Users/YOUR_NAME/Downloads/hildap_vGLOB-2.0_geotiff_wgs84.zip" --verify-md5
```

The ZIP does not need to be unzipped: GDAL reads the required GeoTIFF members directly. If the 60 annual state files for 1960-2019 are already extracted, point to their folder instead:

```powershell
Rscript "Feature explorations/Biosphere/scripts/4b_change_freq_hilda_v2.R" --states-dir="D:/data/HILDA/states_wgs84"
```

The HILDA+ v1 change layer is optional. When present, `4b` adds a v1-v2 comparison to the QA table; when absent, the v2 calculation still completes and records that the comparison was skipped.

## 7. Explore files with `0_load_layers.R`

From RStudio after opening the `.Rproj`:

```r
source("Feature explorations/Analysis/scripts/0_load_layers.R")
anth_layers()
anth_layers(only_available = TRUE)
anth_info("ookla_fixed")
r <- anth("ookla_fixed")
anth_plot("ookla_fixed")
```

`anth_layers()` reports both available and missing files. Sourcing the loader successfully means only that its functions were defined; it does not mean every listed dataset is installed.

By default, raw data are sought inside the current clone. For interactive loading only, an alternative project-shaped raw-data root can be selected before sourcing:

```r
options(anth.raw_root = "D:/Anthropocene-data")
source("Feature explorations/Analysis/scripts/0_load_layers.R")
```

That alternative root must contain the same `Feature explorations/<Feature>/data_raw/...` structure. Numbered processing scripts still use the clone's own `data_raw/` paths, except for the explicit HILDA `--archive` and `--states-dir` options.

## 8. Next steps

- Use the [workflow map](workflows.md) to identify a script's prerequisites and outputs.
- Use the [troubleshooting guide](troubleshooting.md) for missing files, credentials,
  downloads, path problems, platform limitations, or unexpected results.
- Dataset-specific URLs, licences, checksums, sizes, and manual target paths remain
  authoritative in [`data-sources.md`](data-sources.md).
