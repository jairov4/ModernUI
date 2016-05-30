module modernui.collections;

import std.range;
import std.container.array;
import std.traits;
import modernui.rx;

class ReadOnlyList(T)
{
	private Array!T impl;

	alias Range = Array!(T).Range;
	alias ConstRange = Array!(T).ConstRange;
	alias ImmutableRange = Array!(T).ImmutableRange;

	this()
	{
		impl = Array!T();
	}

	this(U)(U[] values...) if (isImplicitlyConvertible!(U, T))
	{
		impl = Array!T(values);
	}

	this(Stuff)(Stuff stuff) if (isInputRange!Stuff && isImplicitlyConvertible!(ElementType!Stuff, T) && !is(Stuff == T[]))
	{
		impl = Array!(stuff);
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

	ConstRange opSlice() const { return impl[]; }

	ConstRange opSlice(size_t begin, size_t excl_end) const
	{
		return impl[begin..excl_end];
	}
}

abstract class ReadOnlyReactiveList(T) : ReadOnlyList!T
{
	alias ItemsAddedRange = Range;

	struct ItemsAddedDescriptor
	{
		private size_t myNewItemsFirstIndex;
		private ItemsAddedRange myNewItems;

		@property size_t newItemsFirstIndex() const { return myNewItemsFirstIndex; }
		@property ItemsAddedRange newItems() { return myNewItems; }

		this(size_t newItemsFirstIndex, ItemsAddedRange newItems)
		{
			this.myNewItemsFirstIndex = newItemsFirstIndex;
			this.myNewItems = newItems;
		}
	}

	struct ItemsRemovedDescriptor
	{
		private bool myIsReset;
		private ReadOnlyList!T myOldItems;
	
		@property bool isReset() const { return myIsReset; }
		@property ReadOnlyList!T oldItems() { return myOldItems; }

		this(bool isReset, ReadOnlyList!T oldItems)
		{
			this.myIsReset = isReset;
			this.myOldItems = oldItems;
		}
	}

	private Subject!ItemsAddedDescriptor itemsAddedSubject = new Subject!ItemsAddedDescriptor;
	@property Observable!ItemsAddedDescriptor itemsAdded() { return itemsAddedSubject; }

	private Subject!ItemsRemovedDescriptor itemsRemovedSubject = new Subject!ItemsRemovedDescriptor;
	@property Observable!ItemsRemovedDescriptor itemsRemoved() { return itemsRemovedSubject; }
}

class ReactiveList(T) : ReadOnlyReactiveList!T
{
	void add(T item)
	{
		auto i = impl.length;
		impl.insertBack(item);
		auto listChange = ItemsAddedDescriptor(i, impl[i..$]);
		itemsAddedSubject.next(listChange);
	}

	// covers T[]
	// covers Array!T
	void addRange(Stuff)(Stuff stuff) if (isInputRange!Stuff && isImplicitlyConvertible!(ElementType!Stuff, T))
	{
		auto i = impl.length;
		impl.insertBack(stuff);
		auto listChange = ItemsAddedDescriptor(i, impl[i..$]);
		itemsAddedSubject.next(listChange);
	}

	void remove(T v)
	{
		bool found = false;
		for(size_t i = 0; i<impl.length; i++)
		{
			if(impl[i] == v) 
			{
				impl.linearRemove(impl[i..i+1]);
				found = true;
				break;
			}
		}

		if(!found) throw new Error("Item not found");

		if(itemsRemovedSubject.hasSubscribers) 
		{
			auto listChange = ItemsRemovedDescriptor(false, new ReadOnlyList!T(v));
			itemsRemovedSubject.next(listChange);
		}
	}

	void removeRange(Stuff)(Stuff val) if (isInputRange!Stuff && isImplicitlyConvertible!(ElementType!Stuff, T))
	{
		T[] oldItems;
		static if(is(Stuff == T[]))
		{
			if(itemsRemovedSubject.hasSubscribers) 
			{
				oldItems = val;
			}
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
						if(itemsRemovedSubject.hasSubscribers) 
						{
							oldItems ~ v;
						}
					}
					break;
				}
			}

			if(!found) throw new Error("Item not found");
		}

		if(itemsRemovedSubject.hasSubscribers) 
		{
			auto listChange = ItemsRemovedDescriptor(false, new ReadOnlyList!T(oldItems));
			itemsRemovedSubject.next(listChange);
		}
	}

	void clear() 
	{
		impl.clear(); 

		auto listChange = ItemsRemovedDescriptor(true, null);
		itemsRemovedSubject.next(listChange);
	}

	void set(size_t index, T value) 
	{
		T oldValue = impl[index];
		impl[index] = value;

		auto listChange = ItemsRemovedDescriptor(false, new ReadOnlyList!T(oldValue));
		itemsRemovedSubject.next(listChange);
		
		auto listChange2 = ItemsAddedDescriptor(index, impl[index..index+1]);
		itemsAddedSubject.next(listChange2);
	}

	T opIndexAssign(T v, size_t i)
	{
		set(i, v);
		return v;
	}
}

unittest
{
	import modernui.rx;

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
		assert(i == 1);
	}

	list.add(7);
	list.add(9);
	assert(list[2] == 9);
	assert(list.contains(7));
	assert(!list.contains(700));
	list[2] = 10;
	assert(list[2] == 10);
	assert(list.length == 3);
	list.remove(7);
	assert(list.length == 2);

	list.clear();
	assert(list.length == 0);

	bool changeInvoked = false;
	list.itemsAdded.then!(typeof(list).ItemsAddedDescriptor)((v) {
		changeInvoked = true;
	});
	list.add(9);
	assert(changeInvoked);
}
