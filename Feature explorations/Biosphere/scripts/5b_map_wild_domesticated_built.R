# =============================================================================
# 5b_map_wild_domesticated_built.R
# Render comparable PNG maps from the annual wild/domesticated/built GeoTIFFs.
# =============================================================================

suppressPackageStartupMessages({
  library(terra)
  library(sf)
  library(ggplot2)
  library(ragg)
  library(patchwork)
})

args <- commandArgs(trailingOnly = TRUE)
get_opt <- function(key, default = NULL) {
  prefix <- paste0("--", key, "=")
  hit <- args[startsWith(args, prefix)]
  if (!length(hit)) return(default)
  sub(prefix, "", hit[[length(hit)]], fixed = TRUE)
}

script_arg <- commandArgs(FALSE)
script_arg <- script_arg[startsWith(script_arg, "--file=")]
if (length(script_arg)) {
  script_file <- normalizePath(sub("^--file=", "", script_arg[[1]]), mustWork = TRUE)
  root <- normalizePath(file.path(dirname(script_file), "../../.."), mustWork = TRUE)
} else {
  root <- normalizePath(getwd(), mustWork = TRUE)
}

parse_years <- function(x) {
  years <- suppressWarnings(as.integer(trimws(strsplit(x, ",", fixed = TRUE)[[1]])))
  if (!length(years) || anyNA(years)) stop("Invalid --years=", x)
  unique(years)
}

years <- parse_years(get_opt("years", "1960,2015,2019"))
grid_km <- as.numeric(get_opt("grid-km", "10"))
if (!is.finite(grid_km) || grid_km <= 0) stop("--grid-km must be positive")

# --dir renders a run written elsewhere. The global run MUST NOT share an output
# directory with the European one: the file names carry only year and grid size,
# so a global run in the default folder would overwrite the European tables the
# method deck reads its numbers from.
base_dir <- get_opt("dir", file.path(
  root, "Feature explorations", "Biosphere", "data_processed",
  "wild_domesticated_built"
))
if (!dir.exists(base_dir)) stop("No such directory: ", base_dir)
raster_dir <- file.path(base_dir, "rasters")
map_dir <- file.path(base_dir, "maps")
dir.create(map_dir, recursive = TRUE, showWarnings = FALSE)

raster_paths <- setNames(
  file.path(
    raster_dir,
    sprintf("wild_domesticated_built_%d_%gkm.tif", years, grid_km)
  ),
  years
)
missing <- raster_paths[!file.exists(raster_paths)]
if (length(missing)) stop("Missing annual raster(s):\n  ", paste(missing, collapse = "\n  "))

rasters <- lapply(raster_paths, rast)
reference <- rasters[[1]]
if (!all(vapply(rasters[-1], compareGeom, logical(1), reference))) {
  stop("Annual rasters do not share the same grid")
}

study_codes <- c(
  "AT", "BE", "BG", "HR", "CY", "CZ", "DK", "EE", "FI", "FR", "DE", "EL",
  "HU", "IE", "IT", "LV", "LT", "LU", "MT", "NL", "PL", "PT", "RO", "SK",
  "SI", "ES", "SE", "UK", "IS", "LI", "NO", "CH"
)
border_path <- file.path(root, "Feature explorations", "_shared", "CNTR_RG_10M_2024_4326.geojson")
# SCOPE IS READ FROM THE RASTER, NOT PASSED IN. ETRS89-LAEA is defined for
# Europe only, so a raster in any other CRS is a global run. Deriving it means a
# global map can never be captioned as EPSG:3035, and a Europe/global mismatch
# cannot be introduced by forgetting a flag.
crs_code <- tryCatch(crs(reference, describe = TRUE)$code,
                     error = function(e) NA_character_)
is_europe <- identical(as.character(crs_code), "3035")

