"""Download E-OBS daily TX and TN (ensemble mean, 0.1 deg) for the period chunk
that contains a given year, from the Copernicus CDS.

E-OBS is distributed as multi-decadal period chunks, not per-month, so we fetch
the chunk and subset the test month later in R.

Usage: python download_eobs_chunk.py YYYY
"""

import sys
from pathlib import Path

if len(sys.argv) != 2 or not sys.argv[1].isdigit():
    raise SystemExit("Usage: python download_eobs_chunk.py YYYY")

year = int(sys.argv[1])
workspace = Path(__file__).resolve().parents[3]

import cdsapi

# CDS E-OBS period chunks (best-guess option strings; the API will reject and
# list valid values if these are wrong).
chunks = [
    (1950, 1964, "1950_1964"),
    (1965, 1979, "1965_1979"),
    (1980, 1994, "1980_1994"),
    (1995, 2010, "1995_2010"),
    (2011, 2021, "2011_2021"),
]
period = next((p for lo, hi, p in chunks if lo <= year <= hi), None)
if period is None:
    raise SystemExit(f"No E-OBS chunk covers {year}")

output_dir = workspace / "Feature explorations" / "Heatwaves" / "data_raw" / "eobs"
output_dir.mkdir(parents=True, exist_ok=True)
target = output_dir / f"eobs_tx_tn_ensmean_0_1deg_v33_{period}.zip"

if target.exists() and target.stat().st_size > 0:
    print(f"Already present: {target}")
    raise SystemExit(0)

client = cdsapi.Client()
client.retrieve(
    "insitu-gridded-observations-europe",
    {
        "product_type": "ensemble_mean",
        "variable": ["maximum_temperature", "minimum_temperature"],
        "grid_resolution": "0_1deg",
        "period": period,
        "version": "33_0e",
    },
    str(target),
)
print(f"Downloaded: {target}")
