# Connectivity (Layer A) — source note

**Status: PROVISIONAL exploration (2026-08-04).** Not scored, not in any Core /
Shortlist / Hold bucket.

## Two layers, deliberately stacked

| Question | Layer | Script | Map |
|---|---|---|---|
| Is a network **offered** here? | Eurostat `isoc_cbt` (DG CNECT Broadband Coverage in Europe) | 3 | `broadband_coverage_vhcn_5g.png` |
| What do people **actually get** when they use it? | Ookla Speedtest open tiles, fixed + mobile | 1–2 | `ookla_{mobile,fixed}_speed_and_effort_5km.png` |

A third quantity — *adoption*, whether households take up the service — is Layer B,
not Layer A: Eurostat `isoc_r_iacc_h` / `isoc_r_broad_h`, NUTS2. Not built here.

## Correction to the plan: no open NUTS3 coverage data

The BCE study **collects** at NUTS3 (1 383 regions, 31 countries), and that is what
was assumed when this feature was scoped. It is **not released** at NUTS3:
`digital-strategy.ec.europa.eu` publishes report PDFs only, and Eurostat's
dissemination of the same survey (`isoc_cbt` by technology, `isoc_cbs` by speed) is
**national, split only by degree of urbanisation** (`terrtypo` = TOTAL / DEG3 rural).
Checked directly against the API: 21 technologies × 2 territory types × 32 geos,
2024–2025.

So the availability layer is a national choropleth with a rural split, not a
surface.

### The BCE PDFs contain no NUTS3 table either — checked, not assumed

The obvious next move was to extract NUTS3 from the report PDFs. Done, and it does
not work, for a reason worth recording rather than rediscovering (script 4):

- Both final reports were parsed page by page — **2024 (236 pp.)** and **2023
  (226 pp.)**. Every extractable table is **per country**: a 67×11 block in each
  country chapter, plus the annex tables on pp. 230–233, one row per country.
  There is no table with 1 383 rows, or anything close, anywhere.
- The "Regional coverage by broadband technology" pages carry the NUTS3
  information as **flat raster images** — 1 259 × 763 DeviceRGB bitmaps, zero
  vector shapes, zero embedded text. Nothing to parse. At best one could sample
  pixel colours back to legend *classes*, never to values.
- The report states the reason itself, p. 30: much of the coverage data,
  "especially on such a granular level", is treated as commercially sensitive.
  P. 34 adds that the speed categories were only ever collected nationally.

So the remaining route to real NUTS3 values is **licensing Point Topic** (NUTS3,
2011–present, commercial), or going to national regulators' own broadband maps
country by country.

### What script 4 does extract

Everything the PDFs *do* contain, which is still richer than Eurostat's `isoc_cbt`
— three years at once, 18 metrics including the speed categories, and per-country
population/household context:

| file | content |
|---|---|
| `bce2024_country_coverage.csv` | **2 232 rows** — 31 countries × 3 years (2024/2023/2022) × 18 metrics × {total, rural}, plus the EU27 reference column |
| `bce2024_country_context.csv` | population, persons per household, rural proportion, per country |
| `bce2024_regional_extremes.csv` | the only NUTS3 numbers in the document: the best/worst region named in each country's regional prose — **11 of 31 countries**, e.g. Austria 18.4 % Oberkärnten → 93.9 % Wien; Germany rural 0.2 % St. Wendel → 99.8 % Lüchow-Dannenberg |
| `bce2024_vs_eurostat_check.csv` | validation, below |

**Validation.** 308 country × metric × territory pairs compared against Eurostat
`isoc_cbt` 2024: **mean absolute difference 0.34 pp**, and 294 of 308 agree within
1 pp. What would have indicted the parser is a systematic offset, or errors spread
evenly across countries. Instead the 14 outliers concentrate in **four** countries
(CH, NO, LT, SI), which is a data restatement between the report and Eurostat's
later dissemination, not a parsing error.

