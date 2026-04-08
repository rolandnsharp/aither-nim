import aither

signal "kick", s:
  s["phase"] += 60.0 / s.sr
  sin(TAU * s["phase"]) * 0.8
