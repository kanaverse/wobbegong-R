#' @import SingleCellExperiment
#' @importFrom DelayedArray type
wobbegongify_SingleCellExperiment <- function(x, path, deposit = TRUE, ...) {
    summ <- wobbegongify_SummarizedExperiment(x, path, deposit = FALSE, ...)

    rdnames <- reducedDimNames(x) 
    summ$reduced_dimension_names <- I(rdnames)
    rdpath <- file.path(path, "reduced_dimensions")
    dir.create(rdpath, showWarnings=FALSE)

    for (ri in seq_along(rdnames)) {
        curdir <- file.path(rdpath, ri - 1L)
        dir.create(curdir, recursive=TRUE)

        rd <- reducedDim(x, rdnames[ri], withDimnames=FALSE)
        everything <- vector("list", ncol(rd))
        for (c in seq_along(everything)) {
            everything[[c]] <- rd[,c]
        }

        curpath <- file.path(curdir, "content")
        payload <- dump_list_of_vectors(everything, curpath)
        rdsummary <- list(
            byte_order = get_byte_order(),
            type = translate_type(type(rd)),
            row_count = nrow(rd),
            column_bytes = I(payload)
        )

        write(toJSON(rdsummary, auto_unbox=TRUE), file=file.path(curdir, "summary.json"))
    }

    if (deposit) {
        write(toJSON(summ, auto_unbox=TRUE), file=file.path(path, "summary.json"))
    }
    summ
}
