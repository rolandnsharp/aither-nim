# aither

Live audio synthesis engine for the terminal. Pure Nim.

Every sound is a function of state: `f(s) → sample`.
No graph. No scheduler. No opinions about signal processing.
The user brings all the math.

## Quick start

```bash
make                            # build the engine (~647K binary)
./aither start                  # launch (opens audio, listens on /tmp/aither.sock)

# in another terminal:
./aither send examples/chaos.nim   # compile & play
./aither send examples/bass.nim    # add another signal
./aither send examples/chaos.nim   # hot-swap — state survives, no pop
./aither stop chaos                # fade out signal (~10ms)
./aither list                      # show active signals
./aither kill                      # shut down
```

## Writing patches

A patch is a Nim file. The `signal` macro defines a function `f(s) → float64`
that the engine calls 48,000 times per second:

```nim
import aither

signal "kick", s:
  s["phase"] += 60.0 / s.sr
  sin(TAU * s["phase"]) * 0.8
```

### State

`s` is persistent per-signal state. It survives hot-swaps.

| Field   | Description              |
|---------|--------------------------|
| `s.t`   | time in seconds          |
| `s.dt`  | 1 / sample_rate          |
| `s.sr`  | sample rate (48000)      |
| `s[k]`  | named user state (float64), auto-created on first access |

### DSP stdlib

Import `dsp` for oscillators, filters, and effects.
All stateful DSP stores its state automatically — no manual management.

```nim
import aither, dsp

signal "bass", s:
  saw(55.0, s).lpf(800.0, 0.5, s).gain(0.4)
```

**Oscillators:** `sin`, `saw`, `tri`, `square`, `pulse`, `phasor`, `wave`, `noise`
**Filters:** `lpf`, `hpf`, `bpf`, `notch` (Cytomic SVF), `lp1`, `hp1` (one-pole)
**Effects:** `delay`, `fbdelay`, `reverb`, `tremolo`, `slew`
**Helpers:** `gain`, `fold`, `decay`, `mix`

Chain with UFCS (`.`) or the pipe operator (`|>`):

```nim
saw(55.0, s) |> lpf(800.0, 0.5, s) |> gain(0.4)
```

### Hot-swap

Edit a patch, `aither send` it again. The function pointer swaps atomically.
State persists — phase accumulators, filter memory, everything.
Zero discontinuity. Zero pops.

If compilation fails, the engine prints the error and keeps playing
the last good version.

## Architecture

```
engine.nim       main binary — audio callback, signal table, socket, CLI
aither.nim       State type, signal macro, pipe operator (shared with patches)
dsp.nim          DSP primitives (imported by patches)
miniaudio.nim    thin FFI wrapper for miniaudio.h
miniaudio.h      audio backend (header-only C library)
```

Patches are compiled as shared libraries (`nim c --app:lib`) and loaded
via `dlopen`. An atomic pointer swap replaces the running function.
The audio thread never stops.

## One language, every instrument

Aither is a synthesizer, a sequencer, a looper, a live coder,
a composer, and an oscilloscope. They're all the same operation —
`f(s) → sample`:

```
# synthesizer
saw(midi_freq) |> lpf(cc(1) * 4000, 0.8)

# sequencer
sin(notes([60, 64, 67, 72], bpm)) * (impulse(bpm/60) |> discharge(4))

# looper — a delay line with feedback = 1
signal |> fbdelay(4 * 60/bpm, 4 * 60/bpm, 1.0)

# composer — pipe through time with hold()
kick + hat * 0.3 + bass |> reverb(1.5, 0.3)
  |> hold(16)
  kick + hat * 0.5 + bass + lead
  |> hold(32)
  |> fadeout(4)
```

### Three targets, same language

- **Native binary** — Nim compiled to C. Maximum performance.
- **Browser** — DSP compiled to JS via `nim js`. Instant REPL,
  zero install. Type math, hear sound.
- **PicoCalc** — portable synthesizer on a $50 calculator.
  MIDI keyboard in, audio out, oscilloscope on screen.
  Type a line of math, play it on a piano.

### Design docs

- [Physics primitives](docs/PHYSICS_PRIMITIVES.md) — impulse, resonator, discharge
- [Composition](docs/COMPOSITION.md) — `hold()` pipes through time
- [Feedback](docs/FEEDBACK.md) — why `$fb` is the honest expression
- [Looper](docs/LOOPER.md) — a looper is a delay with feedback = 1
- [Oscilloscope](docs/OSCILLOSCOPE.md) — phosphor dot tracing
- [Spectral](docs/SPECTRAL.md) — why no FFT, and what to use instead
- [Patterns](docs/PATTERNS.md) — rhythmic techniques without a pattern system
- [Faust comparison](docs/FAUST_COMPARISON.md) — how `+` replaces six operators
- [Browser REPL](docs/BROWSER_REPL.md) — instant sound in three files
- [Multichannel](docs/MULTICHANNEL.md) — stereo and polyphony via arrays

## Requirements

- Nim 2.x
- Linux with PulseAudio, PipeWire, or ALSA
- GCC or Clang
