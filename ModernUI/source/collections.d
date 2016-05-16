module modernui.collections;

import std.range;

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

interface IIterable(T)
{
	InputRange!T rangeof() const;
}

interface ICollection(T) : IIterable!T
{
	void addRange(const T[] val);
	void removeRange(const T[] val);
	void clear();

	@property size_t length() const;
	void contains(T val) const;
}

interface IList(T) : ICollection!T
{
	T opIndex(size_t index) const;
	void set(size_t index, T value);
}

interface IDictionary(TKey, TValue)
{
	bool addRange(const Tuple!(TKey,TValue)[] items);
	void removeRange(const TKey[] key);
	void clear();

	TValue opIndex(TKey key) const;
	@property const(TKey[]) keys() const;
	@property const(TValue[]) values() const;

	@property size_t length() const;
	void contains(TKey key) const;
}

// Dictionary Extensions
void add(TKey, TValue, TDictionary : IDictionary!(TKey, TValue))(TDictionary dictionary, TKey key, TValue value)
{
	dictionary.addRange([ Tuple!(TKey, TValue)(key, value) ]);
}

void add(T, TCollection : ICollection!T)(TCollection collection, T value)
{
	collection.addRange([ value ]);
}

void remove(TKey, TValue, TDictionary : IDictionary!(TKey, TValue))(TDictionary dictionary, TKey key)
{
	dictionary.removeRange([ key ]);
}

void remove(T, TCollection : ICollection!T)(TCollection collection, T value)
{
	collection.removeRange([ value ]);
}

class HashSet(T) : ICollection!T
{
	private None[T] backingField;

	this()
	{
	}

	this(T[] items)
	{
		addRange(items);
	}

	@property size_t length() const
	{ 
		return backingField.length;
	}
	
	void addRange(T[] val)
	{
		foreach(v; val)
		{
			backingField[v] = None.val;
		}
	}

	void removeRange(T[] val)
	{
		foreach(v; val)
		{
			backingField.remove(v);
		}
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

	InputRange!T rangeof() const
	{
	}
}

unittest
{
	auto set = new HashSet!int;
	set.add(5);
}