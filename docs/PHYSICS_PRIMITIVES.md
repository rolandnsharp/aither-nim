# Physics Primitives: impulse, resonator, discharge

Three DSP primitives derived from the same physics.
Together they replace most percussion synthesis, modal synthesis,
and envelope generation with a unified model.

## The physics

All three are solutions to the damped harmonic oscillator:

    ẍ + 2γẋ + ω²x = F(t)

- **impulse** — F(t) itself. A single-sample spike of energy.
- **resonator** — the full second-order system. Oscillates and decays.
- **discharge** — first-order reduction (ω=0). Decays without oscillating.

| Primitive   | Equation           | Behavior              |
|-------------|--------------------|-----------------------|
| `impulse`   | δ(t)               | spike, then zero      |
| `resonator` | ẍ + 2γẋ + ω²x = F  | rings at freq, decays |
| `discharge` | ẋ + αx = F          | exponential decay     |

## The electrical analogy

The equation maps directly to electronic circuits:

    ẍ + 2γẋ + ω²x = F(t)

    L·C·ẍ + R·C·ẋ + x = F(t)

| Component  | Symbol | Role in the equation | Aither parameter |
|------------|--------|---------------------|------------------|
| Resistor   | R      | damping (γ = R/2L)  | `decay`, `rate`  |
| Capacitor  | C      | stores charge       | (implicit)       |
| Inductor   | L      | stores momentum     | (implicit)       |

The three circuit configurations produce the three primitives:

| Circuit | Components | Equation        | Primitive    |
|---------|-----------|-----------------|--------------|
| RC      | R + C     | ẋ + x/RC = F    | `discharge`  |
| LC      | L + C     | ẍ + ω²x = F     | `resonator` (γ=0, rings forever) |
| RLC     | R + L + C | ẍ + 2γẋ + ω²x = F | `resonator` (rings and decays) |

You don't need separate R and C primitives. Only the ratio
matters — R/C is the time constant, and that's the `rate` or
`decay` parameter. One number controls how fast energy drains.

`discharge` and `lp1` are the same circuit — an RC filter:

```
signal |> lp1(freq)         # RC lowpass: smooths audio
impulse(4) |> discharge(8)  # RC envelope: smooths an impulse
```

Same equation, same math. One filters, one shapes amplitude.
The physics doesn't distinguish between the two — only the
input signal differs.

## impulse

A single-sample trigger at a given rate (Hz).

```
proc impulse(freq, s): float64
```

Returns 1.0 once per cycle, 0.0 otherwise.
Implemented via phasor wrap detection.

```nim
proc impulse*(freq: float64, s: State): float64 =
  let i = claimDsp(s)
  let prev = s.dsp[i]
  s.dsp[i] = (s.dsp[i] + freq / s.sr) mod 1.0
  if s.dsp[i] < prev: 1.0 else: 0.0
```

Usage:

```
impulse(4)                    # quarter notes at 120bpm (4 Hz = 240bpm... adjust)
impulse(2)                    # half notes
impulse(8)                    # eighth notes
```

## discharge

First-order exponential decay. Follows the peak of the input
and decays at `rate`. No oscillation — just energy draining away.

```
proc discharge(input, rate, s): float64
```

```nim
proc discharge*(input, rate: float64, s: State): float64 =
  let i = claimDsp(s)
  s.dsp[i] = max(input, s.dsp[i] * (1.0 - rate * s.dt))
  s.dsp[i]
```

Usage:

```
impulse(4) |> discharge(8)    # percussive envelope, ~125ms decay
impulse(4) |> discharge(2)    # slow swell, ~500ms decay
impulse(4) |> discharge(40)   # sharp click, ~25ms
```

## resonator

Second-order damped harmonic oscillator. Rings at `freq` Hz,
decays at rate `decay`. Driven by input signal F(t).

```
proc resonator(input, freq, decay, s): float64
```

Euler integration of ẍ + 2γẋ + ω²x = F(t):

```nim
proc resonator*(input, freq, decay: float64, s: State): float64 =
  let i = claimDsp(s, 2)  # x, dx
  let omega2 = freq * freq
  s.dsp[i+1] += (-decay * s.dsp[i+1] - omega2 * s.dsp[i] + input * omega2) * s.dt
  s.dsp[i] += s.dsp[i+1] * s.dt
  s.dsp[i]
```

Usage:

```
impulse(2) |> resonator(440, 2)       # struck tuning fork
noise() * impulse(4) |> resonator(180, 15)  # kick drum body
saw(55) |> resonator(800, 1)          # resonant filter
```

## Composition

The three primitives compose into complete instruments:

**Kick drum:**
```
let hit = impulse(2)
hit |> resonator(60, 8) * (hit |> discharge(6))
```
Resonator for the body, discharge for the envelope.

**Hi-hat:**
```
noise() * (impulse(8) |> discharge(40)) |> hpf(8000, 0.1)
```
Noise burst shaped by a fast discharge.