borders <- st_read(border_path, quiet = TRUE)
if (is_europe) {
  borders <- borders[borders$CNTR_ID %in% study_codes, ]
} else {
  # Split polygons that straddle 180 deg before projecting. Without this,
  # Chukotka and Fiji reproject into horizontal streaks across the whole map.
  borders <- suppressWarnings(st_wrap_dateline(borders))
}
borders <- st_transform(st_make_valid(borders), st_crs(crs(reference)))

map_extent <- ext(reference)
x_limits <- c(map_extent$xmin, map_extent$xmax)
y_limits <- c(map_extent$ymin, map_extent$ymax)

# --- Colour ------------------------------------------------------------------
# The four components are shares of ONE partition summing to 100 %. Hue carries
# WHICH component (nominal); lightness carries HOW MUCH (ordered). That is the
# standard pairing of visual variable to data type, and it is what the previous
# version got wrong: it used hcl.colors(), whose sequential ramps run DARK to
# LIGHT, so 0 % wild rendered as saturated dark green and 100 % as near-white --
# the map read as the exact inverse of its own data.
#
# Ramps are ColorBrewer sequential, light -> dark, each a single hue family, so
# every panel degrades correctly to greyscale (lightness alone is monotonic).
# The pale end is deliberately NOT white: it must stay distinguishable from the
# no-data grey below.
component_info <- data.frame(
  key = c("pct_wild", "pct_domesticated", "pct_built_up", "pct_unresolved"),
  # "Domesticated" alone was the visible half of a structural error: built-up
  # is a subset of anthropogenic land, not its sibling, so this share is the
  # NON-BUILT part of it and the label has to say so.
  label = c("Wild", "Domesticated (non-built)", "Built-up / urban", "Unresolved"),
  brewer = c("Greens", "YlOrBr", "RdPu", "Greys"),
  stringsAsFactors = FALSE
)

# No-data must not be confusable with "0 %". Land inside the study countries
# without a value is mid-grey; sea and everything outside is a cool near-white
# panel ground. Both differ from the pale end of every ramp.
COL_NODATA_LAND <- "#C8C8C8"
COL_SEA <- "#F2F5F7"
COL_BORDER <- "grey30"

# Panels built from different sources must say so ON the figure. With Lesiv
# applied to 2015 alone, `unresolved` reads 31.8 / 4.7 / 38.2 % across
# 1960 / 2015 / 2019 -- a collapse and a rebound that never happened on the
# ground. A reader holding only the PNG has no other way to know.
SUPPORT_LABELS <- c(
  hilda_only = "HILDA only",
  hilda_gpw = "HILDA + GPW",
  hilda_lesiv_snapshot = "HILDA + Lesiv",
  hilda_lesiv_gpw_snapshot = "HILDA + Lesiv + GPW"
)

summary_path <- file.path(
  base_dir, "tables", sprintf("trajectory_summary_%gkm.csv", grid_km)
)
year_support <- setNames(rep(NA_character_, length(years)), as.character(years))
if (file.exists(summary_path)) {
  s <- read.csv(summary_path, stringsAsFactors = FALSE)
  hit <- match(years, s$year)
  year_support[] <- s$temporal_support[hit]
} else {
  warning("No trajectory summary found; panels cannot be labelled with their source.",
          call. = FALSE)
}
support_pretty <- ifelse(
  is.na(year_support), "source unknown",
  ifelse(year_support %in% names(SUPPORT_LABELS),
         SUPPORT_LABELS[year_support], year_support)
)
year_labels <- sprintf("%d\n(%s)", years, support_pretty)
mixed_support <- length(unique(na.omit(year_support))) > 1L
if (mixed_support) {
  message("Panels mix temporal support: ",
          paste(sprintf("%d=%s", years, year_support), collapse = ", "))
}

