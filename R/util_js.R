js_method <- function(name, args, body) {
  c(
    sprintf("%s(%s) {", name, paste0(args, collapse = ", ")),
    sprintf("  %s", body),
    "},"
  )
}


## Hoist look-ups in a generated method (see js_hoist_lookups); the
## declarations go at the top of the method body.
js_hoist_method <- function(code) {
  n <- length(code)
  if (n < 3) {
    return(code)
  }
  body <- sub("^  ", "", code[-c(1, n)])
  c(code[[1]], sprintf("  %s", js_hoist_lookups(body)), code[[n]])
}


## The generated update(), rhs() and output() methods read dimensions,
## parameters and internal arrays through property chains such as
## `params.dim.S.mult[1]` and `internal.foi`, and these sit inside the
## array loops, so they are re-evaluated for every element on every
## step. JavaScript engines do not reliably move these out of the
## loops (particularly for large methods), unlike a C++ compiler for
## the equivalent dust2 code. This reads each one once into a local
## constant at the top of the method. None of them change during a
## call: shared state is never written outside buildParams(), and an
## internal is only aliased if the method never reassigns it as a
## whole (interpolated values are). Local names start with an
## underscore, which odin variable names cannot, so they never clash.
js_hoist_lookups <- function(body) {
  if (length(body) == 0) {
    return(body)
  }
  text <- paste(body, collapse = "\n")
  id <- "[A-Za-z][A-Za-z0-9_]*"
  rules <- list(
    list(re = sprintf("params\\.dim\\.(%s)\\.(dim|mult)\\[([0-9]+)\\]", id),
         local = "_dim_\\1_\\2_\\3"),
    list(re = sprintf("params\\.dim\\.(%s)\\.size", id),
         local = "_dim_\\1_size"),
    list(re = sprintf("params\\.dim\\.(%s)", id),
         local = "_dim_\\1"),
    list(re = sprintf("params\\.odin\\.packing\\.idx\\.(%s)\\.start", id),
         local = "_idx_\\1_start"),
    list(re = sprintf("params\\.(%s)", id),
         local = "_p_\\1"),
    list(re = sprintf("internal\\.(%s)", id),
         local = "_i_\\1"))

  reassigned <- regmatches(
    text,
    gregexpr(sprintf("(params|internal)\\.%s(?= = )", id), text,
             perl = TRUE))[[1]]

  decl <- character()
  for (r in rules) {
    ## (?![A-Za-z0-9_.(]) stops `params.dim.S` matching the start of
    ## `params.dim.S.mult[1]` and keeps method calls off the list.
    re <- sprintf("%s(?![A-Za-z0-9_.(])", r$re)
    found <- unique(regmatches(text, gregexpr(re, text, perl = TRUE))[[1]])
    found <- setdiff(found, c("params.odin", reassigned))
    if (length(found) == 0) {
      next
    }
    local <- sub(r$re, r$local, found, perl = TRUE)
    decl <- c(decl, sprintf("const %s = %s;", local, found))
    for (k in seq_along(found)) {
      pat <- gsub("([.\\[\\]])", "\\\\\\1", found[[k]], perl = TRUE)
      pat <- sprintf("%s(?![A-Za-z0-9_.(])", pat)
      text <- gsub(pat, local[[k]], text, perl = TRUE)
    }
  }
  c(decl, strsplit(text, "\n", fixed = TRUE)[[1]])
}
