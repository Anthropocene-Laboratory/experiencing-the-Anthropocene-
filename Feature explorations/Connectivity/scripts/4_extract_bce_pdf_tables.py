"""
4_extract_bce_pdf_tables.py
Layer-A Connectivity feature: pull every table out of the DG CNECT
"Broadband Coverage in Europe 2024" final report PDF (Omdia / Point Topic).

*** WHY THIS SCRIPT DOES NOT PRODUCE A NUTS3 TABLE ***
The plan was to recover NUTS3 coverage from the BCE report, because the study
collects at NUTS3 (1,383 regions, 31 countries). Checked page by page, in both the
2024 (236 pp.) and 2023 (226 pp.) final reports: THE REPORTS CONTAIN NO NUTS3 TABLE.
  - Every extractable table is per COUNTRY: a 67x11 block per country chapter
    (national + rural, 2024/2023/2022, plus an EU27 reference column) and the
    annex tables on pp. 230-233, which are also one row per country.
  - The "Regional coverage by broadband technology" pages carry the NUTS3
    information as flat RASTER images (1259x763 DeviceRGB bitmaps; zero vector
    shapes, zero embedded text), so there is nothing to parse - at best one could
    sample colours back to legend CLASSES, not values.
  - The report says why, on p.30: "much of the coverage data (especially on such a
    granular level) could be regarded as commercially sensitive".
So the NUTS3 numbers are not in the public PDFs at all. What follows extracts
everything that IS there, which is still richer than Eurostat's isoc_cbt: three
years, 15 technology/combination/speed categories, rural split, and per-country
population and household context.

The one genuine NUTS3 residue in the PDF is prose: each country's regional section
names its best and worst region with a value ("ranged from 18.4% in Oberkarnten to
93.9% in Wien"). That is scraped into a third, deliberately partial, table.

OUTPUT (data_processed/tables/):
  bce2024_country_coverage.csv   country x year x metric x {total, rural}
  bce2024_country_context.csv    population, persons per household, rural share
  bce2024_regional_extremes.csv  NUTS3 region names + values found in prose
  bce2024_vs_eurostat_check.csv  validation against Eurostat isoc_cbt

RUN FROM WORKSPACE ROOT:
  python "Feature explorations/Connectivity/scripts/4_extract_bce_pdf_tables.py"
"""
import csv
import re
import sys
from pathlib import Path

import pdfplumber

ROOT = Path(__file__).resolve().parents[3]
RAW = ROOT / "Feature explorations" / "Connectivity" / "data_raw"
OUT = ROOT / "Feature explorations" / "Connectivity" / "data_processed" / "tables"
PDF = RAW / "bce2024.pdf"
OUT.mkdir(parents=True, exist_ok=True)

PCT = re.compile(r"^-?\d+(?:[.,]\d+)?%$")


def is_value(cell):
    if cell is None:
        return False
    c = cell.strip()
    return c == "-" or bool(PCT.match(c))


def to_num(cell):
    """'44.8%' -> 44.8 ; '-' -> None (the report's own not-collected marker)."""
    c = (cell or "").strip()
    if c in ("-", "", None):
        return None
    return float(c.rstrip("%").replace(",", "."))


def blank_row(row):
    return all(c is None or str(c).strip() == "" for c in row)


def parse_country_table(tbl):
    """The 67x11 block -> (header_labels, [(metric, [v1..v8])]).

    Layout is rigidly regular: blank rows delimit blocks; within a block the
    label is spread over cols 0-1 across one to three rows (multi-line names such
    as 'Cable modem' / 'DOCSIS 3.0' straddle the value row), and exactly one row
    carries the eight values.
    """
    # header: the row holding 'X 2024', 'X 2023', 'X 2022', 'EU27 2024'
    header = None
    for row in tbl[:4]:
        cells = [c for c in row if c and re.search(r"\b20\d\d\b", str(c))]
        if len(cells) >= 3:
            header = cells
            break
    if header is None:
        return None, []

    records, block = [], []
    for row in list(tbl) + [[None] * len(tbl[0])]:      # sentinel flush
        if blank_row(row):
            if block:
                label_bits, values = [], None
                for r in block:
                    for c in (r[0], r[1]):
                        if c and str(c).strip() and not is_value(c):
                            label_bits.append(str(c).strip())
                    vals = [c for c in r[3:] if is_value(c)]
                    if len(vals) >= 4:
                        values = [c for c in r[3:] if c is not None and str(c).strip() != ""]
                if values and label_bits:
                    label = " ".join(label_bits)
                    label = re.sub(r"\s+", " ", label).strip()
                    if label.lower() not in ("technology",):
                        records.append((label, values))
                block = []
        else:
            block.append(row)
    return header, records


def parse_context_table(tbl):
    out = {}
    for row in tbl:
        cells = [str(c).strip() for c in row if c is not None and str(c).strip()]
        if len(cells) >= 2 and cells[0] != "Statistic":
            out[cells[0]] = cells[1]
    return out