has_lesiv <- grepl("lesiv", year_support, fixed = TRUE) & !is.na(year_support)
forest_note <- if (all(has_lesiv)) {
  "Forest split into managed/unmanaged with Lesiv 2015."
} else if (any(has_lesiv)) {
  paste0("Forest is split with Lesiv 2015 only in the panel whose label says so; ",
         "elsewhere it stays unresolved.")
} else {
  "Forest remains unresolved without the Lesiv 2015 layer."
}
mixed_note <- if (mixed_support) {
  paste0("CAUTION: panels do not share a source. Differences between panels mix ",
         "land-use change with the change of method.")
} else NULL

# Captions are laid out as SHORT lines. A single long line is silently clipped
# at the plot edge by ggplot, which loses exactly the warning it was meant to
# carry -- the first version of this caption lost its CAUTION that way.
#
# A scientific map's caption must let a reader judge provenance, vintage and
# geometry without external context: source, reference period, projection,
# boundary source, and how no-data is shown.
PROVENANCE <- paste0(
  "Sources: HILDA+ v2.0 land-use states (PANGAEA 10.1594/PANGAEA.974335)",
  # Citing a source no panel actually used is a provenance error, not a detail:
  # it invites a reader to attribute the forest split to a plate that has none.
  if (any(year_support != "hilda_only")) paste0(
    "; forest management from Lesiv et al. 2022 ",
    "(Zenodo 5879022, reference year 2015)") else "",
  ". Boundaries: Eurostat GISCO CNTR_RG_10M_2024. Retrieved 2026-08-26."
)
CRS_LABEL <- if (is_europe) "ETRS89-LAEA (EPSG:3035)" else "Eckert IV (ESRI:54012)"
GEOMETRY <- paste0(
  "Equal-area projection ", CRS_LABEL, ", ", grid_km, " km cells. ",
  "Grey = land with no value; percentages are of valid terrestrial area, ",
  "inland water excluded."
)
# Wrap rather than hand-count. ggplot clips a caption line at the panel edge
# without warning, and the clipped tail is silently lost -- twice already here,
# once losing the CAUTION and once losing the retrieval date. strwrap makes the
# limit structural instead of a thing to remember.
CAPTION_WIDTH <- 130
wrap_caption <- function(parts) {
  wrapped <- unlist(lapply(parts, function(x) strwrap(x, width = CAPTION_WIDTH)))
  paste(wrapped, collapse = "\n")
}

# For figures whose panels DO share a source. The 1960-2019 change map compares
# two hilda_only years, so attaching the mixed-source CAUTION there would warn
# against a problem that figure does not have -- a false warning costs as much
# credibility as a missing one.
caption_plain <- function(first) wrap_caption(c(first, PROVENANCE, GEOMETRY))

caption_lines <- function(first) {
  wrap_caption(c(first, forest_note, mixed_note, PROVENANCE, GEOMETRY))
}

component_data <- list()
for (i in seq_len(nrow(component_info))) {
  key <- component_info$key[i]
  frames <- lapply(seq_along(rasters), function(j) {
    if (!key %in% names(rasters[[j]])) stop("Layer missing: ", key, " in ", raster_paths[j])
    d <- as.data.frame(rasters[[j]][[key]], xy = TRUE, na.rm = TRUE)
    names(d)[3] <- "value"
    d$year <- factor(year_labels[j], levels = year_labels)
    d$component <- component_info$label[i]
    d
  })
  component_data[[key]] <- do.call(rbind, frames)
}

# Light -> dark, single hue family. brewer.pal returns light-to-dark already;
# the first stop is dropped so the pale end keeps a visible tint and cannot be
# mistaken for the no-data grey underneath.
percent_scale <- function(brewer_name) {
  stops <- RColorBrewer::brewer.pal(9, brewer_name)[2:9]
  scale_fill_gradientn(
    colours = grDevices::colorRampPalette(stops)(101),
    limits = c(0, 100),
    breaks = c(0, 25, 50, 75, 100),
    labels = function(x) paste0(x, "%"),
    oob = scales::squish, na.value = NA
  )
}

