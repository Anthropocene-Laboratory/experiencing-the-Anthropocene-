# =============================================================================
# 5_build_wild_domesticated_built.R
#
# Build mutually exclusive %wild, %domesticated, %built-up and %unresolved
# layers from HILDA+ v2, with two optional refinements:
#   * Lesiv et al. (2015) splits HILDA forest into managed/unmanaged forest.
#   * Global Pasture Watch (GPW) adds annual diagnostics inside HILDA classes
#     33 and 55. GPW never changes or gets added to the primary partition.
#
# No population variable is used. All aggregation is performed on an equal-area
# target grid and all area outputs are in square metres.
#
# Examples (run from any directory):
#   Rscript 5_build_wild_domesticated_built.R --years=2015 --grid-km=10
#   Rscript 5_build_wild_domesticated_built.R --years=1960:2019 --grid-km=10
#   Rscript 5_build_wild_domesticated_built.R --years=2000:2019 \
#     --gpw-manifest=C:/data/gpw_manifest.csv
#
# Use --help for all options.
# =============================================================================

suppressPackageStartupMessages(library(terra))

args <- commandArgs(trailingOnly = TRUE)

has_flag <- function(flag) flag %in% args
get_opt <- function(key, default = NULL) {
  prefix <- paste0("--", key, "=")
  hit <- args[startsWith(args, prefix)]
  if (!length(hit)) return(default)
  sub(prefix, "", hit[[length(hit)]], fixed = TRUE)
}

usage <- function() {
  cat(paste0(
    "HILDA+ -> wild/domesticated/built-up workflow\n\n",
    "Core options:\n",
    "  --years=2015               One year, comma list, or range (1960:2019)\n",
    "  --grid-km=10               Equal-area target-cell size\n",
    "  --analysis-km=1            Intermediate equal-area resolution\n",
    "  --extent=-25,34,45,72      Input WGS84 bbox xmin,ymin,xmax,ymax\n",
    "  --target-crs=EPSG:3035     Equal-area output CRS\n",
    "  --target-extent=xmin,ymin,xmax,ymax  Optional fixed target extent\n",
    "  --mask=study|none          Mask to configured European countries\n",
    "  --hilda-dir=PATH           Directory with annual HILDA state GeoTIFFs\n",
    "  --lesiv=PATH               Optional Lesiv 2015 forest-management raster\n",
    "  --lesiv-year=2015          Year in which Lesiv replaces HILDA forest\n",
    "  --gpw-manifest=PATH        Optional annual GPW dominant-class manifest\n",
    "  --wsf3d=PATH               Optional physical built-fraction raster\n",
    "  --wsf3d-year=2015          Snapshot year for the WSF3D auxiliary layer\n",
    "  --hemeroby-min-coverage=75 Below this % of resolved land, hemeroby_mean is NA\n",
    "  --out-dir=PATH             Output directory\n",
    "  --dry-run                  Validate configuration without raster work\n",
    "  --overwrite                Replace existing annual outputs\n",
    "  --help                     Show this message\n\n",
    "For a 10 km global Eckert IV grid, use:\n",
    "  --extent=-180,-90,180,90 --target-crs=ESRI:54012 \\\n",
    "  --target-extent=-18000000,-9000000,18000000,9000000 --mask=none\n"
  ))
}

if (has_flag("--help")) {
  usage()
  quit(save = "no", status = 0)
}

script_arg <- commandArgs(FALSE)
script_arg <- script_arg[startsWith(script_arg, "--file=")]
if (length(script_arg)) {
  script_file <- normalizePath(sub("^--file=", "", script_arg[[1]]), mustWork = TRUE)
  root <- normalizePath(file.path(dirname(script_file), "../../.."), mustWork = TRUE)
} else {
  root <- normalizePath(getwd(), mustWork = TRUE)
}

abs_path <- function(path, base = root, must_work = FALSE) {
  if (is.null(path) || !nzchar(path)) return(NULL)
  is_abs <- grepl("^[A-Za-z]:[/\\\\]", path) || startsWith(path, "/")
  candidate <- if (is_abs) path else file.path(base, path)
  normalizePath(candidate, winslash = "/", mustWork = must_work)
}

parse_numbers <- function(x, expected = NULL, label = "value") {
  out <- suppressWarnings(as.numeric(strsplit(x, "[,;]", perl = TRUE)[[1]]))
  if (anyNA(out) || (!is.null(expected) && length(out) != expected)) {
    stop("Invalid --", label, "=", x)
  }
  out
}

parse_years <- function(x) {
  bits <- trimws(strsplit(x, ",", fixed = TRUE)[[1]])
  years <- integer()
  for (bit in bits) {
    if (grepl("^[0-9]{4}:[0-9]{4}$", bit)) {
      ends <- as.integer(strsplit(bit, ":", fixed = TRUE)[[1]])
      years <- c(years, seq(ends[1], ends[2], by = ifelse(ends[2] >= ends[1], 1, -1)))
    } else if (grepl("^[0-9]{4}$", bit)) {
      years <- c(years, as.integer(bit))
    } else {
      stop("Invalid year expression: ", bit)
    }
  }
  sort(unique(years))
}

parse_codes <- function(x) {
  if (is.null(x) || is.na(x) || !nzchar(trimws(x))) return(integer())
  values <- trimws(strsplit(as.character(x), "[|;, ]+", perl = TRUE)[[1]])
  out <- suppressWarnings(as.integer(values[nzchar(values)]))
  if (!length(out) || anyNA(out)) stop("Invalid class-code list: ", x)
  unique(out)
}

years <- parse_years(get_opt("years", "2015"))
grid_km <- as.numeric(get_opt("grid-km", "10"))
if (!is.finite(grid_km) || grid_km <= 0) stop("--grid-km must be positive")
cell_m <- grid_km * 1000
analysis_km <- as.numeric(get_opt("analysis-km", "1"))
if (!is.finite(analysis_km) || analysis_km <= 0 || analysis_km > grid_km) {
  stop("--analysis-km must be positive and no larger than --grid-km")
}
aggregation_factor <- grid_km / analysis_km
if (abs(aggregation_factor - round(aggregation_factor)) > 1e-9) {
  stop("--grid-km must be an integer multiple of --analysis-km")
}
aggregation_factor <- as.integer(round(aggregation_factor))
analysis_m <- analysis_km * 1000

