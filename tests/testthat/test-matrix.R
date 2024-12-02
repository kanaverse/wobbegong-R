# This checks that the staging of a matrix is correct.
# library(testthat); library(wobbegong); source("setup.R"); source("test-matrix.R")

check_stats <- function(mat, path, summary) {
    starts <- c(0L, cumsum(summary$bytes))
    i <- which(summary$names == "column_sum")
    expect_equal(Matrix::colSums(mat, na.rm=TRUE), read_double(path, starts[i], summary$bytes[i]))
    i <- which(summary$names == "row_sum")
    expect_equal(Matrix::rowSums(mat, na.rm=TRUE), read_double(path, starts[i], summary$bytes[i]))

    detected <- mat != 0
    i <- which(summary$names == "column_nonzero")
    expect_equal(Matrix::colSums(detected, na.rm=TRUE), read_integer(path, starts[i], summary$bytes[i]))
    i <- which(summary$names == "row_nonzero")
    expect_equal(Matrix::rowSums(detected, na.rm=TRUE), read_integer(path, starts[i], summary$bytes[i]))
}

read_sparse <- function(path, start, vlen, ilen, FUN, ncols) {
    vals <- FUN(path, start, vlen)
    idxs <- cumsum(read_integer(path, start + vlen, ilen))
    output <- rep(as(0, typeof(vals)), ncols)
    output[idxs + 1L] <- vals
    output
}

library(DelayedArray)
test_that("staging of an integer dense matrix is correct", {
    for (scenario in 1:4) {
        if (scenario < 4L) {
            mat <- matrix(rpois(1000, lambda=5), ncol=50)
            if (scenario == 2L) {
                mat <- t(DelayedArray(mat))
            } else if (scenario == 3L) {
                mat[10,10] <- NA
            }
        } else if (scenario == 4L) {
            # Bigger matrix to check correct management of temporaries.
            mat <- matrix(rpois(100000, lambda=5), ncol=2000)
        }

        tmp <- tempfile()
        wobbegong:::wobbegongify_matrix(mat, tmp)

        summary <- jsonlite::fromJSON(file.path(tmp, "summary.json"))
        expect_identical(summary$type, "integer")
        expect_identical(summary$format, "dense")
        expect_identical(summary$row_count, nrow(mat))
        expect_identical(summary$column_count, ncol(mat))

        starts <- c(0L, cumsum(summary$row_bytes))
        conpath <- file.path(tmp, "content")
        expect_identical(mat[1,], read_integer(conpath, starts[1], summary$row_bytes[1]))
        expect_identical(mat[10,], read_integer(conpath, starts[10], summary$row_bytes[10]))
        expect_identical(mat[20,], read_integer(conpath, starts[20], summary$row_bytes[20]))

        check_stats(mat, file.path(tmp, "stats"), summary$statistics)
    }
})

test_that("staging of an integer sparse matrix is correct", {
    for (scenario in 1:4) {
        if (scenario < 4L) { 
            mat <- as(matrix(rpois(1000, lambda=0.5), ncol=50), "SVT_SparseMatrix")
            if (scenario == 2L) {
                mat <- t(DelayedArray(mat))
            } else if (scenario == 3L) {
                mat[10,10] <- NA
            }
        } else {
            # Bigger matrix to check correct management of temporaries.
            mat <- as(matrix(rpois(100000, lambda=0.5), ncol=5000), "SVT_SparseMatrix")
        }

        tmp <- tempfile()
        wobbegong:::wobbegongify_matrix(mat, tmp)

        summary <- jsonlite::fromJSON(file.path(tmp, "summary.json"))
        expect_identical(summary$type, "integer")
        expect_identical(summary$format, "sparse")
        expect_identical(summary$row_count, nrow(mat))
        expect_identical(summary$column_count, ncol(mat))

        starts <- c(0L, cumsum(summary$row_bytes$value + summary$row_bytes$index))
        conpath <- file.path(tmp, "content")
        expect_identical(mat[1,], read_sparse(conpath, starts[1], summary$row_bytes$value[1], summary$row_bytes$index[1], read_integer, ncol(mat)))
        expect_identical(mat[10,], read_sparse(conpath, starts[10], summary$row_bytes$value[10], summary$row_bytes$index[10], read_integer, ncol(mat)))
        expect_identical(mat[20,], read_sparse(conpath, starts[20], summary$row_bytes$value[20], summary$row_bytes$index[20], read_integer, ncol(mat)))

        # check_stats(mat, file.path(tmp, "stats"), summary$statistics) # Some SVT matrix issues with colSums.
    }
})

test_that("staging of a double-precision dense matrix is correct", {
    for (scenario in 1:4) {
        if (scenario < 4L) { 
            mat <- matrix(rnorm(1000), ncol=10)
            if (scenario == 2L) {
                mat <- t(DelayedArray(mat))
            } else if (scenario == 3L) {
                mat[10,10] <- NA
            }
        } else {
            # Bigger matrix to check correct management of temporaries.
            mat <- matrix(rnorm(10000), ncol=1000)
        }

        tmp <- tempfile()
        wobbegong:::wobbegongify_matrix(mat, tmp)

        summary <- jsonlite::fromJSON(file.path(tmp, "summary.json"))
        expect_identical(summary$type, "double")
        expect_identical(summary$format, "dense")
        expect_identical(summary$row_count, nrow(mat))
        expect_identical(summary$column_count, ncol(mat))

        starts <- c(0L, cumsum(summary$row_bytes))
        conpath <- file.path(tmp, "content")
        expect_identical(mat[1,], read_double(conpath, starts[1], summary$row_bytes[1]))
        expect_identical(mat[5,], read_double(conpath, starts[5], summary$row_bytes[5]))
        expect_identical(mat[10,], read_double(conpath, starts[10], summary$row_bytes[10]))

        check_stats(mat, file.path(tmp, "stats"), summary$statistics)
    }
})