map_theme <- theme_void(base_size = 11) +
  theme(
    plot.title = element_text(face = "bold", size = 15, margin = margin(b = 3)),
    plot.subtitle = element_text(size = 10, colour = "grey30", margin = margin(b = 7)),
    plot.caption = element_text(size = 8, colour = "grey35", hjust = 0, margin = margin(t = 6)),
    strip.text = element_text(face = "bold", size = 11, margin = margin(4, 4, 5, 4)),
    panel.spacing = unit(3, "mm"),
    panel.background = element_rect(fill = COL_SEA, colour = NA),
    legend.position = "right",
    legend.title = element_text(size = 9),
    legend.text = element_text(size = 8),
    plot.margin = margin(8, 8, 8, 8)
  )

make_component_plot <- function(i, compact = FALSE) {
  key <- component_info$key[i]
  label <- component_info$label[i]
  p <- ggplot(component_data[[key]], aes(x = x, y = y, fill = value)) +
    # Study land drawn UNDER the tiles: any country area the raster does not
    # cover shows as no-data grey instead of borrowing the sea colour, so a
    # gap in coverage cannot be misread as 0 %.
    geom_sf(
      data = borders, inherit.aes = FALSE,
      fill = COL_NODATA_LAND, colour = NA
    ) +
    geom_tile(width = grid_km * 1000, height = grid_km * 1000) +
    geom_sf(data = borders, inherit.aes = FALSE, fill = NA,
            colour = COL_BORDER, linewidth = 0.12) +
    facet_wrap(~year, nrow = 1) +
    coord_sf(
      crs = st_crs(borders), xlim = x_limits, ylim = y_limits,
      expand = FALSE, datum = NA
    ) +
    percent_scale(component_info$brewer[i]) +
    # A thematic map a reader cannot measure is not publication-grade. No north
    # arrow: over this LAEA extent north is not uniformly up, so an arrow would
    # be wrong everywhere except the central meridian.
    # Only on the standalone plates -- on the 4-row composite this would repeat
    # twelve times and become noise.
    (if (compact || !is_europe) NULL else ggspatial::annotation_scale(
      location = "bl", width_hint = 0.28, height = unit(1.4, "mm"),
      text_cex = 0.55, line_width = 0.4, pad_x = unit(1.5, "mm"),
      pad_y = unit(1.5, "mm"), bar_cols = c("grey20", "white")
    )) +
    labs(
      title = if (compact) label else paste0(label, " fraction"),
      subtitle = if (compact) NULL else "Share of valid terrestrial area in each 10 km cell",
      fill = "% of cell",
      caption = if (compact) NULL else caption_lines(
        "Share of valid terrestrial area per cell; the four components sum to 100%."
      )
    ) +
    map_theme
  p
}

map_records <- list()
for (i in seq_len(nrow(component_info))) {
  key <- component_info$key[i]
  out <- file.path(map_dir, sprintf("%s_%s_%gkm.png", key, paste(years, collapse = "_"), grid_km))
  plot <- make_component_plot(i, compact = FALSE)
  ggsave(
    out, plot = plot, device = ragg::agg_png,
    width = 12.5, height = 5.4, units = "in", dpi = 260, bg = "white"
  )
  map_records[[length(map_records) + 1L]] <- data.frame(
    file = basename(out), description = paste(component_info$label[i], "trajectory"),
    stringsAsFactors = FALSE
  )
  message("Wrote ", out)
}

combined <- wrap_plots(
  lapply(seq_len(nrow(component_info)), make_component_plot, compact = TRUE),
  ncol = 1
) +
  plot_annotation(
    title = paste0("SPACE: land-area composition across ",
                   if (is_europe) "Europe" else "the world"),
    subtitle = "HILDA+ v2.0 aggregated to equal-area 10 km cells",
    caption = caption_lines(
      "Wild + domesticated + built-up + unresolved = 100% of valid terrestrial area."
    ),
    theme = theme(
      plot.title = element_text(face = "bold", size = 18),
      plot.subtitle = element_text(size = 11, colour = "grey30"),
      plot.caption = element_text(size = 9, colour = "grey35", hjust = 0)
    )
  )

