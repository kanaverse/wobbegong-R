#include "Rcpp.h"

#include "Rtatami.h"
#include "byteme/byteme.hpp"

#include "utils.h"

#include <filesystem>
#include <cstdio>
#include <cstdint>

std::vector<unsigned char> recompress(const std::string& path, std::vector<unsigned char>& buffer, const unsigned char* leftovers, const std::pair<size_t, size_t>& leftover_offsets) {
    byteme::ZlibBufferWriter writer(/* mode = */ 0);

    if (std::filesystem::exists(path)) {
        auto handle = std::fopen(path.c_str(), "rb");
        if (handle == NULL) {
            throw std::runtime_error("failed to open file at '" + path + "'");
        }

        try {
            while (true) {
                auto read = std::fread(buffer.data(), sizeof(unsigned char), buffer.size(), handle);
                writer.write(buffer.data(), read);
                if (read < buffer.size()) {
                    break;
                }
            }
        } catch (std::exception& e) {
            std::fclose(handle);
            throw;
        }
        std::fclose(handle);
    }

    auto start = leftover_offsets.first;
    auto end = leftover_offsets.second;
    writer.write(leftovers + start, end - start);
    writer.finish();
    return writer.output;
}

std::pair<const unsigned char*, size_t> transfer_values(const double* ptr, int32_t n, int sexp_type, std::vector<int32_t>& ibuffer, std::vector<uint8_t>& lbuffer) {
    if (sexp_type == INTSXP) {
        std::copy_n(ptr, n, ibuffer.data());
        return std::make_pair(reinterpret_cast<const unsigned char*>(ibuffer.data()), n * sizeof(int32_t));
    } else if (sexp_type == LGLSXP) {
        for (int32_t i = 0; i < n; ++i, ++ptr) {
            lbuffer[i] = transfer_boolean(*ptr);
        }
        return std::make_pair(reinterpret_cast<const unsigned char*>(lbuffer.data()), n * sizeof(uint8_t));
    } else {
        return std::make_pair(reinterpret_cast<const unsigned char*>(ptr), n * sizeof(double));
    }
}

size_t get_element_size(int sexp_type) {
    if (sexp_type == INTSXP) {
        return sizeof(int32_t);
    } else if (sexp_type == LGLSXP) {
        return sizeof(uint8_t);
    } else {
        return sizeof(double);
    }
}

template<typename T>
void add_to_working_buffer(T val, unsigned char* buffer, size_t& pos) {
    std::copy_n(reinterpret_cast<const unsigned char*>(&val), sizeof(T), buffer + pos);
    pos += sizeof(T);
}

//[[Rcpp::export(rng=false)]]
Rcpp::List dump_dense_rows(Rcpp::RObject mat, std::string output_file, std::string rtype) {
    Rtatami::BoundNumericPointer parsed(mat);
    const auto& mptr = parsed->ptr;
    int NR = mptr->nrow();
    int NC = mptr->ncol();

    byteme::RawFileWriter ohandle(output_file);
    Rcpp::IntegerVector payloads(NR);
    Rcpp::NumericVector rowsums(NR), colsums(NC);
    Rcpp::IntegerVector rownnz(NR), colnnz(NC);

    auto sexp_type = translate_type(rtype);

    auto ext = tatami::consecutive_extractor<true, false>(mptr.get(), 0, NR);
    std::vector<double> buffer(NC);
    std::vector<int32_t> int_buffer(sexp_type == INTSXP ? NC : 0);
    std::vector<uint8_t> lgl_buffer(sexp_type == LGLSXP ? NC : 0);

    for (int r = 0; r < NR; ++r) {
        auto ptr = ext->fetch(r, buffer.data());

        double& sum = rowsums[r];
        int& count = rownnz[r];
        if (sexp_type == INTSXP) {
            for (int c = 0; c < NC; ++c) {
                auto val = ptr[c];
                if (val != static_cast<double>(NA_INTEGER)) {
                    sum += val;
                    count += (val != 0);
                    colsums[c] += val;
                    colnnz[c] += (val != 0);
                }
            }
        } else if (sexp_type == LGLSXP) {
            for (int c = 0; c < NC; ++c) {
                auto val = ptr[c];
                if (val != static_cast<double>(NA_LOGICAL)) {
                    sum += val;
                    count += (val != 0);
                    colsums[c] += val;
                    colnnz[c] += (val != 0);
                }
            }
        } else {
            for (int c = 0; c < NC; ++c) {
                auto val = ptr[c];
                if (!ISNAN(val)) {
                    sum += val;
                    count += (val != 0);
                    colsums[c] += val;
                    colnnz[c] += (val != 0);
                }
            }
        }

        // Using raw DELATE here.
        auto transferred = transfer_values(ptr, NC, sexp_type, int_buffer, lgl_buffer);
        byteme::ZlibBufferWriter writer(/* mode = */ 0);
        writer.write(transferred.first, transferred.second);
        writer.finish();

        const auto& compact = writer.output;
        ohandle.write(compact.data(), compact.size());
        payloads[r] = compact.size();
    }

    ohandle.finish();
    return Rcpp::List::create(
        Rcpp::Named("size") = payloads,
        Rcpp::Named("statistics") = Rcpp::List::create(
            Rcpp::Named("row_sum") = rowsums,
            Rcpp::Named("row_nonzero") = rownnz,
            Rcpp::Named("column_sum") = colsums,
            Rcpp::Named("column_nonzero") = colnnz
        )
    );
}

