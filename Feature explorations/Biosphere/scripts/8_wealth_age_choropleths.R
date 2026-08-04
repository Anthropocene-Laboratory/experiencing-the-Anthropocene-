# =============================================================================
# 8_wealth_age_choropleths.R
# Two Layer-B exposure-filter maps at NATIONAL resolution (choropleth):
#   - Wealth  : GDP per capita, PPP (current international $), World Bank
#   - Ageing  : population aged 65+ (% of total), World Bank
# National level is deliberate: what these filters REVEAL about lived experience
# matters more than sub-national resolution here (both are also intrinsically
# national variables). Data pulled live from the World Bank API (most recent
# non-empty value per country, mrnev=1).
#
# NOTE (shared Layer-B outputs): like the population map, these are cross-feature
# filters, not biosphere-specific; they live in Biosphere/data_processed for now
# because no dedicated shared-output home is defined yet.
#
# CAVEAT: GDP per capita PPP overstates *lived* wealth for Ireland and Luxembourg
# (multinational profit-shifting / cross-border workers). GNI* or median
# disposable income would be truer to experience - swap if needed.
#
# RUN FROM WORKSPACE ROOT:
#   Rscript "Feature explorations/Biosphere/scripts/8_wealth_age_choropleths.R"
# =============================================================================
suppressMessages({library(jsonlite); library(terra)})
setwd(here::here())

shared   <- "Feature explorations/_shared"
out      <- "Feature explorations/Biosphere/data_processed"
out_maps <- file.path(out, "maps"); out_tables <- file.path(out, "tables")
dir.create(out_maps, showWarnings = FALSE, recursive = TRUE)
dir.create(out_tables, showWarnings = FALSE, recursive = TRUE)

STUDY <- c("AT","BE","BG","HR","CY","CZ","DK","EE","FI","FR","DE","EL","HU","IE",
           "IT","LV","LT","LU","MT","NL","PL","PT","RO","SK","SI","ES","SE","UK",
           "IS","LI","NO","CH")
euro <- ext(-25, 45, 34, 72)

getwb <- function(ind) {
  url <- sprintf("https://api.worldbank.org/v2/country/all/indicator/%s?format=json&per_page=400&mrnev=1", ind)
  x <- fromJSON(url)
  df <- x[[2]]
  d <- data.frame(iso2 = df$country$id, year = df$date, value = df$value,
                  stringsAsFactors = FALSE)
  # World Bank uses GR/GB; Eurostat CNTR uses EL/UK
  d$cntr <- d$iso2; d$cntr[d$cntr == "GR"] <- "EL"; d$cntr[d$cntr == "GB"] <- "UK"
  d[d$cntr %in% STUDY & !is.na(d$value), ]
}

gdp <- getwb("NY.GDP.PCAP.PP.CD")     # GDP per capita, PPP (current intl $)
old <- getwb("SP.POP.65UP.TO.ZS")     # Population ages 65+ (% of total)

cn <- vect(file.path(shared, "CNTR_RG_10M_2024_4326.geojson"))
study <- crop(cn[cn$CNTR_ID %in% STUDY, ], euro)
study$gdp <- gdp$value[match(study$CNTR_ID, gdp$cntr)]
study$old <- old$value[match(study$CNTR_ID, old$cntr)]

cat("GDP years:", paste(sort(unique(gdp$year)), collapse=","),
    "| 65+ years:", paste(sort(unique(old$year)), collapse=","), "\n")
cat("countries missing GDP:", paste(setdiff(STUDY, gdp$cntr), collapse=" "), "\n")
cat("countries missing 65+:", paste(setdiff(STUDY, old$cntr), collapse=" "), "\n")

tab <- data.frame(cntr = study$CNTR_ID, name = study$NAME_ENGL,
                  gdp_pc_ppp = round(study$gdp), pct_65plus = round(study$old, 1))
tab <- tab[!duplicated(tab$cntr), ]
tab <- tab[order(-tab$gdp_pc_ppp), ]
write.csv(tab, file.path(out_tables, "wealth_age_by_country.csv"), row.names = FALSE)

# ---- WEALTH map (GDP per capita PPP) ----
pal_w <- colorRampPalette(c("#f7fcf5","#c7e9c0","#74c476","#238b45","#00441b"))(100)
png(file.path(out_maps, "wealth_gdp_pc_ppp.png"), width = 2400, height = 2400, res = 240)
par(mar = c(2,2,4,1))
plot(study, "gdp", type = "continuous", col = pal_w, border = "grey55", lwd = 0.3,
     mar = c(2,2,4,8), axes = TRUE,
     main = "Wealth: GDP per capita (PPP, current int'l $)\nWorld Bank, most recent year",
     plg = list(title = "$ / capita"))
dev.off(); cat("wrote wealth_gdp_pc_ppp.png\n")

# ---- AGE map (share 65+) ----
pal_a <- colorRampPalette(c("#fcfbfd","#dadaeb","#9e9ac8","#6a51a3","#3f007d"))(100)
png(file.path(out_maps, "age_share_65plus.png"), width = 2400, height = 2400, res = 240)
par(mar = c(2,2,4,1))
plot(study, "old", type = "continuous", col = pal_a, border = "grey55", lwd = 0.3,
     mar = c(2,2,4,8), axes = TRUE,
     main = "Ageing: population aged 65+ (% of total)\nWorld Bank, most recent year",
     plg = list(title = "% aged 65+"))
dev.off(); cat("wrote age_share_65plus.png\n")

cat("\n-- Country table (top/bottom by GDP) --\n")
print(head(tab, 6), row.names = FALSE)
print(tail(tab, 6), row.names = FALSE)
