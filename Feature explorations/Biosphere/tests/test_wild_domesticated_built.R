# Synthetic integration test for 5_build_wild_domesticated_built.R
#
# Part 1 is the positive case: a four-quadrant world whose answer is known by
# hand. Parts 2 and 3 are negative cases. They exist because a control that
# never fails proves nothing: part 2 shows the refinement guard actually stops
# a run, part 3 shows the routing control actually fires when a valid HILDA
# class is left unrouted.
suppressPackageStartupMessages(library(terra))

script_arg <- commandArgs(FALSE)
script_arg <- script_arg[startsWith(script_arg, "--file=")]
this_file <- normalizePath(sub("^--file=", "", script_arg[[1]]), mustWork = TRUE)
root <- normalizePath(file.path(dirname(this_file), "../../.."), mustWork = TRUE)
pipeline <- file.path(
  root, "Feature explorations", "Biosphere", "scripts",
  "5_build_wild_domesticated_built.R"
)

test_root <- file.path(tempdir(), "wdb_synthetic_integration")
unlink(test_root, recursive = TRUE)
dir.create(test_root, recursive = TRUE, showWarnings = FALSE)
hilda_dir <- file.path(test_root, "hilda")
dir.create(hilda_dir, recursive = TRUE, showWarnings = FALSE)

rscript <- file.path(R.home("bin"), "Rscript.exe")

run_pipeline <- function(extra, out_dir, quiet = FALSE) {
  system2(
    rscript,
    c(
      shQuote(pipeline), "--years=2015", "--grid-km=30",
      "--extent=0,0,0.2,0.2", "--target-crs=EPSG:6933",
      "--target-extent=0,0,30000,30000", "--mask=none", "--wsf3d=",
      paste0("--out-dir=", shQuote(out_dir)),
      extra
    ),
    stdout = if (quiet) FALSE else "", stderr = if (quiet) FALSE else ""
  )
}

# =============================================================================
# Part 1 -- positive case
# =============================================================================

# Four equal quadrants: unmanaged grass, pasture, urban and forest.
hilda <- rast(ncols = 20, nrows = 20, xmin = 0, xmax = 0.2,
              ymin = 0, ymax = 0.2, crs = "EPSG:4326")
xy <- crds(hilda, df = TRUE)
values(hilda) <- ifelse(
  xy$x < 0.1 & xy$y >= 0.1, 55,
  ifelse(xy$x >= 0.1 & xy$y >= 0.1, 33,
         ifelse(xy$x < 0.1, 11, 40))
)
writeRaster(
  hilda,
  file.path(hilda_dir, "hilda_plus_states_2015_GLOB-v2_wgs84.tif"),
  overwrite = TRUE
)

# The HILDA forest quadrant is half unmanaged (11), half managed (20).
lesiv <- rast(ncols = 40, nrows = 40, xmin = 0, xmax = 0.2,
              ymin = 0, ymax = 0.2, crs = "EPSG:4326")
xy_l <- crds(lesiv, df = TRUE)
values(lesiv) <- ifelse(
  xy_l$x >= 0.1 & xy_l$y < 0.1,
  ifelse(xy_l$x < 0.15, 11, 20),
  0
)
lesiv_path <- file.path(test_root, "lesiv.tif")
writeRaster(lesiv, lesiv_path, overwrite = TRUE)

# GPW: pasture is 50/50 cultivated/natural; unmanaged grass is 25/75.
gpw <- rast(lesiv)
values(gpw) <- 30
pasture <- xy_l$x >= 0.1 & xy_l$y >= 0.1
unmanaged <- xy_l$x < 0.1 & xy_l$y >= 0.1
values(gpw)[pasture] <- ifelse(xy_l$x[pasture] < 0.15, 31, 32)
values(gpw)[unmanaged] <- ifelse(xy_l$x[unmanaged] < 0.025, 31, 32)
gpw_path <- file.path(test_root, "gpw_2015.tif")
writeRaster(gpw, gpw_path, overwrite = TRUE)

manifest_path <- file.path(test_root, "gpw_manifest.csv")
write.csv(
  data.frame(
    year = 2015, dominant_path = gpw_path, cultivated_codes = "31",
    natural_codes = "32", shrub_codes = "", nodata_codes = "",
    version = "synthetic", source_url = ""
  ),
  manifest_path,
  row.names = FALSE
)

out_dir <- file.path(test_root, "output")
status <- run_pipeline(
  c(
    paste0("--hilda-dir=", shQuote(hilda_dir)),
    paste0("--lesiv=", shQuote(lesiv_path)),
    paste0("--gpw-manifest=", shQuote(manifest_path)),
    "--overwrite"
  ),
  out_dir
)
stopifnot(status == 0)

qa <- read.csv(file.path(out_dir, "tables", "qa_30km.csv"))
summary <- read.csv(file.path(out_dir, "tables", "trajectory_summary_30km.csv"))
cells <- read.csv(file.path(
  out_dir, "tables", "wild_domesticated_built_cells_2015_30km.csv"
))

