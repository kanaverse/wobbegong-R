#include "Rcpp.h"
#include "byteme/byteme.hpp"

#include <vector>

//[[Rcpp::export(rng=false)]]
Rcpp::RawVector decompress(Rcpp::RawVector input) {
   auto ptr = static_cast<const unsigned char*>(input.begin());
   std::vector<unsigned char> output;
   byteme::ZlibBufferReader reader(ptr, input.size(), [&](){
       byteme::ZlibBufferReaderOptions opt;
       opt.mode = 0;
       return opt;
   }());
   while (reader.load()) {
      output.insert(output.end(), reader.buffer(), reader.buffer() + reader.available());
   }
   return Rcpp::RawVector(output.begin(), output.end());
}