combined_path <- file.path(
  map_dir,
  sprintf("space_composition_%s_%gkm.png", paste(years, collapse = "_"), grid_km)
)
ggsave(
  combined_path, plot = combined, device = ragg::agg_png,
  width = 13.2, height = 17.2, units = "in", dpi = 240, bg = "white"
)
map_records[[length(map_records) + 1L]] <- data.frame(
  file = basename(combined_path), description = "Four-component comparison",
  stringsAsFactors = FALSE
)
message("Wrote ", combined_path)

if (all(c(1960, 2019) %in% years)) {
  i0 <- match(1960, years)
  i1 <- match(2019, years)
  delta_frames <- lapply(seq_len(nrow(component_info)), function(i) {
    key <- component_info$key[i]
    delta <- rasters[[i1]][[key]] - rasters[[i0]][[key]]
    d <- as.data.frame(delta, xy = TRUE, na.rm = TRUE)
    names(d)[3] <- "delta"
    d$component <- factor(component_info$label[i], levels = component_info$label)
    d
  })
  delta_data <- do.call(rbind, delta_frames)
  robust_limit <- as.numeric(quantile(abs(delta_data$delta), 0.98, na.rm = TRUE))
  robust_limit <- min(100, max(5, ceiling(robust_limit / 5) * 5))
  delta_plot <- ggplot(delta_data, aes(x = x, y = y, fill = delta)) +
    geom_sf(data = borders, inherit.aes = FALSE, fill = COL_NODATA_LAND, colour = NA) +
    geom_tile(width = grid_km * 1000, height = grid_km * 1000) +
    geom_sf(data = borders, inherit.aes = FALSE, fill = NA,
            colour = COL_BORDER, linewidth = 0.12) +
    facet_wrap(~component, ncol = 2) +
    coord_sf(
      crs = st_crs(borders), xlim = x_limits, ylim = y_limits,
      expand = FALSE, datum = NA
    ) +
    scale_fill_gradient2(
      low = hcl.colors(3, "Blue-Red 3")[1], mid = "white",
      high = hcl.colors(3, "Blue-Red 3")[3], midpoint = 0,
      limits = c(-robust_limit, robust_limit), oob = scales::squish,
      breaks = pretty(c(-robust_limit, robust_limit), n = 5),
      labels = function(x) paste0(ifelse(x > 0, "+", ""), x, " pp")
    ) +
    labs(
      title = "Change in land-area composition, 1960-2019",
      subtitle = "Difference in percentage points for each 10 km cell",
      fill = "Change",
      caption = caption_plain(paste0(
        "Both years use HILDA alone, so this comparison carries none of the source ",
        "change that affects 2015. Scale saturated at +/-", robust_limit,
        " pp (98th percentile of absolute cell-level changes)."
      ))
    ) +
    map_theme
  delta_path <- file.path(map_dir, sprintf("space_change_1960_2019_%gkm.png", grid_km))
  ggsave(
    delta_path, plot = delta_plot, device = ragg::agg_png,
    width = 12.2, height = 9.5, units = "in", dpi = 260, bg = "white"
  )
  map_records[[length(map_records) + 1L]] <- data.frame(
    file = basename(delta_path), description = "Cell-level change, 1960 to 2019",
    stringsAsFactors = FALSE
  )
  message("Wrote ", delta_path)
}

