#ifndef UTILS_H
#define UTILS_H
#include "Rcpp.h"
#include <cstdint>

template<typename T>
uint8_t transfer_boolean(T val) {
    if (val == static_cast<T>(NA_LOGICAL)) {
        return 2;
    } else {
        return val > 0;
    }
}

inline int translate_type(const std::string& rtype) {
    if (rtype == "boolean") {
        return LGLSXP;
    } else if (rtype == "integer") {
        return INTSXP;
    } else if (rtype == "double") {
        return REALSXP;
    } else {
        throw std::runtime_error("unsupported matrix type '" + rtype + "'");
    }
}

#endif
