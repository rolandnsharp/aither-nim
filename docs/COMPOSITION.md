# Composition

A song is one signal piped through time.

## The idea

The `|>` pipe chains DSP in space (oscillator into filter)
and sections in time (via `hold`). Same operator, same direction.
Read top to bottom, hear beginning to end.

```
saw(55) |> lpf(800, 0.5)
  |> hold(8)
  sin(440) |> reverb(1.5, 0.3)
  |> hold(8)
  noise() |> hpf(8000, 0.1)
  |> hold(4)
  |> fadeout(4)
```

`hold(n)` holds the current sound for `n` seconds. When it
ends, flow continues to the next expression. Each section
boundary is a new signal — the previous one stops, the new
one starts.

The file IS the score. The pipe IS the timeline.

## Building up layers

Add signals to the existing sound with `+`:

```
saw(55) |> lpf(800, 0.5)
  |> hold(8)
  + sin(440) * 0.3
  |> hold(8)
  + noise() * 0.1 |> hpf(6000, 0.1)
  |> hold(8)
  |> fadeout(4)
```

Section 1: saw alone. Section 2: saw + sine. Section 3:
saw + sine + hi-hat noise. Each `+` layers on top of what
came before.

## Dropping and replacing

Start fresh with a new expression after `hold`:

```
# verse
saw(55) |> lpf(800, 0.5) + sin(440) * 0.3
  |> hold(16)
# chorus — completely different sound
noise() |> resonator(800, 0.3) + noise() |> resonator(1200, 0.4)
  |> hold(16)
# back to verse
saw(55) |> lpf(800, 0.5) + sin(440) * 0.3
  |> hold(16)
  |> fadeout(4)
```

No `drop` keyword needed. A new expression after `hold` starts
from scratch. If you want to keep the previous sound, use `+`.

## Transitions

Crossfade between sections with `xfade`:

```
saw(55) |> lpf(800, 0.5)
  |> xfade(2)
  sin(440) |> reverb(1.5, 0.3)
  |> hold(8)
```

`xfade(n)` fades the previous signal out and the next signal
in over `n` seconds. Smooth transitions without clicks.

## Rhythm within sections

Each section is a full signal expression. Use the same clock
primitives for rhythm:

```
let kick = impulse(2) |> resonator(60, 8) * (impulse(2) |> discharge(6))
let hat = noise() * (impulse(8) |> discharge(40)) |> hpf(8000, 0.1)
let bass = saw(wave(4, [55, 55, 73, 65])) |> lpf(800, 0.5) * 0.4

# intro — kick only
kick
  |> hold(8)
# verse — add hat and bass
kick + hat * 0.3 + bass
  |> hold(16)
# chorus — everything louder, reverb
(kick + hat * 0.5 + bass * 1.5) |> reverb(1.0, 0.3)
  |> hold(16)
# outro — fade
kick + hat * 0.2
  |> hold(8)
  |> fadeout(8)
```

The `let` bindings define the instruments. The pipe chain
arranges them in time. The entire song — rhythm, arrangement,
mixing, effects — in one file.

## Rendering

```
aither render song.aither 56 output.wav
```

The engine runs offline at maximum speed. Same signals, same
math, writes to disk instead of speakers. A one-minute song
renders in seconds.

## Continuity across sections

`hold` works like hot-swap internally. When a section ends,
the engine swaps the signal function but keeps the state
object — same mechanism as `aither send`, triggered by the
clock instead of the user.

This means:
- Kick phasor keeps its phase — no timing glitch
- Resonator keeps its energy — no click
- Filter state carries over — no discontinuity
- `$` variables persist — envelopes continue naturally

A section change is a scheduled hot-swap. The signal function
changes, the state survives. Same operation, different trigger.
The engine doesn't need a separate mechanism for composition —
`hold` IS `send` on a timer.

## Why this works

Every other composition tool has two languages: one for sound,
one for structure. A DAW has a timeline AND a synth UI. A
tracker has a pattern grid AND instrument definitions.
SuperCollider has SynthDefs AND Routines AND Patterns.

This has one: a pipe. Sound flows through DSP. Sections flow
through time. Same operator, same syntax, same file.
