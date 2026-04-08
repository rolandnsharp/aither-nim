import std/[math, macros]
export math

const
  MaxSlots* = 128
  MaxKeyLen* = 32
  DspPoolSize* = 262144 ## 256K floats (~2 MB) per signal

type
  StateObj* = object
    t*: float64        ## time in seconds
    dt*: float64       ## 1 / sample_rate
    sr*: float64       ## sample rate
    dspIdx*: int       ## DSP state counter (reset each sample)
    slotCount*: int
    keys*: array[MaxSlots, array[MaxKeyLen, char]]
    vals*: array[MaxSlots, float64]
    dsp*: ptr UncheckedArray[float64]
    dspLen*: int

  State* = ptr StateObj
  SignalFn* = proc(s: State): float64 {.cdecl.}

# --- key helpers (allocation-free) ---

proc keyEq(a: array[MaxKeyLen, char], b: string): bool {.inline.} =
  if b.len >= MaxKeyLen: return false
  for i in 0 ..< b.len:
    if a[i] != b[i]: return false
  a[b.len] == '\0'

proc setKey(dst: var array[MaxKeyLen, char], src: string) {.inline.} =
  let n = min(src.len, MaxKeyLen - 1)
  for i in 0 ..< n: dst[i] = src[i]
  dst[n] = '\0'

# --- state access ---

proc `[]`*(s: State, key: string): var float64 =
  for i in 0 ..< s.slotCount:
    if keyEq(s.keys[i], key): return s.vals[i]
  # auto-create slot with default 0.0
  if s.slotCount < MaxSlots:
    setKey(s.keys[s.slotCount], key)
    s.vals[s.slotCount] = 0.0
    let idx = s.slotCount
    inc s.slotCount
    return s.vals[idx]
  return s.vals[0] # overflow fallback

# --- DSP state allocation ---

proc claimDsp*(s: State, n: int = 1): int {.inline.} =
  result = s.dspIdx
  s.dspIdx += n

# --- pipe operator ---

macro `|>`*(lhs: typed, rhs: untyped): untyped =
  ## Insert lhs as the first argument of rhs.
  result = rhs.copyNimTree()
  result.insert(1, lhs)

# --- signal macro ---

macro signal*(name: static[string], stateVar: untyped, body: untyped): untyped =
  ## Generates exported signal function + name accessor for .so loading.
  result = newStmtList()
  # proc aither_signal_fn*(s: State): float64 {.exportc, dynlib, cdecl.}
  result.add nnkProcDef.newTree(
    nnkPostfix.newTree(ident"*", ident"aither_signal_fn"),
    newEmptyNode(), newEmptyNode(),
    nnkFormalParams.newTree(
      ident"float64",
      nnkIdentDefs.newTree(stateVar, ident"State", newEmptyNode())
    ),
    nnkPragma.newTree(ident"exportc", ident"dynlib", ident"cdecl"),
    newEmptyNode(),
    body
  )
  # proc aither_signal_name*(): cstring {.exportc, dynlib, cdecl.}
  result.add nnkProcDef.newTree(
    nnkPostfix.newTree(ident"*", ident"aither_signal_name"),
    newEmptyNode(), newEmptyNode(),
    nnkFormalParams.newTree(ident"cstring"),
    nnkPragma.newTree(ident"exportc", ident"dynlib", ident"cdecl"),
    newEmptyNode(),
    newStmtList(newLit(name))
  )