# Minimum share of the mapped land that the auxiliary layer must cover for the
# comparison plate to be drawn at all. Not a scientific threshold -- a legibility
# one, and it exists because of a defect this plate actually produced.
#
# WHAT WENT WRONG. The global run picked up the default WSF3D file, which covers
# EUROPE ONLY. The plate rendered a world map whose right-hand panel was grey
# everywhere outside Europe, under a caption asserting that "HILDA must exceed
# WSF3D everywhere". Absence of measurement renders identically to a measured
# zero, so the figure invited the reading that the rest of the world has no
# buildings. A caption cannot fix that: the misreading happens in the eye before
# anyone reaches the caption.
#
# So the plate is skipped when the auxiliary does not cover the extent, and the
# measured coverage is printed either way -- refusing to draw is the fix, saying
# why is the courtesy.
WSF3D_MIN_COVERAGE_PCT <- 95

if (2015 %in% years) {
  r2015 <- rasters[[match(2015, years)]]
  aux_coverage_pct <- NA_real_
  if ("pct_built_wsf3d_aux" %in% names(r2015)) {
    mapped <- global(!is.na(r2015[["pct_built_up"]]), "sum", na.rm = TRUE)[[1]]
    covered <- global(!is.na(r2015[["pct_built_wsf3d_aux"]]), "sum", na.rm = TRUE)[[1]]
    aux_coverage_pct <- if (isTRUE(mapped > 0)) 100 * covered / mapped else 0
  }
  if ("pct_built_wsf3d_aux" %in% names(r2015) &&
      aux_coverage_pct < WSF3D_MIN_COVERAGE_PCT) {
    message(sprintf(
      paste0("Skipping the HILDA/WSF3D comparison: the auxiliary layer covers ",
             "%.1f%% of the mapped land, below the %g%% needed for the plate to ",
             "be readable. Outside its extent, no measurement would render the ",
             "same as a measured zero."),
      aux_coverage_pct, WSF3D_MIN_COVERAGE_PCT))
  } else if ("pct_built_wsf3d_aux" %in% names(r2015)) {
    comparison_layers <- c("pct_built_up", "pct_built_wsf3d_aux")
    comparison_labels <- c(
      "HILDA urban-class share", "WSF3D physical building-footprint share"
    )
    built_frames <- lapply(seq_along(comparison_layers), function(i) {
      d <- as.data.frame(r2015[[comparison_layers[i]]], xy = TRUE, na.rm = TRUE)
      names(d)[3] <- "value"
      d$measure <- factor(comparison_labels[i], levels = comparison_labels)
      d
    })
    built_data <- do.call(rbind, built_frames)
    built_plot <- ggplot(built_data, aes(x = x, y = y, fill = value)) +
      geom_sf(data = borders, inherit.aes = FALSE, fill = COL_NODATA_LAND, colour = NA) +
      geom_tile(width = grid_km * 1000, height = grid_km * 1000) +
      geom_sf(data = borders, inherit.aes = FALSE, fill = NA,
              colour = COL_BORDER, linewidth = 0.12) +
      facet_wrap(~measure, nrow = 1) +
      coord_sf(
        crs = st_crs(borders), xlim = x_limits, ylim = y_limits,
        expand = FALSE, datum = NA
      ) +
      percent_scale("RdPu") +
      labs(
        title = "Two non-interchangeable measures of built-up area, 2015",
        subtitle = "Categorical urban land versus physical building footprint",
        fill = "% of cell",
        caption = caption_plain(paste0(
          "WSF3D is auxiliary and is not added to the HILDA partition. Both use the ",
          "same 0-100% scale but measure different things: HILDA urban covers the whole ",
          "urban footprint, WSF3D only building footprints, so HILDA must exceed WSF3D ",
          "everywhere. The gap is the informative quantity, not the disagreement.",
          sprintf(" WSF3D covers %.1f%% of the land mapped here.", aux_coverage_pct)
        ))
      ) +
      map_theme
    built_path <- file.path(map_dir, sprintf("built_up_hilda_vs_wsf3d_2015_%gkm.png", grid_km))
    ggsave(
      built_path, plot = built_plot, device = ragg::agg_png,
      width = 11.5, height = 5.6, units = "in", dpi = 260, bg = "white"
    )
    map_records[[length(map_records) + 1L]] <- data.frame(
      file = basename(built_path), description = "HILDA versus WSF3D built-up comparison",
      stringsAsFactors = FALSE
    )
    message("Wrote ", built_path)
  }
}

