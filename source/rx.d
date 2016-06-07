module modernui.rx;

import modernui.collections;

import std.algorithm;
import std.range;
import std.container.array;

struct None
{
	void[0] dummy;

	immutable static None val = {};
}

alias Action(T) = void delegate(T);
alias Delegate = void delegate();
alias Func(T,K) = K delegate(T);

final class Subscription
{
	private void delegate() action;

	this(void delegate() action)
	{
		this.action = action;
	}

	void release()
	{
		if(action == null) return;

		// executes the action
		this.action();

		// release the reference
		this.action = null;
	}
}

final class Observer(T)
{
	private Action!T onNextCallback;
	private Delegate onCompletedCallback;
	private Action!Exception onErrorCallback;

	this(Action!T nextCallback)
	{
		this.onNextCallback = nextCallback;
		this.onCompletedCallback = null;
		this.onErrorCallback = null;
	}
	
	this(Action!T nextCallback, Action!Exception errorCallback)
	{
		this.onNextCallback = nextCallback;
		this.onCompletedCallback = null;
		this.onErrorCallback = errorCallback;
	}

	this(Action!T nextCallback, Action!Exception errorCallback, Delegate completedCallback)
	{
		this.onNextCallback = nextCallback;
		this.onCompletedCallback = completedCallback;
		this.onErrorCallback = errorCallback;
	}

	void onCompleted()
	{
		if(onCompletedCallback != null) onCompletedCallback();
		finalize();
	}

	void onNext(T value)
	{
		if(onNextCallback != null) onNextCallback(value);
	}

	void onError(Exception e)
	{
		if(onErrorCallback != null) onErrorCallback(e);
		finalize();
	}

	private void finalize()
	{
		// release references to delegates
		onNextCallback = null;
		onErrorCallback = null;
		onCompletedCallback = null;
	}
}

abstract class Observable(T)
{
	private Subscription[Observer!T] observers;
	private Array!(Observer!T) myObserversArray;
	private bool myIsCompleted;

	alias ObservedType = T;

	@property bool isCompleted() { return myIsCompleted; }
	@property bool hasSubscribers() { return observers.length != 0; }

	abstract Subscription subscribe(Observer!T observer);

	bool unsubscribe(Observer!T observer)
	{
		if(observer !in observers)
		{
			return false;
		}

		auto subscription = observers[observer];
		auto result = observers.remove(observer);
		auto foundObs = myObserversArray[].find(observer).takeOne;
		myObserversArray.linearRemove(foundObs);
		subscription.release();
		return result;
	}
}

final class Subject(T) : Observable!T
{
	import std.stdio : writefln;

	void next(T value)
	{
		foreach(observer ; myObserversArray)
		{
			observer.onNext(value);
		}
	}

	void complete()
	{
		foreach(observer ; myObserversArray)
		{
			observer.onCompleted();
		}

		observers.clear();
		myIsCompleted = true;
	}

	void error(Exception e)
	{
		foreach(observer ; myObserversArray)
		{
			observer.onError(e);
		}
	}

	override Subscription subscribe(Observer!T observer)
	{
		if(isCompleted)
		{
			return new Subscription(null);
		}

		auto subscription = new Subscription({
			this.unsubscribe(observer);
		});

		observers[observer] = subscription;
		myObserversArray.insertBack(observer);

		return subscription;
	}
}

unittest
{
	// Observable
	auto test1 = new Subject!int;
	auto test1var = 10;
	test1.then!int((v) { 
		test1var = v; 
	},
	(e)
	{
		test1var = -1;
	},
	{
		test1var = -100;
	});
	assert(test1var == 10);

	test1.next(15);
	assert(test1var == 15);

	test1.next(32);
	assert(test1var == 32);
	
	assert(!test1.isCompleted);
	test1.complete();
	assert(test1var == -100);
	assert(test1.isCompleted);
}

// A Promise is an object representing a observable value that will be resolved in the future.
// As an observable it will yield a single value and switch to completed state.
abstract class Promise(T) : Observable!T
{
	private T myResolvedValue;

	@property T value() { return myResolvedValue; }

	override Subscription subscribe(Observer!T observer)
	{
		if(isCompleted)
		{
			observer.onNext(value);
			return new Subscription({});
		}

		auto subscription = new Subscription({
			this.unsubscribe(observer);
		});

		observers[observer] = subscription;
		myObserversArray.insertBack(observer);

		return subscription;
	}
}

final class Deferred(T) : Promise!T
{
	void resolve(T value)
	{
		myIsCompleted = true;
		foreach(observer; myObserversArray)
		{
			observer.onNext(value);
		}

		foreach(observer; myObserversArray)
		{
			observer.onCompleted();
		}

		observers.clear();
	}

	void error(Exception e)
	{
		myIsCompleted = true;
		foreach(observer; myObserversArray)
		{
			observer.onError(e);
		}

		foreach(observer; myObserversArray)
		{
			observer.onCompleted();
		}

		observers.clear();
	}
}

Subscription then(T)(Observable!T self, Action!T action)
{
	return self.subscribe(new Observer!T(action));
}

Subscription then(T)(Observable!T self, Action!T action, Action!Exception error)
{
	self.subscribe(new Observer!T(action, error));
}

Subscription then(T)(Observable!T self, Action!T action, Action!Exception error, Delegate complete)
{
	return self.subscribe(new Observer!T(action, error, complete));
}

unittest
{
	// Promise
	auto test1 = new Deferred!int;
	auto test1var = 10;
	test1.then!int((v) { 
		test1var = v; 
	});
	assert(test1var == 10);
	assert(!test1.isCompleted);

	test1.resolve(15);
	assert(test1var == 15);
	assert(test1.isCompleted);
}

Observable!T merge(T)(Observable!T[] inputs ...)
{
	auto output = new Subject!T;

	// Intialize a copy of the observables
	auto alive = inputs.length;
	foreach(input ; inputs)
	{
		// We subscribe and forward next() and error() events
		input.then!T((v) {
			output.next(v); 
		}, 
		(e) { 
			output.error(e); 
		}, 
		{
			// On complete(), we test if this is the last observable alive			
			if(alive-- == 0)
			{
				output.complete();
			}
		});
	}

	return output;
}

unittest
{
	auto obs1 = new Subject!int;
	auto obs2 = new Subject!int;
	auto merged = merge(obs1, obs2);

	auto received = 0;
	merged.then!int((v) {
		received = v;
	});

	assert(received == 0);

	obs1.next(10);
	assert(received == 10);
	assert(!merged.isCompleted);

	obs2.next(20);
	assert(received == 20);
	assert(!merged.isCompleted);

	obs2.complete();
	assert(!merged.isCompleted);

	obs1.complete();
	assert(merged.isCompleted);
}
