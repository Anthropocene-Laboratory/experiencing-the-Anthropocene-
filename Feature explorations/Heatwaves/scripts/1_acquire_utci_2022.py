"""Download hourly UTCI (ERA5-HEAT) over Europe for the 2022 analysis year.

WHY THIS EXISTS. The P90 index (compute_p90_thresholds.R + 3_calculate_...) uses a
threshold defined by the LOCAL climate distribution. By construction 10% of
reference-period days exceed it everywhere, so the absolute difference in heat
between places is normalised away -- and the human does not enter the variable
until the population weighting downstream. That makes it an Anthropocene
component, not a Layer A experienceable feature.

UTCI fixes exactly that: its bands (no stress / moderate / strong / very strong /
extreme heat stress) are calibrated on the physiological response of the human
body, and they are the SAME everywhere -- structurally the analogue of the WHO
bands already used in the Air quality feature.

Trade-off accepted: 0.25 deg (~28 km) instead of E-OBS 0.1 deg (~11 km).

Downloads one file per month (zip of daily netCDFs) into data_raw/utci/.
Re-running skips months already present.

Usage: python "Feature explorations/Heatwaves/scripts/1_acquire_utci_2022.py"
"""

import sys
from pathlib import Path

workspace = Path(__file__).resolve().parents[3]

import cdsapi

YEAR = 2022
# N, W, S, E -- Europe, matching the E-OBS analysis domain
AREA = [72, -25, 34, 45]

output_dir = workspace / "Feature explorations" / "Heatwaves" / "data_raw" / "utci"
output_dir.mkdir(parents=True, exist_ok=True)

client = cdsapi.Client()

for month in range(1, 13):
    target = output_dir / f"utci_{YEAR}{month:02d}_europe.zip"
    if target.exists() and target.stat().st_size > 0:
        print(f"skip {target.name} ({target.stat().st_size/1e6:.0f} MB)", flush=True)
        continue

    print(f"downloading {target.name} ...", flush=True)
    client.retrieve(
        "derived-utci-historical",
        {
            "variable": ["universal_thermal_climate_index"],
            "version": "1_1",
            "product_type": "consolidated_dataset",
            "year": [str(YEAR)],
            "month": [f"{month:02d}"],
            "day": [f"{d:02d}" for d in range(1, 32)],
            "area": AREA,
        },
        str(target),
    )
    print(f"  done: {target.name} ({target.stat().st_size/1e6:.0f} MB)", flush=True)

total = sum(f.stat().st_size for f in output_dir.glob("*.zip"))
print(f"UTCI {YEAR} ACQUISITION DONE -- {total/1e9:.2f} GB in {output_dir}")
