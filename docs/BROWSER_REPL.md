# Browser REPL

Compile the DSP library to JavaScript once with `nim js`.
Eval patches instantly in the browser. No compile step,
no server, no build tools. A single HTML file.

## Architecture

```
dsp.nim ──nim js──> dsp.js (compiled once, static asset)
                      │
user types patch ──eval()──> calls dsp.js functions
                      │
              AudioWorklet ──> speakers
```

The Nim DSP library — `sin`, `saw`, `lpf`, `resonator`,
`impulse`, `discharge`, all of it — compiles to JavaScript
via Nim's JS backend. The output is a single `dsp.js` file
shipped as a static asset.

The user types a patch in a text box. On enter, `eval()`
runs it. The patch calls the DSP functions from `dsp.js`.
The AudioWorklet calls the resulting function 48,000 times
per second. Sound comes out.

No compilation. No server. No nim or gcc on the user's
machine. Just a browser.

## How it works

### Step 1: Compile DSP to JS

```bash
nim js --opt:speed -o:web/dsp.js dsp.nim
```

This runs once. The output is a JavaScript file containing
all DSP functions as native JS. `sin(freq, s)` becomes a
JS function that does the same math. The Nim source is not
shipped — only the compiled JS.

### Step 2: The AudioWorklet

The worklet runs per-sample, same as the native engine:

```javascript
// worklet.js
class AitherProcessor extends AudioWorkletProcessor {
  constructor() {
    super()
    this.state = { t: 0, dt: 1/48000, sr: 48000, dspIdx: 0 }
    this.fn = () => 0
    this.port.onmessage = (e) => {
      this.fn = e.data
    }
  }

  process(inputs, outputs) {
    const out = outputs[0][0]
    const s = this.state
    for (let i = 0; i < out.length; i++) {
      s.t += s.dt
      s.dspIdx = 0
      let sample = this.fn(s)
      if (isNaN(sample) || !isFinite(sample)) sample = 0
      out[i] = Math.tanh(sample)
    }
    return true
  }
}

registerProcessor('aither', AitherProcessor)
```

Same audio callback as the native engine. Same state
model. Same NaN protection. Same tanh soft clip.

### Step 3: The page

```html
<!DOCTYPE html>
<html>
<head><title>aither</title></head>
<body style="background:#111;color:#0f0;font-family:monospace">
  <textarea id="patch" rows="10" cols="60"
    style="background:#000;color:#0f0;border:1px solid #0f0;
           font-family:monospace;font-size:14px;width:100%"
  >saw(55, s) |> lpf(800, 0.5, s) * 0.3</textarea>
  <br>
  <button onclick="send()" style="color:#0f0;background:#222;
    border:1px solid #0f0;padding:8px 16px;cursor:pointer"
  >send (ctrl+enter)</button>
  <canvas id="scope" width="640" height="200"
    style="border:1px solid #0f0;display:block;margin-top:8px"
  ></canvas>

  <script src="dsp.js"></script>
  <script>
    let ctx, node

    async function init() {
      ctx = new AudioContext({ sampleRate: 48000 })
      await ctx.audioWorklet.addModule('worklet.js')
      node = new AudioWorkletNode(ctx, 'aither')
      node.connect(ctx.destination)
    }

    function send() {
      const code = document.getElementById('patch').value
      try {
        const fn = new Function('s', code)
        node.port.postMessage(fn)
      } catch (e) {
        console.error(e)
      }
    }

    document.addEventListener('keydown', (e) => {
      if (e.ctrlKey && e.key === 'Enter') { send(); e.preventDefault() }
    })

    document.getElementById('patch').addEventListener('focus', () => {
      if (!ctx) init()
    })
  </script>
</body>
</html>
```

Green on black. Text box. Send button. Oscilloscope canvas.
That's the entire application.

### Step 4: Phosphor scope

Draw the output waveform on the canvas. The worklet sends
samples to the main thread via a SharedArrayBuffer or
port messages. The canvas renders with phosphor decay:

```javascript
function drawScope(samples) {
  const canvas = document.getElementById('scope')
  const g = canvas.getContext('2d')

  // phosphor decay — fade previous frame
  g.fillStyle = 'rgba(0, 0, 0, 0.1)'
  g.fillRect(0, 0, canvas.width, canvas.height)

  // draw new samples
  g.strokeStyle = '#0f0'
  g.beginPath()
  for (let i = 0; i < samples.length; i++) {
    const x = (i / samples.length) * canvas.width
    const y = (0.5 - samples[i] * 0.4) * canvas.height
    if (i === 0) g.moveTo(x, y)
    else g.lineTo(x, y)
  }
  g.stroke()

  requestAnimationFrame(() => drawScope(latestSamples))
}
```

## What the user experiences

1. Open an HTML file in a browser
2. See a text box with green text on black
3. Type: `saw(55, s) |> lpf(800, 0.5, s) * 0.3`
4. Press ctrl+enter
5. Hear the sound immediately
6. See the waveform on the scope
7. Edit the numbers, press ctrl+enter again
8. Sound changes instantly — no compilation

## Hot-swap

`new Function()` creates a fresh function from the code
string. `postMessage` sends it to the worklet. The worklet
swaps the function pointer. State persists — same `s` object,
same `$` variables, same phase continuity.

This is the same hot-swap as the native engine. The function
changes, the state survives. No clicks, no pops.

## Why this is the ideal demo

- Zero install — open a URL, start making sound
- Instant feedback — type, enter, hear
- Same DSP — the Nim functions compiled to JS
- Same syntax — identical to native aither patches
- Oscilloscope built in — see what you hear
- Shareable — send someone a link, they hear your patch

The browser is the REPL. The native binary is the instrument.
Same language. Same sound.

## Limitations

- JS is slower than native — fewer simultaneous signals
- AudioWorklet has ~3ms minimum latency (128 sample buffer)
- No file system — patches live in the text box or URL params
- Single-precision float in some browsers (WebAudio spec)
- `eval()` security — only safe for local/trusted use

For production performance, use the native Nim binary.
For exploration, teaching, and sharing — the browser is
instant.

## Deploying

Three files. No server needed. Open `index.html` from disk:

```
web/
  index.html      — the page
  dsp.js          — compiled from Nim (nim js dsp.nim)
  worklet.js      — AudioWorklet processor
```

Or host on any static file server. GitHub Pages works.
No backend, no database, no API. Just files.
