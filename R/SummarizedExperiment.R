#' @import SummarizedExperiment
#' @import SingleCellExperiment
wobbegongify_SummarizedExperiment <- function(x, path, deposit = TRUE, assay.check = NULL) {
    dir.create(path, showWarnings=FALSE)

    has_row_data <- !is.null(rownames(x)) || ncol(rowData(x)) > 0
    if (has_row_data) {
        wobbegongify_DataFrame(rowData(x), file.path(path, "row_data"))
    }

    has_col_data <- !is.null(colnames(x)) || ncol(colData(x)) > 0
    if (has_col_data) {
        wobbegongify_DataFrame(colData(x), file.path(path, "column_data"))
    }

    assay.dir <- file.path(path, "assays")
    dir.create(assay.dir, showWarnings=FALSE)
    assay.names <- assayNames(x)
    keep <- logical(length(assay.names)) 

    for (i in seq_along(assay.names)) {
        current <- assay(x, i, withDimnames=FALSE)
        if (length(dim(current)) != 2L) {
            warning("skipping assay '", assay.names[i], "' with more than 2 dimensions");
            next
        }
        if (!(type(current) %in% c("double", "integer", "logical"))) {
            warning("skipping assay '", assay.names[i], "' that is not numeric or logical");
            next
        }
        if (is.null(assay.check) || assay.check(i, assay.names[i], current)) {
            keep[i] <- TRUE
            wobbegongify_matrix(current, file.path(assay.dir, i - 1L))
        }
    }

    summary <- list(
        object = "summarized_experiment",
        row_count = nrow(x),
        column_count = ncol(x),
        has_row_data = has_row_data,
        has_column_data = has_col_data,
        assay_names = I(assay.names[keep])
    )

    if (deposit) {
        write(jsonlite::toJSON(summary, auto_unbox=TRUE), file=file.path(path, "summary.json"))
    }
    summary
}
