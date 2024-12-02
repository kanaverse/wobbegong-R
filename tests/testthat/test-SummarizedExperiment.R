# This checks the SummarizedExperiment dumper.
# library(testthat); library(wobbegong); source("setup.R"); source("test-SummarizedExperiment.R")

library(SummarizedExperiment)
se <- SummarizedExperiment(list(counts=matrix(rpois(100, lambda=10), ncol=5), logcounts=matrix(rnorm(100), ncol=5)))

test_that("naked SummarizedExperiment staging", {
    tmp <- tempfile()
    wobbegong:::wobbegongify_SummarizedExperiment(se, tmp)

    summary <- jsonlite::fromJSON(file.path(tmp, "summary.json"))
    expect_false(summary$has_row_data)
    expect_false(summary$has_column_data)
    expect_equal(summary$row_count, nrow(se))
    expect_equal(summary$column_count, ncol(se))
    expect_equal(summary$assay_names, assayNames(se))

    expect_true(file.exists(file.path(tmp, "assays", "0", "content")))
    expect_true(file.exists(file.path(tmp, "assays", "1", "stats")))
})

test_that("SummarizedExperiment staging with rownames and column data", {
    copy <- se
    rownames(se) <- sprintf("GENE_%i", seq_len(nrow(copy)))
    se$blah <- runif(ncol(se))
    se$stuff <- sample(LETTERS, ncol(se))

    tmp <- tempfile()
    wobbegong:::wobbegongify_SummarizedExperiment(se, tmp)

    summary <- jsonlite::fromJSON(file.path(tmp, "summary.json"))
    expect_true(summary$has_row_data)
    expect_true(summary$has_column_data)
    expect_equal(summary$row_count, nrow(se))
    expect_equal(summary$column_count, ncol(se))
    expect_equal(summary$assay_names, assayNames(se))

    expect_true(file.exists(file.path(tmp, "row_data")))
    expect_true(file.exists(file.path(tmp, "column_data")))
})

test_that("ignoring SummarizedExperiment assays", {
    tmp <- tempfile()
    wobbegong:::wobbegongify_SummarizedExperiment(se, tmp, dense.assays=FALSE)
    summary <- jsonlite::fromJSON(file.path(tmp, "summary.json"))
    expect_equal(length(summary$assay_names), 0L) 

    tmp <- tempfile()
    assay(se, withDimnames=FALSE) <- Matrix::rsparsematrix(nrow(se), ncol(se), density=0.1)
    wobbegong:::wobbegongify_SummarizedExperiment(se, tmp, dense.assays=FALSE)
    summary <- jsonlite::fromJSON(file.path(tmp, "summary.json"))
    expect_equal(summary$assay_names, "counts")

    tmp <- tempfile()
    wobbegong:::wobbegongify_SummarizedExperiment(se, tmp, sparse.assays=FALSE)
    summary <- jsonlite::fromJSON(file.path(tmp, "summary.json"))
    expect_equal(summary$assay_names, "logcounts")

    tmp <- tempfile()
    assay(se, 1, withDimnames=FALSE) <- matrix("A", nrow(se), ncol(se))
    assay(se, 2, withDimnames=FALSE) <- array("A", c(nrow(se), ncol(se), 2L))
    wobbegong:::wobbegongify_SummarizedExperiment(se, tmp)
    summary <- jsonlite::fromJSON(file.path(tmp, "summary.json"))
    expect_equal(length(summary$assay_names), 0L) 
})
