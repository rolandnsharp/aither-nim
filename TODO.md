# TODO

### Next up
- Browser REPL prototype — the first real demo of the language
  - Write JS parser (~500 lines) that parses aither syntax
  - Transpile to JS strings, eval with new Function()
  - DSP stdlib written in aither, transpiled to JS
  - AudioWorklet for per-sample evaluation
  - Phosphor oscilloscope on canvas
  - Three files: index.html, stdlib.js, worklet.js
  - See docs/BROWSER_REPL.md and docs/LANGUAGE_SPEC.md
- Stereo — engine always returns a pair, pan() primitive
- Polyphony — array expansion with separate state contexts
  (see docs/MULTICHANNEL.md)
- Physics primitives — impulse, resonator, discharge
  (see docs/PHYSICS_PRIMITIVES.md)

### Engine
- Old .so leak management — defer unload 2-3 callbacks after swap
- Signal references — last sample of named signal available
  as a value for conductor pattern (see docs/PHYSICS_PRIMITIVES.md)
- Globals table for shared state between signals —
  sidechain compression, tempo sync, shared LFO
- hold() for composition — scheduled hot-swap triggered by
  the clock (see docs/COMPOSITION.md)

### Live tooling
- Phosphor oscilloscope — Y-T waveform, X-Y phase portrait,
  state waterfall (see docs/OSCILLOSCOPE.md)
- aither debug — print signal state values without stopping audio
- aither watch — stream a named state value to terminal

### Native compiler
- Nim parser (~500 lines) that parses aither syntax, emits C
- Same grammar as browser parser, different output
- DSP stdlib written in aither, transpiled to C
- Engine stays in Nim — audio callback, state, sockets
- Compile with gcc (desktop) or arm-gcc (PicoCalc)

### Hardware
- PicoCalc + Pico Plus 2W — portable synth
- I2S DAC (PCM5102) for high quality audio output
- MIDI input via USB — midi_freq, midi_gate, cc(n) as globals
- Teensy 4.1 option — 600MHz, audio shield, USB MIDI host

### Language
- osc(shape, freq) — unified oscillator, shapes are math functions
  (see docs/LANGUAGE_SPEC.md)
- No significant whitespace — if/then/else, single-line expressions
- $name for state, let for bindings, += for mutation
- def for user functions
- Implicit s — DSP functions get state injected
- Everything is float64 — no type system
