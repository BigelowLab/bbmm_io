suppressPackageStartupMessages({
  library(stars)
})

#' Read in the template
#' 
#' @param filename chr, the name of the template file
#' @param mask logical, if TRUE mask the input values so they are all NA
#'  but if FALSE just return the original
#' @return a stars object
read_template = function(filename = "Jul01.nc",
                         mask = TRUE){
  x = stars::read_stars(filename)
  if (mask){
    x[[1]] <- NA_real_
    names(x) = "bbmm"
  }
  x
}


#' Encode a raster to simplify into a non-NA, non-zero listing of 
#' pixel addresses and values.
#' 
#' @param x SpatRaster or stars object.  Only one variable is encoded.
#' @return a 4 column numeric matrix with "index", "lon", "lat" and "value"
encode_raster = function(x = read_template(mask = FALSE)){
  if (inherits(x, "SpatRaster")) x = stars::st_as_stars(x)
  xy = sf::st_coordinates(x) |>
    as.matrix()
  index = (!is.na(x[[1]]) & (x[[1]] > 0)) |>
    as.vector()
  wix = which(index)
  r = cbind(wix,
            xy[wix, , drop = FALSE],
            x[[1]][wix])
  return(r)
}


#' Write an stars or SpatRaster as an encoded matrix
#' 
#' @param x stars or SpatRaster object OR an encoded version of either one
#' @param file the name of the file to create
#' @return the input `x`
write_encoded = function(x = read_template(mask = FALSE), 
                         file = "encoded.bin"){
  if (inherits(x, c("stars", "terra"))){
    e = encode_raster(x)
  } else {
    e = x
  }
  d = dim(e)
  d = unname(d)
  conn = gzfile(file, open = "wb")
  writeBin(123456789L, conn)  # magic number
  writeBin(d, conn) # dimensions
  writeBin(as.vector(e), conn) # data
  close(conn)
  
  invisible(x)
}

#' Read an encoded raster
#' 
#' @param file the filename of the encoded raster
#' @param template a stars (or SpatRaster) object sevring as a template
#' @param form chr one of "stars" or "SpatRaster" to define the output type
read_encoded = function(file = "encoded.bin",
                        template = read_template(mask = TRUE),
                        form = c("stars", "SpatRaster")[1]){
  if (!inherits(template, "stars")) template = stars::st_as_stars(template)
  conn = gzfile(file, open = "rb")
  magic = readBin(conn, 123456789L)
  swap_me = magic != 123456789L
  endian = .Platform$endian
  if (magic != 123456789L) endian = "swap"
  d = readBin(conn, "integer", n = 2, endian = endian)
  v = readBin(conn, "numeric", n = prod(d), endian = endian) |>
    matrix( ncol = d[2], nrow = d[1], byrow = FALSE)
  close(conn)
  template[[1]][v[, 1, drop = TRUE]] <- v[, 4, drop = TRUE]
  if (tolower(form[1]) == "spatraster"){
    template = as(template, "SpatRaster")
  }
  template
}


#' Purge a number from a raster
#' 
#' @param x raster object
#' @param value num the value to be replace
#' @param replacement num or NA, the new replacement value
#' @return raster object with values replaced
purge_number = function(x = read_template(mask = FALSE),
                        value = 0,
                        replacement = NA_real_){
  x[x == value] <- replacement
  x
}


#' Plot a raster in a pretty way
#' 
#' @param x stars raster
#' @param nbreaks num, number of color breaks
#' @param breaks chr, method for dividing breaks
#' @param col chr color palette 
#' @param ... other arguments for `plot.stars` 
pretty_plot = function(x, 
                       title = names(x)[1],
                       nbreaks = 11,
                       breaks = "equal",
                       cols = hcl.colors(nbreaks, palette = "viridis"),
                       ...){
  plot(orig,
       main = title, 
       col = cols,
       breaks = breaks,
       ...)
}