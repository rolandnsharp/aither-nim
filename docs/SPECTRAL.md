# Spectral processing

Aither does not include FFT. Here's why, and what to use instead.

## Why no FFT

Every function in aither processes one sample at a time.
The engine calls `f(s)`, gets one float, moves on. The
function never sees more than the current moment. This is
the core architecture — it's what makes hot-swap seamless,
state inspection trivial, and the mental model honest.

FFT breaks this. It needs 1024 samples at once to decompose
a signal into frequencies. That means buffering, windowing,
overlap-add, and 1024 samples of latency before you hear
anything. The pipe `signal |> fft |> freeze |> ifft` looks
like sample-by-sample flow but it's lying — internally it's
batching and reconstructing blocks.

We don't include primitives that lie about what they do.

## Time-domain alternatives

Most effects that people reach for FFT can be done in the
time domain, sample by sample, with no latency and no
artifacts:

### Spectral freeze → resonator bank

Drive several resonators, then stop the input. They ring
at their frequencies indefinitely:

```
let input = if t < 2: signal else: 0
(input |> resonator(440, 0.01))
+ (input |> resonator(880, 0.01))
+ (input |> resonator(1320, 0.01)) * 0.3
```

Low damping = long sustain. Zero damping = infinite freeze.
Each resonator holds one frequency. The sound sustains
naturally because the physics sustains naturally.

### Pitch shift → modulated delay

Read a delay line at a slightly different rate than you
write it. Classic pitch shifter, no FFT:

```
signal |> delay(0.01 + sin(0.5) * 0.005, 0.05)
```

For cleaner pitch shifting, use two delay lines crossfaded
to hide the discontinuity at the buffer boundary.

### Vocoder → bandpass filter bank

Run the modulator (voice) through N bandpass filters to
extract the spectral envelope. Run the carrier (synth)
through the same filters. Multiply the envelopes:

```
let voice = input_signal
let synth = saw(110)
let freqs = [200, 400, 800, 1600, 3200, 6400]

# for each band: extract envelope from voice, apply to synth
let band1 = synth |> bpf(200, 0.95) * abs(voice |> bpf(200, 0.95))
let band2 = synth |> bpf(400, 0.95) * abs(voice |> bpf(400, 0.95))
let band3 = synth |> bpf(800, 0.95) * abs(voice |> bpf(800, 0.95))
# ... etc

(band1 + band2 + band3) * 0.3
```

This is how Moog and EMS vocoders worked. Filter banks,
not FFTs. The "classic" vocoder sound IS the time-domain
sound.

### Spectral gate → resonator with threshold

```
let energy = signal * signal |> lp1(10)
signal * (if energy > 0.01: 1 else: 0)
```

Or using a resonator that only responds above a threshold.

### Convolution reverb → Schroeder reverb

The `reverb` primitive is a Schroeder reverb — comb filters
and allpass filters approximating a room impulse response.
It's a time-domain approximation of what convolution does
in the frequency domain. For music, it sounds as good.

## Where FFT actually wins

Surgical precision. Removing exactly one frequency.
Analyzing the spectrum for visualization. Cross-synthesis
between two complex signals. Phase manipulation.

These are real capabilities. They're also rare in practice.
Most music production uses FFT for spectrum analyzers and
linear-phase EQ — not for sound design.

## If you need FFT

Write it as a DSP primitive in Nim. The function accumulates
samples in a buffer, runs the transform when the buffer is
full, and outputs from the result buffer with overlap-add:

```nim
proc fftProcess*(signal: float64, process: proc(bins: var seq[Complex]),
                 s: State): float64 =
  let blockSize = 1024
  let i = claimDsp(s, blockSize * 4)  # input buf, output buf, window, overlap
  # accumulate samples
  # when buffer full: window, FFT, process(bins), IFFT, overlap-add
  # return from output buffer
```

This breaks the one-sample mental model. The pipe lies about
the latency. But it works, and the user who needs it knows
what they're getting into. It's a power-user escape hatch,
not a default primitive.

## The philosophy

FFT is a mathematical microscope — it reveals structure but
adds complexity. Aither's time-domain primitives are hands —
they shape sound directly. Most of the time, hands are
enough. When you need the microscope, bring your own.
