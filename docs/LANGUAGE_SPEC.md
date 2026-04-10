# Aither Language Specification

The complete language definition. Both the browser transpiler
and the native compiler implement this spec.

## Overview

Aither is a language for real-time audio signal processing.
A program is a single expression that produces one float64
sample, evaluated 48,000 times per second.

Everything is a number. There is one type: float64.

## Globals

Available in every program without declaration:

| Name   | Description                    |
|--------|--------------------------------|
| `t`    | time in seconds (always advancing) |
| `dt`   | 1 / sample_rate               |
| `sr`   | sample rate (48000)            |
| `PI`   | 3.14159...                     |
| `TAU`  | 6.28318...                     |

## State variables

Prefix with `$`. Persistent across samples. Survive hot-swap.
Auto-initialized to 0.

```
$phase += 440 / sr
$env = $env * 0.999
$count = $count + 1
```

`$name` on the right reads the previous sample's value.
`$name` on the left writes the current sample's value.

## Literals

```
440         # integer (treated as float64)
0.5         # float
-1.0        # negative
[220, 330]  # array of float64
```

## Operators

### Arithmetic (in precedence order, high to low)

| Operator | Description      |
|----------|------------------|
| `-x`     | unary negation   |
| `*`, `/`, `mod` | multiply, divide, modulo |
| `+`, `-` | add, subtract    |
| `|>`     | pipe (lowest precedence) |

### Comparison

| Operator | Description       |
|----------|-------------------|
| `==`     | equal             |
| `!=`     | not equal         |
| `<`      | less than         |
| `>`      | greater than      |
| `<=`     | less or equal     |
| `>=`     | greater or equal  |

### Logical

| Operator | Description |
|----------|-------------|
| `and`    | logical and |
| `or`     | logical or  |
| `not`    | logical not |

True is any non-zero value. False is 0.

## Pipe operator

`|>` inserts the left side as the first argument of the
right side:

```
saw(55) |> lpf(800, 0.5) |> gain(0.3)

# equivalent to:
gain(lpf(saw(55), 800, 0.5), 0.3)
```

Left-to-right signal flow. Lowest precedence — arithmetic
binds tighter:

```
sin(440) * 0.5 |> lpf(800, 0.5)
# means: lpf(sin(440) * 0.5, 800, 0.5)
```

## Bindings

Immutable. Computed once per sample.

```
let freq = 440 + sin(0.3) * 50
let env = exp(-t * 4)
sin(freq) * env
```

Multiple bindings:

```
let a = sin(440)
let b = sin(442)
(a + b) * 0.3
```

## Conditionals

Expression-oriented. Always returns a value.

```
if $count > 1000 then osc(saw, 55) else osc(sin, 440)
```

With else-if:

```
if t < 4 then osc(sin, 440)
else if t < 8 then osc(saw, 220)
else noise() * 0.1
```

No blocks. No braces. No indentation required.
The branches are expressions, not statements.

## Functions

```
def pluck(freq):
  noise() * impulse(3) |> resonator(freq, 0.2)

def chord(root):
  osc(sin, root) + osc(sin, root * 5/4) + osc(sin, root * 3/2)

pluck(330) + chord(220) * 0.2
```

Functions are expressions — the last line is the return value.
Functions can use `$state` (scoped to the call site via DSP
counter). Functions can call other functions.

The body uses `:` to begin, and ends at the next `def`,
top-level expression, or end of file.

## DSP functions

Built-in. State is managed automatically — each call gets
its own persistent state via the DSP counter.

### Oscillators

One oscillator: `osc(shape, freq)`. The shape is a math
function. The oscillator manages the phasor internally.

```
osc(sin, 440)      # sine wave
osc(saw, 440)      # sawtooth
osc(tri, 440)      # triangle
osc(sqr, 440)      # square
osc(x => sin(x) + sin(3*x)/3, 440)  # custom harmonic
```

No shortcuts. Every oscillator is `osc`. The shape and the
clock are separate concepts composed together.

The shapes are plain math functions, usable independently
as waveshapers:

```
sin(signal * 5)    # sine waveshaping distortion
saw(signal * 3)    # sawtooth folding
```

Built-in shapes:

| Function | Formula | Description |
|----------|---------|-------------|
| `sin(x)` | sin(x) | sine curve |
| `saw(x)` | x * 2 - 1 | ramp -1 to 1 |
| `tri(x)` | abs(x * 4 - 2) - 1 | triangle fold |
| `sqr(x)` | if x < 0.5 then 1 else -1 | square |

Other oscillator functions:

| Function | Description |
|----------|-------------|
| `phasor(freq)` | raw ramp 0 to 1 |
| `wave(freq, [values])` | wavetable / sequencer |
| `noise()` | white noise |
| `pulse(freq, width)` | variable pulse width |

### Filters

| Function | Description |
|----------|-------------|
| `lpf(signal, cutoff, res)` | lowpass (SVF) |
| `hpf(signal, cutoff, res)` | highpass (SVF) |
| `bpf(signal, cutoff, res)` | bandpass (SVF) |
| `notch(signal, cutoff, res)` | notch (SVF) |
| `lp1(signal, cutoff)` | one-pole lowpass |
| `hp1(signal, cutoff)` | one-pole highpass |

