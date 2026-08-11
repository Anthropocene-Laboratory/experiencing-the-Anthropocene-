# =============================================================================
# 3_map_broadband_coverage_eurostat.R
# Layer-A Connectivity feature, THE "AVAILABILITY" LAYER: what share of households
# a network is offered to, from operator and regulator returns rather than from
# volunteers running a speed test.
#
# WHY THIS SITS UNDER THE OOKLA LAYER: Ookla (script 2) measures performance only
# where somebody chose to test. This one is a census-style declaration collected
# from National Regulatory Authorities and operators, so a low value means "not
# offered", not "nobody looked". It is the honest floor the lived layer sits on.
#
# ** RESOLUTION CORRECTION — READ THIS. ** The Broadband Coverage in Europe (BCE)
# study collects at NUTS3, but that NUTS3 detail is NOT released as open data:
# digital-strategy.ec.europa.eu publishes only report PDFs, and Eurostat's
# dissemination of the same survey (isoc_cbt / isoc_cbs) is NATIONAL, split only
# by degree of urbanisation (TOTAL vs DEG3 = rural). So this layer is a national
# choropleth with a rural split, not a NUTS3 surface. Getting NUTS3 would mean
# extracting tables from the BCE report PDFs or licensing Point Topic.
#
# WHAT IS MAPPED: % of households covered, latest year, 2x2 —
#   rows    = VHCN_FX (fixed very-high-capacity, the gigabit target) and 5G
#   columns = all households (TOTAL) and rural households (DEG3)
# One shared colour scale across all four panels, so the rural shortfall is read
# directly by comparing left to right rather than from a derived difference.
#
# SOURCE: Eurostat isoc_cbt "Broadband internet coverage by technology", the
#   dissemination of DG CNECT's Broadband Coverage in Europe study. Unit PC_HH.
#
# OUTPUT: data_processed/maps/broadband_coverage_vhcn_5g.png
#         data_processed/tables/broadband_coverage_by_country.csv
#
# RUN FROM WORKSPACE ROOT:
#   Rscript "Feature explorations/Connectivity/scripts/3_map_broadband_coverage_eurostat.R"
# =============================================================================
suppressPackageStartupMessages({
  library(sf); library(ggplot2); library(ragg); library(patchwork)
})
setwd(here::here())
sf::sf_use_s2(FALSE)

DATA_RETRIEVED <- "2026-08-04"

shared     <- "Feature explorations/_shared"
raw_dir    <- "Feature explorations/Connectivity/data_raw"
out        <- "Feature explorations/Connectivity/data_processed"
out_maps   <- file.path(out, "maps")
out_tables <- file.path(out, "tables")
for (d in c(raw_dir, out_maps, out_tables))
  dir.create(d, showWarnings = FALSE, recursive = TRUE)

csv <- file.path(raw_dir, "eurostat_isoc_cbt.csv")

# 1. HARVEST (guarded) — SDMX-CSV is far easier than Eurostat's JSON-stat -----
#    Fetched through PowerShell: R's libcurl SSL-fails on the Eurostat host.
if (!file.exists(csv)) {
  u <- paste0("https://ec.europa.eu/eurostat/api/dissemination/sdmx/2.1/data/",
              "isoc_cbt/?format=SDMX-CSV&startPeriod=2024")
  ps <- sprintf(paste0("$ProgressPreference='SilentlyContinue'; ",
                       "Invoke-WebRequest -Uri '%s' -OutFile '%s' ",
                       "-UseBasicParsing -TimeoutSec 300"),
                u, gsub("\\\\", "/", csv))
  system2("powershell", c("-NoProfile", "-Command", shQuote(ps)),
          stdout = TRUE, stderr = TRUE)
  if (!file.exists(csv) || file.size(csv) < 1000) stop("Eurostat fetch failed")
  message("Downloaded ", csv)
}

d <- read.csv(csv, stringsAsFactors = FALSE)
d <- d[d$unit == "PC_HH" & d$inet_tec %in% c("VHCN_FX", "5G") &
       d$terrtypo %in% c("TOTAL", "DEG3") & !is.na(d$OBS_VALUE), ]
YEAR <- max(d$TIME_PERIOD)
d <- d[d$TIME_PERIOD == YEAR & d$geo != "EU27_2020", ]
message("Year mapped: ", YEAR, " | countries: ", length(unique(d$geo)))

# 2. WIDE table + the rural shortfall ---------------------------------------
w <- reshape(d[, c("geo", "inet_tec", "terrtypo", "OBS_VALUE")],
             timevar = c("terrtypo"), idvar = c("geo", "inet_tec"),
             direction = "wide")
names(w) <- sub("^OBS_VALUE\\.", "", names(w))
w$rural_gap_pp <- round(w$TOTAL - w$DEG3, 1)
w$year <- YEAR
w <- w[order(w$inet_tec, w$rural_gap_pp, decreasing = TRUE), ]
write.csv(w[, c("geo", "year", "inet_tec", "TOTAL", "DEG3", "rural_gap_pp")],
          file.path(out_tables, "broadband_coverage_by_country.csv"), row.names = FALSE)
message("Wrote ", file.path(out_tables, "broadband_coverage_by_country.csv"))

# 3. GEOMETRY — same PROJ-string rule as everywhere else in this project ------
LAEA_PROJ <- paste0("+proj=laea +lat_0=52 +lon_0=10 +x_0=4321000 +y_0=3210000 ",
                    "+ellps=GRS80 +units=m +no_defs")
win_ext <- c(xmin = 2.4e6, xmax = 6.1e6, ymin = 1.4e6, ymax = 5.5e6)

cn <- st_read(file.path(shared, "CNTR_RG_10M_2024_4326.geojson"), quiet = TRUE) |>
  st_transform(LAEA_PROJ) |> st_make_valid()
