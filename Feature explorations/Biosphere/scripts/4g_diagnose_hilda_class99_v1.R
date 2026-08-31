# v1: the count of class 99 over Europe is NOT constant (1768 / 1769 / 1777 in
# 1960 / 1990 / 2019), unlike v2 where the same 191 pixels are 99 in all 60 years.
# So v1 DOES have some 99 dynamics. How many transitions, exactly?
#
# READING RULE (same thresholds as the v2 test, written before running):
#   N99 = annual pixel-transitions where exactly one side is 99 and the other is
#   a land class, 1960-2019. Compared to the ~8.76M changes the churn map counts.
#   PASSES if 0. NEGLIGIBLE if < 0.1%. FAILS if >= 1%.
# Method: locate the 99 pixels first (they are ~1770 of 38M and clustered), then
# read all 60 years only over their bounding window. Stated limit: a 99 pixel
# appearing ONLY in a year not sampled AND outside that window would be missed.
suppressMessages(library(terra))
setwd(here::here())
terraOptions(progress = 0)
euro <- ext(-25, 45, 34, 72)
LAND <- c(11,22,23,24,33,40,41,42,43,44,45,55,66)
hurl <- function(y) sprintf("/vsicurl/https://s3.openlandmap.org/arco/land.use.land.cover_hilda.plus_c_1km_s_%d0101_%d1231_go_espg.4326_v1.0.tif", y, y)

# locate 99 pixels from three widely spaced years
pts <- NULL
for (y in c(1960, 1990, 2019)) {
  r <- crop(rast(hurl(y)), euro)
  p <- as.points(ifel(r == 99, 1, NA), na.rm = TRUE)
  pts <- if (is.null(pts)) crds(p) else rbind(pts, crds(p))
}
cat(sprintf("99 pixel locations found across the 3 sampled years: %d\n", nrow(pts)))
cat(sprintf("bounding box: lon %.2f..%.2f | lat %.2f..%.2f\n",
            min(pts[,1]), max(pts[,1]), min(pts[,2]), max(pts[,2])))
# cluster description
cat("\nlongitude/latitude rounded to 1 degree, top cells:\n")
print(head(sort(table(sprintf("%.0fE %.0fN", pts[,1], pts[,2])), decreasing = TRUE), 10))

win <- ext(floor(min(pts[,1])) - 0.5, ceiling(max(pts[,1])) + 0.5,
           floor(min(pts[,2])) - 0.5, ceiling(max(pts[,2])) + 0.5)
cat(sprintf("\nreading 60 years over the window %s\n", paste(round(as.vector(win),2), collapse=" ")))

prev <- values(crop(rast(hurl(1960)), win), mat = FALSE)
n99_to_land <- 0; n_land_to_99 <- 0; per_year <- integer(60); per_year[1] <- sum(prev == 99, na.rm=TRUE)
for (i in 2:60) {
  y <- 1959 + i
  cur <- values(crop(rast(hurl(y)), win), mat = FALSE)
  per_year[i] <- sum(cur == 99, na.rm = TRUE)
  n99_to_land  <- n99_to_land  + sum(prev == 99 & cur %in% LAND, na.rm = TRUE)
  n_land_to_99 <- n_land_to_99 + sum(prev %in% LAND & cur == 99, na.rm = TRUE)
  prev <- cur
  if (i %% 20 == 0) cat("  ...", y, "\n")
}
cat("\ncount of 99 in the window, per year:\n")
print(setNames(per_year, 1960:2019))
TOT <- 8764638
N99 <- n99_to_land + n_land_to_99
cat(sprintf("\nv1 transitions 99 -> land : %d\n", n99_to_land))
cat(sprintf("v1 transitions land -> 99 : %d\n", n_land_to_99))
cat(sprintf("N99 = %d, i.e. %.6f%% of the %s changes the churn map counts\n",
            N99, 100*N99/TOT, format(TOT, big.mark=",")))
cat(sprintf("VERDICT: %s\n",
            if (N99 == 0) "PASSED - 99 never touches a land class" else
            if (N99/TOT < 0.001) "NEGLIGIBLE" else
            if (N99/TOT >= 0.01) "FAILED" else "between thresholds"))