//[[Rcpp::export(rng=false)]]
Rcpp::List dump_sparse_rows(Rcpp::RObject mat, std::string output_file, std::string rtype) {
    Rtatami::BoundNumericPointer parsed(mat);
    const auto& mptr = parsed->ptr;
    int NR = mptr->nrow();
    int NC = mptr->ncol();

    byteme::RawFileWriter ohandle(output_file);
    Rcpp::IntegerVector vpayload(NR), ipayload(NR);
    Rcpp::NumericVector rowsums(NR), colsums(NC);
    Rcpp::IntegerVector rownnz(NR), colnnz(NC);

    auto sexp_type = translate_type(rtype);
    auto ext = tatami::consecutive_extractor<true, true>(mptr.get(), 0, NR);
    std::vector<double> vbuffer(NC);
    std::vector<int> ibuffer(NC);
    std::vector<int32_t> int_buffer(NC);
    std::vector<uint8_t> lgl_buffer(sexp_type == LGLSXP ? NC : 0);

    for (int r = 0; r < NR; ++r) {
        auto range = ext->fetch(r, vbuffer.data(), ibuffer.data());
        auto transferred = transfer_values(range.value, range.number, sexp_type, int_buffer, lgl_buffer);

        double& sum = rowsums[r];
        int& count = rownnz[r];
        if (sexp_type == INTSXP || sexp_type == LGLSXP) {
            for (int i = 0; i < range.number; ++i) {
                auto val = range.value[i];
                if (val != static_cast<double>(NA_INTEGER)) {
                    sum += val;
                    count += (val != 0);
                    auto c = range.index[i];
                    colsums[c] += val;
                    colnnz[c] += (val != 0);
                }
            }
        } else if (sexp_type == LGLSXP) {
            for (int i = 0; i < range.number; ++i) {
                auto val = range.value[i];
                if (val != static_cast<double>(NA_LOGICAL)) {
                    sum += val;
                    count += (val != 0);
                    auto c = range.index[i];
                    colsums[c] += val;
                    colnnz[c] += (val != 0);
                }
            }
        } else {
            for (int i = 0; i < range.number; ++i) {
                auto val = range.value[i];
                if (!ISNA(val)) {
                    sum += val;
                    count += (val != 0);
                    auto c = range.index[i];
                    colsums[c] += val;
                    colnnz[c] += (val != 0);
                }
            }
        }

        byteme::ZlibBufferWriter vwriter(/* mode = */ 0);
        vwriter.write(transferred.first, transferred.second);
        vwriter.finish();

        if (range.number) { // delta-encoding the indices to save space.
            int_buffer[0] = range.index[0];
            for (int i = 1; i < range.number; ++i) {
                int_buffer[i] = range.index[i] - range.index[i - 1]; 
            }
        }

        byteme::ZlibBufferWriter iwriter(/* mode = */ 0);
        iwriter.write(reinterpret_cast<const unsigned char*>(int_buffer.data()), range.number * sizeof(int32_t));
        iwriter.finish();

        const auto& vcompact = vwriter.output;
        ohandle.write(vcompact.data(), vcompact.size());
        vpayload[r] = vcompact.size();

        const auto& icompact = iwriter.output;
        ohandle.write(icompact.data(), icompact.size());
        ipayload[r] = icompact.size();
    }

    ohandle.finish();
    return Rcpp::List::create(
        Rcpp::Named("value_size") = vpayload,
        Rcpp::Named("index_size") = ipayload,
        Rcpp::Named("statistics") = Rcpp::List::create(
            Rcpp::Named("row_sum") = rowsums,
            Rcpp::Named("row_nonzero") = rownnz,
            Rcpp::Named("column_sum") = colsums,
            Rcpp::Named("column_nonzero") = colnnz
        )
    );
}
