module modernui.collections;

import std.range;
import std.container.array;
import std.traits;
import modernui.rx;

enum ListChangeType
{
	AddOrReplace, Remove, Reset
}

struct ReactiveListChange(T)
{
	ListChangeType type;

	int oldItemsFirstIndex;
	T[] oldItems;

	int newItemsFirstIndex;
	T[] newItems;
}

class ReactiveList(T)
{
	private Array!T impl;

	this()
	{
		impl = Array!T();
		collectionChangedSubject = new Subject!(const ListChange);
	}

	this(U)(U[] values...) if (isImplicitlyConvertible!(U, T))
	{
		impl = Array!T(values);
		collectionChangedSubject = new Subject!(const ListChange);
	}

	this(Stuff)(Stuff stuff) if (isInputRange!Stuff && isImplicitlyConvertible!(ElementType!Stuff, T) && !is(Stuff == T[]))
	{
		impl = Array!(stuff);
		collectionChangedSubject = new Subject!(const ListChange);
	}

	alias Range = Array!(T).Range;
	alias ConstRange = Array!(T).ConstRange;
	alias ImmutableRange = Array!(T).ImmutableRange;

	alias ItemsAddedRange = Range;

	struct ListChange 
	{
		ListChangeType type;
		size_t newItemsFirstIndex;
		ItemsAddedRange newItems;
		T[] oldItems;
	}

	private Subject!(const ListChange) collectionChangedSubject;
	@property Observable!(const ListChange) collectionChanged() { return collectionChangedSubject; }

	void addRange(Stuff)(Stuff stuff) if (isInputRange!Stuff && isImplicitlyConvertible!(ElementType!Stuff, T))
	{
		auto i = impl.length;
		impl.insertBack(stuff);
		auto listChange = ListChange.init;
		listChange.type = ListChangeType.AddOrReplace;
		listChange.newItemsFirstIndex = i;
		listChange.newItems = impl[i..$];
		collectionChangedSubject.next(listChange);
	}

	void add(T item)
	{
		auto i = impl.length;
		impl.insertBack(item);
		auto listChange = ListChange.init;
		listChange.type = ListChangeType.AddOrReplace;
		listChange.newItemsFirstIndex = i;
		listChange.newItems = impl[i..$];
		collectionChangedSubject.next(listChange);
	}

	void removeRange(Stuff)(Stuff val) if (isImplicitlyConvertible!(Stuff, T) || isInputRange!Stuff && isImplicitlyConvertible!(ElementType!Stuff, T))
	{
		static if(is(Stuff == T[]))
		{
			T[] oldItems = val;;
		}
		else
		{
			T[] oldItems;
		}

		foreach(v; val)
		{
			bool found = false;
			for(size_t i = 0; i<impl.length; i++)
			{
				if(impl[i] == v) 
				{
					impl.linearRemove(impl[i..i+1]);
					found = true;
					static if(!is(Stuff == T[]))
					{
						if(collectionChangedSubject.hasSubscribers) {
							oldItems ~ v;
						}
					}
					break;
				}
			}

			if(!found) throw new Error("Item not found");
		}

		if(collectionChangedSubject.hasSubscribers) 
		{
			auto listChange = ListChange.init;
			listChange.type = ListChangeType.Remove;
			listChange.oldItems = oldItems;
			collectionChangedSubject.next(listChange);
		}
	}

	void clear() 
	{
		impl.clear(); 

		auto listChange = ListChange.init;
		listChange.type = ListChangeType.Reset;
		collectionChangedSubject.next(listChange);
	}

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

	void set(size_t index, T value) 
	{
		T oldValue = impl[index];
		impl[index] = value;

		auto listChange = ListChange.init;
		listChange.type = ListChangeType.AddOrReplace;
		listChange.oldItems = [oldValue];
		listChange.newItemsFirstIndex = index;
		listChange.newItems = impl[index..index+1];
		collectionChangedSubject.next(listChange);
	}

	ConstRange opSlice() const { return impl[]; }

	ConstRange opSlice(size_t begin, size_t excl_end) const
	{
		return impl[begin..excl_end];
	}
}

unittest
{
	auto list = new ReactiveList!int;
	assert(list.length == 0);

	list.addRange([5]);
	assert(list.length == 1);
	assert(list[0] == 5);

	list.set(0, 6);
	assert(list[0] == 6);
	assert(list.length == 1);

	list.removeRange([6]);
	assert(list.length == 0);

	list.add(1);
	assert(list[0] == 1);
	assert(list.length == 1);
	foreach(i; list[])
	{
		;
	}
}
