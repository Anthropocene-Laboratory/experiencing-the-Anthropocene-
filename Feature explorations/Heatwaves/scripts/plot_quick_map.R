library(terra)
base <- here::here("Feature explorations", "Heatwaves")
r <- rast(file.path(base, "data_processed", "heatwave_days_2022_tx_w2.nc"))
v <- vect(here::here("Feature explorations", "_shared", "CNTR_RG_10M_2024_4326.geojson"))

png(file.path(base, "data_processed", "heatwave_map_2022.png"), width=1200, height=1000, res=150)
plot(r, main='Jours de canicule en Europe - Été 2022', col=hcl.colors(10, 'YlOrRd'), axes=TRUE)
plot(v, add=TRUE, border="gray50", lwd=0.5)
dev.off()