# --------------------------------------------------------------------------
def main():
    if not PDF.exists():
        sys.exit(f"missing {PDF} - download the BCE 2024 final report first")

    coverage_rows, context_rows, regional_rows = [], [], []
    country_pages = []

    with pdfplumber.open(PDF) as pdf:
        # 1. locate country data-table pages: a 4x5 context table + a ~67x11 block
        for n, page in enumerate(pdf.pages, start=1):
            tabs = page.extract_tables()
            if len(tabs) == 2 and len(tabs[0]) == 4 and len(tabs[1]) > 40:
                country_pages.append((n, tabs))
        print(f"country data-table pages found: {len(country_pages)}")

        for n, tabs in country_pages:
            ctx = parse_context_table(tabs[0])
            header, records = parse_country_table(tabs[1])
            if not header:
                print(f"  ! p{n}: no header, skipped")
                continue
            # header like ['Austria 2024', 'Austria 2023', 'Austria 2022', 'EU27 2024']
            country = re.sub(r"\s*20\d\d\s*$", "", header[0]).strip()
            years = [re.search(r"(20\d\d)", h).group(1) for h in header]
            sources = [re.sub(r"\s*20\d\d\s*$", "", h).strip() for h in header]

            context_rows.append({
                "country": country,
                "page": n,
                "population": ctx.get("Population", "").replace(",", ""),
                "persons_per_household": ctx.get("Persons per household", ""),
                "rural_proportion_pct": ctx.get("Rural proportion", "").rstrip("%"),
            })

            for metric, values in records:
                # values are Total,Rural per header column, in header order
                for i, (src, yr) in enumerate(zip(sources, years)):
                    tot = values[2 * i] if 2 * i < len(values) else None
                    rur = values[2 * i + 1] if 2 * i + 1 < len(values) else None
                    coverage_rows.append({
                        "country": src,
                        "year": yr,
                        "metric": metric,
                        "total_pct": to_num(tot),
                        "rural_pct": to_num(rur),
                        "source_country_chapter": country,
                        "page": n,
                    })

        # 2. the only NUTS3 numbers in the document: prose extremes.
        #    Sentence splitting is NOT used - "0.2% in St. Wendel" would break on
        #    the abbreviation. Instead: anchor on "ranged/ranging from", take a
        #    fixed window, split it once on " to ", and read each side.
        anchor = re.compile(r"rang(?:ed|ing)\s+from\s+", re.I)
        side_val = re.compile(r"(\d+(?:\.\d+)?)\s*%")
        side_reg = re.compile(r"\bin\s+(?:the\s+capital\s+region\s+)?(.+)$", re.S)

        def clean_region(s):
            s = re.sub(r"\s+", " ", s)
            # Running footers put the page number right after the sentence, e.g.
            # "...Lüchow-Dannenberg. 106 regions recorded...". Cut at a full stop
            # followed by digits — which also leaves abbreviations such as
            # "St. Wendel" intact, unlike cutting at ". <Capital>".
            s = re.split(r"\.\s*\d", s)[0]
            # ...and the sentence may simply continue ("Šibensko-kninska županija.
            # Zagrebačka županija was the only region that..."). Cut at a full stop
            # only when the token before it is >=4 characters, so real
            # abbreviations ("St. Wendel", "Kraj Vysočina") survive.
            m_end = re.search(r"(?<=\w{4})\.\s", s)
            if m_end:
                s = s[:m_end.start() + 1]
            s = s.strip(" .,;")
            s = re.sub(r"\s+(?:regions?|county|counties)$", "", s, flags=re.I)
            return s.strip(" .,;")

        current_country = None
        chapter_starts = {p: c for p, c in
                          [(row["page"], row["country"]) for row in context_rows]}
        # a chapter's regional pages come BEFORE its data-table page, so walk the
        # chapter boundaries rather than assuming the table page opens the chapter
        chapter_of_page = {}
        ordered = sorted(chapter_starts.items())
        prev = 1
        for pageno, name in ordered:
            for p in range(prev, pageno + 1):
                chapter_of_page[p] = name
            prev = pageno + 1

        for n, page in enumerate(pdf.pages, start=1):
            current_country = chapter_of_page.get(n)
            if not current_country:
                continue
            text = re.sub(r"\s+", " ", (page.extract_text() or ""))
            for m in anchor.finditer(text):
                before = text[max(0, m.start() - 160):m.start()]
                window = text[m.end():m.end() + 280]
                if " to " not in window:
                    continue
                left, right = window.split(" to ", 1)
                lv, rv = side_val.search(left), side_val.search(right[:60])
                lr, rr = side_reg.search(left), side_reg.search(right)
                if not (lv and rv and lr and rr):
                    continue
                a, b = float(lv.group(1)), float(rv.group(1))
                ra, rb = clean_region(lr.group(1)), clean_region(rr.group(1))
                lo, hi = (a, ra), (b, rb)
                if a > b:
                    lo, hi = (b, rb), (a, ra)
                ind = re.sub(r"\s+", " ", before.split(". ")[-1]).strip()
                regional_rows.append({
                    "country_chapter": current_country, "page": n,
                    "kind": "rural" if "rural" in before.lower() else "total",
                    "indicator": ind[-110:],
                    "region_low": lo[1], "value_low_pct": lo[0],
                    "region_high": hi[1], "value_high_pct": hi[0],
                })

    # 3. VALIDATION against Eurostat isoc_cbt ------------------------------
    #    The two should agree: Eurostat disseminates this very study. What would
    #    indict the extraction is a systematic offset, or a handful of countries
    #    far off while the rest match - that is a parser bug, not a data
    #    disagreement. Small deviations are expected (Eurostat restates).
    GEO = {
        "Austria": "AT", "Belgium": "BE", "Bulgaria": "BG", "Croatia": "HR",
        "Cyprus": "CY", "Czechia": "CZ", "Denmark": "DK", "Estonia": "EE",
        "Finland": "FI", "France": "FR", "Germany": "DE", "Greece": "EL",
        "Hungary": "HU", "Iceland": "IS", "Ireland": "IE", "Italy": "IT",
        "Latvia": "LV", "Lithuania": "LT", "Luxembourg": "LU", "Malta": "MT",
        "Netherlands": "NL", "Norway": "NO", "Poland": "PL", "Portugal": "PT",
        "Romania": "RO", "Slovakia": "SK", "Slovenia": "SI", "Spain": "ES",
        "Sweden": "SE", "Switzerland": "CH", "UK": "UK",
    }
    METRIC = {"FTTP": "FTTP", "5G": "5G", "Fixed VHCN (FTTP & DOCSIS 3.1)": "VHCN_FX",
              "DSL": "DSL", "Overall NGA broadband": "NGA"}

    check_rows = []
    euro_csv = RAW / "eurostat_isoc_cbt.csv"
    if euro_csv.exists():
        euro = {}
        with open(euro_csv, encoding="utf-8") as f:
            for r in csv.DictReader(f):
                if r["unit"] != "PC_HH" or not r["OBS_VALUE"]:
                    continue
                euro[(r["geo"], r["inet_tec"], r["terrtypo"], r["TIME_PERIOD"])] = \
                    float(r["OBS_VALUE"])
        for row in coverage_rows:
            if row["year"] != "2024" or row["metric"] not in METRIC:
                continue
            geo = GEO.get(row["country"])
            if not geo:
                continue
            for terr, key in (("TOTAL", "total_pct"), ("DEG3", "rural_pct")):
                bce = row[key]
                est = euro.get((geo, METRIC[row["metric"]], terr, "2024"))
                if bce is None or est is None:
                    continue
                check_rows.append({
                    "geo": geo, "metric": METRIC[row["metric"]], "terrtypo": terr,
                    "bce_pdf_pct": bce, "eurostat_pct": est,
                    "diff_pp": round(bce - est, 2)})
        if check_rows:
            diffs = [abs(r["diff_pp"]) for r in check_rows]
            big = [r for r in check_rows if abs(r["diff_pp"]) > 1.0]
            print(f"\nValidation vs Eurostat isoc_cbt 2024: {len(check_rows)} pairs, "
                  f"max |diff| {max(diffs):.2f} pp, mean {sum(diffs)/len(diffs):.3f} pp, "
                  f"{len(big)} pair(s) off by >1 pp")
            for r in big[:10]:
                print("   ", r)
    else:
        print("\n! eurostat_isoc_cbt.csv absent - run script 3 first to validate")

    # 4. write --------------------------------------------------------------
    def write(name, rows, fields):
        p = OUT / name
        with open(p, "w", newline="", encoding="utf-8") as f:
            w = csv.DictWriter(f, fieldnames=fields)
            w.writeheader()
            w.writerows(rows)
        print(f"wrote {p}  ({len(rows)} rows)")

    write("bce2024_country_coverage.csv", coverage_rows,
          ["country", "year", "metric", "total_pct", "rural_pct",
           "source_country_chapter", "page"])
    write("bce2024_country_context.csv", context_rows,
          ["country", "page", "population", "persons_per_household",
           "rural_proportion_pct"])
    write("bce2024_regional_extremes.csv", regional_rows,
          ["country_chapter", "page", "kind", "indicator", "region_low",
           "value_low_pct", "region_high", "value_high_pct"])
    if check_rows:
        write("bce2024_vs_eurostat_check.csv", check_rows,
              ["geo", "metric", "terrtypo", "bce_pdf_pct", "eurostat_pct", "diff_pp"])

    countries = sorted({r["country"] for r in coverage_rows if r["country"] != "EU27"})
    metrics = sorted({r["metric"] for r in coverage_rows})
    print(f"\ncountries: {len(countries)} -> {countries}")
    print(f"metrics ({len(metrics)}): {metrics}")


if __name__ == "__main__":
    main()
