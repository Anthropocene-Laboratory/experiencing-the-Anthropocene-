# Superseded clustering scripts

These four scripts are the **first generation** of the exposure-typology work. They are
kept because they are the record of an approach that was tested and rejected on stated
grounds, not because they should be run.

**Use `Analysis/scripts/1_…4_` instead.**

| script | what it did |
|---|---|
| `1_exposure_clustering_typology.R` | k-means on built fraction + night light + PM2.5 |
| `2_exposure_clustering_profile2.R` | "techno-ecological disconnection" variant |
| `3_exposure_clustering_profile3.R` | "resource-climate vulnerability" variant |
| `3_exposure_clustering_profile3_corrected.R` | the profile-3 variant after an audit of the original map |

## Why they were superseded

The three-variable set reaches a high silhouette at k = 3 (0.46), and that is precisely
the problem: **PC1 alone carries 65.5 % of the variance of those three variables**. They
are proxies of a single gradient. K-means on one gradient always produces a high
silhouette, because slicing a continuum yields compact, well-separated slices — so the
silhouette could not distinguish "there are archetypes" from "there is one gradient".
It was not a test the clustering could fail.

The current generation pre-declares four disqualifying conditions (redundancy, coverage,
duplication, structure) *before* fitting, and this feature set is rejected by the first
of them. Full argument in `../exposure_archetypes_notes.md`.

Their figures are still present under `../data_processed/maps/` with the `profile1_`,
`profile2_`, `profile3_` and `exposure_typology_europe` prefixes. Do not present them as
current results.
