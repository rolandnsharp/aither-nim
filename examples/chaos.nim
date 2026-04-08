import aither

signal "chaos", s:
  s["chaos"] = if s["chaos"] == 0.0: 0.5
               else: 3.59 * s["chaos"] * (1.0 - s["chaos"])
  s["tick"] += 1.0
  if s["tick"] >= 2000.0: s["tick"] = 0.0
  let freq = 200.0 + s["chaos"] * 400.0
  s["phase"] = (s["phase"] + freq / s.sr) mod 1.0
  sin(TAU * s["phase"]) * 0.3
