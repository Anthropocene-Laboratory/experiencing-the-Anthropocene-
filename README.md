# Experiencing the Anthropocene

Code, figures and method notes for a project mapping **how human-driven Earth-system
transformations are actually encountered in daily life** across Europe — as heat on the
body, particles in the air, a built horizon, a lost night sky, a road-cut landscape, a
depleted biosphere — and how those encounters are filtered by where and who you are.

The organising rule of the whole project is: **do not collapse the layers.** Upstream
drivers, experienceable features (Layer A), exposure filters (Layer B), implications and
response capacities stay analytically separate. `AGENTS.md` states that architecture in
full; the code follows it.

---

## ⚠️ Status: exploratory, not settled

**This repository is prototype work, not a finished pipeline.** The project roadmap has
not reached Phase 2 (feature ranking): nothing here has been scored or placed into a
Core / Shortlist / Hold bucket. Each feature folder asks *"what can we do with this
feature, given available data?"* — it does not deliver a validated result.

Read every map and number here as provisional. Methods have changed after prototypes
revealed problems, and are expected to change again. Each feature's `*_notes.md` records
what is known to be wrong or unresolved about it — read that note before reusing a
figure. Some of those caveats are load-bearing, for example:

- the CLC-based transport layer under-captures the road footprint by a factor of ~20;
- the EEA PM2.5 reference year is not confirmed;
- the exposure archetypes rest on mixed reference years (2020-2024).

---

## What is and is not in this repository

**In:** every analysis script (46 R, 7 Python), the method notes, and the final outputs —
52 PNG figures under `data_processed/maps/` and 37 CSV tables under `data_processed/tables/`.
About 33 MB in total. The committed figures are there so you can check that a run on your
machine reproduces them.

**Out:** roughly 40 GB of source and intermediate data, all of it re-obtainable.
`data_raw/` is empty in a fresh clone. Every dataset — provider, version, licence, size,
and either the script that downloads it or the manual steps plus a SHA-256 to verify it —
is documented in **[`data_sources.md`](data_sources.md)**. Also out: literature PDFs
(third-party copyright) and internal working documents.

---

## Quickstart

```bash
git clone https://github.com/Anthropocene-Laboratory/<repo>.git
cd <repo>
```

**1. R packages** — the exact versions used to produce the committed figures are pinned
in `renv.lock`. Opening the project in RStudio bootstraps renv automatically; otherwise:

```bash
Rscript -e "renv::restore()"
```

**2. Python packages** — only needed for the Copernicus downloaders:

```bash
python -m venv .venv && .venv\Scripts\activate && pip install -r requirements.txt
```

**3. Copernicus credentials** — free CDS *and* ADS accounts, token in `~/.cdsapirc`.
See the credentials section of [`data_sources.md`](data_sources.md). Check it works:

```bash
python "Feature explorations/Heatwaves/scripts/1_acquire_test_cds_connection.py"
```

**4. Get some data.** Start with Transport — it is the lightest feature (~360 MB), both
its sources are scripted, and it needs no credentials:

```bash
Rscript "Feature explorations/Transport/scripts/3_acquire_grip4_road_density.R"
```

**5. Reproduce a figure** and compare it to the committed one:

```bash
Rscript "Feature explorations/Transport/scripts/4_map_road_density_grip4.R"
```

It should rewrite `Feature explorations/Transport/data_processed/maps/road_density_grip4_8km.png`.
If `git diff --stat` shows that file changed materially, something in your environment
differs from the one that produced it — say so in an issue rather than working around it.

### Requirements

| | version used | note |
|---|---|---|
| R | 4.5.3 | `renv.lock` pins 83 packages |
| GDAL | 3.12.1 | system library, **not** pinned by renv |
| PROJ | 9.7.1 | see the PROJ trap below |
| GEOS | 3.14.1 | |
| Python | 3.11-3.14 | only for the acquisition scripts |

`sf` and `terra` bind to whatever GDAL/PROJ your OS provides. renv cannot pin those, and
they are the most likely source of a result that differs from the committed figures.
Check yours with `Rscript -e "print(sf::sf_extSoftVersion())"`.

One script is **Windows-only as written**:
`Transport/scripts/1_acquire_clc122_transport_land.R` shells out to PowerShell
`Invoke-WebRequest` to work around an SSL failure (see below).

---

## Layout

