test_that("can create simple js functions", {
  expect_equal(
    js_method("a", c("x", "y"), "return x + y;"),
    c("a(x, y) {",
      "  return x + y;",
      "},")
  )
})


test_that("hoists dimension, parameter and internal look-ups out of loops", {
  body <- c(
    "for (let i = 1; i <= params.dim.x.dim[0]; i++) {",
    "  internal.y[i - 1 + params.dim.x.mult[1]] = params.a * params.ab;",
    "  stateNext[params.odin.packing.idx.x.start + i - 1] = params.dim.x.size;",
    "}")
  expect_equal(
    js_hoist_lookups(body),
    c("const _dim_x_dim_0 = params.dim.x.dim[0];",
      "const _dim_x_mult_1 = params.dim.x.mult[1];",
      "const _dim_x_size = params.dim.x.size;",
      "const _idx_x_start = params.odin.packing.idx.x.start;",
      "const _p_a = params.a;",
      "const _p_ab = params.ab;",
      "const _i_y = internal.y;",
      "for (let i = 1; i <= _dim_x_dim_0; i++) {",
      "  _i_y[i - 1 + _dim_x_mult_1] = _p_a * _p_ab;",
      "  stateNext[_idx_x_start + i - 1] = _dim_x_size;",
      "}"))
})


test_that("does not hoist internals that are reassigned, or method calls", {
  body <- c("internal.z = params.z_interp.eval(time);",
            "stateNext[0] = internal.z + internal.w;")
  expect_equal(
    js_hoist_lookups(body),
    c("const _i_w = internal.w;",
      "internal.z = params.z_interp.eval(time);",
      "stateNext[0] = internal.z + _i_w;"))
})


test_that("generated update() reads look-ups once at the top", {
  dat <- odin_parse({
    a <- parameter()
    n <- parameter(3)
    update(x[]) <- x[i] + a
    initial(x[]) <- 0
    dim(x) <- n
  })
  dat <- generate_prepare(dat)
  expect_equal(
    generate_js_parts()$update(dat),
    c("update(imports, time, dt, state, params, internal, stateNext, random) {",
      "  const _dim_x_dim_0 = params.dim.x.dim[0];",
      "  const _p_a = params.a;",
      "  const unpacked = params.odin.packing.unpackArray(state);",
      "  const x = unpacked.get('x').data;",
      "  for (let i = 1; i <= _dim_x_dim_0; i++) {",
      "    stateNext[i - 1 + 0] = x[i - 1] + _p_a;",
      "  }",
      "},"))
})
