
setMethod("nsds", signature(x="SpatRasterStack"),
	function(x) {
		x@ptr$nsds()
	}
)

setMethod("rstk", signature(x="character"),
	function(x, ...) {
		x <- trimws(x[1])
		if (nchar(x) == 0) {
			stop("provide valid file name(s)")
		}
		f <- .fullFilename(x)
		r <- methods::new("SpatRasterStack")
		r@ptr <- SpatRasterStack$new(f)
		show_messages(r, "rstk")
	}
)

setMethod("rstk", signature(x="SpatRaster"),
	function(x, name="sd1", ...) {
		r <- methods::new("SpatRasterStack")
		r@ptr <- SpatRasterStack$new(x@ptr, name)
		dots <- list(...)
		nms <- names(dots)
		for (i in seq_along(dots)) {
			if (inherits(dots[[i]], "SpatRaster")) {
				r@ptr$add(dots[[i]]@ptr, nms[i])
			}
		}	
		show_messages(r, "rstk")
	}
)


setMethod("c", signature(x="SpatRasterStack"), 
	function(x, ...) {
		r <- methods::new("SpatRasterStack")
		# deep copy of the SRS, but not of the SRs within it
		# that is bad and must change.
		x@ptr <- x@ptr$subset((1:x@ptr$nsds()) -1 )
		dots <- list(...)
		nms <- names(dots)
		for (i in seq_along(dots)) {
			if (inherits(dots[[i]], "SpatRaster")) {
				x@ptr$add(dots[[i]]@ptr, nms[i])
			}
		}
		show_messages(x, "c")		
	}
)

# perhaps instead use [[ for return SpatRasterStack
setMethod("[", c("SpatRasterStack", "numeric", "missing"),
function(x, i, j, ... ,drop=TRUE) {
	if (length(i) == 1) {
		ptr <- x@ptr$getsds(i-1)
		x <- rast()
		x@ptr <- ptr
	} else {
		x@ptr <- x@ptr$subset(i-1)
	}
	show_messages(x)
})


setReplaceMethod("[", c("SpatRasterStack","numeric","missing"),
	function(x, i, j, value) {
		if (any(!is.finite(i)) | any(i<1)) {
			stop("invalid index")
		}
		if (length(i) > 1) {
			stop("you can only replace one sub-dataset at a time")		
		}
		stopifnot(inherits(value, "SpatRaster"))
		x@ptr$replace(i-1, value@ptr)
		show_messages(x)
	}
)


setMethod("[", c("SpatRasterStack", "numeric", "numeric"),
function(x, i, j, ... ,drop=TRUE) {
	y <- x[i]
	if (inherits(y, "SpatRaster")) {
		return(y[[j]])
	}
	nd <- y@ptr$nsds()
	x@ptr <- SpatRasterStack$new()
	nms <- y@ptr$names
	for (k in seq_along(1:nd)) {
		r <- y[k][[j]]
		x@ptr$add(r@ptr, nms[k])
	}
	show_messages(x)
})


setMethod("[", c("SpatRasterStack", "logical", "missing"),
function(x, i, j, ... ,drop=TRUE) {
	x[which(i), ..., drop=drop]
})

setMethod("[", c("SpatRasterStack", "character", "missing"),
function(x, i, j, ... ,drop=TRUE) {
	i <- match(i, names(x))
	if (any(is.na(i))) {stop("unknown name(s) provided")}
	x[i, ..., drop=drop]
})

setMethod("$", "SpatRasterStack",  
	function(x, name) { 
		x[name] 
	}
)

