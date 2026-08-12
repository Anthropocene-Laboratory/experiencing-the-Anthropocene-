# Troubleshooting

[Documentation index](README.md) · [Getting started](getting-started.md) · [Workflow map](workflows.md)

Start every diagnosis with these two commands from inside the clone:

```powershell
Rscript download_data.R
Rscript validation/check_repository.R
```

The first reports source-data availability without downloading anything. The second checks
repository structure, R syntax, local documentation links, forbidden personal paths, and
accidentally tracked raw data without running a scientific analysis.

## Symptom guide

| Symptom | Likely cause | First action |
|---|---|---|
| `Rscript` is not recognised | R's command-line directory is not on Windows `PATH` | use the RStudio Console method in [getting started](getting-started.md#2-install-the-r-environment-once) |
| `there is no package called ...` | `renv` was not restored or activated | open the `.Rproj`, then run `renv::restore()` |
| `Not on disk` or `cannot open` | required raw/intermediate input is absent | run the catalogue and inspect the exact missing path |
| sourcing `0_load_layers.R` works but layers are missing | the loader defines functions; it does not acquire data | run `anth_layers()` and acquire the relevant inputs |
| a new `Feature explorations/` tree appears elsewhere | the working directory was changed to a non-project folder | stop, return to the clone, and do not edit `setwd()` |
| download command prints a catalogue but transfers nothing | `download_data.R` was run with no selection | add `--id=...`, `--feature=...`, or `--all` after reviewing size/cost |
| CDS/ADS request fails | credentials absent, dataset terms not accepted, or request too large | test `.cdsapirc`; accept the dataset terms; use the repository's chunked request |
| HILDA ZIP has an unexpected size | interrupted download or HTML error page saved as ZIP | rerun to resume `.part`, or use the official manual ZIP with `--verify-md5` |
| central Europe becomes `NA` after reprojection | local PROJ lacks deformation grids used by the EPSG route | use the explicit LAEA/GRS80 string already established in project scripts |
| a reproduced PNG differs | environment, source version, font/rendering, or code changed | inspect numeric QA before treating a visual diff as scientific change |

## Paths and working directories

Executable code must not contain a collaborator's personal path. Active R scripts resolve
the `.here` marker from within the clone; Python scripts resolve from `__file__`.

Correct:

```r
root <- here::here()
input <- file.path(root, "Feature explorations", "Biosphere", "data_raw", "...")
```

Incorrect:

```r
input <- "C:/Users/a-person/OneDrive/project/data.tif"
```

Do not change the working directory to the location of a manually downloaded file. Move
the file to its documented target, or use a supported argument such as HILDA's
`--archive="..."`.

## R and `renv`

R 4.5.x is the recorded environment. Opening `experiencing-the-anthropocene.Rproj`
activates `renv`; `renv::restore()` installs the versions in `renv.lock`.

If using a newer R, binaries for pinned package versions may not exist. Installing current
binaries can be useful for exploration, but it is a different environment and must be
reported in any reproduction result. Do not run `renv::snapshot()` merely to remove a
warning: it changes the shared environment definition.

Check native geospatial libraries with:

```r
sf::sf_extSoftVersion()
terra::gdal(lib = "all")
```

## Python and Copernicus credentials

Python is needed only for selected acquisition utilities. Create the environment described
in the getting-started guide and never commit `.venv/`, `.cdsapirc`, `.Renviron`, tokens,
or API responses containing secrets.

On Windows, R and Python can resolve the home directory differently. The acquisition
manager checks `%USERPROFILE%`, `%HOME%`, and R's expanded home. A credential test should
be run before any multi-gigabyte request:

```powershell
python "Feature explorations/Heatwaves/scripts/1_acquire_test_cds_connection.py"
```

## Downloads, disk space, and retries

- Review the catalogue size before using `--all`.
- A directory existing is not proof that a download completed; verify the specific target
  file and checksum where documented.
- HILDA automatic downloads use a resumable `.part` file when `curl` is available.
- Streamed COG workflows still require stable internet even when `data_raw/` looks full.
- Keep raw and intermediate data outside version control; accidentally committing a large
  raster permanently enlarges repository history.

## Platform-specific limitations

Some acquisition scripts use PowerShell `Invoke-WebRequest` because R/libcurl failed
against particular Eurostat, GISCO, EEA, GRIP, or Ookla endpoints in the development
environment. Those scripts are Windows-specific as written. Processing scripts are
intended to be portable, but cross-platform numerical equivalence is not yet continuously
tested.

## Unexpected scientific results

Do not “fix” an unexpected map by changing colour limits, dropping missing cells, swapping
resampling methods, or adding variables until the numerical cause is known. Check the
source range, units, CRS, coverage, aggregation rule, population denominator, reference
period, and the script's predefined fail criteria.

Open a scientific-method issue when a result challenges an assumption rather than when
the code merely crashes. State whether the concern affects an Anthropocene component,
Layer-A feature, Layer-B filter, implication, or response capacity.

## Reporting a useful issue

Include:

- operating system, R version, and `sf::sf_extSoftVersion()`;
- exact script and command;
- first complete error message, not only the last line;
- output of `Rscript download_data.R` for the relevant dataset;
- source version/checksum if known;
- whether the file is automatic, streamed, credentialed, or manual;
- the smallest reproducible example that does not expose data or credentials.

Use the repository's issue forms. Do not upload third-party source data, confidential
documents, credentials, or screenshots containing personal filesystem paths.
