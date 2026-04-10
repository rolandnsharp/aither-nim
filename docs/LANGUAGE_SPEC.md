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
if $count > 1000 then saw(55) else sin(440)
```

With else-if:

```
if t < 4 then sin(440)
else if t < 8 then saw(220)
else noise() * 0.1
```

No blocks. No braces. No indentation required.
The branches are expressions, not statements.

## Functions

```
def pluck(freq):
  noise() * impulse(3) |> resonator(freq, 0.2)

def chord(root):
  sin(root) + sin(root * 5/4) + sin(root * 3/2)

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

| Function | Description |
|----------|-------------|
| `sin(freq)` | sine wave |
| `saw(freq)` | sawtooth |
| `tri(freq)` | triangle |
| `square(freq)` | square wave |
| `pulse(freq, width)` | variable pulse width |
| `phasor(freq)` | ramp 0 to 1 |
| `wave(freq, [values])` | wavetable / sequencer |
| `noise()` | white noise |

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

### Math (pass-through from host language)

| Function | Description |
|----------|-------------|
| `sin(x)` | sine (math, not oscillator — one arg) |
| `cos(x)` | cosine |
| `tan(x)` | tangent |
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

Note: `sin(440)` (one arg) is math sine. `sin(440)` as a
DSP oscillator is distinguished by context — if it appears
in a pipe or its result is piped, it's the oscillator.
Actually: the DSP oscillator uses the phasor internally.
The math `sin` is just `Math.sin`. The distinction:

- `sin(freq)` where freq is meant as Hz → DSP oscillator
- `sin(x)` where x is a phase/angle → math function

This ambiguity is resolved by naming the oscillator `osc_sin`
or by using `sine` for the oscillator and `sin` for math.

**Resolution: use `sine` for the oscillator, `sin` for math:**

```
sine(440) |> lpf(800, 0.5)        # oscillator at 440 Hz
sin(TAU * $phase) * 0.3            # math sine of a value
```

This applies to all oscillator/math conflicts:
- `sine` / `sin`
- No conflict for `saw`, `tri`, `square`, `noise` — no math equivalents

## Arrays

### Polyphony (arrays as input)

When a DSP function receives an array, it runs once per
element with independent state. Results are summed.

```
sine([220, 330, 440]) * 0.3
# three oscillators, separate state, summed to mono
```

### Stereo (arrays as output)

Return an array of two for stereo:

```
sine(440) |> pan(0.3)
# returns [left, right]
```

Manual stereo:

```
[sine(440), sine(442)]
```

### Both

```
sine([220, 330, 440]) * 0.3 |> pan([-0.5, 0, 0.5])
# three voices, panned, summed to stereo
```

## Program structure

A program is one or more statements. The last expression
is the output sample.

```
# bindings
let freq = 440 + sine(0.3) * 50

# state updates
$phase += freq / sr

# output (last expression)
sin(TAU * $phase) * 0.5
```

Statements are separated by newlines or semicolons:

```
$phase += 440 / sr; sin(TAU * $phase) * 0.5
```

## Comments

```
# single line comment
```

## Composition (future)

```
sine(440) |> lpf(800, 0.5)
  |> hold(8)
  saw(220) |> reverb(1.5, 0.3)
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
sine(midi_freq) * midi_vel * (midi_gate |> discharge(4))
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

### Browser (transpiler)

Parse aither syntax, emit JavaScript strings, eval with
`new Function()`. The DSP stdlib is hand-written JS
(stdlib.js). The AudioWorklet calls the function per sample.

### Native (compiler)

Parse aither syntax, emit Nim AST or C code. Compile to
native binary. DSP stdlib is compiled Nim (dsp.nim).

### Embedded (interpreter)

Parse aither syntax, compile to bytecode, execute in a
stack VM. DSP stdlib is compiled C/Nim called via function
table. Runs on PicoCalc, Teensy, any microcontroller.

## Complete example

```
# acid bass with pattern and filter envelope

let bpm = 128
let beat = phasor(bpm / 60)
let notes = [55, 55, 82, 55, 73, 55, 98, 55]
let freq = wave(bpm / 60, notes)
let env = impulse(bpm / 60) |> discharge(8)

saw(freq)
  |> lpf(200 + env * 4000, 0.85)
  |> gain(0.4)
  |> delay(0.375, 0.5, 0.3)
```
