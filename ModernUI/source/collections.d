module collections;

private struct None
{
	void[0] dummy;

	immutable static None val = {};
}

class HashSet(T)
{
	private None[T] backingField;

	this()
	{
	}

	this(T[] items)
	{
		foreach(item; items)
		{
			add(item);
		}
	}

	@property size_t length() const
	{ 
		return backingField.length;
	}

	void add(T val)
	{
		backingField[val] = None.val;
	}

	void remove(T val)
	{
		backingField.remove(val);
	}

	void clear()
	{
		backingField.clear;
	}

	bool contains(T val) const
	{
		return (val in backingField) !is null;
	}

	const(T[]) values() const
	{
		auto keys = backingField.keys;
		return keys;
	}
}
