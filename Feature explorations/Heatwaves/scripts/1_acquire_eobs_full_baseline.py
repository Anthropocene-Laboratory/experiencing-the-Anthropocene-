"""Download the full E-OBS daily TX and TN record (ensemble mean, 0.1 deg, v33)
from the Copernicus CDS.

We need the 1991-2020 baseline (for the local calendar-day P90 thresholds) AND
the 2022 analysis year. The CDS period chunks stop at 2011_2021, so 2022 can only
be obtained through the `full_period` option -- which also already contains the
whole 1991-2020 baseline. One download therefore covers everything.

Usage: python download_eobs_baseline.py
"""

import sys
from pathlib import Path

workspace = Path(__file__).resolve().parents[3]

import cdsapi

output_dir = workspace / "Feature explorations" / "Heatwaves" / "data_raw" / "eobs"
output_dir.mkdir(parents=True, exist_ok=True)
target = output_dir / "eobs_tx_tn_ensmean_0_1deg_v33_full_period.zip"

if target.exists() and target.stat().st_size > 0:
    print(f"Already present: {target} ({target.stat().st_size/1e9:.2f} GB)")
    raise SystemExit(0)

client = cdsapi.Client()
client.retrieve(
    "insitu-gridded-observations-europe",
    {
        "product_type": "ensemble_mean",
        "variable": ["maximum_temperature", "minimum_temperature"],
        "grid_resolution": "0_1deg",
        "period": "full_period",
        "version": "33_0e",
    },
    str(target),
)
print(f"Downloaded: {target} ({target.stat().st_size/1e9:.2f} GB)")
