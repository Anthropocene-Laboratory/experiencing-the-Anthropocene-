# HILDA+ change counts: are they land-use change, or fusion flicker?

**Date** 2026-08-13 · **Origin** Denis's question of the same day ("could the
'changes in category' stem from NA in the data — would NA-forest-clouded-forest-NA
be counted as four changes?") · **Scripts**
`scripts/4c_diagnose_hilda_nodata.R`, `4d_diagnose_hilda_flicker.R`,
`4e_diagnose_hilda_flicker_impact.R` (all runnable from the repo root)

---

## 1. The question

Denis's question was about no-data. It answered itself quickly and negatively, and
in answering it opened a second, larger one:

- **Q1** Can a no-data / cloud gap inflate the HILDA+ change-frequency count?
- **Q2** HILDA+ is gap-free *by construction* — gaps were resolved upstream in the
  fusion, not absent from the inputs. Can the count be inflated instead by a
  gap-filling that **invents back-and-forth transitions**?

## 2. The reading rules, written before the measurements

Written into the script headers before running; reproduced here verbatim in
substance.

**A (Q1).** Per pixel, count years carrying a class we map to NA (raw 00 ocean,
77 water, 99 no data). A pixel *flickers* if that count is neither 0 nor 60.
*Passes* if flickering pixels = 0 — a no-data can then never sit between two valid
land states and the sequence in the question does not exist. *Fails* otherwise.

**B (Q1, HILDA+ v1).** Our v1 map displays a change-freq layer precomputed by the
producers, so the rule is theirs. Recount v1 states with an explicit NA-safe rule
over a land/water-interleaved window and compare. *Passes* on exact agreement,
*fails* if the precomputed layer is systematically higher, **null** if the v1
states contain no NA at all — the two rules would then be indistinguishable.

**C1 (Q2).** Annual count of pixels changing broad class, 1961–2019. The producers'
own documentation dates their EO inputs: GLAD UMD VCF 1982–2016 (earliest global),
ESA CCI 1992–2019, CORINE 1990/2000/2006/2012/2018, GLC2000 2000, Copernicus LC100
2015–2019, ESA WorldCover 2020. **1960–1981 has no satellite constraint at all.**
Nothing happens on the ground because a satellite went up, so a step at 1982, 1990,
2000 or 2015 is an artefact signature. Statistic: mean of the 5 years after each
boundary over the 5 years before. *Fails* if any ratio > 2.0 or < 0.5; *passes* if
all in [0.67, 1.5]; inconclusive between.

**C2 (Q2).** Decompose each pixel's 60-year sequence into runs of constant broad
class. At HILDA's thematic breadth a class held one or two years is not a land use.
Over episodes whose start is observed (first and last episodes censored and
excluded): (a) share lasting ≤ 2 years, (b) share that are ≤ 2-year A→B→A
reversals. *Fails* if either ≥ 10%; *passes* if both < 2%.

**D (impact, new question, own rule).** Filter each sequence — pass 1 removes
`A B A`, pass 2 removes `A B B A`; nothing else touched, symmetric, cannot create
changes — then recount. Let `m_raw`, `m_flt` be mean changes per land pixel.
*≥ 0.8 × m_raw* → flicker cosmetic, map stands. *≤ 0.5 × m_raw* → map dominated by
transient excursions, cannot be presented as land-use change without filtering or
relabelling. Between → report and relabel, claim nothing more.

**Confounder declared in advance:** C2 cannot separate "fusion artefact" from
"genuine short-lived cover" (a clearcut read as sparse for a year before regrowth).
C2 bounds the magnitude of possible flicker; it cannot attribute it. C1 is the test
that can attribute.

## 3. Raw results

**A** — 60 v2 annual states, study area, **6 636 179 pixels**: land in all 60 years
6 366 025 (95.93%); land in no year 270 154 (4.07%); **flickering 0 (0.0000%)**.
Class counts for 00 / 77 / 99 over the European crop are *identical* in 1960, 1990
and 2019 (14 062 888 / 353 914 / 1 236) — static masks.

**B** — Dutch-delta window (3–6 E, 51–53.5 N), 60 v1 annual states, 108 000 cells:
**0 cells NA in any year.** v1 encodes sea as class 00, not as NA.

**C1** — changed pixels per year, range 130 251 (1982) to 178 962 (1991), no trend
break:

