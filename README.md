# gdscript-async
Some GDScript async (signal / coroutine) helpers.

## Reference

### Async.any

Creates a new signal that, when awaited, returns after one of the passed signals has emitted.

Usage:

```gdscript
signal signal1
signal signal2(a, b)

func coro1():
  await ready

func coro2(a, b):
  await renamed

await Async.any([signal1, Async.signal_to_coro(signal2), coro1, [coro2, "a", "b"]])
```

### Async.all

Creates a new signal that, when awaited, returns after all of the passed signals have emitted.

Usage:

```gdscript
signal signal1
signal signal2(a, b)

func coro1():
  await ready

func coro2(a, b):
  await renamed

await Async.all([signal1, Async.signal_to_coro(signal2), coro1, [coro2, "a", "b"]])
```

### Async.coro_to_signal

Converts a coroutine into a signal that, when awaited, will emit the coroutine's return value.

Usage:

```gdscript
func coro1():
  await ready

func coro2():
  return await replacing_by

func coro3(a, b):
  await ready

var coro_signal1: Signal = Async.coro_to_signal(coro1)
var coro_signal2: Signal = Async.coro_to_signal(coro2)
var coro_signal3: Signal = Async.coro_to_signal(coro3, "a", "b")

coro_signal1.connect(func(): print("Hello"))
coro_signal2.connect(func(node: Node): node.free())
coro_signal3.connect(func(): print("World!"))
ready.emit()  # => print("Hello"), print("World!")
replacing_by.emit(self)  # => self.free()
```

### Async.signal_to_coro

Converts a signal into a coroutine that, when awaited, will return signal's next emitted value.

This can be used to pass a signals with arguments to `Async.any` or `Async.all`, which would otherwise fail.

Usage:

```gdscript
signal signal1
signal signal2(a)
signal signal3(a, b)

var signal_coro1: Signal = Async.coro_to_signal(coro1)
var signal_coro2: Signal = Async.coro_to_signal(coro2)
var signal_coro3: Signal = Async.coro_to_signal(coro3)

signal1.emit.call_deferred()
signal2.emit.call_deferred("a")
signal3.emit.call_deferred("a", "b")
print(await Async.signal_to_coro(signal_coro1).call())  # <null>
print(await Async.signal_to_coro(signal_coro2).call())  # "a"
print(await Async.signal_to_coro(signal_coro3).call())  # ["a", "b"]
```


### Async.map

An async version of `Array.map`. I haven't actually tested, but thought it's a fun example to include.

Usage:

```gdscript
func square(value: int):
  await ready
  return value ** 2

var squares = Async.map([1, 2, 3, 4], square)
```

### Combinations

Since the `any` / `all` functions return signals, they can be combined like so:

```gdscript
await Async.any([
  signal1,
  Async.all([
    signal2,
    signal3,
    Async.any([...])
  ]
])
```

## Why?

I just sometimes thought "gee, I sure wish I could just use `Promise.any` in GDScript," so I made this. Shared it here in case someone finds it useful.

## How does it work?

Basically, it creates reference counted objects with signals and then returns those signals. This normally wouldn't work, because the signal instance holds a weak reference to the owning object, meaning once the reference count for the owning object reaches 0, the signal's object "pointer" will be set to `null`, which will cause an error when the signal tries to run. As a workaround, the objects store a reference of themselves in a variable (see `KeepAlive` class). This reference is freed as soon as the object's signal is triggered, deleting the object. This may break if Juan implements cycle detection...

## Would it work without the `KeepAlive` hack?

For the most part, yes. `coro_to_signal` would not work and the way `any` / `all` deal with coroutines would need changes. `any` / `all` calls could not be nested. I think `map` should work fine.

## Will you implement tests using GUT?

I honestly tried, but frankly I have no idea how to test async stuff well. PRs welcome.

## Will you add feature XYZ?

I might, if I find it interesting enough. Otherwise, feel free to send a PR.