stopifnot(
  qa$temporal_support == "hilda_lesiv_gpw_snapshot",
  qa$lesiv_used,
  qa$gpw_used,
  # C0: identity, kept as a float guard only.
  qa$identity_max_abs_sum_error_pct < 1e-5,
  # C1: routing must hold, before and after the Lesiv split.
  qa$routing_ok,
  qa$routing_max_gap_pp < 1e-5,
  # C2: not computable without a study mask, and must say so rather than
  # inventing a number.
  is.na(qa$land_over_polygon_ratio),
  is.na(qa$study_polygon_area_m2),
  qa$land_area_m2 > 0,
  all(abs(rowSums(cells[c(
    "pct_wild", "pct_domesticated", "pct_built_up", "pct_unresolved"
  )]) - 100) < 1e-5),
  all(c(
    "pct_gpw_cultivated_grass", "pct_gpw_natural_semi_grass",
    "pct_grass_conflict"
  ) %in% names(cells)),
  abs(summary$pct_wild - 37.5) < 3,
  abs(summary$pct_domesticated - 37.5) < 3,
  abs(summary$pct_built_up - 25) < 3,
  summary$pct_unresolved < 1e-4,
  # Nested accounting: built-up is INSIDE anthropogenic, not beside it.
  abs(summary$pct_anthropogenic -
        (summary$pct_domesticated + summary$pct_built_up)) < 1e-6,
  abs(summary$pct_wild + summary$pct_anthropogenic + summary$pct_unresolved - 100) < 1e-6,
  # C4: degree shares close on the resolved share.
  qa$hemeroby_closure_ok,
  qa$hemeroby_max_closure_gap_pp < 1e-3
)

# Hemeroby, computed by hand from the four quadrants:
#   55 unmanaged grass  -> degree 2, 25 %
#   33 pasture          -> degree 4, 25 %
#   11 urban            -> degree 6, 25 %
#   40 forest, 25 %, split by Lesiv into half 11 (degree 2) and half 20 (degree 3)
# so shares are d2 = 37.5, d3 = 12.5, d4 = 25, d6 = 25, and the mean degree is
#   (2*37.5 + 3*12.5 + 4*25 + 6*25) / 100 = 3.625
expected_shares <- c(`1` = 0, `2` = 37.5, `3` = 12.5, `4` = 25, `5` = 0, `6` = 25)
for (d in names(expected_shares)) {
  col <- paste0("pct_hemeroby_", d)
  stopifnot(col %in% names(cells))
  stopifnot(abs(mean(cells[[col]]) - expected_shares[[d]]) < 3)
}
stopifnot(
  "hemeroby_mean" %in% names(cells),
  abs(mean(cells$hemeroby_coverage_pct) - 100) < 1e-3,
  abs(summary$hemeroby_mean_area_weighted - 3.625) < 0.15
)

cat(sprintf(
  "Part 1 -- synthetic HILDA + Lesiv + GPW integration: PASS (mean hemeroby %.3f, expected 3.625)\n",
  summary$hemeroby_mean_area_weighted
))

# =============================================================================
# Part 2 -- the refinement guard must actually stop a run
#
# Reproduces the trap the workflow note used to document: compute a year with
# no refinement, then ask for --lesiv on the same year without --overwrite.
# Before the guard, this exited 0 and silently kept the un-refined result.
# =============================================================================

guard_dir <- file.path(test_root, "output_guard")
hilda_arg <- paste0("--hilda-dir=", shQuote(hilda_dir))
lesiv_arg <- paste0("--lesiv=", shQuote(lesiv_path))

stopifnot(run_pipeline(c(hilda_arg, "--overwrite"), guard_dir, quiet = TRUE) == 0)
qa_plain <- read.csv(file.path(guard_dir, "tables", "qa_30km.csv"))
stopifnot(!qa_plain$lesiv_used)

# Same year, now asking for Lesiv, no --overwrite: must FAIL, not skip.
refused <- run_pipeline(c(hilda_arg, lesiv_arg), guard_dir, quiet = TRUE)
stopifnot(refused != 0)
qa_after_refusal <- read.csv(file.path(guard_dir, "tables", "qa_30km.csv"))
stopifnot(!qa_after_refusal$lesiv_used)  # nothing was overwritten

# With --overwrite it goes through and the flag flips.
stopifnot(
  run_pipeline(c(hilda_arg, lesiv_arg, "--overwrite"), guard_dir, quiet = TRUE) == 0
)
stopifnot(read.csv(file.path(guard_dir, "tables", "qa_30km.csv"))$lesiv_used)

# A re-run asking for nothing new is still allowed to skip.
stopifnot(run_pipeline(c(hilda_arg, lesiv_arg), guard_dir, quiet = TRUE) == 0)

cat("Part 2 -- refinement guard refuses a silent skip: PASS\n")