| boundary | before (5 y) | after (5 y) | ratio |
|---|---|---|---|
| 1982 | 137 866 | 135 116 | 0.98 |
| 1990 | 142 456 | 153 322 | 1.08 |
| 2000 | 145 691 | 164 017 | 1.13 |
| 2015 | 148 782 | 154 569 | 1.04 |

**C2** — 8 764 638 changes; 6 373 481 closed episodes with observed start.
Episodes ≤ 2 years: **4 436 327 (69.61%)**. Of those, ≤ 2-year A→B→A reversals:
**4 236 435 (66.47%)**. **Median closed-episode length: 1 year.** Length histogram
1…10 = 4 144 446 / 291 881 / 145 984 / 106 198 / 78 773 / 72 175 / 59 487 / 49 671 /
44 179 / 40 179, then an **unexplained spike of 624 020 at exactly 11 years** (15×
its neighbours, 40 179 at 10 and 70 612 at 12). Not diagnosed.

**D** — 6 344 464 land pixels. Raw 8 764 638 changes = **1.381 per pixel**;
filtered 3 279 750 = **0.517 per pixel**; **37.4% retained**.

Which pairs the ≤ 2-year reversals run between (A → B → back to A):

| A → B | count |
|---|---|
| pasture → grass/shrub | 769 225 |
| grass/shrub → pasture | 672 425 |
| cropland → pasture | 568 211 |
| pasture → cropland | 488 750 |
| forest → grass/shrub | 366 702 |
| cropland → grass/shrub | 342 812 |
| forest → pasture | 321 851 |
| grass/shrub → cropland | 262 399 |

**Nothing ever flickers *into* forest**: the forest column is 0 throughout, and the
urban column is small. The flicker is confined to the herbaceous/agricultural
classes — exactly the pairs whose distinction (managed pasture vs unmanaged
grass/shrubland; pasture vs cropland) is a land-*use* judgement no sensor can make
and which HILDA+ therefore allocates from statistics.

## 3b. Class 99 taken on its own (added the same day, after Denis's question was
## re-read: test A had lumped 99 with ocean and water, which was too coarse)

Scripts `4f_diagnose_hilda_class99.R`, `4g_diagnose_hilda_class99_v1.R`.
Rule written before running: N99 = annual transitions where exactly one side is
code 99 and the other a land class. *Passes* if 0, *negligible* if < 0.1% of the
8 764 638 changes, *fails* if ≥ 1%.

**v2, study area, 6 582 589 pixels.** 191 pixels carry 99, the **same 191 in all
60 years** (count constant, single distinct value). Transitions 99 → land: **0**.
Land → 99: **0**. 99 ↔ ocean/water: **0**. N99 = 0. **PASSED.**

**v1, Europe.** Unlike v2, the 99 count moves: 1768 (1960) → 1769 (1990) → 1777
(2019). The pixels sit in two clusters — around 71 N, 8–9 W (Jan Mayen) and 35 N,
33–34 E (part of Cyprus), plus a dozen near 44 N, 7 E. Measured over all 60 years:
99 → land 1808, land → 99 1817, **N99 = 3625 = 0.041%**. **NEGLIGIBLE** against
the rule.

**But ~98% of that comes from one defective year.** The v1 file for **2015 contains
no class 99 at all** — 1588 pixels in 2014, 1588 in 2016, **0 in 2015**, verified by
reading the three files' full class inventories. That single discontinuity generates
1777 + 1776 = 3553 of the 3625 transitions. Excluding 2015, N99 ≈ **72 transitions
in 59 years, 0.0008%**.

That 2015 hole does **not** reach anything we publish: our v1 map displays the
producers' precomputed change-freq layer, and `4_change_freq_intensity_hilda.R`
reads the annual v1 states only for 1960 and 2019 (the intensity analysis). Logged
as a defect of the OpenLandMap-hosted v1 states, not acted on.

**Conclusion on Denis's question, stated in his terms:** going from "no data" to a
data class is *not* counted as a change by our v2 code (the NA guard), and in the
data it essentially never happens — 0 times in v2, ~72 times in v1 outside a
single defective year, against 8.76 million counted changes. The churn map is not
inflated by no-data. It is inflated, by a factor of 2.7, by something else entirely
(§3 C2 and D).

## 4. Verdicts against the rules as written

