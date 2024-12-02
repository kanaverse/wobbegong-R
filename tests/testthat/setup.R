read_and_decompress_bytes <- function(path, start, length) {
    handle <- file(path, open="rb")
    on.exit(close(handle), add=TRUE, after=FALSE)
    seek(handle, where=start)
    compressed <- readBin(handle, what=raw(), n=length)
    wobbegong:::decompress(compressed)
}

read_integer <- function(path, start, length) {
    out <- read_and_decompress_bytes(path, start, length)
    readBin(out, integer(), n=length(out)/4L)
}

read_double <- function(path, start, length) {
    out <- read_and_decompress_bytes(path, start, length)
    readBin(out, double(), n=length(out)/8L)
}

read_boolean <- function(path, start, length) {
    out <- read_and_decompress_bytes(path, start, length)
    full <- as.logical(out)
    full[out == as.raw(2)] <- NA
    full
}

read_string <- function(path, start, length) {
    out <- read_and_decompress_bytes(path, start, length)
    endpoints <- which(out == as.raw(0))
    last <- 1L
    full <- character(length(endpoints))
    for (e in seq_along(endpoints)) {
        cure <- endpoints[e]
        full[e] <- rawToChar(out[last:cure])
        last <- cure + 1L
    }
    full[full == "�"] <- NA
    full
}
