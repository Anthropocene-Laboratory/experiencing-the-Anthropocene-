# Heatwave person-days exposed, 2022 = (TX heatwave days) x (GHS-POP 2020),
# using the PRIMARY TX-based index (Perkins-Alexander standard).
#
# Usage: Rscript 4_calculate_exposure_2022.R [W]

suppressMessages(library(terra))
args <- commandArgs(trailingOnly = TRUE)
W <- if (length(args) >= 1) as.integer(args[1]) else 2L

proc_dir   <- normalizePath(file.path("Feature explorations", "Heatwaves", "data_processed"), mustWork = TRUE)
shared_dir <- normalizePath(file.path("Feature explorations", "_shared"), mustWork = TRUE)
hw  <- rast(file.path(proc_dir, sprintf("heatwave_days_2022_tx_w%d.nc", W)))
pop <- rast(file.path(shared_dir, "pop2020_0p1deg.tif"))
stopifnot(compareGeom(hw, pop, stopOnError = FALSE))

exposure <- hw * pop                       # person-days per cell
names(exposure) <- "exposed_person_days"
out_f <- file.path(proc_dir, sprintf("exposed_person_days_2022_tx_w%d.nc", W))
writeRaster(exposure, out_f, overwrite = TRUE)

v <- values(exposure, mat = FALSE)
cat("==================== EXPOSURE (2022, TX index) ====================\n")
cat(sprintf("Total European heatwave person-days: %s\n", format(round(sum(v, na.rm = TRUE)), big.mark = ",")))
cat(sprintf("Max cell: %s person-days | cells>0: %d\n",
            format(round(max(v, na.rm = TRUE)), big.mark = ","), sum(v > 0, na.rm = TRUE)))
cat(sprintf("Wrote %s\n", out_f))
