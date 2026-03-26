#include "Rcpp.h"
#include "byteme/byteme.hpp"

#include <vector>

//[[Rcpp::export(rng=false)]]
Rcpp::RawVector decompress(Rcpp::RawVector input) {
    auto ptr = static_cast<const unsigned char*>(input.begin());
    std::vector<unsigned char> output;

    byteme::ZlibBufferReader reader(ptr, input.size(), [&](){
        byteme::ZlibBufferReaderOptions opt;
        opt.mode = byteme::ZlibCompressionMode::DEFLATE;
        return opt;
    }());

    std::vector<unsigned char> buffer(65536);
    while (1) {
        auto available = reader.read(buffer.data(), buffer.size());
        output.insert(output.end(), buffer.begin(), buffer.begin() + available);
        if (available < buffer.size()) {
            break;
        }
    }

   return Rcpp::RawVector(output.begin(), output.end());
}
