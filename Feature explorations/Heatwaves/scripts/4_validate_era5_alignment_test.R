suppressMessages(library(terra))
base <- file.path("Feature explorations", "Heatwaves")
mx  <- rast(file.path(base, "data_raw/era5_land_daily/era5_land_daily_max_1991-07_europe.nc"))
pop <- rast(file.path(base, "data_processed/pop1991_0p1deg.tif"))
cat("ERA5 max layers:", nlyr(mx), "| dims:", nrow(mx), "x", ncol(mx), "\n")
cat("ERA5 ext:", round(as.vector(ext(mx)), 3), "\n")
cat("POP  ext:", round(as.vector(ext(pop)), 3), "\n")
same <- isTRUE(all.equal(res(mx), res(pop))) &&
        isTRUE(all.equal(as.vector(ext(mx)), as.vector(ext(pop))))
cat("Same geometry (res + extent):", same, "\n")
v <- as.numeric(global(mx[[1]], "max", na.rm = TRUE)) - 273.15
cat("ERA5 1991-07-01 max Tmax over box (deg C):", round(v, 1), "\n")
