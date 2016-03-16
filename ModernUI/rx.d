module Rx;

interface ISubscription
{
	void Release();
}

interface IObserver(T)
{
	void OnCompleted();
	void OnNext(T value);
	void OnError(Exception e);
}

interface IObservable(T)
{
	ISubscription Subscribe(IObserver!T observer);
}

class DelegateSubscription : ISubscription
{
	private void delegate() action;

	this(void delegate() action)
	{
		this.action = action;
	}

	override void Release()
	{
		this.action();
	}
}

class Subject(T) : IObservable!T
{
	private IObserver!T[] observers;

	override ISubscription Subscribe(IObserver!T observer)
	{
		auto subscription = new DelegateSubscription({});
		observers ~= observer;
		return subscription;
	}

	void OnNext(T value)
	{
		foreach(IObserver!T observer ; observers)
		{
			observer.OnNext(value);
		}
	}

	void OnCompleted()
	{
		foreach(IObserver!T observer ; observers)
		{
			observer.OnCompleted();
		}
		observers.length = 0;
	}

	void OnError(Exception e)
	{
		foreach(IObserver!T observer ; observers)
		{
			observer.OnError(e);
		}
	}
}