extent_wgs <- parse_numbers(get_opt("extent", "-25,34,45,72"), 4, "extent")
names(extent_wgs) <- c("xmin", "ymin", "xmax", "ymax")
if (extent_wgs[1] >= extent_wgs[3] || extent_wgs[2] >= extent_wgs[4]) {
  stop("--extent must be xmin,ymin,xmax,ymax")
}

target_crs <- get_opt("target-crs", "EPSG:3035")
target_extent_text <- get_opt("target-extent", NULL)
mask_mode <- tolower(get_opt("mask", "study"))
if (!mask_mode %in% c("study", "none")) stop("--mask must be study or none")

bio_raw <- file.path(root, "Feature explorations", "Biosphere", "data_raw", "biosphere")
hilda_dir <- abs_path(get_opt(
  "hilda-dir",
  file.path(bio_raw, "hilda_plus_v2", "states_wgs84")
))
lesiv_path <- abs_path(get_opt("lesiv", ""))
lesiv_year <- as.integer(get_opt("lesiv-year", "2015"))
gpw_manifest_path <- abs_path(get_opt("gpw-manifest", ""))
wsf3d_default <- file.path(
  root, "Feature explorations", "Technosphere", "data_processed",
  "eu_fraction_wsf3d_3km.tif"
)
wsf3d_path <- abs_path(get_opt("wsf3d", if (file.exists(wsf3d_default)) wsf3d_default else ""))
wsf3d_year <- as.integer(get_opt("wsf3d-year", "2015"))
out_dir <- abs_path(get_opt(
  "out-dir",
  file.path(root, "Feature explorations", "Biosphere", "data_processed",
            "wild_domesticated_built")
))

# Below this share of resolved land, `hemeroby_mean` is written NA rather than
# computed on a fraction of the cell. 75 % is a CHOICE, not a measured value:
# it is stated here and in run_config.csv so it can be argued with, and it is
# exposed as a flag so the sensitivity can be tested rather than assumed.
hemeroby_min_coverage <- as.numeric(get_opt("hemeroby-min-coverage", "75"))
if (!is.finite(hemeroby_min_coverage) ||
    hemeroby_min_coverage < 0 || hemeroby_min_coverage > 100) {
  stop("--hemeroby-min-coverage must be between 0 and 100")
}

overwrite <- has_flag("--overwrite")
dry_run <- has_flag("--dry-run")

hilda_path <- function(year) file.path(
  hilda_dir,
  sprintf("hilda_plus_states_%d_GLOB-v2_wgs84.tif", year)
)
hilda_files <- vapply(years, hilda_path, character(1))
missing_hilda <- hilda_files[!file.exists(hilda_files)]
if (length(missing_hilda)) {
  stop("Missing HILDA state raster(s):\n  ", paste(missing_hilda, collapse = "\n  "))
}

gpw_manifest <- NULL
if (!is.null(gpw_manifest_path)) {
  if (!file.exists(gpw_manifest_path)) stop("GPW manifest not found: ", gpw_manifest_path)
  gpw_manifest <- read.csv(gpw_manifest_path, stringsAsFactors = FALSE, check.names = FALSE)
  required <- c("year", "dominant_path", "cultivated_codes", "natural_codes")
  missing_cols <- setdiff(required, names(gpw_manifest))
  if (length(missing_cols)) {
    stop("GPW manifest lacks columns: ", paste(missing_cols, collapse = ", "))
  }
  gpw_manifest$year <- as.integer(gpw_manifest$year)
}

cat("Configuration\n")
cat("  workspace:  ", root, "\n", sep = "")
cat("  years:      ", paste(years, collapse = ", "), "\n", sep = "")
cat("  grid:       ", grid_km, " km (", analysis_km,
    " km intermediate); ", target_crs, "\n", sep = "")
cat("  WGS84 bbox: ", paste(extent_wgs, collapse = ", "), "\n", sep = "")
cat("  mask:       ", mask_mode, "\n", sep = "")
cat("  HILDA:      ", hilda_dir, "\n", sep = "")
cat("  Lesiv:      ", ifelse(is.null(lesiv_path), "not configured", lesiv_path), "\n", sep = "")
cat("  GPW:        ", ifelse(is.null(gpw_manifest_path), "not configured", gpw_manifest_path), "\n", sep = "")
cat("  WSF3D:      ", ifelse(is.null(wsf3d_path), "not configured", wsf3d_path), "\n", sep = "")
cat("  output:     ", out_dir, "\n", sep = "")

if (!is.null(lesiv_path) && !file.exists(lesiv_path)) stop("Lesiv raster not found: ", lesiv_path)
if (!is.null(wsf3d_path) && !file.exists(wsf3d_path)) stop("WSF3D raster not found: ", wsf3d_path)

if (dry_run) {
  if (!is.null(gpw_manifest)) {
    available <- intersect(years, gpw_manifest$year)
    cat("  GPW years matching request: ",
        ifelse(length(available), paste(available, collapse = ", "), "none"), "\n", sep = "")
  }
  cat("Dry run complete; no raster was processed.\n")
  quit(save = "no", status = 0)
}

