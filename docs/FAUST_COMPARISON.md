# Faust comparison

Faust is a functional DSP language with a block diagram algebra.
Six operators compose signal processors into graphs. Aither
achieves the same results with arithmetic and state.

## The six Faust operators

### `:` sequential composition

Connect output of A to input of B.

Faust:
```faust
process = osc(440) : *(0.5) : fi.lowpass(2, 800);
```

Aither:
```
sin(440) * 0.5 |> lpf(800, 0.5)
```

Same thing. `|>` is `:`. But in aither, `*` is just
multiplication — not a special one-input block that scales.
`0.5` is a number, not a signal processor.

### `,` parallel composition

Run A and B side by side as separate channels.

Faust:
```faust
process = osc(440), osc(880);
```

Aither:
```
[sin(440), sin(880)]
```

An array. Two channels. Or if you want them mixed:

```
sin(440) + sin(880)
```

Addition is mixing. No merge operator needed.

### `<:` split

Route one signal to multiple destinations.

Faust:
```faust
process = osc(440) <: fi.lowpass(2, 800), fi.highpass(2, 800);
```

Aither:
```
let x = sin(440)
[x |> lpf(800, 0.5), x |> hpf(800, 0.5)]
```

`let` binds the value. Use it as many times as you want.
No split operator — just a variable.

### `:>` merge

Sum multiple signals into one.

Faust:
```faust
process = osc(440), osc(880) :> _;
```

Aither:
```
sin(440) + sin(880)
```

Addition. Merge is `+`. Always was.

### `~` feedback

Route output back to input.

Faust:
```faust
process = + ~ (@(100) : *(0.95));
```

This reads: "add the input to a delayed, decayed copy of the
output." It's a feedback delay. The `~` operator creates the
loop. Understanding this requires tracing the signal flow
through the algebra.

Aither:
```
signal |> fbdelay(0.002, 0.01, 0.95)
```

Or with raw state:
```
$fb = signal + $fb * 0.95
```

The feedback is a state variable that reads its previous
value. `$fb` on the right is the last sample. `$fb` on
the left is the next sample. The loop is visible in the
assignment. No operator needed — mutation IS feedback.

### `!` cut

Discard a signal. Used in Faust to drop unwanted outputs
from multi-output blocks.

Aither: don't use the value. There's nothing to discard
because you only compute what you reference.

## Where Faust's algebra breaks down

Faust's operators form a closed algebra — you can compose
any block diagram. But the algebra is abstract:

```faust
process = _ <: (*(0.5) : fi.lowpass(2, 800)),
                (*(0.3) : fi.highpass(2, 2000))
          :> _;
```

To read this: "split input, scale by 0.5 into lowpass and
0.3 into highpass, merge." You trace signals through operators.
The topology is implicit in the nesting.

Aither:
```
let x = input
x * 0.5 |> lpf(800, 0.5) + x * 0.3 |> hpf(2000, 0.5)
```

You read left to right. `x` is the input. Two paths. Added.
The topology is visible in the arithmetic.

## Where Faust adds complexity

Faust needs a type system for signal routing. How many inputs
does this block have? How many outputs? Do they match when
composed? The compiler checks this. The error messages are
about "signal width mismatch."

Aither has no routing. A signal is a float. Two signals is
addition. A function takes floats, returns a float. There's
nothing to mismatch.

## The real difference

Faust thinks in **blocks and wires**. You build a circuit.
The operators are the wiring. The blocks are opaque.

Aither thinks in **values and math**. You compute a number.
The operators are arithmetic. Everything is transparent.

Faust: "connect oscillator block to filter block to gain block."
Aither: "the sound is `sin(440) |> lpf(800, 0.5) * 0.3`."

Same result. One describes the graph. The other describes
the value. The value is simpler because there's nothing
between you and the math.

## What Faust has that aither doesn't (yet)

- **Multi-rate processing** — run parts of the graph at
  different sample rates. Aither runs everything at one rate.
- **Automatic vectorization** — Faust's compiler can SIMD-
  optimize the block diagram. Aither relies on the C compiler.
- **Compile to many targets** — Faust outputs C++, LLVM, WASM,
  SOUL. Aither compiles to C via Nim (covers most targets).
- **Formal semantics** — Faust has a mathematical model of its
  block diagram algebra. Aither's semantics are "it's a function."

These are real advantages for Faust in specific domains
(plugin development, embedded DSP). For live coding,
experimentation, and signal exploration, aither's directness
wins.
