"""Download one small ERA5-Land request to verify CDS access and the data schema."""

from pathlib import Path
import sys

workspace = Path(__file__).resolve().parents[3]

import cdsapi

output_dir = workspace / "Feature explorations" / "Heatwaves" / "data_raw" / "era5_land_test"
output_dir.mkdir(parents=True, exist_ok=True)
target = output_dir / "era5_land_daily_max_1991-07-01_europe.nc"

if target.exists() and target.stat().st_size > 0:
    print(f"Already present: {target}")
else:
    client = cdsapi.Client()
    client.retrieve(
        "derived-era5-land-daily-statistics",
        {
            "variable": ["2m_temperature"],
            "year": ["1991"],
            "month": ["07"],
            "day": ["01"],
            "daily_statistic": "daily_maximum",
            "time_zone": "utc+00:00",
            "frequency": "1_hourly",
            "area": [72, -25, 34, 45],
        },
        str(target),
    )
    print(f"Downloaded: {target}")
