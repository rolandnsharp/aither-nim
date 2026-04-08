import aither

# ---------------------------------------------------------------- oscillators

proc sin*(freq: float64, s: State): float64 =
  let i = claimDsp(s)
  s.dsp[i] = (s.dsp[i] + freq / s.sr) mod 1.0
  sin(TAU * s.dsp[i])

proc saw*(freq: float64, s: State): float64 =
  let i = claimDsp(s)
  s.dsp[i] = (s.dsp[i] + freq / s.sr) mod 1.0
  s.dsp[i] * 2.0 - 1.0

proc tri*(freq: float64, s: State): float64 =
  let i = claimDsp(s)
  s.dsp[i] = (s.dsp[i] + freq / s.sr) mod 1.0
  abs(s.dsp[i] * 4.0 - 2.0) - 1.0

proc square*(freq: float64, s: State): float64 =
  let i = claimDsp(s)
  s.dsp[i] = (s.dsp[i] + freq / s.sr) mod 1.0
  if s.dsp[i] < 0.5: 1.0 else: -1.0

proc pulse*(freq, width: float64, s: State): float64 =
  let i = claimDsp(s)
  s.dsp[i] = (s.dsp[i] + freq / s.sr) mod 1.0
  if s.dsp[i] < width: 1.0 else: -1.0

proc phasor*(freq: float64, s: State): float64 =
  let i = claimDsp(s)
  s.dsp[i] = (s.dsp[i] + freq / s.sr) mod 1.0
  s.dsp[i]

proc wave*(freq: float64, values: openArray[float64], s: State): float64 =
  let i = claimDsp(s)
  s.dsp[i] = (s.dsp[i] + freq / s.sr) mod 1.0
  let idx = int(s.dsp[i] * float64(values.len)) mod values.len
  values[idx]

proc noise*(s: State): float64 =
  let i = claimDsp(s)
  var seed = if s.dsp[i] == 0.0: 12345'u32 else: uint32(s.dsp[i])
  seed = seed xor (seed shl 13)
  seed = seed xor (seed shr 17)
  seed = seed xor (seed shl 5)
  s.dsp[i] = float64(seed)
  float64(seed) / 4294967295.0 * 2.0 - 1.0

# ---------------------------------------------------------- one-pole filters

proc lp1*(signal, cutoff: float64, s: State): float64 =
  let i = claimDsp(s)
  let a = clamp(cutoff / s.sr, 0.0, 1.0)
  s.dsp[i] += a * (signal - s.dsp[i])
  s.dsp[i]

proc hp1*(signal, cutoff: float64, s: State): float64 =
  let i = claimDsp(s)
  let a = clamp(cutoff / s.sr, 0.0, 1.0)
  s.dsp[i] += a * (signal - s.dsp[i])
  signal - s.dsp[i]

# ------------------------------------------------ SVF (Cytomic trapezoidal)

type FilterMode* = enum
  fmLow, fmHigh, fmBand, fmNotch

proc svf*(signal, cutoff, res: float64, mode: FilterMode, s: State): float64 =
  let i = claimDsp(s, 2)
  let g = tan(PI * min(cutoff, s.sr * 0.49) / s.sr)
  let k = 2.0 * (1.0 - res)
  let a1 = 1.0 / (1.0 + g * (g + k))
  let a2 = g * a1
  let a3 = g * a2
  let v3 = signal - s.dsp[i + 1]
  let v1 = a1 * s.dsp[i] + a2 * v3
  let v2 = s.dsp[i + 1] + a2 * s.dsp[i] + a3 * v3
  s.dsp[i]     = 2.0 * v1 - s.dsp[i]
  s.dsp[i + 1] = 2.0 * v2 - s.dsp[i + 1]
  case mode
  of fmLow:   v2
  of fmHigh:  signal - k * v1 - v2
  of fmBand:  v1
  of fmNotch: signal - k * v1

proc lpf*(signal, cutoff, res: float64, s: State): float64 =
  svf(signal, cutoff, res, fmLow, s)

proc hpf*(signal, cutoff, res: float64, s: State): float64 =
  svf(signal, cutoff, res, fmHigh, s)

proc bpf*(signal, cutoff, res: float64, s: State): float64 =
  svf(signal, cutoff, res, fmBand, s)

