# Author: Robert J. Hijmans
# Date :  October 2017
# Version 1.0
# License GPL v3


setMethod("rast", signature(x="missing"),
	function(x, nrows=180, ncols=360, nlyrs=1, xmin=-180, xmax=180, ymin=-90, ymax=90, crs, extent, resolution, ...) {

		if (missing(extent)) {	extent <- ext(xmin, xmax, ymin, ymax) }
		e <- as.vector(extent)
		if ((e[1] >= e[2]) || e[3] >= e[4]) {stop("invalid extent")}
		
		if (missing(crs)) {
			if (e[1] > -360.01 & e[2] < 360.01 & e[3] > -90.01 & e[4] < 90.01) {
				crs <- "+proj=longlat +datum=WGS84"
				#crs <- 'GEOGCS["WGS 84", DATUM["WGS_1984", SPHEROID["WGS 84",6378137,298.257223563]], PRIMEM["Greenwich",0], UNIT["degree",0.0174532925199433]]'
			} else {
				crs <- ""
			}
		} else {
			crs <- as.character(crs)
		}

		if (!missing(resolution)) {
			nrows <- max(1, round((e[4] - e[3]) / resolution))
			ncols <- max(1, round((e[2] - e[1]) / resolution))
		}

		r <- methods::new("SpatRaster")
		r@ptr <- SpatRaster$new(c(nrows, ncols, nlyrs), e, crs)

		show_messages(r, "rast")
	}
)

setMethod("rast", signature(x="list"),
	function(x, ...) {
		i <- sapply(x, function(i) inherits(i, "SpatRaster"))
		if (!any(i)) {
			stop("None of the elements of x are a SpatRaster")
		}
		if (!all(i)) {
			warning(paste(sum(!i), "out of", length(x), "elements of x are a SpatRaster"))
		}
		x <- x[i]
		r <- x[[1]]
		if (length(x) > 1) {
			for (i in seq_along(2:length(x))) {
				r <- c(r, x[[i]])
			}
		}
		r
	}
)


setMethod("rast", signature(x="SpatExtent"),
	function(x, nrows=10, ncols=10, nlyrs=1, crs="", ...) {
		e <- as.vector(x)
		r <- methods::new("SpatRaster")
		r@ptr <- SpatRaster$new(c(nrows, ncols, nlyrs), e, crs)
		show_messages(r, "rast")
	}
)

setMethod("rast", signature(x="SpatVector"),
	function(x, nrows=10, ncols=10, nlyrs=1, ...) {
		r <- rast(ext(x), nrows=nrows, ncols=ncols, nlyrs=nlyrs, crs=crs(x), ...)
		#why needed?
		# probably no more
		#crs(r) <- crs(x)[1]
		r
	}
)



.fullFilename <- function(x, expand=FALSE) {
	x <- trimws(x)
	p <- normalizePath(x, winslash = "/", mustWork = FALSE)
	if (file.exists(p)) {
		return(p)
	}
	#if (identical(basename(x), x)) {
	#	x <- file.path(getwd(), x)
	#}
	#if (expand) {
	#	x <- path.expand(x)
	#}
	return(x)
}

setMethod("rast", signature(x="character"),
	function(x, subds=-1, ...) {
		x <- trimws(x)
		x <- x[x!=""]
		if (length(x) == 0) {
			stop("provide a valid filename")
		}
		r <- methods::new("SpatRaster")
		f <- .fullFilename(x)
		if (length(f) > 1) {
			r@ptr <- SpatRaster$new(f)		
		} else {
			r@ptr <- SpatRaster$new(f, subds-1)
		}
		show_messages(r, "rast")
	}
)
setMethod("rast", signature(x="SpatRaster"),
	function(x, nlyrs=nlyr(x), ...) {
		r <- methods::new("SpatRaster")
		r@ptr <- x@ptr$geometry(nlyrs)
		
		#dims <- dim(x)
		#stopifnot(nlyrs > 0)
		#dims[3] <- nlyrs
		#r@ptr <- SpatRaster$new(dims, as.vector(ext(x)), crs(x))
		# also need the keep the names ?
		show_messages(r, "rast")
	}
)




setMethod("rast", signature(x="array"),
	function(x, ...) {
		dims <- dim(x)
		if (length(dims) > 3) {
			stop("cannot handle an array with more than 3 dimensions")
		}
		r <- methods::new("SpatRaster")
		r@ptr <- SpatRaster$new(dims, c(0, dims[2], 0, dims[1]), "")
		values(r) <- x
		show_messages(r, "rast")
	}
)



setMethod("rast", signature(x="Raster"),
	function(x, ...) {
		methods::as(x, "SpatRaster")
	}
)


.rastFromXYZ <- function(xyz, digits=6, crs="", ...) {

	ln <- colnames(xyz)
	## xyz might not have colnames, or might have "" names
	if (any(nchar(ln) < 1)) ln <- make.names(ln)
	if (inherits(xyz, "data.frame")) {
		xyz <- as.matrix(xyz)
		xyz <- matrix(as.numeric(xyz), ncol=ncol(xyz), nrow=nrow(xyz))
	}
	x <- sort(unique(xyz[,1]))
	dx <- x[-1] - x[-length(x)]

	rx <- min(dx)
	for (i in 1:5) {
		rx <- rx / i
		q <- sum(round(dx / rx, digits=digits) %% 1)
		if ( q == 0 ) {
			break
		}
	}
	if ( q > 0 ) {
		stop("x cell sizes are not regular")
	}

	y <- sort(unique(xyz[,2]))
	dy <- y[-1] - y[-length(y)]
	# probably a mistake to use the line below
	# Gareth Davies suggested that it be removed
	# dy <- round(dy, digits)

	ry <- min(dy)
	for (i in 1:5) {
		ry <- ry / i
		q <- sum(round(dy / ry, digits=digits) %% 1)
		if ( q == 0 ) {
			break
		}
	}
	if ( q > 0 ) {
		stop("y cell sizes are not regular")
	}

	minx <- min(x) - 0.5 * rx
	maxx <- max(x) + 0.5 * rx
	miny <- min(y) - 0.5 * ry
	maxy <- max(y) + 0.5 * ry

	d <- dim(xyz)
	r <- rast(xmin=minx, xmax=maxx, ymin=miny, ymax=maxy, crs=crs, nl=d[2]-2)
	res(r) <- c(rx, ry)
	cells <- cellFromXY(r, xyz[,1:2])
	if (d[2] > 2) {
		names(r) <- ln[-c(1:2)]
		v <- rep(NA, ncell(r))
		v[cells] <- xyz[,3:d[2]]
		values(r) <- v
	}
	return(r)
}



setMethod("rast", signature(x="matrix"),
	function(x, crs="", type="", ...) {
		if (type == "xyz") {
			r <- .rastFromXYZ(x, crs = crs, ...)
		} else {
			r <- methods::new("SpatRaster")
			r@ptr <- SpatRaster$new(c(dim(x), 1), c(0, ncol(x), 0, nrow(x)), crs)
			values(r) <- t(x)
		}
		show_messages(r, "rast")
	}
)

