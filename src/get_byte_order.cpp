#include "Rcpp.h"

#include <cstdint>

//[[Rcpp::export(rng=false)]]
Rcpp::CharacterVector get_byte_order() {
    uint32_t val = 1;
    auto ptr = reinterpret_cast<unsigned char*>(&val);
    if (ptr[0] == 1) {
        return Rcpp::CharacterVector::create("little_endian");
    } else {
        return Rcpp::CharacterVector::create("big_endian");
    }
}