suppressWarnings(st_crs(cn) <- 3035)     # re-tag only: LAEA_PROJ *is* EPSG:3035
win <- st_as_sfc(st_bbox(c(win_ext), crs = 3035))
cn  <- st_crop(cn, win)

# The BCE study covers 31 countries. Everything else in the window (RU, UA, BY,
# TR, the Maghreb) is OUT OF SCOPE, not "missing" — drawing it in the same grey as
# a non-reporting study country would invent a data gap that does not exist.
STUDY <- unique(d$geo)
ctx   <- cn[!cn$CNTR_ID %in% STUDY, ]
cns   <- cn[ cn$CNTR_ID %in% STUDY, ]

BRK <- c(0, 50, 70, 85, 95, 99, 100)
LAB <- c("<50", "50–70", "70–85", "85–95", "95–99", "99–100")

mk <- function(tec, terr, title, subtitle, keep_legend) {
  v <- d[d$inet_tec == tec & d$terrtypo == terr, c("geo", "OBS_VALUE")]
  m <- merge(cns, v, by.x = "CNTR_ID", by.y = "geo", all.x = TRUE)
  m$cls <- factor(cut(m$OBS_VALUE, breaks = BRK, labels = LAB, include.lowest = TRUE),
                  levels = LAB)
  ggplot() +
    geom_sf(data = ctx, fill = "grey10", colour = "grey20", linewidth = 0.1) +
    geom_sf(data = m, aes(fill = cls), colour = "grey25", linewidth = 0.12) +
    # limits = LAB (not just drop = FALSE) is what makes the four panels share ONE
    # identical scale, which is the precondition for plot_layout(guides="collect").
    scale_fill_viridis_d(option = "viridis", begin = 0.08, name = "% of households",
                         na.value = "grey40", drop = FALSE, limits = LAB) +
    coord_sf(crs = 3035, xlim = win_ext[c("xmin", "xmax")],
             ylim = win_ext[c("ymin", "ymax")], expand = FALSE) +
    labs(title = title, subtitle = subtitle) +
    theme_void(base_size = 11) +
    theme(
      plot.background  = element_rect(fill = "black", colour = NA),
      panel.background = element_rect(fill = "black", colour = NA),
      legend.key   = element_rect(fill = "black", colour = NA),
      plot.title    = element_text(colour = "white", face = "bold", size = 12),
      plot.subtitle = element_text(colour = "grey55", size = 8.5, margin = margin(b = 3)),
      legend.title  = element_text(colour = "grey80", size = 9),
      legend.text   = element_text(colour = "grey80", size = 8),
      legend.position = if (keep_legend) "right" else "none",
      legend.key.height = unit(0.5, "cm"), legend.key.width = unit(0.35, "cm"))
}

# One legend per ROW, on the right-hand panel. patchwork's guides = "collect"
# collapses these four identical scales in an isolated reproduction but not here
# (ggplot2 4.0.3 / patchwork 1.3.2), and chasing that further was not worth it:
# two symmetric legends keep all four panels the same width, which a single
# collected legend would not. The scale is identical in all four panels.
fig <- wrap_plots(list(
    mk("VHCN_FX", "TOTAL", "Gigabit-capable fixed network", "all households", FALSE),
    mk("VHCN_FX", "DEG3",  "Gigabit-capable fixed network", "rural households only", TRUE),
    mk("5G", "TOTAL", "5G mobile", "all households", FALSE),
    mk("5G", "DEG3",  "5G mobile", "rural households only", TRUE)), ncol = 2) +
  plot_annotation(
    title = "What is on offer, and what is on offer in the countryside",
    subtitle = paste0("Share of households covered, ", YEAR,
                      " — declared by national regulators and operators, not crowdsourced. ",
                      "All four panels share one colour scale."),
    caption = paste0(
      "Data: Eurostat isoc_cbt (Broadband internet coverage by technology), unit PC_HH, ",
      YEAR, ", retrieved ", DATA_RETRIEVED, ". This is Eurostat's dissemination of DG ",
      "CNECT's\n'Broadband Coverage in Europe' study. The study COLLECTS at NUTS3 but ",
      "only national figures split by degree of urbanisation are released as open data, ",
      "so this is a national\nchoropleth, not a NUTS3 surface. VHCN_FX = fixed ",
      "very-high-capacity network (FTTP + DOCSIS 3.1).\nCountries drawn in flat dark ",
      "grey are outside the study's 31-country scope, not missing values. ",
      "Projection: LAEA Europe (EPSG:3035). Boundaries: Eurostat GISCO CNTR 10M. ",
      "PROVISIONAL exploration."),
    theme = theme(
      plot.background = element_rect(fill = "black", colour = NA),
      plot.title    = element_text(colour = "white", face = "bold", size = 15),
      plot.subtitle = element_text(colour = "grey80", size = 10, margin = margin(b = 6)),
      plot.caption  = element_text(colour = "grey55", size = 6.2, hjust = 0)))

png_out <- file.path(out_maps, "broadband_coverage_vhcn_5g.png")
ragg::agg_png(png_out, width = 11.5, height = 12.4, units = "in", res = 300,
              background = "black")
print(fig)
invisible(dev.off())
message("Wrote ", png_out)

# 4. Report the widest rural gaps -------------------------------------------
for (tec in c("VHCN_FX", "5G")) {
  s <- w[w$inet_tec == tec, ]
  s <- s[order(-s$rural_gap_pp), ]
  message("\nWidest rural shortfall, ", tec, " (percentage points, ", YEAR, "):")
  print(utils::head(s[, c("geo", "TOTAL", "DEG3", "rural_gap_pp")], 8), row.names = FALSE)
}