### Effects

| Function | Description |
|----------|-------------|
| `delay(signal, time, maxTime)` | simple delay |
| `fbdelay(signal, time, maxTime, fb)` | feedback delay |
| `reverb(signal, rt60, wet)` | Schroeder reverb |
| `tremolo(signal, rate, depth)` | amplitude modulation |
| `slew(signal, time)` | portamento / smoothing |

### Physics

| Function | Description |
|----------|-------------|
| `impulse(freq)` | single-sample trigger |
| `resonator(signal, freq, decay)` | damped harmonic oscillator |
| `discharge(signal, rate)` | exponential decay envelope |

### Helpers

| Function | Description |
|----------|-------------|
| `gain(signal, amount)` | multiply |
| `fold(signal, amount)` | wavefolder |
| `decay(signal, rate)` | exp(-signal * rate) |
| `pan(signal, pos)` | stereo pan, returns [L, R] |

### Math

All math functions are stateless. They compute values.
They are also the shape functions passed to `osc`.

| Function | Description |
|----------|-------------|
| `sin(x)` | sine |
| `cos(x)` | cosine |
| `tan(x)` | tangent |
| `saw(x)` | sawtooth shape: x * 2 - 1 |
| `tri(x)` | triangle shape: abs(x * 4 - 2) - 1 |
| `sqr(x)` | square shape: if x < 0.5 then 1 else -1 |
| `exp(x)` | e^x |
| `log(x)` | natural log |
| `log2(x)` | log base 2 |
| `abs(x)` | absolute value |
| `floor(x)` | floor |
| `ceil(x)` | ceiling |
| `min(a, b)` | minimum |
| `max(a, b)` | maximum |
| `pow(a, b)` | exponentiation |
| `sqrt(x)` | square root |
| `clamp(x, lo, hi)` | clamp to range |

No ambiguity between oscillators and math. `sin` is always
the math function. `osc(sin, 440)` is the oscillator. The
oscillator is a composition of a shape and a clock — not a
separate concept.

## Arrays

### Polyphony (arrays as input)

When a DSP function receives an array, it runs once per
element with independent state. Results are summed.

```
osc(sin, [220, 330, 440]) * 0.3
# three oscillators, separate state, summed to mono
```

### Stereo (arrays as output)

Return an array of two for stereo:

```
osc(sin, 440) |> pan(0.3)
# returns [left, right]
```

Manual stereo:

```
[osc(sin, 440), osc(sin, 442)]
```

### Both

```
osc(sin, [220, 330, 440]) * 0.3 |> pan([-0.5, 0, 0.5])
# three voices, panned, summed to stereo
```

## Program structure

A program is one or more statements. The last expression
is the output sample.

```
# bindings
let freq = 440 + osc(sin, 0.3) * 50

# output (last expression)
osc(sin, freq) * 0.5
```

Statements are separated by newlines or semicolons:

```
let lfo = osc(sin, 0.3) * 50; osc(sin, 440 + lfo) * 0.5
```

## Comments

```
# single line comment
```

## Composition (future)

```
osc(sin, 440) |> lpf(800, 0.5)
  |> hold(8)
  osc(saw, 220) |> reverb(1.5, 0.3)
  |> hold(8)
  |> fadeout(4)
```

`hold(n)` sustains the current signal for n seconds,
then flow continues. State persists across sections.

## MIDI (future)

When MIDI is connected, additional globals:

| Name | Description |
|------|-------------|
| `midi_freq` | current note frequency (Hz) |
| `midi_gate` | 1 while key held, 0 on release |
| `midi_vel` | velocity 0-1 |
| `cc(n)` | control change value 0-1 |

```
osc(sin, midi_freq) * midi_vel * (midi_gate |> discharge(4))
```

## Signal references (future)

Signals can reference other signals by name. The value is
the previous sample's output:

```
# kick (separate file/signal)
impulse(2) |> resonator(60, 8)

# mix (references kick by name)
kick + hat * 0.3 |> reverb(1.5, 0.3)
```

## Implementation targets

### Browser (transpiler — parser in JS)

Parse aither syntax, emit JavaScript strings, eval with
`new Function()`. DSP stdlib written in aither, transpiled
to JS. AudioWorklet calls the function per sample.

### Native (compiler — parser in Nim)

Parse aither syntax, emit C. Compile with gcc (desktop) or
arm-gcc (PicoCalc/Teensy). DSP stdlib written in aither,
transpiled to C. Engine written in Nim.

Two separate parsers (~500 lines each), same grammar. The
browser parser emits JS. The native parser emits C.

## Complete example

```
# acid bass with pattern and filter envelope

let bpm = 128
let beat = phasor(bpm / 60)
let notes = [55, 55, 82, 55, 73, 55, 98, 55]
let freq = wave(bpm / 60, notes)
let env = impulse(bpm / 60) |> discharge(8)

osc(saw, freq)
  |> lpf(200 + env * 4000, 0.85)
  |> gain(0.4)
  |> delay(0.375, 0.5, 0.3)
```
