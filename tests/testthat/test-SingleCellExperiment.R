# This checks the SingleCellExperiment dumper.
# library(testthat); library(wobbegong); source("setup.R"); source("test-SingleCellExperiment.R")

library(SingleCellExperiment)
sce <- SingleCellExperiment(list(counts=matrix(rpois(100, lambda=10), ncol=5), logcounts=matrix(rnorm(100), ncol=5)))

test_that("naked SingleCellExperiment staging", {
    tmp <- tempfile()
    wobbegong:::wobbegongify_SingleCellExperiment(sce, tmp)

    summary <- jsonlite::fromJSON(file.path(tmp, "summary.json"))
    expect_false(summary$has_row_data)
    expect_false(summary$has_column_data)
    expect_equal(summary$row_count, nrow(sce))
    expect_equal(summary$column_count, ncol(sce))
    expect_equal(summary$assay_names, assayNames(sce))
    expect_equal(summary$reduced_dimension_names, list())

    expect_true(file.exists(file.path(tmp, "assays", "0", "content")))
    expect_true(file.exists(file.path(tmp, "assays", "1", "stats")))
})

test_that("SingleCellExperiment staging with reduced dimensions", {
    copy <- sce
    reducedDim(copy, "TSNE") <- matrix(rnorm(ncol(copy) * 4), nrow=ncol(copy))
    reducedDim(copy, "UMAP") <- matrix(rpois(ncol(copy) * 2, lambda=10), nrow=ncol(copy))

    tmp <- tempfile()
    wobbegong:::wobbegongify_SingleCellExperiment(copy, tmp)

    summary <- jsonlite::fromJSON(file.path(tmp, "summary.json"))
    expect_equal(summary$reduced_dimension_names, c("TSNE", "UMAP"))

    {
        rd1.dir <- file.path(tmp, "reduced_dimensions", "0")
        rd1 <- jsonlite::fromJSON(file.path(rd1.dir, "summary.json"))
        expect_identical(rd1$type, 'double')
        expect_identical(rd1$row_count, ncol(copy))

        expected1 <- reducedDim(copy, "TSNE")
        expect_identical(length(rd1$column_bytes), ncol(expected1))
        starts <- c(0L, cumsum(rd1$column_bytes))
        rd1.path <- file.path(rd1.dir, "content")
        expect_identical(expected1[,1], read_double(rd1.path, starts[1], rd1$column_bytes[1]))
        expect_identical(expected1[,4], read_double(rd1.path, starts[4], rd1$column_bytes[4]))
    }

    {
        rd2.dir <- file.path(tmp, "reduced_dimensions", "1")
        rd2 <- jsonlite::fromJSON(file.path(rd2.dir, "summary.json"))
        expect_identical(rd2$type, 'integer')
        expect_identical(rd2$row_count, ncol(copy))

        expected2 <- reducedDim(copy, "UMAP")
        expect_identical(length(rd2$column_bytes), ncol(expected2))
        starts <- c(0L, cumsum(rd2$column_bytes))
        rd2.path <- file.path(rd2.dir, "content")
        expect_identical(expected2[,1], read_integer(rd2.path, starts[1], rd2$column_bytes[1]))
        expect_identical(expected2[,2], read_integer(rd2.path, starts[2], rd2$column_bytes[2]))
    }
})
