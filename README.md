# Format SummarizedExperiments for HTTP range requests

## Overview

The **wobbegong** R client converts `SummarizedExperiment` objects into files that can be easily interrogated via HTTP range requests.
The idea is to use a static file server to transfer parts of the object to the client for use in web applications.
Using the R client is very easy; just take your `SummarizedExperiment` and call the `wobbegongify()` function:

```r
library(wobbegong)
wobbegongify(my_se, "/my/server/directory")
```

This will dump a whole bunch of files at the requested directory.
Now, the real challenge is how to retrieve information from these files on the client.

## Directory structure

### For a `SummarizedExperiment`

The top-level directory (referred to here as `{DIR}`) has a number of files and subdirectories.
The most important is `{DIR}/summary.json`, which provides a summary of the `SummarizedExperiment`'s components.
This will have the following properties:

- `row_count`: integer, the number of rows.
- `column_count`: integer, the number of columns.
- `has_row_data`: boolean, whether any row annotations are available.
- `has_column_data`: boolean, whether any column annotations are available.
- `assay_names`: array of strings, the assay names.
- `reduced_dimension_names`: array of strings, the names of the reduced dimensions.
  Only available for `SingleCellExperiment` objects.

If `has_row_data = true`, a `{DIR}/row_data` subdirectory will be present, containing the row annotations in the [`DataFrame` directory layout](#for-a-dataframe).

If `has_column_data = true`, a `{DIR}/column_data` subdirectory will be present, containing the column annotations in the [`DataFrame` directory layout](#for-a-dataframe).

Any assay with more than two dimensions is not converted and is automatically excluded from `assay_names`.
Any non-integer, non-logical or non-double assays are also ignored.
Sparse and dense assays may be additionally excluded based on options in `wobbegongify()`.

For each element of `assay_names`, a subdirectory will be present at `{DIR}/assays/{i}` where `i` is the zero-based index within `assay_names`.
(For example, the first assay would be present at `{DIR}/assays/0`.)
This subdirectory uses the [assay matrix directory layout](#for-an-assay-matrix).

For each element of `reduced_dimensions`, a subdirectory will be present at `{DIR}/reduced_dimensions/{i}` where `i` is the zero-based index within `reduced_dimensions`.
(For example, the first reduced dimensionality result would be present at `{DIR}/reduced_dimensions/0`.)
This subdirectory uses the [reduced dimension directory layout](#for-reduced-dimensions).

### For a `DataFrame`

Each `DataFrame` directory contains a `summary.json` file and a `content` file.
The `summary.json` file has the following properties:

- `byte_order`: string, the byte order used for [encoding](#data-encoding).
- `row_count`: integer, the number of rows in the `DataFrame`.
- `has_row_names`: boolean, whether row names are present in the `DataFrame`.
- `columns`: object, information about the columns.
  - `names`: array of strings, the column names.
    Each value corresponds to one of the columns of the `DataFrame`.
  - `types`: array of strings, the type of each column (integer, boolean, string or double).
    Each value corresponds to an entry of `names`.
  - `bytes`: array of integers, the length (in bytes) of the range in `content` corresponding to each column.
    Each value corresponds to an entry of `names`.
    If `has_row_names = true`, an additional value is appended to the end of this array, representing the number of bytes of the range corresponding to the row names.

To retrieve a particular column, clients should take the cumulative sum of `bytes` to determine the range of bytes to request from `content`.
For example, if `bytes` is `[100, 200, 300]`, the first column could be retrieved by requesting bytes `0-99` in a HTTP range request;
the second column would be retrieved by requesting bytes `100-299`;
and the final column (or the row names, if `has_row_names = true`) would be retrieved with `300-599`.

Once a column is retrieved, it can be decoded according to its type in `types` - see the [Data encoding section](#data-encoding) for more details.

### For an assay matrix

Each assay matrix directory contains a `summary.json` file, a `content` file and `stats` file.
The `summary.json` file has the following properties:

- `byte_order`: string, the byte order used for [encoding](#data-encoding).
- `row_count`: integer, the number of rows in the matrix.
- `column_count`: integer, the number of rows in the matrix.
- `type`: string, the type of the matrix (integer, boolean or double).
- `format`: string, the matrix format (dense or sparse).
- `statistics`: object, information about the [statistics](#matrix-statistics).

#### Dense matrices

Dense matrices have the following additional properties in the `summary.json`:

- `row_bytes`: array of integers, the length (in bytes) of the range in `content` corresponding to each row of the matrix.
  This has length equal to `row_count`.

To retrieve a particular row, clients should take the cumulative sum of `row_bytes` to determine the range of bytes to request from `content`.
For example, if `row_bytes` is `[100, 200, 300]`, the first row could be retrieved by requesting bytes `0-99` in a HTTP range request;
the second row would be retrieved by requesting bytes `100-299`;
and the final row would be retrieved with `300-599`.

Once a row is retrieved from a dense matrix, it can be decoded according to the matrix `type` - see the [Data encoding section](#data-encoding) for more details.
Decoding yields an array that is guaranteed to be the same length as `column_count`.

#### Sparse matrices

Sparse matrices have the following additional properties in the `summary.json`:

- `row_bytes`: object, information about the structural non-zeros.
  - `value`: array of integers, the length (in bytes) of the range in `content` corresponding to the values of the structural non-zeros in each row of the matrix.
    This has length equal to `row_count`.
  - `index`: array of integers, the length (in bytes) of the range in `content` corresponding to the delta-encoded column indices of the structural non-zeros in each row.
    This has length equal to `row_count`.

To retrieve a particular row `r`, clients should compute the sum of `value` and `index` for all rows less than `r` -
this defines the starting byte within `content` for the contents of that row.
The next `value[r]` bytes contains the values of the structural non-zeros within `r`.
After that, the next `index[r]` bytes contains the delta-encoded indices of the structural non-zeroe.

To illustrate, let's say that `value` is `[100, 200, 300]` and `index` is `[10, 20, 30]`.
Values of the first row could be retrieved by requesting bytes `0-99`, while the delta-encoded indices could be retrieved by requesting bytes `100-109`.
Values of the second row could be retrieved by requesting bytes `110-309`, while the delta-encoded indices could be retrieved by requesting bytes `310-329`.
Values of the third row could be retrieved by requesting bytes `330-629`, while the delta-encoded indices could be retrieved by requesting bytes `630-659`.

Once the values are retrieved from a dense matrix, they can be decoded according to the matrix `type` - see the [Data encoding section](#data-encoding) for more details.
The delta-encoded indices are decoded as integers, which are decoded to the column indices by computing the cumulative sum across the array.
Both decoded arrays are guaranteed to be of the same length that is no greater than `column_count`.
Column indices (after decoding) are guaranteed to be zero-based and sorted in strictly ascending order.

#### Matrix statistics 

Both dense and sparse matrices will report several statistics in the `stats` file - typically, the row/column sums and the number of non-zero entries for each row/column.
This is described by the `statistics` property of `summary.json`, which contains the following properties:

- `names`: array of strings, the names of the statistics.
  This is guaranteed to have `row_sum`, `column_sum`, `row_nonzero` and `column_nonzero`. 
- `types`: array of strings, the types of the statistics.
- `bytes`: array of integers, the length (in bytes) of the range in `content` corresponding to each statistic.
  Each value corresponds to an entry of `names`.

To retrieve a particular statistic, clients should take the cumulative sum of `row_bytes` to determine the range of bytes to request from `stats`.
For example, if `row_bytes` is `[100, 200, 300, 400]`, the first statistic could be retrieved by requesting bytes `0-99` in a HTTP range request;
the second statistic would be retrieved by requesting bytes `100-299`;
and so on.

Once a statistic is retrieved, it can be decoded according to its type in `types` - see the [Data encoding section](#data-encoding) for more details.

### For reduced dimensions

Each reduced dimension directory contains a `summary.json` file and a `content` file. 
The `summary.json` file has the following properties:

- `byte_order`: string, the byte order used for [encoding](#data-encoding).
- `row_count`: integer, the number of rows in the reduced dimension matrix.
- `type`: string, the type of the data (integer, boolean, string or double).
- `column_bytes`: array of integers, the length (in bytes) of the range in `content` corresponding to each column of the reduced dimension matrix.
  The number of columns is defined by the length of this array.

To retrieve a particular column, clients should take the cumulative sum of `column_bytes` to determine the range of bytes to request from `content`.
For example, if `row_bytes` is `[100, 200, 300]`, the first column could be retrieved by requesting bytes `0-99` in a HTTP range request;
the second column would be retrieved by requesting bytes `100-299`;
and the final column would be retrieved with `300-599`.

Once a column is retrieved, it can be decoded according to its type in `types` - see the [Data encoding section](#data-encoding) for more details.

## Data encoding

### Basics

Integer data are encoded as a DEFLATE-compressed array of 32-bit signed integers in the specified `byte_order`.
Missing values are represented as -2147483648.

Double-precision data are encoded as a DEFLATE-compressed array of 64-bit IEEE double-precision floats in the specified `byte_order`.
This may contain IEEE special values like NaN and infinity.

Boolean data are encoded as a DEFLATE-compressed array of 8-bit unsigned integers. 
Values of 0 represent false, values of 1 represent true, and values of 2 are missing. 

String data are encoded as a DEFLATE-compressed array of null-terminated strings.
Each string can be assumed to follow the UTF-8 character encoding.
Missing values are represented by the Unicode replacement character (`U+FFFD`).

### Demonstration code

First let's set up some common utility functions:

```js
async function decompress(raw) {
    // See https://developer.mozilla.org/en-US/docs/Web/API/DecompressionStream
    // for the implementation status across browsers and frameworks.
    let dec = new DecompressionStream("deflate-raw");
    let bb = new Blob([raw]);
    let readable = bb.stream().pipeThrough(dec);

    let chunks = [];
    let total = 0;
    for await (const chunk of readable) {
        chunks.push(chunk)
        total += chunk.length;
    }

    let combined = new Uint8Array(total);
    let offset = 0;
    for (const chunk of chunks) {
        combined.set(chunk, offset);
        offset += chunk.length;
    }

    return combined;
}

function current_byte_order() { 
    let val = new Int32Array([1]);
    let view = new Uint8Array(val.buffer)
    return (view[0] == 1 ? "little_endian" : "big_endian");
}

function convert_byte_order(x, size) {
    for (let i = 0; i < x.length; i += size) {
        const sub = x.subarray(i, i + size);
        sub.reverse();
    }
}
```

Now we can decode integer data:

```js
let out = await decompress(range);
if (current_byte_order() != summary["byte_order"]) {
    convert_byte_order(out, 4);
}
let data = new Int32Array(out.buffer);
```

Doubles:

```js
let out = await decompress(range);
if (current_byte_order() != summary["byte_order"]) {
    convert_byte_order(out, 8);
}
let data = new Float64Array(out.buffer);
```

Booleans:

```js
let out = await decompress(range);
let data = Array.from(out);
for (const [i, v] of Object.entries(data)) {
    switch (v) {
        case 0: case 1:
            data[i] = (v != 0);
            break;
        default:
            data[i] = null;
    }
}
```

And strings:

```js
let out = await decompress(range);
let last = 0;
let data = [];
const dec = new TextDecoder;
for (let i = 0; i < out.length; i++) {
    if (out[i] == 0) {
        const view = out.subarray(last, i);
        let curstr = dec.decode(view);
        if (curstr == "�") {
            curstr = null;
        }
        data.push(curstr);
        last = i + 1;
    }
}
```
