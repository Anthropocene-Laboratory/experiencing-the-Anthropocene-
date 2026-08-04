# Transport (Layer A) — source note

**Status: PROVISIONAL exploration (2026-07-30).** Not scored, not in any Core /
Shortlist / Hold bucket.

## Two different questions, two different layers

| Question | Layer | Script | Map |
|---|---|---|---|
| How much **land** does transport infrastructure take? | CLC2018 class 122 | 1–2 | `transport_land_share_10km.png` |
| **How roaded** is this place? | GRIP4 total road density | 3–4 | `road_density_grip4_8km.png` |

The second is the one to use for "roadedness". The first was built before the
question was pinned down and is kept because it answers a real, different question
(visible land take by big corridors) — but it cannot answer the roadedness one, for
the reason quantified below.

## GRIP4 road density — the roadedness layer

**Metres of road per km² of land**, all classes, GRIP4 (Meijer et al. 2018,
PBL/GLOBIO, ODbL). Native 5 arcmin (~55 km² per cell at 50°N), reprojected to 8 km
LAEA. Open direct download from `https://dataportaal.pbl.nl/downloads/GRIP4/`
(3.5 MB for the total-density zip; per-class grids tp1–tp5 also downloaded).

Result: median 354 m/km² over mapped European land, p95 1 993, max 23 026.
National means: NL 2 247, BE 2 133, LU 1 890, DE 1 591, AL 1 154, CH 1 150 m/km²
(`tables/road_density_by_country.csv`; Gibraltar/Vatican/Monaco are artefacts of
GRIP's coarse land-area grid and must be dropped before any ranking).

### Completeness check — and what would have failed it

GRIP total road length per country, against published national network length:

| | DE | FR | IT | SE | NL | PL | ES |
|---|---|---|---|---|---|---|---|
| GRIP / published | 0.68 | 0.48 | 0.52 | 0.55 | 0.55 | 0.53 | 1.58 |

GRIP recovers roughly **half** the road length. The gap is municipal/local roads:
class tp5 has a **median of 0 m/km²** across European land cells, i.e. over half of
Europe has no local road recorded at all.

The point of the check was not the level but the **spread**. Had the ratio scattered
from 0.2 to 1.5 across countries with comparably-defined networks, the map's spatial
pattern would have been an artefact of national data availability and the layer
unusable. Instead six independent road administrations land within 0.48–0.68. So:
absolute values read low by a factor ~2; relative pattern holds. Spain's 1.58 is the
reference figure being wrong for the comparison (166 000 km excludes municipal
roads), not a GRIP excess.

### PROJ trap — do not "simplify" the reprojection

`project(r, crs = "EPSG:3035")` makes PROJ route WGS84→ETRS89 through
country-specific deformation/tinshift grids (`de_*`, `nl_*`, `ch_*`,
`fi_nls_ykj_etrs35fin.json`). Those grids are missing from this PROJ install and
**terra returns NA instead of erroring** — punching a hole in the map exactly over
Germany, the Netherlands, Belgium, Switzerland and Austria. 106 806 non-NA cells
with `"EPSG:3035"` vs **113 870** with an explicit `+proj=laea … +ellps=GRS80`
string (`PROJ_NETWORK=ON` does not help). Script 4 uses the PROJ string, then tags
the result EPSG:3035, and asserts a minimum non-NA cell count so the hole cannot
come back unnoticed. **Any other script in this project that calls
`project(..., "EPSG:3035")` should be checked for the same silent hole.**

## CLC class 122 — the land-take layer (built first, keeps a narrower use)

`CLC2018 class 122` ("Road and rail networks and associated land") aggregated to a
10 km EPSG:3035 grid as **% of cell covered**.

- `scripts/1_acquire_clc122_transport_land.R` → `data_raw/clc2018_class122_eea39_3035.geojson`
- `scripts/2_map_transport_land_share.R` → `data_processed/maps/transport_land_share_10km.png`,
  `data_processed/tables/transport_land_share_by_country.csv`,
  `data_processed/transport_land_share_10km.tif` (for the 30 km Analysis stack)

Access route: the official CLC2018 100 m GeoTIFF is behind a Copernicus Land
(CLMS) login and cannot be fetched from a script. The **EEA discomap
`Corine/CLC2018_LAEA` MapServer layer 0** serves the same product as an open,
un-authenticated *vector* layer already in EPSG:3035. Class 122 is only 4 839
polygons EEA39-wide → 5 paginated requests. R's libcurl SSL-fails on that host
(same known issue as Eurostat/GISCO in this project), so requests are shelled out
to PowerShell `Invoke-WebRequest`.

Method: exact polygon×grid geometric intersection, not rasterization —
`terra::rasterize(cover = TRUE)` quantizes coverage to 1 % steps, and here the
median cell value is 0.49 %, so the quantization would be larger than the signal.

## The caveat that decides whether this feature is usable

CLC's **25 ha minimum mapping unit** and **100 m minimum width for linear
elements** mean an ordinary 2-lane road (10–20 m wide) is *never* in class 122.
What is actually mapped is wide transport *land*: motorway carriageways with
verges and interchanges, large rail yards, port/airport access corridors.

Measured consequence:

| | value |
|---|---|
| class 122, EEA39 | **4 143 km²** (4 839 polygons, median 43 ha) |
| share of Europe's land surface | **≈ 0.07 %** |
| literature road+rail footprint | order of **1–2 %** |
| non-zero 10 km cells (in window) | 2 468 of 140 000 |
| non-zero cell shares | Q1 0.27 %, median 0.49 %, Q3 1.02 %, p99 3.35 %, max 8.9 % |

So this layer under-captures the transport footprint by roughly a factor of 20.
**It is an honest map of big transport infrastructure; it is not road-network
density.** Titles, captions and any downstream use must say so.

What it *does* show well: the motorway/rail spine of Europe — the German autobahn
grid, the Po valley, Benelux, the Iberian and Greek/Balkan corridors. Read as
"where transport takes visible land", it works. Read as "how roaded is this
place", it is wrong.

National shares (`tables/transport_land_share_by_country.csv`) top out at
0.37 % (SI), 0.34 % (BE), 0.30 % (NL) — Vatican City's 0.75 % is a small-polygon
artefact and should be dropped before any ranking.

## Remaining upgrade paths for the roadedness layer

| Source | Grandeur | Res. | Note |
|---|---|---|---|
| **GRIP4** (in use, scripts 3–4) | road length per km², also by class tp1–tp5 | 5 arcmin ≈ 8 km | ODbL, open; coarser than the 1–3 km of other Layer-A features, but the Analysis stack runs at 30 km so this is not binding |
| OSM via Geofabrik | road length per cell, any resolution, filterable by class | your choice | the only route to a true 1 km layer, and it would close GRIP's local-road gap; cost = summing lengths continent-wide |
| EEA Effective Mesh Density (FGA1-S / FGA2-S) | landscape fragmentation, meshes per 1 000 km² | 1 km LEAC grid | measures *severance*, a different experienceable quantity — a candidate feature of its own, not a substitute |
| Eurostat `tran_r_net` | road-network km per NUTS 0/1/2 | admin units | voluntary reporting → national gaps; Layer-B style, not Layer A |
