# This checks that the staging of the data frame is correct.
# library(testthat); library(wobbegong); source("setup.R"); source("test-DataFrame.R")

library(S4Vectors)
test_that("basic staging", {
    df <- DataFrame(A = 1:5, B = runif(5), C = c("akari", "ai", "alice", "alicia", "athena"), D = rbinom(5, 1, 0.5) == 1)

    tmp <- tempfile()
    dir.create(tmp)
    wobbegong:::wobbegongify_DataFrame(df, tmp)

    summary <- jsonlite::fromJSON(file.path(tmp, "summary.json"))
    expect_identical(summary$columns$names, c("A", "B", "C", "D"))
    expect_identical(summary$columns$types, c("integer", "double", "string", "boolean"))
    expect_false(summary$has_row_names)
    expect_identical(summary$row_count, 5L)

    conpath <- file.path(tmp, "content")
    ends <- cumsum(summary$columns$bytes)
    expect_identical(df$A, read_integer(conpath, 0L, summary$columns$bytes[1]))
    expect_identical(df$B, read_double(conpath, ends[1], summary$columns$bytes[2]))
    expect_identical(df$C, read_string(conpath, ends[2], summary$columns$bytes[3]))
    expect_identical(df$D, read_boolean(conpath, ends[3], summary$columns$bytes[4]))
})

test_that("staging with missing values", {
    df <- DataFrame(A = 1:5, B = runif(5), C = c("akari", "ai", "alice", "alicia", "athena"), D = rbinom(5, 1, 0.5) == 1)
    df$A[1] <- NA
    df$B[2] <- NA
    df$C[3] <- NA
    df$D[4] <- NA

    tmp <- tempfile()
    dir.create(tmp)
    wobbegong:::wobbegongify_DataFrame(df, tmp)

    summary <- jsonlite::fromJSON(file.path(tmp, "summary.json"))
    conpath <- file.path(tmp, "content")
    ends <- cumsum(summary$columns$bytes)
    expect_identical(df$A, read_integer(conpath, 0L, summary$columns$bytes[1]))
    expect_identical(df$B, read_double(conpath, ends[1], summary$columns$bytes[2]))
    expect_identical(df$C, read_string(conpath, ends[2], summary$columns$bytes[3]))
    expect_identical(df$D, read_boolean(conpath, ends[3], summary$columns$bytes[4]))
})

test_that("staging with factors", {
    df <- DataFrame(foo = runif(5), bar = factor(c("akari", "ai", "alice", "alicia", "athena")))

    tmp <- tempfile()
    dir.create(tmp)
    wobbegong:::wobbegongify_DataFrame(df, tmp)

    summary <- jsonlite::fromJSON(file.path(tmp, "summary.json"))
    conpath <- file.path(tmp, "content")
    ends <- cumsum(summary$columns$bytes)
    expect_identical(df$foo, read_double(conpath, 0L, summary$columns$bytes[1]))
    expect_identical(as.character(df$bar), read_string(conpath, ends[1], summary$columns$bytes[2]))
})

test_that("complex objects are ignored", {
    df <- DataFrame(foo = runif(5), foo2 = S4Vectors::I(cbind(1:5)), bar = c("akari", "ai", "alice", "alicia", "athena"), bar2 = S4Vectors::I(DataFrame(X = 1:5)))

    tmp <- tempfile()
    dir.create(tmp)
    wobbegong:::wobbegongify_DataFrame(df, tmp)

    summary <- jsonlite::fromJSON(file.path(tmp, "summary.json"))
    expect_identical(summary$columns$names, c("foo", "bar"))
    expect_identical(summary$columns$types, c("double", "string"))

    conpath <- file.path(tmp, "content")
    ends <- cumsum(summary$columns$bytes)
    expect_identical(df$foo, read_double(conpath, 0L, summary$columns$bytes[1]))
    expect_identical(df$bar, read_string(conpath, ends[1], summary$columns$bytes[2]))
})

test_that("staging with row names", {
    df <- DataFrame(foo = runif(5), bar = c("akari", "ai", "alice", "alicia", "athena"))
    rownames(df) <- c("mizunashi", "aino", "carroll", "florence", "glory")

    tmp <- tempfile()
    dir.create(tmp)
    wobbegong:::wobbegongify_DataFrame(df, tmp)
    summary <- jsonlite::fromJSON(file.path(tmp, "summary.json"))
    expect_true(summary$has_row_names)

    conpath <- file.path(tmp, "content")
    ends <- cumsum(summary$columns$bytes)
    expect_identical(df$foo, read_double(conpath, 0L, summary$columns$bytes[1]))
    expect_identical(df$bar, read_string(conpath, ends[1], summary$columns$bytes[2]))
    expect_identical(rownames(df), read_string(conpath, ends[2], summary$columns$bytes[3]))
})

test_that("staging with empty vectors", {
    df <- DataFrame(A = integer(0), B = character(0))

    tmp <- tempfile()
    dir.create(tmp)
    wobbegong:::wobbegongify_DataFrame(df, tmp)
    summary <- jsonlite::fromJSON(file.path(tmp, "summary.json"))
    expect_identical(summary$row_count, 0L)

    conpath <- file.path(tmp, "content")
    ends <- cumsum(summary$columns$bytes)
    expect_identical(df$A, read_integer(conpath, 0L, summary$columns$bytes[1]))
    expect_identical(df$B, read_string(conpath, ends[1], summary$columns$bytes[2]))
})
