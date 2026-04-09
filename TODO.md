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
- aither repl — readline loop, blank line triggers compile,
  sends to running engine
- Custom language with same syntax — C interpreter,
  instant eval, no compile step.
  This is the long term vision: same signal philosophy,
  your own runtime, runs on microcontrollers
