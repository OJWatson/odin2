# Speed of odin2's generated JavaScript: look-ups inside loops

A small example of where the time goes in the JavaScript odin2 generates on `odin2-js-wip`, and how much is saved by
reading dimensions, parameters and internals once per call instead of on every loop iteration. It's here to show the
issue, not as a proposed implementation.

## The issue

`generate_js_sexp()` writes every dimension, parameter and internal as a property chain (`params.dim.foi.mult[1]`,
`params.contact`, `internal.foi`), and `generate_js_array_loops()` puts these inside the loops, so they are looked up
again for every element on every step. From `model_before.mjs` (the FOI matrix in `update()`):

```js
for (let i = 1; i <= params.dim.foi.dim[0]; i++) {
  for (let j = 1; j <= params.dim.foi.dim[1]; j++) {
    internal.foi[i - 1 + (j - 1) * params.dim.foi.mult[1]] = params.contact[i - 1 + (j - 1) * params.dim.contact.mult[1]] * internal.I_age[j - 1] / internal.N_age[j - 1];
  }
}
```

The generated C++ has the same pattern (`shared.dim.foi.mult[1]`), but there the compiler moves loop-invariant reads
out of the loop itself. V8 doesn't reliably do that, particularly for large functions, so the JS pays for it.

Reading each one once at the top of `update()` (`model_after.mjs`) gives the same loop as:

```js
const _dim_foi_dim_0 = params.dim.foi.dim[0];
const _dim_foi_mult_1 = params.dim.foi.mult[1];
const _p_contact = params.contact;
const _i_foi = internal.foi;
// ...
for (let i = 1; i <= _dim_foi_dim_0; i++) {
  for (let j = 1; j <= _dim_foi_dim_1; j++) {
    _i_foi[i - 1 + (j - 1) * _dim_foi_mult_1] = _p_contact[i - 1 + (j - 1) * _dim_contact_mult_1] * _i_I_age[j - 1] / _i_N_age[j - 1];
  }
}
```

Nothing changes within a call, so the results are bit-identical.

## The example

- `model.R`: a deterministic discrete-time SEIR by age and vaccine stratum (3 strata), with ageing, vaccination and a
  contact matrix. `n_age` sets the size.
- `run.sh`: installs odin2 at `ff5d050` (the tip of `odin2-js-wip` when this was written; change with `BASE=`) and at
  this branch into temporary libraries, writes `model_before.mjs` and `model_after.mjs` with `generate.R`, then runs
  `bench.mjs`.
- `bench.mjs`: steps each generated `update()` directly for 3650 days, checks the final states are bit-identical, and
  reports the median of 7 timed runs.
- `model_before.mjs` / `model_after.mjs`: the generated files, committed so they can be compared without running anything.

```
cd js-hoist-mwe
./run.sh              # n_age 10, 50, 100
./run.sh 200          # other sizes
```

Needs R with odin2's dependencies, and node >= 18 (`run.sh` installs `@reside-ic/dust2` for the runtime the generated
code imports).

## Results

Laptop, node 24.22:

```
n_age  state  identical  before (ms)  after (ms)  speed-up
   10    120       true         82.4        12.7      6.5x
   50    600       true        588.5        50.3     11.7x
  100   1200       true       1461.4       123.9     11.8x
```

The same rewrite on a much larger model (PREVAIL, a 140 KB `update()`) took a 3-year run from ~1.2 s to ~225 ms
(compiled C++ is ~75 ms).

## How `model_after.mjs` was made

On this branch, `js_hoist_lookups()` (`R/util_js.R`) is a text pass over the generated `update()`, `rhs()` and
`output()` bodies, applied in `generate_js_parts()`. It's the quickest way to get the "after" code, not a suggestion for
how to do it properly. Doing it in `generate_js_sexp()` itself (emitting local names and collecting the declarations)
would be cleaner.
