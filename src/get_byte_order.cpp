#include "Rcpp.h"

#include <cstdint>
#include <limits>

//[[Rcpp::export(rng=false)]]
Rcpp::CharacterVector get_byte_order() {
    uint32_t val = 1;
    auto ptr = reinterpret_cast<unsigned char*>(&val);

    // must use IEEE754 doubles for the binary representation to be correct, see:
    // https://stackoverflow.com/questions/19351843/why-is-ieee-754-floating-point-not-exchangable-between-platforms
    static_assert(std::numeric_limits<double>::is_iec559);

    // check that we're using 2's complement, see:
    // https://stackoverflow.com/questions/64842669/how-to-test-if-a-target-has-twos-complement-integers-with-the-c-preprocessor
    // https://stackoverflow.com/questions/12276957/are-there-any-non-twos-complement-implementations-of-c
    static_assert((static_cast<int32_t>(-1) & static_cast<int32_t>(3)) == static_cast<int32_t>(3));

    if (ptr[0] == 1) {
        return Rcpp::CharacterVector::create("little_endian");
    } else {
        return Rcpp::CharacterVector::create("big_endian");
    }
}