dir.create(file.path(out_dir, "rasters"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(out_dir, "tables"), recursive = TRUE, showWarnings = FALSE)
terra_tmp <- file.path(out_dir, "_terra_tmp")
dir.create(terra_tmp, recursive = TRUE, showWarnings = FALSE)
terraOptions(tempdir = terra_tmp, progress = 0)

euro_codes <- c(
  "AT", "BE", "BG", "HR", "CY", "CZ", "DK", "EE", "FI", "FR", "DE", "EL",
  "HU", "IE", "IT", "LV", "LT", "LU", "MT", "NL", "PL", "PT", "RO", "SK",
  "SI", "ES", "SE", "UK", "IS", "LI", "NO", "CH"
)

input_extent <- ext(extent_wgs[c("xmin", "xmax", "ymin", "ymax")])
bbox_poly <- as.polygons(input_extent, crs = "EPSG:4326")
study_target <- NULL
study_polygon_area_m2 <- NULL
if (mask_mode == "study") {
  border_path <- file.path(
    root, "Feature explorations", "_shared", "CNTR_RG_10M_2024_4326.geojson"
  )
  if (!file.exists(border_path)) stop("Study-country boundary not found: ", border_path)
  countries <- vect(border_path)
  if (!"CNTR_ID" %in% names(countries)) stop("CNTR_ID missing from study-country boundary")
  study_wgs <- crop(countries[countries$CNTR_ID %in% euro_codes, ], input_extent)
  if (!nrow(study_wgs)) stop("No study country intersects --extent")
  study_target <- project(study_wgs, target_crs)
  # Planimetric area in the equal-area target CRS, so it is comparable with the
  # sum of cell areas the pipeline produces. transform=FALSE keeps it planar
  # instead of recomputing a geodesic area on the ellipsoid.
  study_polygon_area_m2 <- sum(expanse(study_target, unit = "m", transform = FALSE))
  target_shape <- study_target
} else {
  target_shape <- if (is.null(target_extent_text)) project(bbox_poly, target_crs) else NULL
}

if (!is.null(target_extent_text)) {
  te <- parse_numbers(target_extent_text, 4, "target-extent")
  target_ext <- ext(te[c(1, 3, 2, 4)])
} else {
  shape_ext <- ext(target_shape)
  target_ext <- ext(
    floor(shape_ext$xmin / cell_m) * cell_m,
    ceiling(shape_ext$xmax / cell_m) * cell_m,
    floor(shape_ext$ymin / cell_m) * cell_m,
    ceiling(shape_ext$ymax / cell_m) * cell_m
  )
}
target <- rast(ext = target_ext, resolution = cell_m, crs = target_crs)
analysis_target <- rast(ext = target_ext, resolution = analysis_m, crs = target_crs)

VALID_HILDA <- c(11L, 22L, 23L, 24L, 33L, 40L:45L, 55L, 66L)
BUILT_HILDA <- 11L
DOMESTICATED_HILDA <- c(22L, 23L, 24L, 33L)
WILD_HILDA <- c(55L, 66L)
FOREST_HILDA <- 40L:45L
LESIV_WILD <- 11L
LESIV_DOMESTICATED <- c(20L, 31L, 32L, 40L, 53L)

# Tolerance below which a stray averaged fraction is treated as float noise
# rather than a resampling defect. Used only to decide whether to warn.
CLAMP_TOL <- 1e-6

# pct_unresolved and pct_unresolved_forest are algebraically the same quantity
# (see the routing control in the QA block). Two thresholds, because the first
# version of this control used 1e-6 pp and could not be satisfied:
#
# ROUTING_NOISE_PP -- the floor below which a gap is storage precision, not a
#   fault. The intermediate and output rasters are written FLT4S, so a value
#   near 4 pp carries a float32 ULP of ~3.8e-06 pp. A tolerance under that is
#   not a strict control, it is an impossible one. Cells above this floor are
#   COUNTED, not failed.
# ROUTING_FAIL_PP -- the verdict threshold. A genuinely unrouted VALID_HILDA
#   class produced a 25.4 pp gap in tests/test_wild_domesticated_built.R, so
#   1e-3 pp still catches that by four orders of magnitude while tolerating
#   resampling residue.
ROUTING_NOISE_PP <- 1e-5
ROUTING_FAIL_PP <- 1e-3

# --- Hemeroby: the wild -> urban gradient ------------------------------------
# The wild / domesticated / built partition treats three SIBLING categories. A
# city is transformed land par excellence, so built-up belongs INSIDE the
# anthropogenic share, not beside it, and the real structure is a gradient.
#
# Hemeroby is the established name for that gradient: an ordinal degree of human
# transformation defined on LAND USE ALONE. That last point is why it is used
# here rather than the Anthromes ordering (which the project already implements
# in 1_map_biosphere_anthromes.R): Anthromes classes are defined partly by
# population density, and this feature exists to avoid a population proxy.
#
# THIS TABLE IS A JUDGEMENT ANCHORED IN THE LITERATURE, NOT A MEASUREMENT.
# It is the one place to argue with, and it is meant to be argued with. Degrees
# follow the standard 7-point scale (ahemerobic .. metahemerobic); only 1-6 are
# assigned, see HEMEROBY_MAX below.
HEMEROBY_LEVELS <- data.frame(
  degree = 1:6,
  name = c("ahemerobic", "oligohemerobic", "mesohemerobic",
           "beta-euhemerobic", "alpha-euhemerobic", "polyhemerobic"),
  gloss = c("no detectable human impact", "weak / close to natural",
            "managed, regularly disturbed", "cultivated (grazing)",
            "intensively cultivated (crops)", "built / very intensively transformed"),
  stringsAsFactors = FALSE
)
HEMEROBY_MAX <- 6L

# HILDA classes -> degree. Forest (40-45) is deliberately absent: its degree is
# not knowable from HILDA, which distinguishes forests botanically (leaf type,
# phenology) and carries no management information. Forest is assigned only
# where Lesiv resolves it, and otherwise stays unresolved -- the same rule the
# wild/domesticated split already follows.
HEMEROBY_HILDA <- list(
  "1" = 66L,           # sparse / no vegetation
  "2" = 55L,           # unmanaged grass / shrubland
  "4" = c(33L, 24L),   # pasture / rangeland; agroforestry
  "5" = c(22L, 23L),   # annual crops; tree crops
  "6" = 11L            # urban
)
# Lesiv classes -> degree, applied inside the HILDA forest mask only.
HEMEROBY_LESIV <- list(
  "2" = LESIV_WILD,          # no management signature in the pixel
  "3" = LESIV_DOMESTICATED   # logged, planted, plantation, agroforestry
)

# NOT IMPLEMENTED, and the reason is deliberate. The 7th degree (metahemerobic,
# sealed surface) would split HILDA urban by WSF3D building fraction, and WSF3D
# is already on disk. It is left out because the split needs a THRESHOLD on
# building fraction and no justified value exists yet: picking one now would put
# an invented number at the top of the scale. Urban therefore sits at degree 6
# as a single class. Revisit with a threshold taken from the WSF3D literature
# or measured against a sealed-surface product, not chosen for convenience.

binary_on_valid <- function(r, codes, valid_codes) {
  # Invalid HILDA classes are zero, not NA, so projected averages retain the
  # terrestrial coverage fraction of coastal/partly valid target cells.
  ifel(is.na(r), 0, ifel(r %in% valid_codes, ifel(r %in% codes, 1, 0), 0))
}

absolute_class_fraction <- function(source, codes, hilda_template, label = "auxiliary") {
  source <- crop(source, ext(hilda_template), snap = "out")
  indicator <- ifel(is.na(source), 0, ifel(source %in% codes, 1, 0))
  if (same.crs(indicator, hilda_template)) {
    out <- resample(indicator, hilda_template, method = "average")
  } else {
    out <- project(indicator, hilda_template, method = "average")
  }
  # The clamp below repairs the value; without this warning it would also hide
  # the fact that a repair was needed. An averaged indicator can only leave
  # [0, 1] through a resampling fault, so anything past the tolerance is a
  # defect to look at, not rounding.
  rng <- unlist(minmax(out))
  if (any(is.finite(rng)) && (min(rng, na.rm = TRUE) < -CLAMP_TOL ||
                              max(rng, na.rm = TRUE) > 1 + CLAMP_TOL)) {
    warning(sprintf(
      "%s fraction left [0,1] before clamping (observed %.6f to %.6f); clamped.",
      label, min(rng, na.rm = TRUE), max(rng, na.rm = TRUE)
    ), call. = FALSE)
  }
  ifel(is.na(out), 0, clamp(out, 0, 1))
}

resolve_manifest_path <- function(value, manifest_path) {
  if (is.na(value) || !nzchar(trimws(value))) return(NULL)
  abs_path(trimws(value), dirname(manifest_path))
}

build_hilda_composition <- function(hilda, year, lesiv = NULL) {
  valid <- ifel(is.na(hilda), 0, ifel(hilda %in% VALID_HILDA, 1, 0))
  wild <- binary_on_valid(hilda, WILD_HILDA, VALID_HILDA)
  domesticated <- binary_on_valid(hilda, DOMESTICATED_HILDA, VALID_HILDA)
  built <- binary_on_valid(hilda, BUILT_HILDA, VALID_HILDA)
  unresolved <- valid - wild - domesticated - built
  unresolved_forest <- binary_on_valid(hilda, FOREST_HILDA, VALID_HILDA)

  lesiv_used <- FALSE
  if (!is.null(lesiv) && year == lesiv_year) {
    message("  Splitting HILDA forest with Lesiv 2015")
    forest <- binary_on_valid(hilda, FOREST_HILDA, VALID_HILDA)
    forest[is.na(forest)] <- 0
    lesiv_wild <- absolute_class_fraction(lesiv, LESIV_WILD, hilda, "Lesiv wild")
    lesiv_dom <- absolute_class_fraction(lesiv, LESIV_DOMESTICATED, hilda, "Lesiv domesticated")
    classified <- lesiv_wild + lesiv_dom
    # If resampling produces a tiny overlap, renormalise rather than double count.
    lesiv_wild <- ifel(classified > 1, lesiv_wild / classified, lesiv_wild)
    lesiv_dom <- ifel(classified > 1, lesiv_dom / classified, lesiv_dom)
    classified <- clamp(lesiv_wild + lesiv_dom, 0, 1)

    wild <- wild + forest * lesiv_wild
    domesticated <- domesticated + forest * lesiv_dom
    unresolved <- unresolved - forest * classified
    unresolved_forest <- forest * (1 - classified)
    lesiv_used <- TRUE
  }

  unresolved <- clamp(unresolved, 0, 1)

  # Hemeroby degree shares, built at NATIVE resolution from the same indicators
  # so they travel through the identical projection chain. Computing them from
  # the aggregated percentages instead would be averaging averages.
  hem <- vector("list", HEMEROBY_MAX)
  for (d in seq_len(HEMEROBY_MAX)) {
    codes <- HEMEROBY_HILDA[[as.character(d)]]
    # length 0 covers both NULL and an emptied entry. A degree fed only by
    # Lesiv (3) legitimately starts empty, and an entry someone removes must
    # produce an empty layer that C4 then catches -- not a crash that hides
    # which control would have fired.
    layer <- if (length(codes) == 0L) {
      wild * 0
    } else {
      binary_on_valid(hilda, codes, VALID_HILDA)
    }
    hem[[d]] <- layer
  }
  if (lesiv_used) {
    # Forest carries its degree only where Lesiv resolves it. `forest`,
    # `lesiv_wild` and `lesiv_dom` are the same objects the wild/domesticated
    # split used above, so the two accountings cannot drift apart.
    for (d in names(HEMEROBY_LESIV)) {
      di <- as.integer(d)
      share <- if (identical(HEMEROBY_LESIV[[d]], LESIV_WILD)) lesiv_wild else lesiv_dom
      hem[[di]] <- hem[[di]] + forest * share
    }
  }
  for (d in seq_len(HEMEROBY_MAX)) {
    hem[[d]] <- clamp(hem[[d]], 0, 1)
    names(hem[[d]]) <- sprintf("hemeroby_%d", d)
  }

  names(wild) <- "wild"
  names(domesticated) <- "domesticated"
  names(built) <- "built_up"
  names(unresolved) <- "unresolved"
  names(unresolved_forest) <- "unresolved_forest"
  list(
    raster = c(wild, domesticated, built, unresolved, unresolved_forest,
               do.call(c, hem)),
    lesiv_used = lesiv_used
  )
}

build_gpw_diagnostics <- function(hilda, year) {
  if (is.null(gpw_manifest)) return(NULL)
  rows <- gpw_manifest[gpw_manifest$year == year, , drop = FALSE]
  if (!nrow(rows)) return(NULL)
  if (nrow(rows) > 1) stop("GPW manifest has more than one row for year ", year)
  row <- rows[1, , drop = FALSE]
  gpw_path <- resolve_manifest_path(row$dominant_path[[1]], gpw_manifest_path)
  if (is.null(gpw_path) || !file.exists(gpw_path)) {
    warning("Skipping GPW ", year, ": raster not found: ", gpw_path)
    return(NULL)
  }

  cultivated_codes <- parse_codes(as.character(row$cultivated_codes[[1]]))
  natural_codes <- parse_codes(as.character(row$natural_codes[[1]]))
  shrub_codes <- if ("shrub_codes" %in% names(row)) {
    parse_codes(as.character(row$shrub_codes[[1]]))
  } else integer()
  nodata_codes <- if ("nodata_codes" %in% names(row)) {
    parse_codes(as.character(row$nodata_codes[[1]]))
  } else integer()

  message("  Adding GPW grassland diagnostics from ", basename(gpw_path))
  gpw <- crop(rast(gpw_path), ext(hilda), snap = "out")
  if (length(nodata_codes)) gpw <- ifel(gpw %in% nodata_codes, NA, gpw)

  cultivated <- absolute_class_fraction(gpw, cultivated_codes, hilda, "GPW cultivated")
  natural <- absolute_class_fraction(gpw, natural_codes, hilda, "GPW natural")
  shrub <- if (length(shrub_codes)) {
    absolute_class_fraction(gpw, shrub_codes, hilda, "GPW shrub")
  } else {
    cultivated * 0
  }
  classified <- clamp(cultivated + natural + shrub, 0, 1)

  pasture <- ifel(hilda == 33, 1, 0)
  unmanaged_grass <- ifel(hilda == 55, 1, 0)
  grass <- pasture + unmanaged_grass

  diagnostics <- c(
    grass * cultivated,
    grass * natural,
    grass * shrub,
    unmanaged_grass * cultivated,
    pasture * natural,
    pasture * cultivated,
    unmanaged_grass * (natural + shrub),
    grass * (1 - classified)
  )
  names(diagnostics) <- c(
    "gpw_cultivated_grass", "gpw_natural_semi_grass", "gpw_open_shrub",
    "grass_conflict", "hilda33_gpw_natural", "hilda33_gpw_cultivated",
    "hilda55_gpw_natural", "gpw_unvalidated_grass"
  )
  diagnostics
}

project_average <- function(x, year, label) {
  fine_filename <- file.path(
    terra_tmp, sprintf("%s_%d_%gkm_fine.tif", label, year, analysis_km)
  )
  fine <- project(
    x, analysis_target, method = "average", filename = fine_filename, overwrite = TRUE,
    wopt = list(datatype = "FLT4S", gdal = c("COMPRESS=DEFLATE", "TILED=YES"))
  )
  if (aggregation_factor > 1L) {
    filename <- file.path(terra_tmp, sprintf("%s_%d_%gkm.tif", label, year, grid_km))
    out <- aggregate(
      fine, fact = aggregation_factor, fun = "mean", na.rm = TRUE,
      filename = filename, overwrite = TRUE,
      wopt = list(datatype = "FLT4S", gdal = c("COMPRESS=DEFLATE", "TILED=YES"))
    )
  } else {
    out <- fine
  }
  if (!is.null(study_target)) out <- mask(out, study_target)
  out
}

wsf_target <- NULL
if (!is.null(wsf3d_path) && wsf3d_year %in% years) {
  message("Preparing WSF3D built-fraction auxiliary snapshot")
  wsf <- rast(wsf3d_path)
  wsf_target <- project_average(wsf, wsf3d_year, "wsf3d_aux")
  names(wsf_target) <- "pct_built_wsf3d_aux"
}

summary_file <- file.path(out_dir, "tables", sprintf("trajectory_summary_%gkm.csv", grid_km))
qa_file <- file.path(out_dir, "tables", sprintf("qa_%gkm.csv", grid_km))
summary_rows <- list()
qa_rows <- list()
if (file.exists(summary_file)) {
  old <- read.csv(summary_file, stringsAsFactors = FALSE)
  summary_rows <- split(old, as.character(old$year))
}
if (file.exists(qa_file)) {
  old <- read.csv(qa_file, stringsAsFactors = FALSE)
  qa_rows <- split(old, as.character(old$year))
}

for (year in years) {
  tif_path <- file.path(
    out_dir, "rasters",
    sprintf("wild_domesticated_built_%d_%gkm.tif", year, grid_km)
  )
  csv_path <- file.path(
    out_dir, "tables",
    sprintf("wild_domesticated_built_cells_%d_%gkm.csv", year, grid_km)
  )
  # A refinement requested for a year that already has outputs must not be
  # skipped silently: the run would report success while leaving the older,
  # un-refined result on disk, and only the QA flags would betray it.
  requested_refinements <- character(0)
  if (!is.null(lesiv_path) && year == lesiv_year) {
    requested_refinements <- c(requested_refinements, "--lesiv")
  }
  if (!is.null(gpw_manifest) && year %in% gpw_manifest$year) {
    requested_refinements <- c(requested_refinements, "--gpw-manifest")
  }
  if (!is.null(wsf_target) && year == wsf3d_year) {
    requested_refinements <- c(requested_refinements, "--wsf3d")
  }

  if (!overwrite && file.exists(tif_path) && file.exists(csv_path)) {
    # Only refinements the existing outputs do NOT already carry are blocking.
    # The QA row records which ones were applied; without it we cannot tell, so
    # we refuse rather than guess.
    prior <- qa_rows[[as.character(year)]]
    unapplied <- if (is.null(prior)) {
      requested_refinements
    } else {
      applied <- c(
        "--lesiv" = isTRUE(as.logical(prior$lesiv_used[1])),
        "--gpw-manifest" = isTRUE(as.logical(prior$gpw_used[1])),
        "--wsf3d" = isTRUE(as.logical(prior$wsf3d_aux_used[1]))
      )
      requested_refinements[!applied[requested_refinements]]
    }
    if (length(unapplied)) {
      stop(
        "Year ", year, " already has outputs that do not carry ",
        paste(unapplied, collapse = " or "),
        ", which this run requests.\n",
        "  Skipping would keep the un-refined result while reporting success.\n",
        "  Re-run with --overwrite, or drop the refinement flag."
      )
    }
    message("Skipping existing outputs for ", year, " (use --overwrite to replace)")
    next
  }

  message("Processing HILDA ", year)
  hilda <- crop(rast(hilda_path(year)), input_extent, snap = "out")
  lesiv <- if (!is.null(lesiv_path) && year == lesiv_year) {
    crop(rast(lesiv_path), input_extent, snap = "out")
  } else NULL

  composition <- build_hilda_composition(hilda, year, lesiv)
  projected <- project_average(composition$raster, year, "composition")
  names(projected) <- names(composition$raster)

  raw_sum <- sum(projected[[c("wild", "domesticated", "built_up", "unresolved")]])
  raw_sum <- ifel(raw_sum > 0, raw_sum, NA)
  primary <- 100 * projected[[c("wild", "domesticated", "built_up", "unresolved")]] / raw_sum
  names(primary) <- c("pct_wild", "pct_domesticated", "pct_built_up", "pct_unresolved")
  unresolved_forest_pct <- 100 * projected[["unresolved_forest"]] / raw_sum
  names(unresolved_forest_pct) <- "pct_unresolved_forest"

  # NESTED accounting. built_up is a SUBSET of anthropogenic land, not a sibling
  # of it: a city is transformed land par excellence. The flat partition is kept
  # (the methods .docx and the living comment doc cite its columns), and the
  # nested reading is added beside it. Top level: wild + anthropogenic +
  # unresolved = 100 -- an identity by construction, exactly like C0, and not to
  # be reported as a control.
  anthropogenic_pct <- primary[["pct_domesticated"]] + primary[["pct_built_up"]]
  names(anthropogenic_pct) <- "pct_anthropogenic"

  cell_area_m2 <- abs(prod(res(target)))
  land_area_m2 <- raw_sum * cell_area_m2
  names(land_area_m2) <- "land_area_m2"
  areas <- primary / 100 * land_area_m2
  names(areas) <- c(
    "wild_area_m2", "domesticated_area_m2", "built_up_area_m2", "unresolved_area_m2"
  )
  anthropogenic_area <- anthropogenic_pct / 100 * land_area_m2
  names(anthropogenic_area) <- "anthropogenic_area_m2"

  # Hemeroby: per-degree shares, then the area-weighted mean degree.
  hem_names <- sprintf("hemeroby_%d", seq_len(HEMEROBY_MAX))
  hem_pct <- 100 * projected[[hem_names]] / raw_sum
  names(hem_pct) <- sprintf("pct_hemeroby_%d", seq_len(HEMEROBY_MAX))
  hem_coverage <- sum(hem_pct)
  names(hem_coverage) <- "hemeroby_coverage_pct"

  # The mean is over the RESOLVED share only. A cell that is 38 % unresolved
  # (1960, 2019) would otherwise yield a mean computed on 62 % of its area and
  # look comparable to 2015 computed on 95 % -- the very artefact `comparable`
  # was added to flag. Coverage is written beside the mean, and the mean is
  # masked below the threshold.
  weighted <- hem_pct[[1]] * 0
  for (d in seq_len(HEMEROBY_MAX)) weighted <- weighted + d * hem_pct[[d]]
  hem_mean <- ifel(hem_coverage > 0, weighted / hem_coverage, NA)
  hem_mean <- ifel(hem_coverage >= hemeroby_min_coverage, hem_mean, NA)
  names(hem_mean) <- "hemeroby_mean"

  output <- c(primary, anthropogenic_pct, unresolved_forest_pct, land_area_m2,
              areas, anthropogenic_area, hem_pct, hem_coverage, hem_mean)

  gpw_native <- build_gpw_diagnostics(hilda, year)
  gpw_used <- !is.null(gpw_native)
  if (gpw_used) {
    gpw_target <- project_average(gpw_native, year, "gpw")
    gpw_pct <- 100 * gpw_target / raw_sum
    names(gpw_pct) <- paste0("pct_", names(gpw_native))
    output <- c(output, gpw_pct)
  }

  if (!is.null(wsf_target) && year == wsf3d_year) output <- c(output, wsf_target)

  support <- if (composition$lesiv_used && gpw_used) {
    "hilda_lesiv_gpw_snapshot"
  } else if (composition$lesiv_used) {
    "hilda_lesiv_snapshot"
  } else if (gpw_used) {
    "hilda_gpw"
  } else {
    "hilda_only"
  }

  writeRaster(
    output, tif_path, overwrite = TRUE, datatype = "FLT4S",
    gdal = c("COMPRESS=DEFLATE", "PREDICTOR=3", "TILED=YES")
  )

  # na.rm=NA removes rows only when every layer is NA. This preserves a valid
  # primary partition even if an optional auxiliary layer is missing there.
  cells <- as.data.frame(output, xy = TRUE, cells = TRUE, na.rm = NA)
  cells <- cells[!is.na(cells$pct_wild), , drop = FALSE]
  if (!nrow(cells)) {
    stop("No valid HILDA terrestrial cell remains for year ", year,
         "; check --extent and --mask")
  }
  cells$year <- year
  cells$grid_km <- grid_km
  cells$crs <- target_crs
  cells$temporal_support <- support
  write.csv(cells, csv_path, row.names = FALSE)

  area_totals <- vapply(
    c("wild_area_m2", "domesticated_area_m2", "built_up_area_m2", "unresolved_area_m2"),
    function(nm) as.numeric(global(output[[nm]], "sum", na.rm = TRUE)[1, 1]),
    numeric(1)
  )
  total_land <- sum(area_totals)

  # Land area under a usable hemeroby mean, i.e. cells that cleared the coverage
  # threshold. The mean below is over THIS area, not over `total_land`.
  hem_area_kept <- as.numeric(global(
    ifel(is.na(output[["hemeroby_mean"]]), NA, output[["land_area_m2"]]),
    "sum", na.rm = TRUE
  )[1, 1])
  hem_mean_weighted <- if (is.finite(hem_area_kept) && hem_area_kept > 0) {
    as.numeric(global(
      output[["hemeroby_mean"]] * output[["land_area_m2"]], "sum", na.rm = TRUE
    )[1, 1]) / hem_area_kept
  } else NA_real_

  summary_rows[[as.character(year)]] <- data.frame(
    year = year,
    temporal_support = support,
    wild_area_m2 = area_totals[["wild_area_m2"]],
    domesticated_area_m2 = area_totals[["domesticated_area_m2"]],
    built_up_area_m2 = area_totals[["built_up_area_m2"]],
    unresolved_area_m2 = area_totals[["unresolved_area_m2"]],
    pct_wild = 100 * area_totals[["wild_area_m2"]] / total_land,
    pct_domesticated = 100 * area_totals[["domesticated_area_m2"]] / total_land,
    pct_built_up = 100 * area_totals[["built_up_area_m2"]] / total_land,
    pct_unresolved = 100 * area_totals[["unresolved_area_m2"]] / total_land,
    # Nested reading: built-up is part of this, not beside it.
    pct_anthropogenic = 100 *
      (area_totals[["domesticated_area_m2"]] + area_totals[["built_up_area_m2"]]) /
      total_land,
    hemeroby_mean_area_weighted = hem_mean_weighted,
    # The retained share is written NEXT TO the mean, and is not optional
    # reading. The mask protects the map, but the aggregate number would still
    # invite a false comparison without it: on the European run, 2015 retains
    # 99 % of the area while 1960 retains 57 % and 2019 47 %, and the years that
    # lose half their area lose the FORESTED half -- so their mean is taken over
    # agricultural lowlands and reads systematically higher. Comparing those
    # means across years measures coverage, not history.
    hemeroby_area_retained_pct = 100 * hem_area_kept / total_land,
    stringsAsFactors = FALSE
  )

  # --- QA ------------------------------------------------------------------
  # C0 is an IDENTITY, not a control. `unresolved` is defined as the residual
  # `valid - wild - domesticated - built` and the denominator is the sum of the
  # four, so the components sum to 100 by construction. It is kept because it
  # would still catch a float or masking fault, but it cannot fail for any
  # reason that would make the partition wrong, and must not be reported as
  # evidence that the partition is right.
  pct_sum <- sum(primary)
  sum_error <- abs(pct_sum - 100)

  # C1 -- ROUTING. Every code in VALID_HILDA must reach exactly one of built /
  # domesticated / wild / forest. If one does not, it silently lands in the
  # residual and inflates `unresolved`. Before Lesiv, unresolved IS the forest
  # indicator; after Lesiv, unresolved = forest * (1 - classified), which is
  # exactly `unresolved_forest`. So in both cases the two layers must be equal.
  # FAILS if the max absolute gap exceeds ROUTING_TOL percentage points, which
  # happens if and only if a valid class is unrouted.
  routing_gap <- abs(primary[["pct_unresolved"]] - unresolved_forest_pct)
  max_routing_gap <- as.numeric(global(routing_gap, "max", na.rm = TRUE)[1, 1])
  routing_cells_over_noise <- as.numeric(
    global(routing_gap > ROUTING_NOISE_PP, "sum", na.rm = TRUE)[1, 1]
  )

  # C2 -- AREA CLOSURE. Total HILDA land area against the planimetric area of
  # the study polygons in the same equal-area CRS. The ratio must be below 1
  # (HILDA drops inland water, which the polygons include) and close to it. A
  # wrong CRS, a clipped extent or a broken mask moves this far off; the
  # identity above would not notice any of them. Reported, with the reading
  # rule and the observed band recorded in the workflow note.
  area_ratio <- if (!is.null(study_polygon_area_m2)) {
    total_land / study_polygon_area_m2
  } else NA_real_

  # C4 -- DEGREE CLOSURE. Every resolved class must reach exactly one hemeroby
  # degree, so the degree shares must sum to the resolved share, i.e. to
  # 100 - pct_unresolved. FAILS if a class is missing from the degree table
  # (share too low) or appears in two degrees (share too high). Same two-level
  # calibration as C1: float32 noise floor to count, a far higher bar to judge.
  closure_gap <- abs(hem_coverage - (100 - primary[["pct_unresolved"]]))
  max_closure_gap <- as.numeric(global(closure_gap, "max", na.rm = TRUE)[1, 1])
  closure_cells_over_noise <- as.numeric(
    global(closure_gap > ROUTING_NOISE_PP, "sum", na.rm = TRUE)[1, 1]
  )
  if (max_closure_gap > ROUTING_FAIL_PP) {
    warning(sprintf(
      paste0("Year %d FAILS the hemeroby closure control: max gap %.4g pp on %d cell(s).\n",
             "  Degree shares do not sum to the resolved share. Most likely a HILDA or ",
             "Lesiv class is missing from HEMEROBY_HILDA / HEMEROBY_LESIV, or appears in ",
             "two degrees."),
      year, max_closure_gap, closure_cells_over_noise
    ), call. = FALSE)
  }

  qa_rows[[as.character(year)]] <- data.frame(
    year = year,
    temporal_support = support,
    n_output_cells = nrow(cells),
    hemeroby_max_closure_gap_pp = max_closure_gap,
    hemeroby_closure_cells_over_noise = closure_cells_over_noise,
    hemeroby_closure_ok = isTRUE(max_closure_gap <= ROUTING_FAIL_PP),
    hemeroby_min_coverage_pct = hemeroby_min_coverage,
    identity_max_abs_sum_error_pct = as.numeric(global(sum_error, "max", na.rm = TRUE)[1, 1]),
    identity_mean_abs_sum_error_pct = as.numeric(global(sum_error, "mean", na.rm = TRUE)[1, 1]),
    routing_max_gap_pp = max_routing_gap,
    routing_cells_over_noise = routing_cells_over_noise,
    routing_ok = isTRUE(max_routing_gap <= ROUTING_FAIL_PP),
    land_area_m2 = total_land,
    study_polygon_area_m2 = if (is.null(study_polygon_area_m2)) NA_real_ else study_polygon_area_m2,
    land_over_polygon_ratio = area_ratio,
    min_component_pct = min(unlist(global(primary, "min", na.rm = TRUE)), na.rm = TRUE),
    max_component_pct = max(unlist(global(primary, "max", na.rm = TRUE)), na.rm = TRUE),
    lesiv_used = composition$lesiv_used,
    gpw_used = gpw_used,
    wsf3d_aux_used = !is.null(wsf_target) && year == wsf3d_year,
    stringsAsFactors = FALSE
  )

  if (max_routing_gap > ROUTING_FAIL_PP) {
    # State the observation, not a cause. An unrouted VALID_HILDA class is the
    # fault this control was built for (25.4 pp in the test suite), but it is
    # not the only thing that can open a gap: a residue of ~0.05 pp on a
    # handful of cells has been seen on the European 2015 run with Lesiv and
    # is NOT explained. Naming the cause here would assert what has not been
    # established. See "Limites connues" in the workflow note.
    warning(sprintf(
      paste0("Year %d FAILS the routing control: max gap %.4g pp between pct_unresolved ",
             "and pct_unresolved_forest, on %d cell(s) above float32 noise.\n",
             "  Cause NOT established by this run. Candidates: an unrouted code in ",
             "VALID_HILDA (large, percent-level gaps), or the unexplained sub-0.1 pp ",
             "residue documented in the workflow note."),
      year, max_routing_gap, routing_cells_over_noise
    ), call. = FALSE)
  } else if (routing_cells_over_noise > 0) {
    message(sprintf(
      "  Routing: %d cell(s) above float32 noise, max %.2e pp (verdict threshold %.0e pp)",
      routing_cells_over_noise, max_routing_gap, ROUTING_FAIL_PP
    ))
  }

  message("  Wrote ", tif_path)
  message("  Wrote ", csv_path)
  rm(hilda, lesiv, composition, projected, raw_sum, primary, output, cells)
  gc()
}

# Rows carried over from an earlier run can predate a QA column. Union the
# columns and leave the missing ones NA rather than failing on rbind or, worse,
# dropping the year: an NA reads as "this control did not exist yet", which is
# what actually happened.
bind_rows_align <- function(rows) {
  rows <- Filter(function(x) !is.null(x) && nrow(x) > 0, rows)
  if (!length(rows)) return(NULL)
  all_cols <- unique(unlist(lapply(rows, names)))
  rows <- lapply(rows, function(df) {
    for (nm in setdiff(all_cols, names(df))) df[[nm]] <- NA
    df[, all_cols, drop = FALSE]
  })
  do.call(rbind, rows)
}

if (length(summary_rows)) {
  summary_table <- bind_rows_align(summary_rows)
  qa_table <- bind_rows_align(qa_rows)
  summary_table <- summary_table[order(summary_table$year), , drop = FALSE]
  qa_table <- qa_table[order(qa_table$year), , drop = FALSE]
  write.csv(summary_table, summary_file, row.names = FALSE)
  write.csv(qa_table, qa_file, row.names = FALSE)
  if (nrow(summary_table) > 1L) {
    pct_names <- c("pct_wild", "pct_domesticated", "pct_built_up", "pct_unresolved")
    from_support <- head(summary_table$temporal_support, -1)
    to_support <- tail(summary_table$temporal_support, -1)
    changes <- data.frame(
      from_year = head(summary_table$year, -1),
      to_year = tail(summary_table$year, -1),
      years_elapsed = diff(summary_table$year),
      from_support = from_support,
      to_support = to_support,
      # A delta between two years built from DIFFERENT sources is a change of
      # method, not a change on the ground. With Lesiv applied to 2015 only,
      # every delta touching 2015 moves forest out of `unresolved` for that
      # reason alone. Flag it here rather than leaving the reader to notice.
      comparable = from_support == to_support,
      stringsAsFactors = FALSE
    )

    # `comparable` is about the SOURCE. Hemeroby needs a second, stricter test:
    # two years can share a source and still be incomparable on this measure,
    # because the mean is taken only over cells that cleared the coverage
    # threshold, and the years that lose area lose the forested part of it.
    # 1960 and 2019 are both hilda_only, yet they retain 57 % and 47 % of the
    # area -- both biased towards agricultural lowlands, and not by the same
    # amount. HEMEROBY_COMPARABLE_PCT is a stated choice, not a measured value.
    HEMEROBY_COMPARABLE_PCT <- 95
    ret <- summary_table$hemeroby_area_retained_pct
    changes$from_hemeroby_retained_pct <- head(ret, -1)
    changes$to_hemeroby_retained_pct <- tail(ret, -1)
    changes$hemeroby_comparable <-
      changes$comparable &
      !is.na(changes$from_hemeroby_retained_pct) &
      !is.na(changes$to_hemeroby_retained_pct) &
      changes$from_hemeroby_retained_pct >= HEMEROBY_COMPARABLE_PCT &
      changes$to_hemeroby_retained_pct >= HEMEROBY_COMPARABLE_PCT
    if (any(!changes$hemeroby_comparable)) {
      warning(sprintf(
        paste0("%d of %d trajectory rows are NOT comparable on hemeroby (source change, ",
               "or retained area below %d%%). Their hemeroby difference measures ",
               "coverage, not land use."),
        sum(!changes$hemeroby_comparable), nrow(changes), HEMEROBY_COMPARABLE_PCT
      ), call. = FALSE)
    }
    for (nm in pct_names) {
      delta <- diff(summary_table[[nm]])
      changes[[paste0("delta_", nm, "_pp")]] <- delta
      # Rows can span 55 years or 4. Raw pp are not comparable between rows.
      changes[[paste0("rate_", nm, "_pp_per_decade")]] <- 10 * delta / changes$years_elapsed
    }
    if (any(!changes$comparable)) {
      warning(sprintf(
        paste0("%d of %d trajectory rows compare years with different temporal_support; ",
               "they are flagged comparable=FALSE and are not land-change measurements."),
        sum(!changes$comparable), nrow(changes)
      ), call. = FALSE)
    }
    write.csv(
      changes,
      file.path(out_dir, "tables", sprintf("trajectory_changes_%gkm.csv", grid_km)),
      row.names = FALSE
    )
  }
}

config <- data.frame(
  parameter = c(
    "created_utc", "years", "grid_km", "analysis_km", "target_crs", "extent_wgs84", "mask",
    "hilda_dir", "lesiv_path", "lesiv_year", "gpw_manifest", "wsf3d_path",
    "wsf3d_year", "water_rule", "population_proxy",
    "hemeroby_scale", "hemeroby_min_coverage_pct", "hemeroby_urban_degree"
  ),
  value = c(
    format(Sys.time(), tz = "UTC", usetz = TRUE), paste(years, collapse = ","),
    grid_km, analysis_km, target_crs, paste(extent_wgs, collapse = ","), mask_mode,
    hilda_dir, ifelse(is.null(lesiv_path), "", lesiv_path), lesiv_year,
    ifelse(is.null(gpw_manifest_path), "", gpw_manifest_path),
    ifelse(is.null(wsf3d_path), "", wsf3d_path), wsf3d_year,
    "HILDA 77 inland water excluded from terrestrial denominator",
    "none",
    sprintf("ordinal 1-%d (7th degree not assigned: no justified WSF3D threshold)",
            HEMEROBY_MAX),
    hemeroby_min_coverage,
    HEMEROBY_MAX
  ),
  stringsAsFactors = FALSE
)
write.csv(config, file.path(out_dir, "tables", "run_config.csv"), row.names = FALSE)

message("Workflow complete: ", out_dir)
