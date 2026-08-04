"""Download daily maximum and minimum 2 m temperature for one month or year."""

import calendar
from pathlib import Path
import sys

if len(sys.argv) not in (2, 3) or not sys.argv[1].isdigit() or (
    len(sys.argv) == 3 and (not sys.argv[2].isdigit() or not 1 <= int(sys.argv[2]) <= 12)
):
    raise SystemExit("Usage: python download_era5_land_year.py YYYY [MM]")

year = sys.argv[1]
months = [int(sys.argv[2])] if len(sys.argv) == 3 else list(range(1, 13))
workspace = Path(__file__).resolve().parents[3]

import cdsapi

output_dir = workspace / "Feature explorations" / "Heatwaves" / "data_raw" / "era5_land_daily"
output_dir.mkdir(parents=True, exist_ok=True)

client = cdsapi.Client()
for month in months:
    request_base = {
        "variable": ["2m_temperature"],
        "year": [year],
        "month": [f"{month:02d}"],
        "day": [f"{day:02d}" for day in range(1, calendar.monthrange(int(year), month)[1] + 1)],
        "time_zone": "utc+00:00",
        "frequency": "1_hourly",
        # North, West, South, East: deliberately wider than the study polygons.
        "area": [72, -25, 34, 45],
    }
    for statistic, suffix in (("daily_maximum", "max"), ("daily_minimum", "min")):
        target = output_dir / f"era5_land_daily_{suffix}_{year}-{month:02d}_europe.nc"
        if target.exists() and target.stat().st_size > 0:
            print(f"Already present: {target}", flush=True)
            continue
        request = {**request_base, "daily_statistic": statistic}
        print(f"Requesting {statistic} for {year}-{month:02d}", flush=True)
        client.retrieve("derived-era5-land-daily-statistics", request, str(target))
        print(f"Downloaded: {target}", flush=True)