```
Feature explorations/
  <Feature>/
    data_raw/                 not in git - see data_sources.md
    data_processed/
      maps/                   final PNG figures        (committed)
      tables/                 final CSV tables         (committed)
      *.nc, *.tif             intermediates, plumbing  (not in git)
    scripts/                  the pipeline, numbered in run order
    *_notes.md                what this feature is, and what is wrong with it
  _shared/                    reference data used by more than one feature
  Analysis/                   cross-feature synthesis (exposure archetypes)
    superseded/               a rejected first generation, kept as a record
```

Conventions for adding a feature or a script: `Feature explorations/CLAUDE.md`.

### Run order

Scripts are numbered by stage; the number is the dependency order.

| Feature | Order | Needs credentials |
|---|---|---|
| **Transport** | `1→2` (CLC land take), `3→4` (GRIP roadedness — use this one for "how roaded") | no |
| **Technosphere** | `1`, `2`, `3` — independent; `1` and `2` stream WSF3D over HTTP | no |
| **Biosphere** | `1→2→2b→3→3b→4→4b→5→6→7`, then `8`, `9`, `10` (Layer-B filters) | no |
| **Air quality** | `1` (EEA, manual data), `2→3` (CAMS download then map) | ADS |
| **Heatwaves** | `1_acquire_*` → `prepare_population_2020` → `compute_p90_thresholds` → `3_calculate_*` → `4_calculate/validate_*` → `5_visualize_*` → `6_ghd_weighted_exposure_2022` | CDS |
| **Analysis** | `scripts/1→2→3→4` — consumes the `data_processed/` of every feature above | inherits |

Every R script resolves the repository root with `here::here()`, so it runs from any
working directory. Python scripts use `Path(__file__).resolve().parents[3]`.

---

## Traps already paid for

Documented so nobody rediscovers them the expensive way. Each is handled in the code;
each will bite a new script that ignores it.

**PROJ / EPSG:3035 silently punches a hole over central Europe.**
`terra::project(r, crs = "EPSG:3035")` makes PROJ route WGS84→ETRS89 through
country-specific deformation grids (`de_*`, `nl_*`, `ch_*`, `fi_*`). When those grids are
absent, **terra returns NA instead of erroring** — deleting Germany, the Netherlands,
Belgium, Switzerland and Austria from the map. 106 806 non-NA cells with `"EPSG:3035"`
versus 113 870 with an explicit `+proj=laea +ellps=GRS80 …` string; `PROJ_NETWORK=ON`
does not help. `Transport/scripts/4_` uses the PROJ string, tags the result EPSG:3035,
and asserts a minimum non-NA cell count so the hole cannot come back unnoticed.
**Any script calling `project(..., "EPSG:3035")` should be checked for it.**

**R's libcurl fails the SSL handshake against Eurostat, GISCO and EEA discomap.**
Affected downloads are shelled out to PowerShell `Invoke-WebRequest`, or the file is
committed to `_shared/`. Not a certificate you can fix from R.

**The ADS cost limit is about one month per request.** Asking CAMS for a year returns
403 "too large". `2_fetch_cams_pm25.R` loops month by month. The `time` subset is also
ignored server-side, so files come back full-hourly (~10 GB, not the intended ~2.5 GB).

**CAMS produces values over sea.** Mask to land or the oceans flood the map.

**WSF3D `BuildingFraction` is Byte with NoData = 255**, not -32767. Read it wrong and
empty land becomes 255 % built.

---

## Licence

**Code** — MIT, see [`LICENSE`](LICENSE).

**Figures and tables** — these are derived products, and some of them inherit terms from
their inputs. In particular the **Biodiversity Intactness Index (BII) v2.1.1 is
CC-BY-NC-SA 4.0**, so `Biosphere/data_processed/maps/bii_*.png` and any output computed
from BII carry non-commercial and share-alike obligations. Other inputs carry their own
attribution requirements (GRIP4 is ODbL; GHSL, EEA and Kummu et al. are CC-BY;
administrative boundaries are © EuroGeographics). Check
[`data_sources.md`](data_sources.md) for the specific layer before reusing a figure.

> The blanket licence for outputs has not been settled — see the open items at the end of
> `data_sources.md`. Until it is, treat the figures as "ask first".

---

## Citing

See [`CITATION.cff`](CITATION.cff). If you use a figure, cite the underlying dataset
too — `data_sources.md` names it.

## Contributing

Read `Feature explorations/CLAUDE.md` first: it defines the folder contract (where a PNG
goes, where a CSV goes, what stays out of git) and the path rule. The one hard rule is
that **a hardcoded `C:/Users/...` path is a defect** — 32 of them were removed to make
this repository runnable elsewhere, and one reintroduced quietly undoes that.
