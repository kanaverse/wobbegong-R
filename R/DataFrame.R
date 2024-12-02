#' @importClassesFrom S4Vectors DataFrame
#' @importFrom jsonlite toJSON
#' @importFrom Rcpp sourceCpp
#' @useDynLib wobbegong
wobbegongify_DataFrame <- function(x, path) {
    summary <- list(
        byte_order = get_byte_order(),
        row_count = nrow(x), 
        has_row_names = !is.null(rownames(x))
    )

    contents <- as.list(x)
    cnames <- colnames(x)
    ctypes <- character(length(x))
    for (i in seq_along(contents)) {
        v <- contents[[i]]
        if (!is.null(dim(v))) {
            contents[i] <- list(NULL)
        } else if (is.factor(v)) {
            ctypes[i] <- "string"
            contents[[i]] <- as.character(v)
        } else if (is.logical(v)) {
            ctypes[i] <- "boolean"
        } else if (is.integer(v)) {
            ctypes[i] <- "integer"
        } else if (is.double(v)) {
            ctypes[i] <- "double"
        } else if (is.character(v)) {
            ctypes[i] <- "string"
        } else {
            contents[i] <- list(NULL)
        }
    }

    keep <- !vapply(contents, is.null, TRUE)
    contents <- contents[keep]
    cnames <- cnames[keep]
    ctypes <- ctypes[keep]
    summary$columns <- list(names = I(cnames), types = I(ctypes))

    # Row names are added onto the end of the columns.
    if (summary$has_row_names) {
        contents <- c(contents, list(rownames(x)))
    }

    dir.create(path, showWarnings=FALSE)
    conpath <- file.path(path, "content")
    summary$columns$bytes <- I(dump_list_of_vectors(contents, conpath))

    write(toJSON(summary, auto_unbox=TRUE), file=file.path(path, "summary.json"))
}
