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

	@property size_t length() 
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

	bool contains(T val)
	{
		return (val in backingField) !is null;
	}

	T[] values()
	{
		auto keys = backingField.keys;
		return keys;
	}
}