# --- Anthropogenic land ------------------------------------------------------
# pct_anthropogenic = domesticated + built_up. It is the FIRST level of the
# nested accounting and the number a reader usually wants first ("how much of
# this place have people worked?"). It was computed and written into the raster
# in the nested-accounting pass, but never rendered -- so the method deck could
# show the stacked bar and no map. This closes that gap.
#
# Deliberately NOT added to component_info. That table drives the composite
# plate, whose four panels are a partition summing to 100 %. Anthropogenic is
# the SUM of two of them, so putting it there would draw the same land twice and
# the plate would no longer close.
if ("pct_anthropogenic" %in% names(rasters[[1]])) {
  anth_frames <- lapply(seq_along(rasters), function(j) {
    d <- as.data.frame(rasters[[j]][["pct_anthropogenic"]], xy = TRUE, na.rm = TRUE)
    names(d)[3] <- "value"
    d$year <- factor(year_labels[j], levels = year_labels)
    d
  })
  anth_data <- do.call(rbind, anth_frames)

  anth_plot <- ggplot(anth_data, aes(x = x, y = y, fill = value)) +
    geom_sf(data = borders, inherit.aes = FALSE, fill = COL_NODATA_LAND, colour = NA) +
    geom_tile(width = grid_km * 1000, height = grid_km * 1000) +
    geom_sf(data = borders, inherit.aes = FALSE, fill = NA,
            colour = COL_BORDER, linewidth = 0.12) +
    facet_wrap(~year, nrow = 1) +
    coord_sf(
      crs = st_crs(borders), xlim = x_limits, ylim = y_limits,
      expand = FALSE, datum = NA
    ) +
    (if (!is_europe) NULL else ggspatial::annotation_scale(
      location = "bl", width_hint = 0.28, height = unit(1.4, "mm"),
      text_cex = 0.55, line_width = 0.4, pad_x = unit(1.5, "mm"),
      pad_y = unit(1.5, "mm"), bar_cols = c("grey20", "white")
    )) +
    # Oranges, not the YlOrBr of "Domesticated (non-built)": the parent category
    # must not be mistaken for its own larger child. Warm, against the Greens of
    # wild -- on resolved land this map is very nearly its complement.
    percent_scale("Oranges") +
    labs(
      title = "Anthropogenic land: domesticated plus built",
      subtitle = paste0("Share of valid terrestrial area in each ", grid_km, " km cell"),
      fill = "% of cell",
      caption = caption_lines(paste0(
        "First level of the nested accounting: wild + anthropogenic + unresolved = 100 %. ",
        "A city is transformed land, so built-up is counted INSIDE this share and not ",
        "beside it -- read alone, the non-built domesticated figure understates ",
        "transformation. This is NOT 100 % minus wild: unresolved forest is in neither, ",
        "which is why the two maps do not mirror each other where forest is unresolved."
      ))
    ) +
    map_theme
  anth_path <- file.path(
    map_dir,
    sprintf("pct_anthropogenic_%s_%gkm.png", paste(years, collapse = "_"), grid_km)
  )
  ggsave(
    anth_path, plot = anth_plot, device = ragg::agg_png,
    width = 12.5, height = 5.6, units = "in", dpi = 260, bg = "white"
  )
  map_records[[length(map_records) + 1L]] <- data.frame(
    file = basename(anth_path),
    description = "Anthropogenic share (domesticated + built-up)",
    stringsAsFactors = FALSE
  )
  message("Wrote ", anth_path)
} else {
  message("No pct_anthropogenic layer in the rasters; skipping. ",
          "Re-run 5_build_wild_domesticated_built.R to produce it.")
}

