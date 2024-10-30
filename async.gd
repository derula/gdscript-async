class_name Async

static func any(signals: Array) -> Signal:
	"""
	Create a new signal that emits once any of the
	passed signals or coroutines has finished.
	"""
	return Awaiter.new(signals, 1).finished

static func all(signals: Array) -> Signal:
	"""
	Create a new signal that emits once all of the
	passed signals or coroutines have emitted.
	"""
	return Awaiter.new(signals, len(signals)).finished

static func coro_to_signal(coro: Callable, args := []) -> Signal:
	"""
	Convert a coroutine into a signal that can be awaited,
	assigned to a variable, subscribed to, passed around, etc.
	"""
	return CoroSignal.new(coro.bindv(args)).returned

static func signal_to_coro(a_signal: Signal) -> Variant:
	"""
	Convert a signal into a coroutine. Useful if you
	want to use any/all with non-niladic signals.
	"""
	return func() -> Variant: return await a_signal

static func map(array: Array, coro: Callable) -> Array:
	"""
	Map array elements asynchronously.
	"""
	return await Mapper.new(array, coro).mapped

class KeepAlive:
	"""
	A reference counted object that keeps itself alive through
	a cyclic reference until its finished signal is emitted.
	"""
	signal finished
	var _me: KeepAlive

	func _init() -> void:
		_me = self
		finished.connect(func() -> void: _me = null)

class Awaiter extends KeepAlive:
	"""
	A KeepAlive that finishes itself once a certain number
	of the passed signals or coroutines have been awaited.
	"""
	var emits_left: int

	func _init(signals: Array, how_many: int) -> void:
		super()
		emits_left = how_many
		for untyped_signal: Variant in signals:
			if untyped_signal is Signal:
				var typed_signal: Signal = untyped_signal
				typed_signal.connect(_collected, CONNECT_ONE_SHOT)
			elif untyped_signal is Callable:
				var coro: Callable = untyped_signal
				CoroSignal.new(coro).finished.connect(_collected)
			elif untyped_signal is Array:
				var args: Array = untyped_signal
				var coro: Callable = args.pop_front()
				CoroSignal.new(coro.bindv(args)).finished.connect(_collected)
			else:
				push_error("Cannot wait for " + type_string(typeof(untyped_signal)))
				emits_left -= 1

	func _collected() -> void:
		emits_left -= 1
		if emits_left == 0: finished.emit()

class CoroSignal extends KeepAlive:
	"""
	A KeepAlive that finishes itself once the passed coroutine has been awaited.
	You can await the `returned` signal to get the coroutine's return value.
	"""
	signal returned(value: Variant)

	func _init(coro: Callable) -> void:
		super()
		_run_coro(coro)

	func _run_coro(coro: Callable) -> void:
		returned.emit(await coro.call())
		finished.emit()

class Mapper extends KeepAlive:
	"""
	A KeepAlive asynchronously maps array values using a coroutine.
	You can await the `mapped` signal to get the mapped array.
	"""
	signal mapped(result: Array)

	func _init(array: Array, coro: Callable) -> void:
		super()
		var result := array.duplicate()
		var signals := []
		for i: int in range(len(array)):
			signals[i] = func() -> void: result[i] = await coro.call(array[i])
		Async.all(signals).connect(func() -> void:
			mapped.emit(result)
			finished.emit()
		)
