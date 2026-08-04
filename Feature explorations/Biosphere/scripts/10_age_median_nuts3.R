# =============================================================================
# 10_age_median_nuts3.R
# Sub-national AGE map (Layer-B filter): MEDIAN AGE by NUTS3 region, 2023
# (Eurostat demo_r_pjanind3, indicator MEDAGEPOP). Unlike the national 65%+
# choropleth (script 8), this resolves INTRA-country ageing (old rural regions
# vs younger metropolitan ones) - lighter than WorldPop's ~1 km grid but still
# beyond the national ceiling.
#
# Data:   Eurostat API (live), median age of population, NUTS3, year 2023.
# Geom:   GISCO NUTS_RG_10M_2021 (LEVL_CODE == 3), in _shared/.
# Coverage: EU + EFTA + candidate NUTS3; UK NUTS3 is only partially maintained
#           by Eurostat post-Brexit (may be missing for recent years).
#
# RUN FROM WORKSPACE ROOT:
#   Rscript "Feature explorations/Biosphere/scripts/10_age_median_nuts3.R"
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

# ---- Eurostat median age (NUTS3, 2023) --------------------------------------
# NB: R's libcurl hits an SSL error on the Eurostat host, so the JSON was
# fetched via PowerShell into _shared/ and is read locally here.
# To refresh: Invoke-WebRequest "https://ec.europa.eu/eurostat/api/dissemination/statistics/1.0/data/demo_r_pjanind3?format=JSON&freq=A&indic_de=MEDAGEPOP&time=2023" -OutFile <path>
js  <- fromJSON(file.path(shared, "eurostat_medage_nuts3_2023.json"))
idx <- unlist(js$dimension$geo$category$index)  # geo code -> 0-based position
val <- unlist(js$value)                          # position(str) -> value (sparse)
geo <- names(idx); pos <- as.integer(idx)
medage <- as.numeric(val[as.character(pos)])     # NA where a position is absent
df  <- data.frame(geo = geo, medage = medage, stringsAsFactors = FALSE)
df  <- df[nchar(df$geo) == 5 & !is.na(df$medage), ]        # NUTS3 only
df  <- df[substr(df$geo, 1, 2) %in% STUDY, ]
cat("NUTS3 regions with median age:", nrow(df), "\n")
cat("countries present:", paste(sort(unique(substr(df$geo,1,2))), collapse=" "), "\n")
cat("study countries with NO NUTS3 data:",
    paste(setdiff(STUDY, unique(substr(df$geo,1,2))), collapse=" "), "\n")

# ---- geometry ---------------------------------------------------------------
n <- vect(file.path(shared, "NUTS_RG_10M_2021_4326.geojson"))
n3 <- n[n$LEVL_CODE == 3 & substr(n$NUTS_ID,1,2) %in% STUDY, ]
n3 <- crop(n3, euro)
n3$medage <- df$medage[match(n3$NUTS_ID, df$geo)]

# country outlines for reference
cn <- crop(vect(file.path(shared, "CNTR_RG_10M_2024_4326.geojson")), euro)
cn <- cn[cn$CNTR_ID %in% STUDY, ]

write.csv(data.frame(nuts3 = n3$NUTS_ID, name = n3$NUTS_NAME, median_age = round(n3$medage,1)),
          file.path(out_tables, "age_median_nuts3_2023.csv"), row.names = FALSE)

pal <- colorRampPalette(c("#fcfbfd","#dadaeb","#9e9ac8","#6a51a3","#3f007d"))(100)
png(file.path(out_maps, "age_median_nuts3_2023.png"), width = 2400, height = 2400, res = 240)
par(mar = c(2,2,4,1))
plot(n3, "medage", type = "continuous", col = pal, border = NA,
     mar = c(2,2,4,9), axes = TRUE,
     main = "Ageing, sub-national: median age by NUTS3 region, 2023\nEurostat - intra-country ageing gradients",
     plg = list(title = "median age"))
lines(cn, col = "grey40", lwd = 0.4)
dev.off()
cat("wrote age_median_nuts3_2023.png\n")
