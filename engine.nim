import std/[os, osproc, dynlib, net, strutils, math]
import aither
import miniaudio

const
  SampleRate  = 48000'u32
  Channels    = 2'u32
  BufferFrames = 512'u32
  MaxSignals  = 16
  SocketPath  = "/tmp/aither.sock"

type
  Signal = object
    name: string
    fn: SignalFn
    state: State
    active: bool
    lib: LibHandle
    fadeGain: float64
    fadeDelta: float64

var
  signals: array[MaxSignals, Signal]
  signalCount: int
  running: bool
  engineDir: string
  timeSec: float64
  timeFrac: float64
  loadCounter: int

# ----------------------------------------------------------- audio callback

proc audioCallback(output: ptr UncheckedArray[cfloat], frameCount: cuint,
                    userData: pointer) {.cdecl.} =
  let dt = 1.0 / float64(SampleRate)
  let frames = int(frameCount)
  let sc = signalCount

  for i in 0 ..< frames:
    timeFrac += dt
    if timeFrac >= 1.0:
      timeSec += 1.0
      timeFrac -= 1.0
    let t = timeSec + timeFrac

    var mix = 0.0
    for v in 0 ..< sc:
      if not signals[v].active: continue
      let fn = signals[v].fn
      if fn == nil: continue

      let st = signals[v].state
      st.t = t
      st.dspIdx = 0

      var sample = fn(st)
      if sample != sample: sample = 0.0              # NaN
      elif sample > 1e6 or sample < -1e6: sample = 0.0  # overflow

      signals[v].fadeGain = clamp(
        signals[v].fadeGain + signals[v].fadeDelta, 0.0, 1.0)
      if signals[v].fadeGain <= 0.0 and signals[v].fadeDelta < 0.0:
        signals[v].active = false

      mix += sample * signals[v].fadeGain

    let clipped = cfloat(tanh(mix))
    output[i * 2]     = clipped
    output[i * 2 + 1] = clipped

# ---------------------------------------------------------- state lifecycle

proc newState(): State =
  result = cast[State](alloc0(sizeof(StateObj)))
  result.sr = float64(SampleRate)
  result.dt = 1.0 / float64(SampleRate)
  result.dsp = cast[ptr UncheckedArray[float64]](
    alloc0(DspPoolSize * sizeof(float64)))
  result.dspLen = DspPoolSize

proc freeState(s: State) =
  if s != nil:
    if s.dsp != nil: dealloc(s.dsp)
    dealloc(s)

# -------------------------------------------------------------- signal mgmt

proc findSignal(name: string): int =
  for i in 0 ..< signalCount:
    if signals[i].name == name: return i
  -1

proc loadPatch(filename: string): string =
  if not fileExists(filename):
    return "file not found: " & filename

  let outDir = engineDir / "patches"
  createDir(outDir)
  let base = splitFile(filename).name
  inc loadCounter
  let soPath = outDir / base & "." & $loadCounter & ".so"

  let cmd = "nim c --app:lib --mm:arc --opt:speed --hints:off " &
            "--warning:UnusedImport:off " &
            "--path:" & quoteShell(engineDir) & " " &
            "--out:" & quoteShell(soPath) & " " &
            quoteShell(filename)

  stderr.write "compiling " & extractFilename(filename) & " ... "
  let (output, exitCode) = execCmdEx(cmd)
  if exitCode != 0:
    stderr.writeLine "FAIL"
    return "compile error:\n" & output
  stderr.writeLine "ok"

  let lib = loadLib(soPath)
  if lib == nil:
    return "dlopen failed: " & soPath

  let nameFn   = cast[proc(): cstring {.cdecl.}](lib.symAddr("aither_signal_name"))
  let signalFn = cast[SignalFn](lib.symAddr("aither_signal_fn"))
  if nameFn == nil or signalFn == nil:
    unloadLib(lib)
    return "missing exports in " & soPath

  let sname = $nameFn()
  let idx = findSignal(sname)

  if idx >= 0:
    signals[idx].fn = signalFn
    signals[idx].state.dspIdx = 0
    signals[idx].lib = lib          # old lib leaked (safe for hot path)
    if not signals[idx].active:
      signals[idx].active = true
      signals[idx].fadeGain = 1.0
      signals[idx].fadeDelta = 0.0
    stderr.writeLine "  hot-swapped: " & sname
  else:
    if signalCount >= MaxSignals:
      unloadLib(lib)
      return "signal limit reached (" & $MaxSignals & ")"
    signals[signalCount] = Signal(
      name: sname, fn: signalFn, state: newState(),
      active: true, lib: lib, fadeGain: 1.0, fadeDelta: 0.0)
    inc signalCount
    stderr.writeLine "  loaded: " & sname
  ""

