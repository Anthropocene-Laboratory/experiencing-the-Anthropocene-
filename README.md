# Experiencing the Anthropocene

[![Repository checks](https://github.com/Anthropocene-Laboratory/experiencing-the-Anthropocene-/actions/workflows/repository-checks.yml/badge.svg)](https://github.com/Anthropocene-Laboratory/experiencing-the-Anthropocene-/actions/workflows/repository-checks.yml)

Research code, method notes, and provisional outputs for mapping how human-driven
Earth-system transformations are encountered in daily life across Europe: heat on the
body, particles in the air, built and transport infrastructure, connectivity, night-sky
brightness, and biosphere change.

> **Research status — exploratory, not a validated production pipeline.** The project
> has not completed feature ranking or final cross-feature validation. Do not treat the
> committed maps as settled findings. Read the feature notes and provenance before
> interpreting or reusing an output.

## Start here

| I want to… | Read or run |
|---|---|
| understand the project and its analytical layers | [`docs/project-architecture.md`](docs/project-architecture.md) |
| install the environment and run a first script | [`docs/getting-started.md`](docs/getting-started.md) |
| know which scripts and inputs belong to a workflow | [`docs/workflows.md`](docs/workflows.md) |
| find a dataset, licence, checksum, or manual target path | [`docs/data-sources.md`](docs/data-sources.md) |
| diagnose an error or unexpected output | [`docs/troubleshooting.md`](docs/troubleshooting.md) |
| assess what is and is not reproducible | [`docs/reproducibility.md`](docs/reproducibility.md) |
| propose a change or report a problem | [`.github/CONTRIBUTING.md`](.github/CONTRIBUTING.md) |
| cite or reuse code, data, figures, or tables | [`CITATION.cff`](CITATION.cff) and [`docs/licensing.md`](docs/licensing.md) |

The longer documentation is deliberately separate from this README. The README is the
landing page; `docs/` contains procedures that need enough detail to be followed without
guessing.

## Ten-minute orientation

Clone the repository and open the RStudio project:

```powershell
git clone https://github.com/Anthropocene-Laboratory/experiencing-the-Anthropocene-.git
cd experiencing-the-Anthropocene-
```

Open `experiencing-the-anthropocene.Rproj`, then restore the recorded R environment:

```r
renv::restore()
```

Inspect the data catalogue. With no arguments, this command **downloads nothing**:

```powershell
Rscript scripts/download-data.R
```

Preview a small workflow, acquire its inputs, and reproduce one figure:

```powershell
Rscript scripts/download-data.R --feature=Transport --dry-run
Rscript scripts/download-data.R --feature=Transport
Rscript "Feature explorations/Transport/scripts/4_map_road_density_grip4.R"
```

See the [getting-started guide](docs/getting-started.md) if `Rscript` is not on the
Windows path, if you use RStudio rather than a terminal, or if data were downloaded
manually.

## What is and is not in the repository

Included:

- R and Python acquisition, processing, mapping, and analysis scripts;
- the `renv.lock` and `requirements.txt` dependency records;
- data provenance and method notes;
- selected final PNG figures and CSV tables for comparison.

Not included:

- roughly 40 GB of raw and intermediate source data;
- datasets whose terms prohibit redistribution;
- literature PDFs and internal Word, Excel, or presentation files;
- credentials for Copernicus or other services.

Raw data belong under each feature's `data_raw/` folder and are ignored by git. Large
intermediate rasters belong at the `data_processed/` root and are also ignored. Final
figures go to `data_processed/maps/`; final tabular outputs go to
`data_processed/tables/`. Exact source locations and exceptions are recorded in
[`docs/data-sources.md`](docs/data-sources.md).

## Analytical architecture

The repository follows a five-step causal stack:

1. **Anthropocene components** — upstream Earth-human system changes.
2. **Layer A: experienceable features** — human-facing interfaces.
3. **Layer B: exposure filters** — who encounters which features and how often.
4. **Layer C: implications** — health, wellbeing, cognition, and social outcomes.
5. **Layer D: response capacities** — institutional, collective, cultural, and technical capacities.

Do not collapse these roles. In particular, population, wealth, demographics, and time
use are exposure filters; they are not Layer-A experienceable features. The complete
classification rules are in [`docs/project-architecture.md`](docs/project-architecture.md).

## Repository layout

```text
Feature explorations/
  <Feature>/
    data_raw/          source data; local only
    data_processed/    intermediates plus maps/ and tables/
    scripts/           numbered workflow steps
    *_notes.md         methods, limitations, and unresolved points
  _shared/             small reference inputs shared across features
  Analysis/            cross-feature harmonisation and exploratory analysis
docs/                  user, workflow, troubleshooting, and reproducibility guides
validation/            repository and scientific validation scripts
.github/               collaboration templates and automated checks
scripts/                repository-level command-line entry points
```

## Reproducibility contract

- R package versions are recorded in `renv.lock`; Python acquisition dependencies are
  recorded in `requirements.txt`.
- Scripts resolve paths from the repository root. A personal `C:/Users/...`,
  `/Users/...`, or `/home/...` path in executable code is a defect.
- `scripts/download-data.R` distinguishes scripted, streamed, credentialed, and manual inputs.
- Source data, methods, and generated outputs remain separate.
- Dataset versions, retrieval routes, licences, and known checksums are recorded in
  `docs/data-sources.md`.
- `Rscript validation/check_repository.R` runs fast structural checks without downloading
  data or recomputing maps.

This is not yet a one-command reproducible compendium: several sources require manual
access, some workflows are Windows-specific, and cross-platform numerical equivalence is
not fully tested. The exact boundaries of current reproducibility are documented in
[`docs/reproducibility.md`](docs/reproducibility.md).

## Getting help and contributing

Before opening an issue, check [`docs/troubleshooting.md`](docs/troubleshooting.md) and
run `Rscript scripts/download-data.R` to identify missing inputs. Use the GitHub issue forms for
usage help, a code failure, a data/provenance problem, or a scientific-method question.
Never attach licensed source data, credentials, confidential material, or personal paths
to an issue.

Changes should be proposed on a branch and reviewed through a pull request. The project
requires contributors to preserve the Layer A/B/C/D distinction, document provenance,
state whether outputs changed, and record the validation performed. See
[`.github/CONTRIBUTING.md`](.github/CONTRIBUTING.md).

## Citation and licences

Citation metadata are in [`CITATION.cff`](CITATION.cff); the author list must be confirmed
before the first formal release. Cite the underlying datasets as well as this repository.

The source code is MIT-licensed. Data and derived outputs can have different or more
restrictive terms, including attribution, non-commercial, share-alike, or database
licence obligations. Read [`docs/licensing.md`](docs/licensing.md) and the relevant entry in
[`docs/data-sources.md`](docs/data-sources.md) before redistribution.

Maintained by the Anthropocene Laboratory project team. See the
[`.github/CODE_OF_CONDUCT.md`](.github/CODE_OF_CONDUCT.md) for participation standards.
