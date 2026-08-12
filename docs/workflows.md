# Workflow map

[Documentation index](README.md) · [Getting started](getting-started.md) · [Troubleshooting](troubleshooting.md)

The numbered scripts are **not one global sequence**. Numbers describe order within a
feature or an analytical branch. Do not run every script from `1` to `10` mechanically.
Choose a research question, identify the required source data, and follow only that
branch.

## Execution model

1. **Inspect** source availability with `Rscript download_data.R`.
2. **Acquire** a selected source with `--id=...` or `--feature=...`, or follow the manual
   target in [`../data_sources.md`](../data_sources.md).
3. **Process/map** with the numbered scripts in the relevant feature folder.
4. **Validate** the expected files, units, coverage, and caveats before interpreting a
   result.
5. **Combine** features only after the Layer-A inputs have passed their own checks.

The acquisition catalogue has four routes:

| Route | Meaning |
|---|---|
| scripted | the repository can download the input |
| credentialed | scripted, but a CDS/ADS account and accepted terms are required |
| streamed | read over the network when the processing script runs; no local source file |
| manual | a browser, login, form, or licence step prevents unattended acquisition |

## Recommended first workflows

### Connectivity: measured internet performance

```powershell
Rscript download_data.R --id=ookla
Rscript "Feature explorations/Connectivity/scripts/2_map_ookla_experienced_speed.R"
```

Script `1_acquire_ookla_tiles.R` downloads fixed and mobile tiles and writes European
GeoPackages under `Connectivity/data_raw/`. Script `2_` creates the 5 km speed-and-effort
maps, reusable rasters, and a country summary. Always interpret speed together with the
number of tests: blank means “not observed”, not “no service”.

`3_map_broadband_coverage_eurostat.R` is an independent availability branch based on
operator/regulator reporting. It is not a required predecessor or successor of the Ookla
branch. `4_extract_bce_pdf_tables.py` is a supporting extraction utility for BCE reports.

### HILDA+ v2: annual land-use change frequency

Acquire the input without starting the long calculation:

```powershell
Rscript download_data.R --id=hilda_v2
```

Then calculate the 1960-2019 change-frequency product:

```powershell
Rscript "Feature explorations/Biosphere/scripts/4b_change_freq_hilda_v2.R"
```

The script accepts a ZIP elsewhere on the computer through `--archive="..."` or a folder
of 60 extracted annual states through `--states-dir="..."`. HILDA+ v1 is optional and is
used only for the v1-v2 QA comparison. Full manual examples are in the
[getting-started guide](getting-started.md#6-hilda-v2-example).

### Transport: two different questions

```powershell
Rscript download_data.R --feature=Transport
```

- `1_acquire_clc122_transport_land.R` → `2_map_transport_land_share.R` maps land occupied
  by wide CORINE transport infrastructure. It does not measure ordinary-road density.
- `3_acquire_grip4_road_density.R` → `4_map_road_density_grip4.R` maps road-network
  length density and is the appropriate branch for “how roaded is this place?”.

The branches are alternatives answering different questions, not successive versions of
one variable.

## Other feature branches

| Feature | Branch | Main access constraint |
|---|---|---|
| Technosphere | scripts `1` and `2` independently stream WSF3D height/fraction; script `3` maps night-sky brightness | WSF3D needs internet at run time; night-sky source is manual |
| Air quality | script `1` maps the manual EEA raster; scripts `2→3` download and map CAMS | EEA source manual; CAMS requires ADS credentials and accepted terms |
| Biosphere / anthromes | `1`, `2`, `2b`, `3`, and `3b` explore state and change at different thematic resolutions | Anthromes inputs are manual; HILDA COGs are streamed |
| Biosphere / BII | `5→6` maps land status and then population-weighted status | BII is manual and CC-BY-NC-SA; population input also required for `6` |
| Layer-B filters | Biosphere scripts `7`, `8`, `9`, and `10` map population, wealth, and age filters | routes differ; these are not Layer-A features |
| Heatwaves | acquisition scripts → thresholds/preparation → calculation → validation → visualisation | large CDS downloads, credentials, and substantial compute time |

For every branch, treat the script header and [`../data_sources.md`](../data_sources.md)
as the authoritative input contract. A file being present does not prove that its version,
licence, coverage, or units are correct.

## Cross-feature analysis

`Feature explorations/Analysis/scripts/0_load_layers.R` is an interactive registry. It
loads existing files and reports missing ones; it is not a pipeline stage.

The analytical sequence is:

```text
1_build_layerA_stack_30km.R
  → 2_diagnose_structure_30km.R
  → 3_compare_feature_sets_30km.R
  → 4_exposure_archetypes_30km.R
```

This sequence requires processed outputs from several feature branches, including manual
inputs. It preserves Layer-B variables for profiling and excludes them from Layer-A
clustering. Do not start it on a fresh clone and expect the missing sources to appear.

## What a successful run proves

An exit code of zero proves only that the script completed. Before using an output, also
check:

- the expected file was written at the documented path;
- the source version and checksum, where available;
- the CRS, extent, resolution, units, and non-missing coverage;
- any QA table or explicit fail criterion produced by the script;
- whether the output changed relative to the committed comparison artifact;
- the input and output licence obligations.

See [`reproducibility.md`](reproducibility.md) for the complete evidence standard.
