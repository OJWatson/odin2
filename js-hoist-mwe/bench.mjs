// Run model_before.mjs (odin2 as it is) and model_after.mjs (look-ups hoisted) on the same inputs: check the final
// states are bit-identical, then time them.
// Usage: node bench.mjs [n_age ...]   (default 10 50 100); 3650 daily steps, 3 vaccine strata.
import { System } from "@reside-ic/dust2";
import before from "./model_before.mjs";
import after from "./model_after.mjs";

const sizes = process.argv.length > 2 ? process.argv.slice(2).map(Number) : [10, 50, 100];
const nVacc = 3, nSteps = 3650, reps = 7;

function pars(nAge) {
  const contact = [], vacc_rate = [], S0 = [], I0 = [];
  // odin arrays are column-major: element [i, j] is at i + j * nrow
  for (let j = 0; j < nAge; j++) for (let i = 0; i < nAge; i++) contact.push(Math.exp(-Math.abs(i - j) / 5) / 5);
  for (let j = 0; j < nVacc; j++) for (let i = 0; i < nAge; i++) {
    vacc_rate.push(j < nVacc - 1 ? 0.002 : 0);
    S0.push(j === 0 ? 10000 : 0);
    I0.push(j === 0 && i === Math.floor(nAge / 5) ? 10 : 0);
  }
  return { n_age: nAge, n_vacc: nVacc, contact, vacc_rate, efficacy: [0, 0.6, 0.9], S0, I0 };
}

// dust2-js does not expose the `imports` object it passes to generated code, so capture it from a throwaway System
function getImports(gen, p) {
  let imports;
  const probe = { ...gen, buildParams(im, q) { imports = im; return gen.buildParams(im, q); } };
  System.createDiscrete(probe, p, 0, 1, 1, undefined, { binomial: () => 0 });
  return imports;
}

// Call the generated update() directly on two swapped Float64Arrays, so the time is the generated code's alone
// (going through System adds per-step copying that is the same for both versions).
function run(gen, p) {
  const im = getImports(gen, p);
  const params = gen.buildParams(im, p);
  const internal = gen.buildInternal(im, params);
  let state = new Float64Array(params.odin.packing.length);
  let next = new Float64Array(state.length);
  gen.initial(im, 0, params, internal, state, null);
  const t0 = performance.now();
  for (let t = 0; t < nSteps; t++) {
    gen.update(im, t, 1, state, params, internal, next, null);
    [state, next] = [next, state];
  }
  return { ms: performance.now() - t0, state };
}

const median = (x) => [...x].sort((a, b) => a - b)[Math.floor(x.length / 2)];
console.log(`${nSteps} steps, median of ${reps} runs after warm-up, node ${process.version}\n`);
console.log("n_age  state  identical  before (ms)  after (ms)  speed-up");
for (const nAge of sizes) {
  const p = pars(nAge);
  const a = run(before, p), b = run(after, p);
  const identical = a.state.length === b.state.length && a.state.every((v, i) => Object.is(v, b.state[i]));
  for (let w = 0; w < 2; w++) { run(before, p); run(after, p); }
  const tb = [], ta = [];
  for (let r = 0; r < reps; r++) { tb.push(run(before, p).ms); ta.push(run(after, p).ms); }
  const mb = median(tb), ma = median(ta);
  console.log(`${String(nAge).padStart(5)}  ${String(a.state.length).padStart(5)}  ${String(identical).padStart(9)}  ` +
    `${mb.toFixed(1).padStart(11)}  ${ma.toFixed(1).padStart(10)}  ${(mb / ma).toFixed(1).padStart(7)}x`);
}