- **A: PASSED.** No-data cannot inflate the count. Denis's mechanism is ruled out.
- **B: NULL — kept as null, not repaired.** The v1 states hold no NA in the window,
  so the producers' rule and an NA-safe rule are indistinguishable there. The
  confounder is that HILDA+ encodes absence as a class rather than as NA. A window
  containing NA would be needed, and none is known to exist in this product.
- **C1: PASSED.** No step at any data-regime boundary. Whatever the flicker is, it
  is *not* introduced when satellites enter the fusion — it is uniform across the
  whole 1960–2019 period, including the two decades with no EO input at all.
- **C2: FAILED, by a wide margin.** The failure threshold was 10%; the measurement
  is 69.61% and 66.47%.
- **D: MAP DOMINATED BY TRANSIENT EXCURSIONS.** The threshold for that verdict was
  ≤ 50% retained; the measurement is 37.4%.

C1 passing and C2 failing together is the informative combination: the flicker is
real and large, but it is **not** an artefact of satellite availability. It is a
property of the change-allocation procedure itself, present as strongly in
1960–1981 (statistics only) as after 2000.

## 5. Provenance of each number

- **Measured by us**, from the 60 local v2 state GeoTIFFs (PANGAEA
  10.1594/PANGAEA.974335, archive MD5 `56fe959df25d8efbc542b90cf971945f`, verified
  by `4b_change_freq_hilda_v2.R`): every figure in A, C1, C2 and D. Scripts 4c/4d/4e,
  run 2026-08-13.
- **Read at the source**: the EO input inventory and dates in C1's rationale come
  from `data_raw/biosphere/hilda_plus_v2/HILDAplus_GLOBv-2.0_documentation.pdf`,
  pp. 2 and 4, read directly. The class legend (00/77/99) from the same PDF p. 1 and
  `Readme.md`.
- **Cross-check on the lock (partial pass, stated as such).** Our published pipeline
  reports `v2_10km_mean = 1.2507` changes per pixel
  (`data_processed/tables/change_freq_hilda_v2_1960_2019_qa.csv`) against my
  **1.381**. These are two different estimators of the same object — theirs is the
  mean of 10 km cell means over the masked study area, weighting partly-oceanic
  coastal cells differently; mine is a plain per-pixel mean over study land pixels.
  The 10% gap is attributable to that, and it is close enough to confirm the
  diagnosis is about the published quantity. It is **not** an exact reproduction and
  is not claimed as one.
- **Independent corroboration from our own QA table**: `v2_1km_max = 59`, i.e. at
  least one pixel changes broad class at *every one* of the 59 annual steps. No land
  parcel does that.
- **Not verified**: the 11-year spike. No explanation attempted.

## 6. 🔑 What this licenses

- **A limit to declare, not a number to use.** The HILDA+ change-frequency layer, as
  published and as we currently map it, is **not** a map of land-use change: 62.6% of
  the changes it counts are ≤ 2-year excursions that return to their starting class.
  Any sentence we write of the form "X changes per cell since 1960" must either be
  filtered or be relabelled as *reconstruction churn*.
- **Justifies a methods choice.** If we keep the feature, the ≤ 2-year filter above
  (or an equivalent stated rule) has to be applied and named, with 1.381 → 0.517 per
  pixel reported as the effect. The filter is symmetric and cannot create changes,
  which is why it is defensible.
- **Kills a comparison we have not yet made.** The v1/v2 agreement in the QA table
  (r = 0.93) says the two versions flicker *alike*; it is not evidence that either
  measures land-use change.
- **Bounds the archetype work.** `landchange_freq` is one of the six features in the
  30 km archetype stack (`Analysis/`). Its churn signal is majority-transient, so any
  cluster that separates on it is separating partly on reconstruction behaviour.

## ⚠ Consigné n'est pas appliqué

As of 2026-08-13 **the code does not carry this.** `4_change_freq_intensity_hilda.R`
and `4b_change_freq_hilda_v2.R` still count raw annual transitions, and the published
PNGs and the 30 km stack still hold the unfiltered numbers. No commit implements the
filter. This must be either applied or explicitly declared before the figures go out.

## Numbers not to use

- **"changes per ~10 km cell" from the current maps** (mean 1.25, p98 7.33 for v2;
  p98 6.88 for v1) — retired 2026-08-13 as a measure of land-use change. Still valid
  as a measure of *reconstruction churn* if labelled that way.
- **`v2_1km_max = 59`** — do not quote as a real maximum; it is a flicker artefact.