proc notch*(signal, cutoff, res: float64, s: State): float64 =
  svf(signal, cutoff, res, fmNotch, s)

# ------------------------------------------------------------------- delay

proc delay*(signal, time, maxTime: float64, s: State): float64 =
  let bufLen = max(1, int(maxTime * s.sr))
  let base = claimDsp(s, 1 + bufLen)
  let cursor = int(s.dsp[base]) mod bufLen
  let rd = (cursor - clamp(int(time * s.sr), 0, bufLen - 1) + bufLen) mod bufLen
  result = s.dsp[base + 1 + rd]
  s.dsp[base + 1 + cursor] = signal
  s.dsp[base] = float64((cursor + 1) mod bufLen)

proc fbdelay*(signal, time, maxTime, fb: float64, s: State): float64 =
  let bufLen = max(1, int(maxTime * s.sr))
  let base = claimDsp(s, 1 + bufLen)
  let cursor = int(s.dsp[base]) mod bufLen
  let rd = (cursor - clamp(int(time * s.sr), 0, bufLen - 1) + bufLen) mod bufLen
  result = s.dsp[base + 1 + rd]
  s.dsp[base + 1 + cursor] = signal + result * fb
  s.dsp[base] = float64((cursor + 1) mod bufLen)

# ------------------------------------------------------------------ reverb

proc reverb*(signal, rt60, wet: float64, s: State): float64 =
  const
    combLens  = [1557, 1617, 1491, 1422]
    apLens    = [225, 556]
    apFb      = 0.5
    damp      = 0.3
  var total = 0
  for L in combLens: total += 2 + L
  for L in apLens:   total += 1 + L
  let base = claimDsp(s, total)
  var off = base

  # 4 parallel comb filters
  var combSum = 0.0
  for ci in 0 .. 3:
    let blen = combLens[ci]
    let curSlot  = off
    let dampSlot = off + 1
    let bufStart = off + 2
    off += 2 + blen
    let cur = int(s.dsp[curSlot]) mod blen
    let output = s.dsp[bufStart + cur]
    let filt = output * (1.0 - damp) + s.dsp[dampSlot] * damp
    s.dsp[dampSlot] = filt
    let g = pow(10.0, -3.0 * float64(blen) / (rt60 * s.sr))
    s.dsp[bufStart + cur] = signal + filt * g
    s.dsp[curSlot] = float64((cur + 1) mod blen)
    combSum += output

  # 2 series allpass filters
  var ap = combSum * 0.25
  for ai in 0 .. 1:
    let blen = apLens[ai]
    let curSlot  = off
    let bufStart = off + 1
    off += 1 + blen
    let cur = int(s.dsp[curSlot]) mod blen
    let bufOut = s.dsp[bufStart + cur]
    s.dsp[bufStart + cur] = ap + bufOut * apFb
    ap = bufOut - ap
    s.dsp[curSlot] = float64((cur + 1) mod blen)

  signal * (1.0 - wet) + ap * wet

# ---------------------------------------------------------------- tremolo

proc tremolo*(signal, rate, depth: float64, s: State): float64 =
  let i = claimDsp(s)
  s.dsp[i] = (s.dsp[i] + rate / s.sr) mod 1.0
  let lfo = (sin(TAU * s.dsp[i]) + 1.0) * 0.5
  signal * (1.0 - depth + lfo * depth)

# ------------------------------------------------------------------- slew

proc slew*(signal, time: float64, s: State): float64 =
  let i = claimDsp(s)
  let a = if time > 0.0: min(1.0, s.dt / time) else: 1.0
  s.dsp[i] += (signal - s.dsp[i]) * a
  s.dsp[i]

# -------------------------------------------------------- stateless helpers

proc gain*(signal, g: float64): float64 {.inline.} = signal * g

proc fold*(signal, amount: float64): float64 =
  var x = signal * amount
  x = ((x mod 4.0) + 4.0) mod 4.0
  if x < 2.0: x - 1.0 else: 3.0 - x

proc decay*(signal, rate: float64): float64 {.inline.} =
  exp(-signal * rate)

proc mix*(signals: varargs[float64]): float64 =
  for v in signals: result += v
