import aither, dsp

signal "bass", s:
  saw(55.0, s).lpf(800.0, 0.5, s).gain(0.4)
