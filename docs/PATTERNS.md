# Pattern techniques

Aither has no pattern system. Patterns are math on time.
Here are techniques for common rhythmic operations using
the existing primitives.

## Basic patterns

**Step sequencer:**
```
steps([1,0,0,1, 0,0,1,0], bpm)
```

**Melody:**
```
let freq = notes([60, 64, 67, 72], bpm)
sin(freq)
```

**Euclidean rhythm:**
```
euclid(3, 8, bpm)
```

## Speed manipulation

**Double time:**
```
steps([1,0,1,0], bpm * 2)
```

**Half time:**
```
steps([1,0,1,0], bpm / 2)
```

**Accelerando — continuous speed increase:**
```
steps([1,0,1,0], bpm + t * 5)
```

**Breathe — speed modulated by LFO:**
```
steps([1,0,1,0], bpm + sin(0.1) * 20)
```

## Conditional patterns

**Every Nth cycle, change something:**
```
let cycle = int(t * bpm / 60 / 4)
let rate = if cycle mod 4 == 3: bpm * 2 else: bpm
steps([1,0,1,0], rate)
```

**Alternate between two patterns:**
```
let cycle = int(t * bpm / 60 / 4)
let p = if cycle mod 2 == 0: [1,0,1,0] else: [1,1,0,1]
steps(p, bpm)
```

## Swing

**Push offbeats late by warping phase:**
```
let raw = phasor(bpm/60)
let swung = if raw < 0.5:
              raw * 0.66
            else:
              0.33 + (raw - 0.5) * 1.34
```

**Swing as modulated clock — no conditional:**
```
phasor(bpm/60 + sin(bpm/30) * bpm/60 * 0.15)
```

## Probability

**Randomly drop hits:**
```
impulse(bpm/60) * (if noise() > 0.3: 1 else: 0)
```

**Random pattern variation:**
```
let base = [1,0,1,0, 0,0,1,0]
let variation = [1,0,0,1, 0,1,1,0]
let p = if noise() > 0.7: variation else: base
steps(p, bpm)
```

## Polyrhythm

**3 against 4:**
```
let three = impulse(bpm/60 * 3/4)
let four = impulse(bpm/60)
three |> resonator(440, 5) + four |> resonator(330, 5)
```

**5 against 8:**
```
impulse(bpm/60 * 5/8) |> resonator(600, 8)
+ impulse(bpm/60) |> resonator(400, 8)
```

## Reverse

**Play a pattern backwards within a cycle:**
```
let phase = phasor(bpm / 60 / 4)
let reversed = 1.0 - phase
steps([1,0,1,0, 0,0,1,0], reversed)
```

**Palindrome — forward then backward:**
```
let phase = phasor(bpm / 60 / 8)
let ping_pong = if phase < 0.5: phase * 2 else: 2.0 - phase * 2
steps([1,0,1,0, 0,0,1,0], ping_pong)
```

## Rotation

**Shift pattern start point:**
```
let offset = 3
let phase = phasor(bpm / 60 / 4)
let rotated = (phase + float(offset) / 8.0) mod 1.0
steps([1,0,1,0, 0,0,1,0], rotated)
```

## Phase techniques from TidalCycles

TidalCycles has pattern-level transforms like `every`,
`sometimes`, `jux`, `rev`. These are operations on opaque
pattern objects.

In aither, patterns are transparent — they're arrays read
by a clock. The same results come from manipulating the
clock or the array directly:

| TidalCycles | Aither |
|-------------|--------|
| `fast 2` | `bpm * 2` |
| `slow 3` | `bpm / 3` |
| `rev` | `1.0 - phase` |
| `every 4 (fast 2)` | `if cycle mod 4 == 3: bpm * 2 else: bpm` |
| `degrade 0.3` | `signal * (if noise() > 0.3: 1 else: 0)` |
| `jux rev` | split to stereo, reverse one channel |
| `palindrome` | `if phase < 0.5: phase * 2 else: 2 - phase * 2` |

More verbose. Fully transparent. If you want the sugar,
write helper functions in a DSP file — the library doesn't
impose a pattern paradigm.

## The philosophy

There is no pattern system because patterns ARE signals.
A kick pattern is an impulse train. A melody is a wave
oscillator at beat rate. Swing is a modulated clock.
Polyrhythm is two clocks at different rates.

The user chooses their own level of abstraction — raw
time math, helper functions, or a custom pattern library
written in Nim. The engine doesn't care. It just calls
`f(s)` and gets a sample.
