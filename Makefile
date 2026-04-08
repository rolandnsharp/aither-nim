NIM   := nim
FLAGS := --mm:arc --threads:on --opt:speed -d:release --hints:off

all: aither

aither: engine.nim aither.nim dsp.nim miniaudio.nim miniaudio_wrapper.c miniaudio.h
	$(NIM) c $(FLAGS) --out:aither engine.nim

clean:
	rm -rf aither patches/ nimcache/

.PHONY: all clean
