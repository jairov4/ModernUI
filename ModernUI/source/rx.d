module Rx;

enum Unit { Unit };

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
		// executes the action
		this.action();

		// release the reference
		this.action = null;
	}
}

final class Observer(T)
{
	Action!T onNextCallback;
	Delegate onCompletedCallback;
	Action!Exception onErrorCallback;

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
	private bool myIsCompleted;

	@property bool isCompleted() { return myIsCompleted; }

	abstract Subscription subscribe(Observer!T observer);

	bool unsubscribe(Observer!T observer)
	{
		if(observer !in observers)
		{
			return false;
		}

		auto subscription = observers[observer];
		auto result = observers.remove(observer);
		subscription.release();
		return result;
	}
}

unittest
{
	// Observable
	auto test1 = new Subject!int;
	auto test1var = 10;
	test1.then!int((v) { test1var = v; });
	assert(test1var == 10);

	test1.next(15);
	assert(test1var == 15);
}

final class Subject(T) : Observable!T
{
	void next(T value)
	{
		foreach(observer ; observers.keys)
		{
			observer.onNext(value);
		}
	}

	void complete()
	{
		foreach(observer ; observers.keys)
		{
			observer.onCompleted();
		}

		observers.clear();
	}

	void error(Exception e)
	{
		foreach(observer ; observers.keys)
		{
			observer.onError(e);
		}
	}

	override Subscription subscribe(Observer!T observer)
	{
		if(isCompleted)
		{
			return new Subscription({});
		}

		auto subscription = new Subscription({
			this.unsubscribe(observer);
		});

		observers[observer] = subscription;
		return subscription;
	}
}

final class Promise(T) : Observable!T
{
	private T myResolvedValue;

	@property T value() { return myResolvedValue; }

	void resolve(T value)
	{
		foreach(observer ; observers.keys)
		{
			observer.onNext(value);
		}

		foreach(observer ; observers.keys)
		{
			observer.onCompleted();
		}

		observers.clear();
		myIsCompleted = true;
	}

	void error(Exception e)
	{
		foreach(observer ; observers.keys)
		{
			observer.onError(e);
		}
	}

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
		return subscription;
	}
}

Observable!T then(T)(Observable!T self, Action!T action)
{
	self.subscribe(new Observer!T(action));
	return self;
}

Observable!K then(T,K)(Observable!T self, Func!(T,Promise!K) fn)
{
	auto promise = new Subject!K;
	self.then!T((value) {
		auto anotherObservable = fn(value);
		anotherObservable.then!K(newValue => promise.next(newValue)); 
	});

	return promise;
}

Observable!T merge(T)(Observable!T[] inputs ...)
{
	auto output = new Subject!T;
	foreach(input ; inputs)
	{
		input.then((v) { output.next(v); }, (e) { output.error(e); }, { output.complete(); });
	}

	return output;
}

unittest
{
	// Promise
	auto test2Promise1 = new Promise!int;
	auto test2Promise2 = new Promise!int();
	auto test2Promise3 = test2Promise1.then!(int,int)(_ => test2Promise2);
	assert(!test2Promise1.isCompleted);
	assert(!test2Promise2.isCompleted);
	assert(!test2Promise3.isCompleted);
	
	test2Promise1.resolve(10);
	assert(test2Promise1.isCompleted);
	assert(!test2Promise2.isCompleted);
	assert(!test2Promise3.isCompleted);
	
	test2Promise2.resolve(15);
	assert(test2Promise1.isCompleted);
	assert(test2Promise2.isCompleted);
	assert(test2Promise3.isCompleted);
}
