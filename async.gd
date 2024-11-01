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
	return CoroSignal.new(coro.bindv(args)).finished

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
	return await Mapper.new(array, coro).finished

class KeepAlive:
	"""
	A reference counted object that keeps itself alive through
	a cyclic reference until its finished signal is emitted.
	"""
	var _me: KeepAlive

	func keep_until(destroy_signal: Signal) -> void:
		_me = self
		destroy_signal.connect(func(_r: Variant) -> void: _me = null)

class Awaiter extends KeepAlive:
	"""
	A KeepAlive that finishes itself once a certain number
	of the passed signals or coroutines have been awaited.
	"""
	signal finished(results: AwaitedResults)
	var results: AwaitedResults

	func _init(signals: Array, how_many: int) -> void:
		keep_until(finished)
		for untyped_signal: Variant in signals:
			if untyped_signal is Signal:
				var typed_signal: Signal = untyped_signal
				(func() -> void: _collected(untyped_signal, await typed_signal)).call()
			elif untyped_signal is Callable:
				var typed_signal: Callable = untyped_signal
				(func() -> void: _collected(untyped_signal, await typed_signal.call())).call()
			else:
				push_error("Cannot wait for " + type_string(typeof(untyped_signal)))
				how_many -= 1
		results = AwaitedResults.new(how_many, finished)

	func _collected(awaitable: Variant, result: Variant) -> void:
		results.collected.emit(AwaitedResult.new(awaitable, result))

class CoroSignal extends KeepAlive:
	"""
	A KeepAlive that finishes itself once the passed coroutine has been awaited.
	You can await the `returned` signal to get the coroutine's return value.
	"""
	signal finished(value: Variant)

	func _init(coro: Callable) -> void:
		keep_until(finished)
		(func() -> void: finished.emit(await coro.call())).call()

class Mapper extends KeepAlive:
	"""
	A KeepAlive asynchronously maps array values using a coroutine.
	You can await the `mapped` signal to get the mapped array.
	"""
	signal finished(value: Variant)

	func _init(array: Array, coro: Callable) -> void:
		keep_until(finished)
		var result := array.duplicate()
		var signals: Array[Callable] = []
		for i: int in range(len(array)):
			signals.append(func() -> void: result[i] = await coro.call(array[i]))
		Async.all(signals).connect(finished.emit.bind(result).unbind(1))

class AwaitedResults:
	"""
	A collection of awaited signals and coroutines.
	Use the `has` function to check if a specific awaitable has emitted /
	returned, or use `flatten` to get all results in one linear array.
	"""
	signal collected(result: AwaitedResult)

	var all: Array[AwaitedResult]

	func _init(how_many: int, finished: Signal) -> void:
		collected.connect(func(result: AwaitedResult) -> void:
			all.append(result)
			if len(all) == how_many: finished.emit(self)
		)

	func has(awaitable: Variant) -> bool:
		for result: AwaitedResult in all:
			if result.result is not AwaitedResults:
				if result.awaited == awaitable: return true
				continue
			var inner_result: AwaitedResults = result.result
			if inner_result.has(awaitable): return true
		return false

	func flatten() -> Array[AwaitedResult]:
		var results: Array[AwaitedResult]
		for result: AwaitedResult in all:
			if result.result is not AwaitedResults:
				results.append(result)
				continue
			var inner_result: AwaitedResults = result.result
			results.append_array(inner_result.flatten())
		return results

	func _to_string() -> String: return str(flatten())

class AwaitedResult:
	"""
	An awaited signal or coroutine together with its emitted / returned value(s).
	Multi-parameter signals will have an array, void functions a null result.
	In all other cases, the result will be a single value.
	"""
	var awaited_signal: Signal:
		get(): return awaited if awaited is Signal else null
	var awaited_coro: Callable:
		get(): return awaited if awaited is Callable else null
	var awaited: Variant
	var result: Variant

	func _init(awaitable: Variant, a_result: Variant) -> void:
		awaited = awaitable
		result = a_result

	func _to_string() -> String:
		var glue := " emitted " if awaited is Signal else " returned "
		return str(awaited) + glue + str(result)
