# Looper

A looper is a delay line with feedback set to 1.

That's it. The signal goes in, comes back after exactly one
loop length, feeds back in at full volume, repeats forever.
Every looper pedal ever made is this circuit.

## The basic loop

```
let len = 4 * 60 / bpm
signal |> fbdelay(len, len, 1.0)
```

Four bars at whatever tempo. Feedback of 1.0 means nothing
decays. The loop plays forever. Add new sound and it layers
on top.

## Every looper feature is a parameter

### Record / play / stop

```
signal * $rec |> fbdelay(len, len, $fb)

# recording:  $rec = 1, $fb = 1.0
# playing:    $rec = 0, $fb = 1.0
# stopped:    $rec = 0, $fb = 0
```

### Overdub with decay

```
signal * $rec |> fbdelay(len, len, 0.95)
```

Feedback below 1.0 means old layers gradually fade. New
signal mixes in on top. This is tape loop behavior — each
pass slightly degrades the previous layers. Natural, warm,
and exactly what expensive tape echo units do.

### Clear

Set feedback to 0. The buffer drains to silence over one
loop cycle. Smooth, no click.

```
# clear:  $fb = 0
# resume: $fb = 1.0
```

### Volume control

Multiply the output:

```
(signal * $rec |> fbdelay(len, len, 1.0)) * $loop_vol + signal
```

Dry signal always passes through. Loop volume is independent.

### Half speed / double speed

Read the delay at a different rate:

```
signal |> fbdelay(len * $speed, len, 1.0)
```

`$speed = 0.5` reads at half speed — pitch drops an octave,
loop takes twice as long. `$speed = 2.0` is double speed —
pitch up an octave, loop is half length. Same buffer, different
read position. Tape varispeed for free.

### Reverse

Read the delay buffer backwards. This needs a primitive that
reads the buffer in the opposite direction — `revdelay`:

```
signal |> revdelay(len, len, 1.0)
```

Same buffer, read cursor moves backwards. This is the one
feature that needs a new DSP function — everything else is
just parameter changes to `fbdelay`.

### Multiple loops

Multiple delay lines at different lengths:

```
let loop1 = signal * $rec1 |> fbdelay(4 * 60/bpm, 4 * 60/bpm, 1.0)
let loop2 = signal * $rec2 |> fbdelay(3 * 60/bpm, 3 * 60/bpm, 1.0)
loop1 + loop2 * 0.8
```

Two loops at different lengths create polyrhythmic textures.
The 4-bar and 3-bar loops phase against each other. No sync
needed — they drift by design. A $200 feature on boutique
pedals.

### Stutter / glitch

Shorten the delay time while the loop plays:

```
let stutter = if $glitch: len / 8 else: len
signal |> fbdelay(stutter, len, 1.0)
```

Toggle `$glitch` and the loop plays back one eighth of the
buffer, repeating rapidly. That's a stutter. Same delay line,
shorter read window.

### Pitch shifting via feedback

Slightly detune the read speed and the pitch drifts up or
down with each pass:

```
signal |> fbdelay(len * 1.001, len, 0.98)
```

Each loop cycle is slightly longer than the buffer, so each
pass reads a slightly different portion. Combined with
decaying feedback, you get a pitch-shifting echo. Shimmer
reverb is built from this — pitch shift up by a fifth,
feed back, each repeat climbs higher.

## The full looper — one signal

```
let len = 4 * 60 / bpm

let dry = signal
let wet = signal * $rec
  |> fbdelay(len * $speed, len, $fb)

dry + wet * $vol
```

Five `$` variables control everything:

| Variable | Effect |
|----------|--------|
| `$rec`   | 1 = recording, 0 = playing |
| `$fb`    | 1 = infinite loop, 0.95 = tape decay, 0 = clear |
| `$speed` | 1 = normal, 0.5 = half speed, 2 = double |
| `$vol`   | loop playback volume |

Hot-swap the signal file to change these values live. Or
wire them to MIDI knobs when MIDI input is implemented.

## Why looper pedals cost $400

Because they're selling you:
- A delay line ($5 of DSP)
- Buttons for record/play/stop ($10 of switches)
- An enclosure ($20 of aluminum)
- "Reverse" and "half speed" as premium features
- The brand name

The DSP is one function: `fbdelay`. The interface is code
instead of buttons. Every feature a pedal advertises is a
number you can change.

A $400 pedal has 6 knobs. Your looper has every float in
the expression.
