# Technosphere — settlement / building intensity (PROVISIONAL)

Exploratory prototype, not a settled finding (see `../CLAUDE.md`). This feature asks
what the built environment ("technosphere") looks like as an experienceable Layer-A
feature across Europe, using remote-sensed building data.

## Current state
Source: DLR World Settlement Footprint 3D (WSF3D v02), ~90 m global COGs, read via GDAL
`/vsicurl/` overviews (no full download); warped to a 3 km European window, EPSG:3035,
`average`. Note: `BuildingFraction` is Byte with **NoData = 255** (not -32767).

- **PRIMARY map:** `data_processed/maps/technosphere_built_fraction.png` — **BuildingFraction**
  (% of each cell built). Fixed % bands (0–1…16+); Inferno luminance on a **dark canvas**
  (empty = dark), mirroring `Biosphere/scripts/7_population_map.R`. External legend.
  Script: `scripts/2_map_technosphere_built_fraction.R`.
  Cached raster: `data_processed/eu_fraction_wsf3d_3km.tif`.
- **Alternative (morphology):** `technosphere_building_height.png` — mean `BuildingHeight`,
  quantile classes, light canvas. Script `1_map_technosphere_buildings.R`. Kept as the
  "how tall" view; the fraction map is the "how built-up" view.

## Decision log
- **Variable = Fraction, not Height** (2026-07-21, prior-art check per r-cartographer SKILL §0):
  "fraction" is the field's direct measure of settlement extent and matches the map's question;
  mean height over a 3 km cell mixes tall + dense and is hard to read. Style (dark-canvas
  Inferno, fixed bands) chosen to align with the project's population map.

## Open questions / likely revisions
- **Scope.** Pan-European window; other feature maps mask to the STUDY set (EU27+EFTA+UK) —
  align if this advances past exploration.
- **Layer B.** No exposure filter linked yet (Layer A only).
