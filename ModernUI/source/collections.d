module modernui.collections;

import std.range;
import std.container.array;
import std.traits;
import modernui.rx;

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

enum ListChangeType
{
	RemoveOrAdd, Reset
}

struct ReactiveListChange(T)
{
	ListChangeType type;

	int oldItemsFirstIndex;
	T[] oldItems;

	int newItemsFirstIndex;
	T[] newItems;
}
/*
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
	bool addRange(const InputRange!(Tuple!(TKey,TValue)) items);
	void removeRange(const InputRange!(TKey) key);
	void clear();

	TValue opIndex(TKey key) const;
	@property const(ICollection!TKey) keys() const;
	@property const(ICollection!TValue) values() const;

	@property size_t length() const;
	void contains(TKey key) const;
}
*/

// Dictionary Extensions
void add(TKey, TValue, TDictionary)(TDictionary dictionary, TKey key, TValue value)
{
	dictionary.addRange([ Tuple!(TKey, TValue)(key, value) ]);
}

void add(T, TCollection)(TCollection collection, T value)
{
	collection.addRange([ value ]);
}

void remove(TKey, TValue, TDictionary)(TDictionary dictionary, TKey key)
{
	dictionary.removeRange([ key ]);
}

void remove(T, TCollection)(TCollection collection, T value)
{
	collection.removeRange([ value ]);
}

class ReactiveList(T)
{
	private Array!T impl;
	private Subject!(const T[]) collectionItemsAddedSubject;

	@property Observable!(const T[]) collectionItemsAdded() { return collectionItemsAddedSubject; }

	this()
	{
		impl = Array!T();
		collectionItemsAddedSubject = new Subject!(const T[]);
	}

	this(U)(U[] values...) if (isImplicitlyConvertible!(U, T))
	{
		impl = Array!T(values);
		collectionItemsAddedSubject = new Subject!(const T[]);
	}

	this(Stuff)(Stuff stuff) if (isInputRange!Stuff && isImplicitlyConvertible!(ElementType!Stuff, T) && !is(Stuff == T[]))
	{
		impl = Array!(stuff);
		collectionItemsAddedSubject = new Subject!(const T[]);
	}

	alias Range = Array!(T).Range;
	alias ConstRange = Array!(T).ConstRange;
	alias ImmutableRange = Array!(T).ImmutableRange;

	struct ListChange 
	{
		ListChangeType type;
		size_t newItemsFirstIndex;
		size_t oldItemsFirstIndex;
	}

	void addRange(Stuff)(Stuff stuff) if (isInputRange!Stuff && isImplicitlyConvertible!(ElementType!Stuff, T))
	{
		auto i = impl.length;
		impl.insertBack(stuff);
		auto listChange = ListChange.init;
		listChange.type = ListChangeType.RemoveOrAdd;
		listChange.newItemsFirstIndex = i;
		listChange.oldItemsFirstIndex = -1;
		collectionItemsAddedSubject.next(listChange);
	}

	void removeRange(Stuff)(Stuff val) if (isImplicitlyConvertible!(Stuff, T) || isInputRange!Stuff && isImplicitlyConvertible!(ElementType!Stuff, T))
	{
		foreach(v; val)
		{
			bool found = false;
			for(size_t i = 0; i<impl.length; i++)
			{
				if(impl[i] == v) 
				{
					impl.linearRemove(impl[i]);
					found = true;
					break;
				}
			}
			if(!found) throw new Error("Item not found");
		}
	}

	void clear() { impl.clear(); }

	@property size_t length() const { return impl.length; }

	bool contains(T val) const 
	{
		foreach(v; impl)
		{
			if(v == val) return true;
		}
		return false;
	}

	inout(T) opIndex(size_t index) inout
	{
		return impl[index];
	}

	void set(size_t index, T value) { impl[index] = value; }

	@property ConstRange rangeof() const { return impl[]; }
}

unittest
{
	auto list = new ReactiveList!int;
	assert(list.length == 0);
	list.addRange([5]);
	assert(list.length == 1);
}

/*
class HashSet(T) : ICollection!T
{
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
*/