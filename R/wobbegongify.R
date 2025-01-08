#' Convert an object to the wobbegong format
#'
#' Dump an object to disk in the \pkg{wobbegong} format for easy HTTP range requests.
#'
#' @param x A supported R object, typically a \link[SummarizedExperiment]{SummarizedExperiment} or an instance of one of its subclasses.
#' @param path String containing a path to the directory to dump \code{x}.
#' @param ... Additional arguments for specific methods.
#' @param SummarizedExperiment.assay.check Function that accepts the index of the assay, the name of the assay, and the assay matrix.
#' It should return a logical scalar specifying whether to save the assay; if \code{FALSE}, the assay is skipped.
#' If \code{NULL}, no assays are skipped.
#'
#' @details
#' For SummarizedExperiment objects, assays will be skipped if they are not 2-dimensional matrix-like objects of integer, logical or numeric type (according to \code{\link[DelayedArray]{type}}).
#' Assays will also be skipped if \code{SummarizedExperiment.assay.check} is supplied and does not return \code{TRUE} when called with the assay's details.
#'
#' When passing \link[S4Vectors]{DataFrame} objects as \code{x}, columns will be skipped if they are not atomic (i.e., integer, logical, numeric or character).
#' Factors will be automatically converted into character vectors.
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
setMethod("wobbegongify", "SummarizedExperiment", function(x, path, SummarizedExperiment.assay.check=NULL, ...) {
    wobbegongify_SummarizedExperiment(x, path, assay.check=SummarizedExperiment.assay.check)
})

#' @export
#' @rdname wobbegongify
#' @importClassesFrom SingleCellExperiment SingleCellExperiment
setMethod("wobbegongify", "SingleCellExperiment", function(x, path, SummarizedExperiment.assay.check=NULL, ...) {
    wobbegongify_SingleCellExperiment(x, path, assay.check=SummarizedExperiment.assay.check)
})

#' @export
#' @rdname wobbegongify
setMethod("wobbegongify", "DataFrame", function(x, path, ...) {
    wobbegongify_DataFrame(x, path)
})
