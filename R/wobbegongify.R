#' Convert an object to the wobbegong format
#'
#' Dump an object to disk in the \pkg{wobbegong} format for easy HTTP range requests.
#'
#' @param x A supported R object, typically a SummarizedExperiment or an instance of one of its subclasses.
#' @param path String containing a path to the directory to dump \code{x}.
#' @param ... Additional arguments for specific methods.
#' @param dense.assays Logical scalar indicating whether to save dense assays.
#' If \code{FALSE}, dense assays are skipped.
#' @param sparse.assays Logical scalar indicating whether to save dense assays.
#' If \code{FALSE}, sparse assays are skipped.
#'
#' @return \code{path} is populated with the contents of \code{x}.
#' \code{NULL} is returned invisibly.
#' 
#' @author Aaron Lun
#' @examples
#' library(SingleCellExperiment)
#' se <- SingleCellExperiment(
#'     assays = list(
#'         counts=matrix(rpois(200, lambda=5), ncol=10), 
#'         logcounts=matrix(rnorm(200), ncol=10)
#'     ),
#'     colData = DataFrame(
#'         yy = letters[1:10],
#'         xx = LETTERS[1:10]
#'     ),
#'     rowData = DataFrame(row.names=sprintf("GENE_%i", 1:20)),
#'     reducedDims = list(
#'         PCA = matrix(rnorm(50), nrow=10),
#'         TSNE = matrix(rnorm(20), nrow=10)
#'     )
#' )
#'
#' tmp <- tempfile()
#' wobbegongify(se, tmp)
#' list.files(tmp, recursive=TRUE)
#'
#' @export
#' @import methods
#' @name wobbegongify
setGeneric("wobbegongify", function(x, path, ...) standardGeneric("wobbegongify"))

#' @export
#' @rdname wobbegongify
setMethod("wobbegongify", "SummarizedExperiment", function(x, path, dense.assays=TRUE, sparse.assays=TRUE, ...) {
    wobbegongify_SummarizedExperiment(x, path, dense.assays=dense.assays, sparse.assays=sparse.assays)
})

#' @export
#' @rdname wobbegongify
#' @importClassesFrom SingleCellExperiment SingleCellExperiment
setMethod("wobbegongify", "SingleCellExperiment", function(x, path, dense.assays=TRUE, sparse.assays=TRUE, ...) {
    wobbegongify_SingleCellExperiment(x, path, dense.assays=dense.assays, sparse.assays=sparse.assays)
})

#' @export
#' @rdname wobbegongify
setMethod("wobbegongify", "DataFrame", function(x, path, ...) {
    wobbegongify_DataFrame(x, path, ...)
})
