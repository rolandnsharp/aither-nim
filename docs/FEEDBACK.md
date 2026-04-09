# Feedback

Feedback requires memory. Sample N depends on sample N-1.
That IS state. There is no pure functional way around it.

Haskell disguises feedback as a recursive lazy list. Faust
disguises it as a `~` operator. Under the hood, both store
the previous value somewhere. The state is there — hidden
behind the type system or the algebra.

Aither doesn't hide it:

```
$fb = sin(440 + $fb * 500)
$fb * 0.3
```

`$fb` on the right is the previous sample. `$fb` on the left
is the next. The loop is an assignment. The physics requires
memory, the code has memory, you can see it.

## Three levels

### 1. DSP primitives (feedback hidden)

For common patterns, use a function. The feedback is internal:

```
signal |> fbdelay(0.002, 0.01, 0.95)
signal |> resonator(440, 2)
```

No `$` variable. No visible state. The user doesn't manage
the loop — the primitive does. This is the right choice when
a well-known DSP structure has a name.

### 2. State variables (feedback visible)

For custom feedback topologies, use `$`:

```
# FM feedback — output modulates own frequency
$fb = sin(440 + $fb * 500)

# Chaos — logistic map
$x = 3.59 * $x * (1 - $x)

# Coupled feedback — two values feeding into each other
$a = sin(440 + $b * 200)
$b = sin(330 + $a * 150)
($a + $b) * 0.2
```

The loop is explicit. You see what feeds where. This is the
right choice when the feedback topology is the creative idea.

### 3. Raw physics (feedback is the equation)

The resonator IS a feedback system — position feeds into
velocity feeds into position:

```
$dx += (-2 * $dx - 440*440 * $x + impulse(2)) * dt
$x += $dx * dt
$x
```

Two state variables, coupled. This is the most transparent
form — you're writing the differential equation directly.
The feedback isn't a feature, it's the physics.

## Why not pure functional feedback?

A pure version would look like:

```
sin(440) |> fb(x => x * 0.95 |> delay(0.002))
```

This hides the loop in a lambda. But the whole point of
feedback is "the output goes back in." An assignment says
that directly:

```
$fb = signal + $fb * 0.95
```

Read it out loud: "fb equals the signal plus fb times 0.95."
That's the feedback equation. The code is the diagram.

The lambda version adds abstraction where you need
transparency. For something as fundamental as a signal
feeding into itself, seeing the loop is the feature.

## The rule

If the feedback has a name — delay, reverb, resonator,
Karplus-Strong — use the DSP primitive. The state is
someone else's problem.

If the feedback IS your idea — FM self-modulation, chaos,
coupled oscillators — use `$`. The state is the point.
