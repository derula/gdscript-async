# gdscript-async
Some GDScript async (signal / coroutine) helpers.

## Reference

### Async.any

Creates a new signal that, when awaited, returns after one of the passed signals has emitted.

Usage:

```gdscript
signal signal1
signal signal2(a, b)
func coro1(): await signal1
func coro2(a, b): return await signal2

signal1.emit.call_deferred()
signal2.emit.call_deferred("a", "b")
print(await Async.any([signal1, signal2, coro1, coro2.bind("a", "b")]))  # e.g. [coro2 returned ["a", "b"]]

### Async.all

Creates a new signal that, when awaited, returns after all of the passed signals have emitted.

Usage:

```gdscript
signal signal1
signal signal2(a, b)
func coro1(): await signal1
func coro2(a, b): return await signal2

await Async.all([signal1, signal2, coro1, coro2.bind("a", "b")])  # [[signal]signal1 emitted <null>, coro1 returned <null>, [signal]signal2 emitted ["a", "b"], coro2 returned ["a", "b"]]
```

### Async.coro_to_signal

Converts a coroutine into a signal that, when awaited, will emit the coroutine's return value.

Usage:

```gdscript
signal signal1
signal signal2(string)
func coro1(): await signal1
func coro2(): return await signal2
func coro3(a, b): await signal1

Async.coro_to_signal(coro1).connect(func(_r): print("Hello"))
Async.coro_to_signal(coro2).connect(print)
Async.coro_to_signal(coro3, ["a", "b"]).connect(func(_r): print("World!"))

signal1.emit()  # => Hello\nWorld!
signal2.emit("Goodbye.")  # => Goodbye.
```

### Async.signal_to_coro

Converts a signal into a coroutine that, when awaited, will return signal's next emitted value.

This could be used, for example, if you want to get the next emitted value from a signal with unknown arity.

Usage:

```gdscript
signal signal1
signal signal2(a)
signal signal3(a, b)

signal1.emit.call_deferred()
signal2.emit.call_deferred("a")
signal3.emit.call_deferred("a", "b")

print(await Async.signal_to_coro(signal1).call())  # <null>
print(await Async.signal_to_coro(signal2).call())  # "a"
print(await Async.signal_to_coro(signal3).call())  # ["a", "b"]
```


### Async.map

An async version of `Array.map`. Not sure if it's useful, but I thought it's a fun example to include.

Usage:

```gdscript
func square(value: int):
  await ready
  return value ** 2

print(await Async.map([1, 2, 3, 4], square))  # [1, 4, 9, 16]
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

For the most part, yes. `coro_to_signal` would not work and the way `any` / `all` deal with coroutines would need changes. `any` / `all` calls could not be nested. Not sure about `map`.

## Will you implement tests using GUT?

I honestly tried, but frankly I have no idea how to test async stuff well. PRs welcome.

## Will you add feature XYZ?

I might, if I find it interesting enough. Otherwise, feel free to send a PR.
