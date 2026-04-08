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

## Requirements

- Nim 2.x
- Linux with PulseAudio, PipeWire, or ALSA
- GCC or Clang
