# Author: Robert J. Hijmans
# Date : December 2017
# Version 1.0
# License GPL v3


.makeTextFun <- function(fun) {
	if (class(fun) != "character") {
		if (is.primitive(fun)) {
			test <- try(deparse(fun)[[1]], silent=TRUE)
			if (test == '.Primitive(\"sum\")') { fun <- 'sum' 
			} else if (test == '.Primitive(\"min\")') { fun <- 'min' 
			} else if (test == '.Primitive(\"max\")') { fun <- 'max' 
			}
		} else {
			test1 <- isTRUE(try( deparse(fun)[2] == 'UseMethod(\"mean\")', silent=TRUE))
			test2 <- isTRUE(try( fun@generic == "mean", silent=TRUE))
			if (test1 | test2) { 
				fun <- "mean" 
			}
			test1 <- isTRUE(try( deparse(fun)[2] == 'UseMethod(\"median\")', silent=TRUE))
			test2 <- isTRUE(try( fun@generic == "median", silent=TRUE))
			if (test1 | test2) { 
				fun <- "median" 
			}
		} 
	}
	return(fun)
}


setMethod("aggregate", signature(x="SpatRaster"), 
function(x, fact=2, fun="mean", ..., filename="", overwrite=FALSE, wopt=list())  {

	#expand=TRUE, 
	fun <- .makeTextFun(match.fun(fun))
	toc <- FALSE
	if (class(fun) == "character") { 
		if (fun %in% c("sum", "mean", "min", "max", "median", "modal")) {
			toc <- TRUE
		}
	}
	if (!hasValues(x)) { toc = TRUE }
	na.rm <- isTRUE(list(...)$na.rm)
	if (toc) {	
		#	fun="mean", expand=TRUE, na.rm=TRUE, filename=""
		opt <- .runOptions(filename, overwrite, wopt)	
		x@ptr <- x@ptr$aggregate(fact, fun, na.rm, opt)
		return (show_messages(x, "aggregate"))
	} else {
		out <- rast(x)
		nl <- nlyr(out)
		opt <- .runOptions("", TRUE, list())	
		out@ptr <- out@ptr$aggregate(fact, "sum", na.rm, opt)
		out <- show_messages(out, "aggregate")
		
		dims <- x@ptr$get_aggregate_dims(fact)
		b <- x@ptr$getBlockSize(4)		
		
		nr <- floor(b$nrows[1] / fact[1]) * fact[1]
		nrs <- rep(nr, floor(nrow(x)/nr))
		d <- nrow(x) - sum(nrs) 
		if (d > 0) nrs <- c(nrs, d)
		b$row <- c(0, cumsum(nrs))[1:length(nrs)] + 1
		b$nrows <- nrs
		b$n <- length(nrs)
		outnr <- ceiling(b$nrows / fact[1])
		outrows  <- c(0, cumsum(outnr))[1:length(outnr)] + 1
		
		nc <- ncol(x)	
		readStart(x)
		ignore <- writeStart(out, filename, overwrite, wopt)
		for (i in 1:b$n) {
			v <- readValues(x, b$row[i], b$nrows[i], 1, nc)
			v <- x@ptr$get_aggregates(v, b$nrows[i], dims)
			v <- sapply(v, fun, ...)
			if (length(v) != outnr[i] * prod(dims[5:6])) {
				stop("this function does not return the correct number of values")
			}
			writeValues(out, v, outrows[i], outnr[i])
		}
		readStop(x)
		show_messages(out, "aggregate")
	}
}
)




