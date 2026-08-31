# =============================================================================
# Denis's question, taken literally and on its own: is a transition from class
# 99 ("no data") to ANY data class counted as a change, and are such transitions
# frequent enough to inflate the churn map?
#
# The earlier test lumped 99 together with 00 (ocean) and 77 (water). That was
# too coarse to answer this. Here 99 is isolated.
#
# READING RULE, WRITTEN BEFORE RUNNING:
#   (a) Count every annual pixel-transition in 1960-2019 over the study area in
#       which exactly one side is code 99 and the other is a land class.
#       Call that N99. Compare it to the total number of changes our map counts
#       (8,764,638 over the same pixels).
#   PASSES (99 is a non-issue) if N99 = 0.
#   NEGLIGIBLE if N99 / total changes < 0.1%.
#   FAILS (99 materially inflates the map) if N99 / total changes >= 1%.
#   Report the raw number either way; do not reason from the class totals alone,
#   because a constant count of 99 pixels per year does not prove they are the
#   SAME pixels.
#   (b) Independently: does HILDA+ v1 - the version behind our published v1 map,
#       whose change-freq layer we did not compute - even contain a 99 class over
#       Europe? If it does not, the question cannot arise there.
# =============================================================================
suppressMessages(library(terra))
setwd(here::here())
terraOptions(progress = 0)

sdir   <- "Feature explorations/Biosphere/data_raw/biosphere/hilda_plus_v2/states_wgs84"
shared <- "Feature explorations/_shared"
STUDY <- c("AT","BE","BG","HR","CY","CZ","DK","EE","FI","FR","DE","EL","HU","IE",
           "IT","LV","LT","LU","MT","NL","PL","PT","RO","SK","SI","ES","SE","UK",
           "IS","LI","NO","CH")
YEARS <- 1960:2019
euro  <- ext(-25, 45, 34, 72)
cn    <- vect(file.path(shared, "CNTR_RG_10M_2024_4326.geojson"))
study <- crop(cn[cn$CNTR_ID %in% STUDY, ], euro)
LAND  <- c(11,22,23,24,33,40,41,42,43,44,45,55,66)
fpath <- function(y) file.path(sdir, sprintf("hilda_plus_states_%d_GLOB-v2_wgs84.tif", y))

# --- (a) v2: isolate code 99 -------------------------------------------------
msk  <- rasterize(study, crop(rast(fpath(1960)), euro))
keep <- which(!is.na(values(msk, mat = FALSE)))
cat(sprintf("study-area pixels: %s\n", format(length(keep), big.mark = ",")))

prev <- values(crop(rast(fpath(1960)), euro), mat = FALSE)[keep]
n99_to_land <- 0; n_land_to_99 <- 0; n99_other <- 0
n99_per_year <- integer(length(YEARS)); n99_per_year[1] <- sum(prev == 99)
ever99 <- prev == 99

for (i in 2:length(YEARS)) {
  cur <- values(crop(rast(fpath(YEARS[i])), euro), mat = FALSE)[keep]
  n99_per_year[i] <- sum(cur == 99)
  ever99 <- ever99 | (cur == 99)
  n99_to_land  <- n99_to_land  + sum(prev == 99 & cur %in% LAND)
  n_land_to_99 <- n_land_to_99 + sum(prev %in% LAND & cur == 99)
  n99_other    <- n99_other    + sum((prev == 99) != (cur == 99)) -
                  sum(prev == 99 & cur %in% LAND) - sum(prev %in% LAND & cur == 99)
  prev <- cur
}

cat("\n--- code 99 (\"no data\") in the study area, v2 ---\n")
cat(sprintf("pixels that are 99 in at least one year : %s\n", format(sum(ever99), big.mark=",")))
cat(sprintf("pixels that are 99 in ALL 60 years      : %s\n",
            format(sum(n99_per_year == n99_per_year[1]) == length(YEARS) &&
                   sum(ever99) == n99_per_year[1], big.mark=",")))
cat("count of 99 pixels per year (should be constant if it is a static mask):\n")
print(setNames(n99_per_year, YEARS)[c(1, 11, 21, 31, 41, 51, 60)])
cat(sprintf("  min %d | max %d | distinct values %d\n",
            min(n99_per_year), max(n99_per_year), length(unique(n99_per_year))))

TOT <- 8764638
N99 <- n99_to_land + n_land_to_99
cat(sprintf("\ntransitions 99 -> land class : %s\n", format(n99_to_land, big.mark=",")))
cat(sprintf("transitions land class -> 99 : %s\n", format(n_land_to_99, big.mark=",")))
cat(sprintf("transitions 99 <-> ocean/water: %s\n", format(n99_other, big.mark=",")))
cat(sprintf("N99 (99 <-> land) = %s, i.e. %.6f%% of the %s changes our map counts\n",
            format(N99, big.mark=","), 100*N99/TOT, format(TOT, big.mark=",")))
cat(sprintf("VERDICT (a): %s\n",
            if (N99 == 0) "PASSED - 99 never touches a land class" else
            if (N99/TOT < 0.001) "NEGLIGIBLE" else
            if (N99/TOT >= 0.01) "FAILED - 99 materially inflates the map" else "between thresholds"))

# --- (b) v1: does a 99 class exist over Europe at all? -----------------------
cat("\n--- HILDA+ v1 raw class inventory over Europe ---\n")
hurl <- function(y) sprintf("/vsicurl/https://s3.openlandmap.org/arco/land.use.land.cover_hilda.plus_c_1km_s_%d0101_%d1231_go_espg.4326_v1.0.tif", y, y)
for (y in c(1960, 1990, 2019)) {
  v <- values(crop(rast(hurl(y)), euro), mat = FALSE)
  tb <- table(v, useNA = "ifany")
  cat(sprintf("v1 %d: classes present = %s\n", y, paste(names(tb), collapse=",")))
  cat(sprintf("        count of 99 = %d | count of NA = %d\n",
              if ("99" %in% names(tb)) tb[["99"]] else 0L, sum(is.na(v))))
}
