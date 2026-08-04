# Feature explorations - folder convention

This guide governs the PHYSICAL folder layout under `Feature explorations/`.
For the conceptual A/B/C/D layer architecture (what a "feature," "exposure
filter," etc. means), see the root `AGENTS.md` and `Feature library/Merged_datasets.xlsx`
(the master feature catalogue) - do not duplicate that content here.

## Why this exists

**This whole folder is exploratory/prototype work, not a finished pipeline.**
The project's roadmap has not yet reached Phase 2 (feature ranking) - nothing
here has been scored or placed into a Core / Shortlist / Hold bucket. Each
feature folder is asking "what CAN we do with this feature, given available
data?", not delivering a final, validated analysis. Concretely this means:
- Methods and results documented here (e.g. the methods .docx) should be
  read and written as provisional and open to revision, not as settled
  findings - say so explicitly rather than presenting them as final.
- A feature folder existing here does not mean that feature will end up in
  the project's final Core set; some explorations may turn out infeasible
  or get dropped after Phase 2 ranking.
- It's normal and expected for a feature's method to change after a working
  prototype reveals a problem (e.g. the GHD linkage in `Heatwaves/` was
  revised more than once after the naive version turned out not to work as
  intended - that back-and-forth is the point of this stage, not a failure).

Within that exploratory work, work on this project happens per experienceable
feature (heatwaves, biosphere, whatever comes next): explore data -> map the
Layer A feature -> link a Layer B exposure filter -> document. That cycle cuts
across several roadmap phases at once for a single feature, so folders are
organized BY FEATURE, not by roadmap phase number. Roadmap phase numbers (0-8)
live only in `Project management/Anthropocene_Project_Roadmap.docx`, never as
folder names here.

## Layout

```
Feature explorations/
  <FeatureName>/              one folder per experienceable feature
    data_raw/                 downloaded/source data, untouched
    data_processed/
      maps/                   every final PNG figure
      tables/                 every CSV table (composition, intensity
                               analysis, transition matrices, exposure
                               summaries, ...)
      (rasters directly here) intermediate .nc/.tif/.aux.xml files that
                               flow between scripts in the same pipeline -
                               NOT sorted further. They are computational
                               plumbing, not a deliverable a person browses.
    scripts/                  R/Python, run from the workspace ROOT
    <feature-specific .md/.docx notes>
  _shared/                    cross-feature reference data used by MORE THAN
                               ONE feature (e.g. CNTR_RG_10M_2024_4326.geojson,
                               pop2020_0p1deg.tif). Check here before
                               re-downloading something a new feature needs.
  <cross-feature docs>        a document that covers more than one feature
                               (e.g. "Heatwave exposure mapping methods.docx",
                               which has a Part I per feature) sits at THIS
                               root level, not inside one feature folder.
```

Existing features: `Heatwaves/`, `Biosphere/`, `Technosphere/`, `Air quality/`,
`Transport/`, plus the cross-feature `Analysis/`.

Note on `data_raw/`: it is never committed to git (see the root `.gitignore`) and
may not be present at all in a fresh clone. Every source is documented in the
root `data_sources.md`, with the acquisition script that re-creates it.

## Rules for adding a new feature or script

1. New feature -> create `Feature explorations/<FeatureName>/` with the same
   `data_raw/ data_processed/{maps,tables}/ scripts/` shape as the existing
   features.
2. A script that writes a final PNG -> write it to `data_processed/maps/`.
   A script that writes a CSV table -> write it to `data_processed/tables/`.
   Intermediate rasters stay at the `data_processed/` root.
3. Before downloading a reference file (country boundaries, population grids,
   anything not specific to one feature), check `_shared/` first.
4. A note or methods doc scoped to one feature lives inside that feature's
   folder (e.g. `Heatwaves/ghd_heatwave_linkage.md`). A doc that discusses
   more than one feature lives at the `Feature explorations/` root.
5. Scripts resolve the repository root with `here::here()`, never with an
   absolute path and never with a bare `setwd()` to someone's own folder.
   `here::here()` walks up from the working directory until it finds the `.here`
   marker at the repository root, so a script runs identically whether it is
   launched from the root, from RStudio, from its own `scripts/` folder, or on
   somebody else's machine.

   R, either form:
   ```r
   setwd(here::here())                                   # then use relative paths
   base_dir <- here::here("Feature explorations", "Heatwaves")
   ```

   Python, the equivalent (no extra dependency needed):
   ```python
   workspace = Path(__file__).resolve().parents[3]
   ```

   Paths below the root stay relative and written with forward slashes, e.g.
   `"Feature explorations/Heatwaves/data_processed"`.

   **A hardcoded `C:/Users/...` path is a defect, not a shortcut** - it is the
   single thing that stops a collaborator from running the pipeline. This whole
   repository was cleaned of 32 of them; do not reintroduce one.
