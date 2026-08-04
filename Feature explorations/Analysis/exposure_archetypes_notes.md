# Exposure archetypes — method notes (2026-07-28)

Exploratory. Phase 1–2 work: these are *candidate* features, not a ranked Core set.

Scripts (run from the workspace root):
`scripts/1_build_layerA_stack_30km.R` → `2_diagnose_structure_30km.R` →
`3_compare_feature_sets_30km.R` → `4_exposure_archetypes_30km.R`.

## 1. Why the first attempt was not a typology

The earlier three-variable combination (built fraction + light pollution +
PM2.5) has a high silhouette at k = 3 (0.46) — and that is exactly the problem.
Those three variables are proxies of one thing: **PC1 alone carries 65.5 % of
their variance** (`tables/diag_feature_set_comparison.csv`). K-means on a single
gradient always yields a high silhouette, because slicing a continuum produces
compact, well-separated slices. A high silhouette therefore cannot distinguish
"there are real archetypes" from "there is one gradient". It was never a test
the clustering could fail.

## 2. Tests stated before the analysis, and their results

`2_diagnose_structure_30km.R` and `3_compare_feature_sets_30km.R` pre-declare
four disqualifying conditions. Each one actually rejected something:

| test | rule | what it rejected |
|---|---|---|
| redundancy | PC1 ≥ 65 % of variance | the 3-variable set (65.5 %), the minimal 4-variable set (69.7 %) |
| coverage | < 75 % of masked cells complete | the full 8-variable pool (56.4 %) |
| duplication | max \|Spearman\| > 0.75 | BII ↔ cropland (−0.81); pop. density ↔ night light (0.84) |
| structure | best silhouette < 0.25 | — (passed) |

Of eight pre-registered candidate sets, exactly one was admissible: **built
fraction, night-sky brightness, PM2.5, strong heat stress, heatwave days,
cropland fraction** (coverage 82.3 %, max ρ 0.62, PC1 50.0 %).

**BII and land-change frequency were dropped for coverage**, not for lack of
interest: those two alone deleted 26 % of European cells. BII is in any case
nearly the negative of cropland fraction at this support (ρ = −0.81).

## 3. Choice of k

Silhouette alone selects k = 2. Its two centres are **one-directional** — every
feature moves the same way — i.e. the single gradient again, cut in half. So the
selection rule adds two conditions silhouette cannot express:

1. the centres must span more than one direction (not a gradient cut);
2. every cluster must reach mean bootstrap Jaccard ≥ 0.75 over 25 resamples
   (Hennig 2007: below 0.75 a cluster is not a stable pattern);
3. among the k that pass, take the best mean silhouette.

k = 2 fails (1); k = 3 (J = 0.68) and k = 5 (J = 0.61) fail (2). **k = 4** wins
with J = 0.95 and silhouette 0.273. That silhouette is modest and is reported as
such on the figure: the archetypes overlap, they are recurring profiles, not
bounded regions.

## 4. Layers kept separate

Population density and GDP per capita are **Layer-B exposure filters** and were
deliberately excluded from the clustering (AGENTS.md: do not collapse the
layers). They characterise the archetypes afterwards. This also removes the
pop-density / night-light duplication that would otherwise have double-counted
urbanisation.

## 5. Support and known limits

- **30 km, EPSG:3035.** The coarsest analytic input is ERA5-HEAT UTCI at 0.25°
  (~28 km N–S). Any finer common grid would invent precision.
- **82.3 % coverage.** The WSF3D / Falchi / CAMS window excludes eastern Türkiye,
  eastern Ukraine and the Caucasus. Shown in grey on the map, not silently white.
- **UTCI ≥ 95 % valid hours** required per cell, so missing hours never read as
  "no heat stress".
- **Non-spatial clustering.** Cells are grouped in feature space only; the
  spatial coherence visible on the map is emergent, not imposed. No post-hoc
  smoothing is applied — displayed classes are the fitted classes.
- **Mixed reference years** (UTCI/heatwaves 2022, PM2.5 2024, WSF3D and Falchi
  one-shot, population 2020, GDP 2022). Acceptable for an exploratory typology;
  it would need resolving before any Phase 6 assembly.
- Only spheres A1 and A2 are represented. A3 (social organisation) and A4
  (institutional-symbolic) have no gridded pan-European source in this workspace,
  so combinations promising e.g. ultra-processed food share or logistics
  dependence are not currently computable at this support.

## 6. Result

| # | archetype (label derived from fitted centres) | % land | % population | median GDP/cap |
|---|---|---|---|---|
| A1 | low heat load, low PM2.5, low built | 27.3 | 3.7 | 41 258 |
| A2 | high heatwave days, high heat load | 35.3 | 19.0 | 30 682 |
| A3 | high cropland, high PM2.5, high built | 29.4 | 29.9 | 26 837 |
| A4 | high night light, high built, high PM2.5 | 8.1 | 47.5 | 41 498 |

Two things the map makes visible that a single-gradient map cannot:

- **A2 vs A3 are not ordered.** They separate on a second axis — anomalous heat
  vs. agricultural landscape + particulates — not on "more or less anthropogenic".
- **Land share and population share diverge.** The least-transformed archetype
  covers 27 % of European land and holds 3.7 % of Europeans; A4 is the mirror
  image (8.1 % of land, 47.5 % of people).
- A3, the archetype with the highest cropland and PM2.5, has the **lowest**
  median GDP per capita — a Layer-A × Layer-B pattern worth testing properly
  rather than asserting from this map.
