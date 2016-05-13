module modernui.collections;

private struct None
{
	void[0] dummy;

	immutable static None val = {};
}

enum CollectionChangeType
{
	Remove, Reset
}

struct CollectionItemsRemoved(T)
{
	bool isReset;
	T[] items;
}

interface IReactiveCollection(T) : ICollection!T, INotifyPropertyChanged
{
	@property Observable!(const T[]) collectionItemsAdded();
	@property Observable!(const CollectionItemsRemoved!T) collectionItemsRemoved();
}

enum ListChangeType
{
	RemoveOrAdd, Reset
}

struct ListChange(T)
{
	ListChangeType type;

	int oldItemsFirstIndex;
	T[] oldItems;

	int newItemsFirstIndex;
	T[] newItems;
}

interface IReactiveList(T) : IReactiveCollection!T
{
	@property Observable!(const ListChange) listChanged();
}

interface ICollection(T)
{
	// TODO: Replace by add Range
	void add(T[] val);
	// TODO: Replace by remove range
	void remove(T[] val);
	void clear();

	@property size_t length() const;
	void contains(T val) const;
}

interface IList(T) : ICollection!T
{
	T get(size_t index) const;
	void set(size_t index, T value);
}

interface IDictionary(TKey, TValue)
{
	// TODO: Replace by add Range
	bool add(Tuple!(TKey,TValue)[] items);
	// TODO: Replace by remove range
	void remove(TKey[] key);
	void clear();

	TValue get(TKey key) const;
	@property const(TKey[]) keys() const;
	@property const(TValue[]) values() const;

	@property size_t length() const;
	void contains(TKey key) const;
}

class HashSet(T) : ICollection!T
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