proc stopSignal(name: string): string =
  let idx = findSignal(name)
  if idx < 0: return "not found: " & name
  signals[idx].fadeDelta = -1.0 / (0.01 * float64(SampleRate))
  ""

proc listSignals(): string =
  var lines: seq[string]
  for i in 0 ..< signalCount:
    let tag = if signals[i].active: "playing" else: "stopped"
    lines.add signals[i].name & " [" & tag & "]"
  if lines.len == 0: "(no signals)" else: lines.join("\n")

# -------------------------------------------------------- command handling

proc handleCmd(line: string): string =
  let parts = line.strip().split(' ', 1)
  if parts.len == 0: return "ERR empty"
  case parts[0].toLowerAscii()
  of "send":
    if parts.len < 2: return "ERR usage: send <file>"
    let err = loadPatch(parts[1].strip())
    if err.len > 0: "ERR " & err else: "OK"
  of "stop":
    if parts.len < 2: return "ERR usage: stop <name>"
    let err = stopSignal(parts[1].strip())
    if err.len > 0: "ERR " & err else: "OK"
  of "list":
    "OK\n" & listSignals()
  of "kill":
    running = false
    "OK bye"
  else:
    "ERR unknown: " & parts[0]

# ----------------------------------------------------------------- engine

proc startEngine() =
  engineDir = getCurrentDir()

  if aither_audio_init(SampleRate, Channels, BufferFrames,
                        audioCallback, nil) != 0:
    quit "audio init failed", 1
  if aither_audio_start() != 0:
    quit "audio start failed", 1

  echo "aither \xC2\xB7 ", SampleRate, " Hz \xC2\xB7 ", SocketPath

  if fileExists(SocketPath): removeFile(SocketPath)

  var server = newSocket(AF_UNIX, SOCK_STREAM, IPPROTO_IP)
  server.bindUnix(SocketPath)
  server.listen()

  running = true
  while running:
    try:
      var client: Socket
      server.accept(client)
      let cmd = client.recvLine()
      let resp = handleCmd(cmd)
      client.send(resp & "\n")
      client.close()
    except CatchableError:
      if running: discard

  discard aither_audio_stop()
  aither_audio_uninit()
  server.close()
  try: removeFile(SocketPath) except CatchableError: discard

  for i in 0 ..< signalCount:
    if signals[i].lib != nil: unloadLib(signals[i].lib)
    freeState(signals[i].state)
  echo "bye"

# ------------------------------------------------------------------ client

proc sendCmd(cmd: string) =
  var sock = newSocket(AF_UNIX, SOCK_STREAM, IPPROTO_IP)
  try:
    sock.connectUnix(SocketPath)
    sock.send(cmd & "\n")
    let resp = sock.recv(65536)
    echo resp.strip()
  except OSError:
    echo "error: engine not running? (" & SocketPath & ")"
  finally:
    sock.close()

# -------------------------------------------------------------------- CLI

when isMainModule:
  let args = commandLineParams()
  if args.len == 0:
    echo "usage: aither <start|send|stop|list|kill>"
    echo ""
    echo "  start            launch engine"
    echo "  send <patch.nim> compile & hot-load signal"
    echo "  stop <name>      fade out & remove signal"
    echo "  list             show active signals"
    echo "  kill             shut down engine"
    quit 0

  case args[0]
  of "start":
    startEngine()
  of "send":
    if args.len < 2: quit "usage: aither send <patch.nim>"
    sendCmd("send " & absolutePath(args[1]))
  of "stop":
    if args.len < 2: quit "usage: aither stop <name>"
    sendCmd("stop " & args[1])
  of "list":
    sendCmd("list")
  of "kill":
    sendCmd("kill")
  else:
    echo "unknown command: " & args[0]
    quit 1
