#include "Rcpp.h"
#include "byteme/byteme.hpp"
#include "utils.h"

#include <filesystem>
#include <cstdio>
#include <cstdint>
#include <cstring>

//[[Rcpp::export(rng=false)]]
Rcpp::IntegerVector dump_list_of_vectors(Rcpp::List incoming, std::string output_file) {
    size_t nelements = incoming.size();
    byteme::RawFileWriter ohandle(output_file);
    Rcpp::IntegerVector collected(nelements);

    std::vector<char> str_buffer;
    std::vector<int32_t> int_buffer;
    std::vector<uint8_t> lgl_buffer;

    for (size_t e = 0; e < nelements; ++e) {
        Rcpp::RObject current(incoming[e]);
        int vtype = current.sexp_type();
        byteme::ZlibBufferWriter writer(/* mode = */ 0);

        switch (vtype) {
            case INTSXP:
                {
                    Rcpp::IntegerVector vec(current);
                    if constexpr(std::is_same<int, int32_t>::value) {
                        const int* ptr = static_cast<const int*>(vec.begin());
                        writer.write(reinterpret_cast<const unsigned char*>(ptr), vec.size() * sizeof(int32_t));
                    } else {
                        int_buffer.resize(vec.size());
                        std::copy(vec.begin(), vec.end(), int_buffer.begin());
                        writer.write(reinterpret_cast<const unsigned char*>(int_buffer.data()), vec.size() * sizeof(int32_t));
                    }
                }
                break;

            case LGLSXP:
                {
                    Rcpp::LogicalVector vec(current);
                    lgl_buffer.resize(vec.size());
                    for (size_t i = 0, end = vec.size(); i < end; ++i) {
                        lgl_buffer[i] = transfer_boolean(vec[i]);
                    }
                    writer.write(reinterpret_cast<const unsigned char*>(lgl_buffer.data()), vec.size() * sizeof(uint8_t));
                }
                break;

            case REALSXP:
                {
                    Rcpp::NumericVector vec(current);
                    const double* ptr = static_cast<const double*>(vec.begin());
                    writer.write(reinterpret_cast<const unsigned char*>(ptr), vec.size() * sizeof(double));
                }
                break;

            case STRSXP:
                {
                    Rcpp::CharacterVector vec(current);
                    str_buffer.clear();
                    for (size_t i = 0, end = vec.size(); i < end; ++i) {
                        if (Rcpp::CharacterVector::is_na(vec[i])) {
                            str_buffer.push_back(0xEF);
                            str_buffer.push_back(0xBF);
                            str_buffer.push_back(0xBD);
                        } else {
                            Rcpp::String current(vec[i]);
                            const char* ptr = current.get_cstring();
                            str_buffer.insert(str_buffer.end(), ptr, ptr + std::strlen(ptr));
                        }
                        str_buffer.push_back('\0');
                    }
                    writer.write(reinterpret_cast<const unsigned char*>(str_buffer.data()), str_buffer.size());
                }
                break;

            default:
                throw std::runtime_error("unknown vector full_type " + std::to_string(vtype));
        }

        writer.finish();
        ohandle.write(writer.output.data(), writer.output.size());
        collected[e] = writer.output.size();
    }

    ohandle.finish();
    return collected;
}