test_that("staging of a double-precision sparse matrix is correct", {
    for (scenario in 1:4) {
        if (scenario < 4) {
            mat <- Matrix::rsparsematrix(100, 10, 0.1)
            if (scenario == 2L) {
                mat <- t(DelayedArray(mat))
            } else if (scenario == 3L) {
                mat[10,10] <- NA
            }
        } else {
            # Bigger matrix to check correct management of temporaries.
            mat <- Matrix::rsparsematrix(100, 1000, 0.1)
        }

        tmp <- tempfile()
        wobbegong:::wobbegongify_matrix(mat, tmp)

        summary <- jsonlite::fromJSON(file.path(tmp, "summary.json"))
        expect_identical(summary$type, "double")
        expect_identical(summary$format, "sparse")
        expect_identical(summary$row_count, nrow(mat))
        expect_identical(summary$column_count, ncol(mat))

        starts <- c(0L, cumsum(summary$row_bytes$value + summary$row_bytes$index))
        conpath <- file.path(tmp, "content")
        expect_identical(mat[1,], read_sparse(conpath, starts[1], summary$row_bytes$value[1], summary$row_bytes$index[1], read_double, ncol(mat)))
        expect_identical(mat[5,], read_sparse(conpath, starts[5], summary$row_bytes$value[5], summary$row_bytes$index[5], read_double, ncol(mat)))
        expect_identical(mat[10,], read_sparse(conpath, starts[10], summary$row_bytes$value[10], summary$row_bytes$index[10], read_double, ncol(mat)))

        check_stats(mat, file.path(tmp, "stats"), summary$statistics)
    }
})

test_that("staging of a boolean dense matrix is correct", {
    for (scenario in 1:4) {
        if (scenario < 4L) {
            mat <- matrix(rbinom(1000, 1, 0.5) > 0, ncol=25)
            if (scenario == 2L) {
                mat <- t(DelayedArray(mat))
            } else if (scenario == 3L) {
                mat[10,10] <- NA
            }
        } else {
            # Bigger matrix to check correct management of temporaries.
            mat <- matrix(rbinom(100000, 1, 0.5) > 0, ncol=2500)
        }

        tmp <- tempfile()
        wobbegong:::wobbegongify_matrix(mat, tmp)

        summary <- jsonlite::fromJSON(file.path(tmp, "summary.json"))
        expect_identical(summary$type, "boolean")
        expect_identical(summary$format, "dense")
        expect_identical(summary$row_count, nrow(mat))
        expect_identical(summary$column_count, ncol(mat))

        starts <- c(0L, cumsum(summary$row_bytes))
        conpath <- file.path(tmp, "content")
        expect_identical(mat[1,], read_boolean(conpath, starts[1], summary$row_bytes[1]))
        expect_identical(mat[5,], read_boolean(conpath, starts[5], summary$row_bytes[5]))
        expect_identical(mat[10,], read_boolean(conpath, starts[10], summary$row_bytes[10]))

        check_stats(mat, file.path(tmp, "stats"), summary$statistics)
    }
})

test_that("staging of a boolean sparse matrix is correct", {
    for (scenario in 1:4) {
        if (scenario < 4L) {
            mat <- abs(Matrix::rsparsematrix(40, 25, 0.1)) > 0
            if (scenario == 2L) {
                mat <- t(DelayedArray(mat))
            } else if (scenario == 3L) {
                mat[10,10] <- NA
            }
        } else {
            # Bigger matrix to check correct management of temporaries.
            mat <- abs(Matrix::rsparsematrix(40, 2500, 0.1)) > 0
        }

        tmp <- tempfile()
        wobbegong:::wobbegongify_matrix(mat, tmp)

        summary <- jsonlite::fromJSON(file.path(tmp, "summary.json"))
        expect_identical(summary$type, "boolean")
        expect_identical(summary$format, "sparse")
        expect_identical(summary$row_count, nrow(mat))
        expect_identical(summary$column_count, ncol(mat))

        starts <- c(0L, cumsum(summary$row_bytes$value + summary$row_bytes$index))
        conpath <- file.path(tmp, "content")
        expect_identical(mat[1,], read_sparse(conpath, starts[1], summary$row_bytes$value[1], summary$row_bytes$index[1], read_boolean, ncol(mat)))
        expect_identical(mat[5,], read_sparse(conpath, starts[5], summary$row_bytes$value[5], summary$row_bytes$index[5], read_boolean, ncol(mat)))
        expect_identical(mat[10,], read_sparse(conpath, starts[10], summary$row_bytes$value[10], summary$row_bytes$index[10], read_boolean, ncol(mat)))

        check_stats(mat, file.path(tmp, "stats"), summary$statistics)
    }
})