Switzerland is the one to watch: the PDF gives FTTP 50.4 % total / 27.2 % rural for
2024, Eurostat gives 62.1 % / 58.4 % — up to **31 pp apart**, and Eurostat's own CH
2024 row is inconsistent with its 2025 row (DSL total 87.9 % then 99.4 %, against a
flat 99.5 % across all three years in the report). **Do not mix the two sources for
Switzerland**; pick one and say which.

The rural split is not a consolation prize — it carries the digital divide directly.
Widest rural shortfalls in gigabit-capable fixed coverage, 2025 (percentage points,
national minus rural): **LV 55.8, EL 52.8, CZ 42.8, LT 40.8, AT 34.3, IT 33.1**.
For 5G: IS 78.7, RO 36.6, then a long drop to FR 13.7 and UK 12.2.

## The Ookla layer, and why it is never shown alone

Zoom-16 tiles (~610 m), 2026 Q1, EPSG:4326, aggregated here to 5 km LAEA.
**982 851** European mobile tiles (4.5 M tests) and **1 830 713** fixed tiles
(26.3 M tests). Licence **CC BY-NC-SA 4.0** — non-commercial *and* share-alike, the
same constraint family already hit with the BII layer.

Aggregation is **test-weighted**: `sum(avg_d_kbps × tests) / sum(tests)` per cell.
Tile test counts run from 1 to several thousand, so an unweighted mean of tile means
would let a single-test tile outvote a city block.

Result, mobile: test-weighted median **71.9 Mbps** per 5 km cell; fixed **172.2 Mbps**.

**The sampling problem.** A tile exists only because somebody chose to run a
Speedtest. Blank does not mean no service — it means nobody tested. And
participation correlates with income, education, age and urbanity, i.e. with the
variables this feature would be crossed against. Measured here: **45.3 % of mobile
cells rest on fewer than 5 tests** (25.6 % for fixed).

This is a *weaker* guarantee than the one that licensed the GRIP4 roadedness map in
[[project_transport_feature]]. There, under-capture was near-constant across
countries, so the spatial pattern survived a level error. Here the bias is
correlated **with** the mapped quantity, so no constant correction exists. Hence the
design: every speed panel is paired with a panel of the sampling effort behind it,
and the layer is labelled "speed among those who tested", not "speed here".

## Literature this follows

- **Riddlesden & Singleton (2014)**, *Broadband speed equity: a new digital divide?*,
  Applied Geography 52:25–33 — the precedent for mapping speed-test data as a
  geography; England.
- **Salemink, Strijker & Bosworth (2017)**, Journal of Rural Studies 54:360–371 —
  systematic review; the availability / adoption / use distinction used above.
- **Mack et al. (2024)**, International Regional Science Review — 1995–2022 review of
  broadband and rural development.
- *Economic growth and broadband access: the European urban–rural digital divide*,
  Telecommunications Policy (2023).
- On the crowdsourcing bias specifically: Paul et al., *Characterizing performance
  inequity across U.S. Ookla Speedtest users*; and arXiv:2310.16136, which proposes a
  demographic bias correction. **Not applied here** — it would need population
  weights per cell, which is a next step, not a done one.

## Reproduction notes

- Ookla is fetched as the **zipped shapefile**, not parquet: no arrow/nanoparquet/
  duckdb in this renv and GDAL 3.12.1 here has no Parquet driver. The `.shp` inside
  is named `gps_{type}_tiles.shp`, not after the zip — discover it, don't assume.
  `sf::st_read(wkt_filter = )` keeps only European tiles in memory.
- `avg_d_kbps * tests` **overflows integer arithmetic** on busy tiles and silently
  becomes NA. Both columns are cast to numeric first.
- All reprojection uses the explicit `+proj=laea …` string, never `"EPSG:3035"` — see
  the PROJ trap documented in the Transport feature note.
- `patchwork` was added to `renv.lock` for the multi-panel figures (1.3.2).
  `plot_layout(guides = "collect")` does not collapse the four identical scales
  under ggplot2 4.0.3 / patchwork 1.3.2, so the coverage figure carries one legend
  per row instead; panel widths stay equal that way.
