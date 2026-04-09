# Multichannel: stereo and polyphony

Two concepts. One syntax. Arrays.

## The rule

- Arrays going IN = polyphony (run N copies, separate state, sum to mono)
- Arrays coming OUT = channels (route to speakers)

## Polyphony — arrays as input

When a DSP function receives an array where it expects a
scalar, the engine runs the function once per element with
independent state. The results are summed.

```
sin([220, 330, 440]) * 0.3
```

This runs three `sin` oscillators, each with its own phase
accumulator, each at a different frequency. The output is
a single float — the sum of all three.

Equivalent to:
```
(sin(220) + sin(330) + sin(440)) * 0.3
```

But with array syntax, each voice gets its own DSP state
automatically. No manual management. Add a note to the
array, get a new voice.

### Why separate state matters

```
sin(220) + sin(220)
```

This is NOT two oscillators. It's one oscillator doubled.
Both calls share the same `claimDsp` counter position, so
they share the same phase accumulator. Result: 2x amplitude,
not two voices.

```
sin([220, 220])
```

This IS two oscillators. The array expansion runs each in
its own state context. Two independent phase accumulators.
In phase initially, but free to diverge if modulated.

### Polyphony through a chain

The array propagates through the pipe:

```
sin([220, 330, 440])
  |> lpf(800, 0.5)
  |> gain(0.3)
```

Each voice gets its own filter state. Three oscillators,
three filters, summed at the end. The pipe doesn't know
it's polyphonic — each stage just processes what it receives.

### Different parameters per voice

Use arrays for any parameter:

```
sin([220, 330, 440]) |> lpf([800, 1200, 600], 0.5)
```

Three oscillators, three filters with different cutoffs.
Array lengths must match — one cutoff per voice.

## Stereo — arrays as output

When a signal returns an array of two values, the engine
routes them to left and right:

```
sin(440) |> pan(0.3)
# returns [left, right]
```

The engine checks the return type:
- Float → duplicate to both channels (mono)
- Array of 2 → left and right (stereo)
- Array of N → surround / ambisonics (future)

### pan

```
sin(440) |> pan(0)      # center
sin(440) |> pan(-1)     # hard left
sin(440) |> pan(1)      # hard right
sin(440) |> pan(sin(0.2))  # autopan via LFO
```

Equal-power pan law:
```
proc pan(signal, pos):
  let angle = (pos + 1) * PI / 4
  [signal * cos(angle), signal * sin(angle)]
```

### Manual stereo

Return an array directly:
```
[sin(440) * 0.8, sin(442) * 0.8]
```

Detuned stereo — 440 Hz left, 442 Hz right. Two-element
array = stereo output.

## Both together

Polyphony (arrays in) summed, then panned (array out):

```
sin([220, 330, 440]) * 0.3 |> pan(0.2)
```

Three voices summed to mono, then panned slightly right.

Per-voice panning:

```
sin([220, 330, 440]) * 0.3 |> pan([-0.5, 0, 0.5])
```

Three voices, each panned to a different position. The
engine sums the stereo outputs:
- 220 Hz panned left
- 330 Hz center
- 440 Hz panned right

Result: `[left_sum, right_sum]` — stereo output.

## Implementation

### Engine changes

The audio callback currently expects `f(s) → float64`.
It needs to handle `f(s) → float64 | array[float64]`.

Option 1: signals always return a fixed-size stereo pair.
Mono signals return `[sample, sample]`. Pan returns
`[left, right]`. The engine always writes two channels.

Option 2: signals return a tagged value — either a float
or an array. The engine checks which and routes accordingly.

Option 1 is simpler. The internal representation is always
stereo. Mono is just stereo where both channels are equal.

### State expansion for polyphony

When `sin([220, 330, 440])` runs, each element needs its
own DSP state (own phase accumulator). The engine needs to:

1. Detect array input on a DSP function
2. Run the function N times
3. Each run uses a separate state context (separate
   `dspIdx` range)
4. Sum the results

This could be implemented as:
- A `poly` wrapper that manages N state contexts
- Or array-aware DSP functions that internally loop

The wrapper approach keeps DSP functions unchanged:

```nim
proc poly(fn: proc, inputs: openArray[float64], s: State): float64 =
  var sum = 0.0
  for i, input in inputs:
    # save and offset dspIdx for this voice
    let base = s.dspIdx
    s.dspIdx = base + i * voiceStateSize
    sum += fn(input, s)
  s.dspIdx = base + inputs.len * voiceStateSize
  sum
```

Each voice gets a slice of the DSP pool. The function
doesn't know it's being run polyphonically.

### Operator overloading for arrays

For `sin([220, 330, 440]) * 0.3` to work, arithmetic
operators need to handle the case where one operand is
an array and the other is a scalar:

```nim
proc `*`(a: openArray[float64], b: float64): seq[float64]
proc `+`(a: openArray[float64], b: openArray[float64]): seq[float64]
```

Scalar operations broadcast. Array operations are
element-wise. Same rules as NumPy or SuperCollider.

## What this enables

**Chords:**
```
sin([261, 329, 392]) * 0.2 |> reverb(1.5, 0.3)
```

**Unison detuning:**
```
saw([440, 440.5, 439.5]) * 0.2
```

**Stereo width:**
```
saw([440, 440.5]) * 0.3 |> pan([-1, 1])
```

**Polyphonic sequences:**
```
let chord = notes([[60,64,67], [62,65,69], [64,67,71]], bpm)
sin(chord) * 0.2
```

**Ambisonic (future):**
```
sin(440) |> ambi(azimuth, elevation)
# returns [W, X, Y, Z]
```

## Priority

This is foundational — not a DSP function but a change to
how the engine evaluates signals. Implement stereo first
(always return a pair), then polyphony (array expansion
with separate state contexts).
