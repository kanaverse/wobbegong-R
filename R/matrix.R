#' @importFrom beachmat initializeCpp
#' @importFrom DelayedArray is_sparse type
#' @importFrom jsonlite toJSON
#' @importFrom Rcpp sourceCpp
#' @useDynLib wobbegong
wobbegongify_matrix <- function(x, path) {
    dir.create(path, showWarnings=FALSE)
    con <- file.path(path, "content")

    # Making life simpler and just realizing everything so we aren't
    # excessively punished for poor access patterns with file-backed matrices.
    ptr <- initializeCpp(x, memorize=TRUE, hdf5.realize=TRUE, tiledb.realize=TRUE)
    rtype <- translate_type(type(x))
    overall <- list(byte_order = get_byte_order(), row_count = nrow(x), column_count = ncol(x), type = rtype)

    if (!is_sparse(x)) {
        details <- dump_dense_rows(ptr, con, rtype)
        overall$format <- "dense"
        overall$row_bytes <- details$size
    } else {
        details <- dump_sparse_rows(ptr, con, rtype)
        overall$format <- "sparse"
        overall$row_bytes <- list(value=details$value_size, index=details$index_size)
    }

    stats <- details$statistics
    marg <- file.path(path, "stats")
    info <- dump_list_of_vectors(stats, marg)
    overall$statistics <- list(names = I(names(stats)), types = I(vapply(stats, typeof, "")), bytes = I(info))

    write(toJSON(overall, auto_unbox=TRUE, pretty=4), file=file.path(path, "summary.json"))
}
