# Oscilloscope

Phosphor dot tracing for all visualization. The dot IS the sample.
No abstraction between what you hear and what you see.

## Why phosphor

The glow persistence matches the time domain of sound. A sharp
attack is a bright flash. A slow decay is a gentle fade. The
visual and the audio are the same physics rendered through
different senses.

The dot traces at sample rate. Each point is one sample, one
moment, one value. Everything more advanced — spectrograms,
3D, fancy UI — adds information but loses immediacy.

Green on black. It looks like test equipment because it is.

## Modes

### Y-T (waveform)

A dot sweeping left to right, fading behind it. The standard
oscilloscope. Shows any signal or `$variable` over time.

```
aither scope kick          # output waveform
aither scope kick $phase   # internal state variable
```

The sweep rate adjusts to the signal. A 440 Hz sine shows
a few cycles. A 0.5 Hz LFO fills the screen with one wave.
Trigger on zero-crossing for a stable display.

### X-Y (phase portrait)

A dot tracing in 2D, no sweep. Two values plotted against
each other. The trail draws the shape.

```
aither scope kick $x $dx   # resonator phase portrait
aither scope mix L R        # stereo Lissajous
```

What you see:

| Patch | X-Y shows |
|-------|-----------|
| `resonator(440, 2)` struck once | spiral converging to origin |
| `resonator(440, 0.01)` bowed | stable ellipse |
| coupled oscillators | figure-8 or pretzel shapes |
| chaos patch | strange attractor |
| stereo L vs R | Lissajous — circle=90° phase, line=mono |

The phase portrait is the killer feature. No other audio tool
shows this because no other tool exposes named internal state.
You see the physics, not just the output.

### State waterfall

All `$` variables for a signal, listed with current values,
horizontal bars showing magnitude, history fading downward.

```
aither watch kick
```

```
$phase  ████████████░░░░░░░░  0.63
$env    ███░░░░░░░░░░░░░░░░░  0.15
$x      ██████░░░░░░░░░░░░░░  0.31
$dx     ░░░░░░░░░░░░░░░░░░░░  0.02
```

Instant read on what the signal is doing internally. The bars
update at frame rate. The numbers update at frame rate. The
state itself runs at sample rate — the display decimates.

## Implementation

### Data path

The engine already computes every sample. The oscilloscope
reads from a ring buffer:

```
const ScopeBufferSize = 4096

type ScopeBuffer = object
  data: array[ScopeBufferSize, float64]
  writePos: int
```

The audio callback writes to the ring buffer after computing
each sample. The display thread reads from it. No lock needed —
single writer, single reader, atomic write position.

### Rendering

Each frame:
1. Read the latest N samples from the ring buffer
2. For each sample, plot a dot at (x, y)
3. Fade the previous frame by multiplying alpha (phosphor decay)
4. New dots are bright, old dots are dim

Y-T: x = sample index, y = sample value
X-Y: x = channel/variable A, y = channel/variable B

The fade rate controls phosphor persistence:
- Fast fade (0.85) — sharp transients visible, history disappears
- Slow fade (0.95) — trails linger, shows trajectory and attractors
- User adjustable

### Triggering (Y-T mode)

Free-running sweep is jittery. Trigger on zero-crossing of the
signal for a stable display:

1. Scan the ring buffer for a rising zero-crossing
2. Start the sweep from that point
3. Display one or more complete cycles

This locks the waveform in place. Same as a real oscilloscope.

### Terminal rendering

For the CLI, render with Unicode block characters or braille
dots in the terminal. No GUI dependency:

```
╔══════════════════════════════════════════╗
║            ···                           ║
║          ··   ··                         ║
║        ··       ··                       ║
║──────··───────────··──────────··─────────║
║                     ··       ··          ║
║                       ··   ··            ║
║                         ···              ║
╚══════════════════════════════════════════╝
```

Braille characters (U+2800 block) give 2x4 dot resolution per
character cell — enough for a usable scope in 80x24 terminal.

### PicoCalc rendering

320x480 screen, SPI display. Layout:

```
┌──────────────────────┐
│                      │
│    Y-T scope         │
│    (top half)        │
│                      │
├──────────────────────┤
│ $phase  ████░░  0.63 │
│ $env    ██░░░░  0.15 │
│ $x      ███░░░  0.31 │
│ $dx     █░░░░░  0.02 │
├──────────────────────┤
│ > saw(55) |> lpf(800 │
│           , 0.5)     │
└──────────────────────┘
```

Top: scope. Middle: state. Bottom: code input.
All green phosphor on black. The whole screen is the instrument.

## What this reveals

The oscilloscope isn't a debugging tool. It's part of the
instrument. When you write:

```
impulse(2) |> resonator(440, 2)
```

The Y-T scope shows the ringing waveform. The X-Y scope shows
the phase spiral. The state waterfall shows `$x` oscillating
and `$dx` decaying. You see the damped harmonic oscillator
from three angles simultaneously.

Change the damping — watch the spiral tighten. Change the
frequency — watch the waveform compress. Change the excitation
— watch the energy spike and dissipate.

The `$` variables exist for the sound. The oscilloscope exists
for the eyes. Same data, same physics, two senses. The phosphor
dot connects them.
