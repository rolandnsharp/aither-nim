# TODO

### Correctness
- Old .so leak management — defer unload 2-3 callbacks after swap

### DSP
- Physics primitives — impulse, resonator, discharge
  (see docs/PHYSICS_PRIMITIVES.md)
- Multichannel expansion — arrays mean two different things:
  - Arrays as INPUT = polyphony. Run the function N times
    with separate state, sum to mono:
      sin([220, 330, 440]) * 0.3
      # three oscillators, separate state, summed to one float
  - Arrays as OUTPUT = channels. Route to speakers:
      sin(440) |> pan(0.3)
      # returns [left, right]
  - Both together:
      sin([220, 330, 440]) * 0.3 |> pan([-0.5, 0, 0.5])
      # three voices, each panned differently, returns [left, right]
  - Engine checks the return: float = duplicate to both channels,
    array of 2 = stereo, array of N = surround/ambisonics

### Signal combination
- Reference other signals by name in a signal block.
  Last sample of named signal available as a value:
    signal "mix", s:
      kick + hat * 0.5 + bass |> reverb(1.5, 0.3)
- Globals table for shared state between signals —
  sidechain compression, tempo sync, shared LFO

### Live tooling
- aither debug — print signal state values without stopping audio
- aither watch name field — stream a named state value to terminal
- Better error messages — line numbers, highlight failing expression

### Performance
- Hash table for state key lookup — replace linear scan for
  complex patches with many named state fields

### Targets
- JACK backend via miniaudio flag — same binary, no recompile
- Browser target — nim js compilation, Web Audio backend
- MIDI input — for live keyboard performance
- Raspberry Pi — ARM binary, test signal count ceiling
- C interpreter — sub-100ms swap times, embedded targets,
  your own language runtime

### Language future
- Interpreter / REPL (~1000 lines):
  - Tokenizer, parser, bytecode compiler, stack VM
  - ~30 DSP functions, arithmetic, $state, let, if/then/else, |>
  - Everything is float64 — no type system needed
  - DSP primitives are compiled Nim called via function table
  - Same syntax as compiled Nim patches
- No significant whitespace — expressions work on a single line,
  use if/then/else not indented blocks. Better for REPL and
  PicoCalc keyboard. Compiled Nim backend keeps Nim's rules.
- $name for persistent state, let for immutable bindings,
  += for state mutation. No := or var.
- Implicit s — DSP functions get state injected by the interpreter.
  User writes sin(440) not sin(440, s). For compiled Nim, macro
  rewrites AST to inject s.
- Browser REPL — compile DSP stdlib to JS via nim js, eval patches
  instantly. Three files: index.html, dsp.js, worklet.js.
  (see docs/BROWSER_REPL.md)

### Hardware
- PicoCalc + Pico Plus 2W — portable synth, interpreter on device
- I2S DAC (PCM5102) for high quality audio output from Pico
- MIDI input via USB — midi_freq and midi_gate as injected values,
  CC knobs mapped to any parameter in the expression
- Teensy 4.1 as alternative board — 600MHz, hardware double
  precision FPU, audio shield for studio quality output