# =============================================================================
# Part 3 -- the routing control must fire on an unrouted valid class
#
# Patches a COPY of the pipeline so that code 70 counts as valid HILDA while
# belonging to no group. The residual then holds 70 as well as forest, so
# pct_unresolved and pct_unresolved_forest diverge and C1 must fail. This is
# the observation that would make the control fail; without it the control
# would be an assertion, not a test.
# =============================================================================

broken_pipeline <- file.path(test_root, "pipeline_unrouted_class.R")
lines <- readLines(pipeline, warn = FALSE)
i <- grep("^VALID_HILDA <- ", lines)
stopifnot(length(i) == 1)
lines[i] <- "VALID_HILDA <- c(11L, 22L, 23L, 24L, 33L, 40L:45L, 55L, 66L, 70L)"
writeLines(lines, broken_pipeline)

broken_hilda_dir <- file.path(test_root, "hilda_unrouted")
dir.create(broken_hilda_dir, recursive = TRUE, showWarnings = FALSE)
broken <- rast(hilda)
xy_b <- crds(broken, df = TRUE)
# One quadrant of an unrouted-but-valid class, no forest anywhere.
values(broken) <- ifelse(
  xy_b$x < 0.1 & xy_b$y >= 0.1, 55,
  ifelse(xy_b$x >= 0.1 & xy_b$y >= 0.1, 33,
         ifelse(xy_b$x < 0.1, 11, 70))
)
writeRaster(
  broken,
  file.path(broken_hilda_dir, "hilda_plus_states_2015_GLOB-v2_wgs84.tif"),
  overwrite = TRUE
)

broken_out <- file.path(test_root, "output_unrouted")
status_broken <- system2(
  rscript,
  c(
    shQuote(broken_pipeline), "--years=2015", "--grid-km=30",
    "--extent=0,0,0.2,0.2", "--target-crs=EPSG:6933",
    "--target-extent=0,0,30000,30000", "--mask=none", "--wsf3d=",
    paste0("--hilda-dir=", shQuote(broken_hilda_dir)),
    paste0("--out-dir=", shQuote(broken_out)), "--overwrite"
  ),
  stdout = FALSE, stderr = FALSE
)
stopifnot(status_broken == 0)  # the run completes; it is the CONTROL that fails

qa_broken <- read.csv(file.path(broken_out, "tables", "qa_30km.csv"))
stopifnot(
  !qa_broken$routing_ok,
  qa_broken$routing_max_gap_pp > 1,
  qa_broken$routing_cells_over_noise > 0,
  # C0 is blind to this: the components still sum to 100.
  qa_broken$identity_max_abs_sum_error_pct < 1e-5
)

cat(sprintf(
  "Part 3 -- routing control fires on an unrouted class (gap %.1f pp, identity blind): PASS\n",
  qa_broken$routing_max_gap_pp
))

# =============================================================================
# Part 4 -- the hemeroby closure control must fire on a class with no degree
#
# Same shape as part 3. Removes pasture/agroforestry from the degree table in a
# COPY of the pipeline, so a quarter of the synthetic world is resolved by the
# partition but carries no degree. C4 must fail; C1 (routing) must NOT, since
# routing is untouched -- that separation is the point of having both.
# =============================================================================

nodegree_pipeline <- file.path(test_root, "pipeline_missing_degree.R")
lines2 <- readLines(pipeline, warn = FALSE)
j <- grep('^  "4" = c\\(33L, 24L\\)', lines2)
stopifnot(length(j) == 1)
lines2[j] <- '  "4" = NULL,'
writeLines(lines2, nodegree_pipeline)

nodegree_out <- file.path(test_root, "output_missing_degree")
status_nodegree <- system2(
  rscript,
  c(
    shQuote(nodegree_pipeline), "--years=2015", "--grid-km=30",
    "--extent=0,0,0.2,0.2", "--target-crs=EPSG:6933",
    "--target-extent=0,0,30000,30000", "--mask=none", "--wsf3d=",
    paste0("--hilda-dir=", shQuote(hilda_dir)),
    paste0("--lesiv=", shQuote(lesiv_path)),
    paste0("--out-dir=", shQuote(nodegree_out)), "--overwrite"
  ),
  stdout = FALSE, stderr = FALSE
)
stopifnot(status_nodegree == 0)  # the run completes; the CONTROL fails

qa_nodegree <- read.csv(file.path(nodegree_out, "tables", "qa_30km.csv"))
stopifnot(
  !qa_nodegree$hemeroby_closure_ok,
  qa_nodegree$hemeroby_max_closure_gap_pp > 1,
  qa_nodegree$hemeroby_closure_cells_over_noise > 0,
  # Routing is a different question and must stay green.
  qa_nodegree$routing_ok,
  # And the flat partition is blind to this entirely.
  qa_nodegree$identity_max_abs_sum_error_pct < 1e-5
)

cat(sprintf(
  "Part 4 -- hemeroby closure fires on a class with no degree (gap %.1f pp, routing still OK): PASS\n",
  qa_nodegree$hemeroby_max_closure_gap_pp
))

cat("All parts: PASS\n")
