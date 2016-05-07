module promise;

enum PromiseState
{
	Pending, Resolved, Rejected
}

abstract class Promise
{
	private PromiseState state;

	this()
	{
		state = PromiseState.Pending;
	}

	@property bool isResolved()
	{
		return state == PromiseState.Resolved;
	}

	@property bool isRejected()
	{
		return state == PromiseState.Rejected;
	}

	@property bool isPending()
	{
		return state == PromiseState.Pending;
	}
}

class Deferred : Promise
{
	void resolve()
	{
	}


}
