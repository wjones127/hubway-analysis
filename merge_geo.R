# This script merges the hubway_stations data with census data of surrounding
# regions


packages <- c("dplyr", "ggplot2", "ggmap", "sp", "rgdal", "broom")
sapply(packages, library, character.only = TRUE)

stations <- read.csv("data/hubway_stations.csv", 
                     colClasses = c("numeric", "factor", "factor", "factor",
                                    "numeric", "numeric", "factor"))
census <- read.csv("data/census.csv")

qmap(location = "boston") + 
  geom_point(aes(x = lng, y = lat, color = status), data = stations)

  ogrInfo(dsn = "data/census_2010_tracts", layer = "CENSUS2010TRACTS_POLY")
tract_map <- readOGR(dsn = "data/census_2010_tracts", layer = "CENSUS2010TRACTS_POLY") %>%
  spTransform(CRS("+init=epsg:4326")) # converting coordinates
tracts_data <- tract_map@data %>% rename(fips = GEOID10)
tracts <- tidy(tract_map) %>% filter(hole == FALSE)

# Plot all census tracts
qmap(location = "boston") + 
  geom_polygon(aes(x = long, y = lat, group = group), data = tracts,
               fill = "steelblue", color = "black", alpha = 0.4)


# need to narrow down census tracts for speed
long_lims <- range(stations$lng)
lat_lims <- range(stations$lat)

tracts_in_range <- filter(tracts, between(long, long_lims[1], long_lims[2]) &
                          between(lat, lat_lims[1], lat_lims[2]))$id %>%
  unique()

tracts_local <- filter(tracts, id %in% tracts_in_range)


qmap(location = "boston", zoom = 12) + 
  geom_polygon(aes(x = long, y = lat, group = group), data = tracts_local,
               fill = "steelblue", color = "black", alpha = 0.4) + 
  geom_point(aes(x = lng, y = lat, color = status), data = stations) + 
  coord_map(xlim = range(stations$lng) + c(-.02, .02) , 
            ylim = range(stations$lat) + c(-.02, .02))


#' @function assign_census_tract: give lat and long, assigns a census tract to
#' that point.
assign_census_tract <- function(coords) {
  lat <- coords[1]
  long <- coords[2]
  
  num_tracts <- tracts_local$id %>% unique() %>% length()
  for (i in tracts_in_range) {
    # pull together data
    tract_longs <- filter(tracts_local, id == i)$long
    tract_lats <- filter(tracts_local, id == i)$lat
    
    if (point.in.polygon(long, lat, tract_longs, tract_lats, mode.checked = TRUE)) {
      return(tracts_data[i,]$fips)
    }
  }
  return(NA)
}

get_tracts <- function(lats, longs) {
  output <- character(nrow(stations))
  for (i in 1:nrow(stations)) {
    output[i] <- as.character(assign_census_tract(cbind(stations[i,]$lat, stations[i,]$lng)))
  }
  as.factor(output)
}
stations$fips <- get_tracts(stations$lat, stations$lng)


stations <- left_join(stations, census, by = c("fips" = "FIPS"))


save(stations, file = "stations.RData")