**Bell:**
```
let strike = impulse(1)
(strike |> resonator(800, 0.3))
+ (strike |> resonator(1260, 0.4))
+ (strike |> resonator(1860, 0.6)) * 0.3
```
Three resonant modes at inharmonic ratios. That's modal synthesis.

**Plucked string:**
```
noise() * impulse(3) |> resonator(330, 0.2)
```
Noise impulse excites a resonator with low damping. Same physics
as Karplus-Strong, different implementation.

**Resonant drum pattern:**
```
let pattern = [1,0,0,1, 0,0,1,0]
let hit = pattern[int(t * 8) mod 8]
hit |> resonator(180, 12) |> fold(1) * 0.4
```
The pattern drives F(t). The resonator is the drum. Fold adds grit.

**Bowed string — continuous excitation:**
```
sin(0.5) * 0.001 |> resonator(440, 0.1) * 10
```
Slow sine drives the oscillator. Low decay = long sustain.
The oscillator rings at 440 Hz regardless of the drive frequency.

## Why these three

Every percussion instrument is: energy in (impulse), vibration
(resonator), decay (discharge). Every resonant filter is a
resonator driven by audio. Every envelope is a discharge.

The three primitives are orthogonal:
- impulse creates events in time
- resonator adds pitch and sustain
- discharge shapes amplitude

They compose freely via `|>` and `+`. No special envelopes,
no trigger buses, no note-on/note-off. Just signal flow.

## Conductor style

One file per signal. One signal per sound. The conductor is a
signal that references the others by name and controls the mix.

### The problem

Instruments don't know about each other. A kick doesn't know
about the hat. The bass doesn't know about the chord progression.
That's good — each signal is independent, hot-swappable, simple.

But a performance needs structure. Timing, levels, effects,
arrangement. Something has to orchestrate.

### The solution

The conductor is a signal file like any other. The engine exposes
each signal's last sample by name. The conductor reads them,
applies timing, levels, and effects, and outputs the final mix.

```
# kick
impulse(2) |> resonator(60, 8) * (impulse(2) |> discharge(6))
```

```
# hat
noise() * (impulse(8) |> discharge(40)) |> hpf(8000, 0.1)
```

```
# bass
let notes = [55, 55, 73, 65]
let freq = notes[int(t * 4) mod 4]
saw(freq) |> lpf(800, 0.5) * 0.4
```

```
# mix
kick + hat * 0.3 + bass |> reverb(1.5, 0.3)
```

Edit `kick` — resend just that file. The conductor picks up the
new sound on the next sample. Edit `mix` — change levels, add
effects, mute a part. Each file is independent.

### Implementation

The engine needs one addition: a global sample table that stores
each signal's most recent output, keyed by name.

```nim
var lastSample: Table[string, float64]
```

In the audio callback, after evaluating each signal, store its
output:

```nim
for sig in signals:
  let sample = sig.fn(sig.state)
  lastSample[sig.name] = sample
```

In the signal macro, a bare signal name (like `kick`) resolves
to a lookup in this table:

```nim
# "kick" in a signal body expands to:
lastSample.getOrDefault("kick", 0.0)
```

The conductor signal is evaluated last (or the engine sorts by
dependency). Its output is what reaches the speakers. Individual
signals produce sound but are muted from the main output — only
the conductor's output is heard.

### Muting raw signals

When a conductor exists, the individual signals shouldn't add
to the audio output directly — the conductor handles mixing.
Two options:

1. **Explicit**: a signal that is referenced by another is
   automatically muted from the main mix.
2. **Convention**: signals prefixed with `_` are silent helpers.
   `_kick`, `_hat`, `_bass` produce values but no audio.
   `mix` (no prefix) is the audible output.

Option 2 is simpler and requires no dependency tracking.

### Evaluation order

The conductor reads other signals' samples. If evaluated before
them, it reads stale values (one sample behind). At 48kHz this
is ~20 microseconds of latency — inaudible. No dependency sorting
needed. One sample of latency is free.

### Live performance workflow

```
aither send kick     # start with rhythm
aither send hat      # layer percussion
aither send bass     # add bass
aither send mix      # connect the conductor — now it controls output
# edit kick, resend — sound changes instantly
# edit mix, resend — arrangement changes instantly
# mute the hat: edit mix to remove it, resend
```

Each file is a module. The conductor is the patch bay. Same
philosophy as the rest of aither: signals are functions, composition
is arithmetic, the engine stays out of the way.

### Why not put it all in one file?

Because hot-swap is per-file. If the kick, hat, bass, and mix
are in one file, changing the kick recompiles everything. With
separate files, you edit one sound, resend one file, hear the
change in the running mix. That's live coding.

The conductor style is the multi-file equivalent of
`pipe(kick, hat, bass, reverb)`. Same composition, granular
hot-swap.