# --- Hemeroby gradient -------------------------------------------------------
# The point of the whole exercise: wild -> domesticated -> urban as ONE
# continuum rather than three boxes. Light = close to natural, dark = heavily
# transformed. YlOrRd is monotonic in lightness, so it survives greyscale, and
# it carries the red-means-transformed reading without depending on hue for the
# ordering (which is what red-green colour blindness would break).
if ("hemeroby_mean" %in% names(rasters[[1]])) {
  hem_frames <- lapply(seq_along(rasters), function(j) {
    d <- as.data.frame(rasters[[j]][["hemeroby_mean"]], xy = TRUE, na.rm = TRUE)
    names(d)[3] <- "value"
    d$year <- factor(year_labels[j], levels = year_labels)
    d
  })
  hem_data <- do.call(rbind, hem_frames)

  degree_labels <- c(
    "1 natural", "2 close to natural", "3 managed",
    "4 grazed", "5 cultivated", "6 built"
  )

  hem_plot <- ggplot(hem_data, aes(x = x, y = y, fill = value)) +
    geom_sf(data = borders, inherit.aes = FALSE, fill = COL_NODATA_LAND, colour = NA) +
    geom_tile(width = grid_km * 1000, height = grid_km * 1000) +
    geom_sf(data = borders, inherit.aes = FALSE, fill = NA,
            colour = COL_BORDER, linewidth = 0.12) +
    facet_wrap(~year, nrow = 1) +
    coord_sf(
      crs = st_crs(borders), xlim = x_limits, ylim = y_limits,
      expand = FALSE, datum = NA
    ) +
    (if (!is_europe) NULL else ggspatial::annotation_scale(
      location = "bl", width_hint = 0.28, height = unit(1.4, "mm"),
      text_cex = 0.55, line_width = 0.4, pad_x = unit(1.5, "mm"),
      pad_y = unit(1.5, "mm"), bar_cols = c("grey20", "white")
    )) +
    scale_fill_gradientn(
      colours = grDevices::colorRampPalette(
        RColorBrewer::brewer.pal(9, "YlOrRd")[2:9]
      )(101),
      limits = c(1, 6), breaks = 1:6, labels = degree_labels,
      oob = scales::squish, na.value = NA
    ) +
    labs(
      title = "Hemeroby: the wild-to-urban gradient",
      subtitle = "Area-weighted mean degree of human transformation per 10 km cell",
      fill = "Degree",
      caption = caption_lines(paste0(
        "Ordinal scale 1-6. The mean treats ordinal degrees as an interval, as the ",
        "landscape-indicator literature does; it is a summary, not a measurement. ",
        "Grey = below the coverage threshold, where too much of the cell is ",
        "unresolved forest for a mean to be comparable. Built-up sits at the top of ",
        "the scale, not beside it. Degree 7 (sealed surface) is not assigned: it would ",
        "need a WSF3D building-fraction threshold that has no justified value yet."
      ))
    ) +
    map_theme
  hem_path <- file.path(
    map_dir, sprintf("hemeroby_gradient_%s_%gkm.png", paste(years, collapse = "_"), grid_km)
  )
  ggsave(
    hem_path, plot = hem_plot, device = ragg::agg_png,
    width = 12.5, height = 5.8, units = "in", dpi = 260, bg = "white"
  )
  map_records[[length(map_records) + 1L]] <- data.frame(
    file = basename(hem_path), description = "Hemeroby wild-to-urban gradient",
    stringsAsFactors = FALSE
  )
  message("Wrote ", hem_path)
} else {
  message("No hemeroby_mean layer in the rasters; skipping the gradient map. ",
          "Re-run 5_build_wild_domesticated_built.R to produce it.")
}

manifest <- do.call(rbind, map_records)
manifest$bytes <- file.info(file.path(map_dir, manifest$file))$size
manifest$created_utc <- format(Sys.time(), tz = "UTC", usetz = TRUE)
write.csv(manifest, file.path(map_dir, "map_outputs.csv"), row.names = FALSE)
message("Map rendering complete: ", map_dir)
