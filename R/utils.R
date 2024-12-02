translate_type <- function(rtype) {
    if (rtype == "logical") {
        "boolean"
    } else if (rtype == "character") {
        "string"
    } else {
        rtype
    } 
}
