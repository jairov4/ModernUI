module ModernUI;

import std.traits;
import std.variant;
import std.typecons;
import Rx;

class PropertyChange
{
	public immutable string name;

	this(string name) 
	{ 
		this.name = name; 
	}
}

interface INotifyPropertyChanged
{
	@property IObservable!PropertyChange propertyChanged();
}

abstract class DependencyPropertyDescriptor
{
	private string myName;
	private TypeInfo myOwnerType;
	private TypeInfo myValueType;
	private bool myHasSetter;

	this(string name, TypeInfo ownerType, TypeInfo valueType, bool hasSetter)
	{
		this.myName = name;
		this.myOwnerType = ownerType;
		this.myValueType = valueType;
		this.myHasSetter = hasSetter;
	}

	@property TypeInfo valueType() { return this.myValueType; }

	@property TypeInfo ownerType() { return this.myOwnerType; }

	@property string name() { return this.myName; }

	@property bool hasSetter() { return this.myHasSetter; }

	abstract Variant getValue(DependencyObject owner) immutable;

	abstract void setValue(DependencyObject owner, Variant value);
}

class DependencyPropertyDescriptorSpecialized(TOwner, T) : DependencyPropertyDescriptor
{	
	alias Getter = T delegate(TOwner);
	alias Setter = void delegate(TOwner,T);
	private Getter myGetValue;
	private Setter mySetValue;

	T getValueTyped(TOwner owner)
	{
		return this.myGetValue(owner);
	}

	void setValueTyped(TOwner owner, T value)
	{
		this.mySetValue(owner, value);
	}

	override Variant getValue(DependencyObject owner) immutable
	{
		Variant value = this.myGetValue(cast(TOwner)owner);
		return value;
	}

	override void setValue(DependencyObject owner, Variant value)
	{
		this.mySetValue(cast(TOwner)owner, value.get!T());
	}

	this(string name, Getter getter, Setter setter)
	{
		super(name, typeid(TOwner), typeid(T), setter !is null);
		this.myGetValue = getter;
		this.mySetValue = setter;
	}
}

class Dispatcher
{
	void invoke(void delegate() action)
	{
	}

	IObservable!Unit invokeAsync(void delegate() action)
	{
		return null;
	}
}

enum DependencyProperty;

private alias helper(alias A) = A;

private template isDependencyProperty(alias T) 
{
	enum bool isDependencyProperty = isCallable!T && hasUDA!(T, DependencyProperty);
}

class ClassDescriptor
{
	const string name;
	const TypeInfo type;
	const ClassDescriptor base;
	const DependencyPropertyDescriptor[string] dependencyPropertiesByName;

	const(DependencyPropertyDescriptor) getFlattenProperty(string name) immutable
	{
		auto bag = rebindable!(const ClassDescriptor)(this);
		while(bag !is null)
		{
			if(name in bag.dependencyPropertiesByName)
			{
				return bag.dependencyPropertiesByName[name];
			}

			bag = bag.base;
		}

		return null;
	}

	public this(string name, TypeInfo type, ClassDescriptor base, const DependencyPropertyDescriptor[string] dependencyPropertiesByName)
	{
		this.name = name;
		this.type = type;
		this.base = base;
		this.dependencyPropertiesByName = dependencyPropertiesByName;
	}
}

string nameof(alias Identifier)()
{
	return __traits(identifier, Identifier);
}

class DependencyObject : INotifyPropertyChanged
{
	private Subject!PropertyChange subjectPropertyChanged = new Subject!PropertyChange();

	private static ClassDescriptor[TypeInfo] classDescriptors;

	protected bool setProperty(alias Identifier, TValue)(ref TValue val, TValue newValue)
	{
		if(val == newValue)
		{
			return false;
		}

		val = newValue;
		subjectPropertyChanged.OnNext(new PropertyChange(nameof!Identifier));
		return true;
	}

	@property ClassDescriptor classDescriptor()
	{
		return classDescriptors[typeid(this)];
	}

	protected static void registerClass(TheClass)()
	{
		// Populate the descriptors for each dependency property
		DependencyPropertyDescriptor[string] properties;
		foreach(memberName; __traits(allMembers, TheClass))
		{
			static if(__traits(getProtection, __traits(getMember, TheClass, memberName)) == "public")
			{
				foreach(member; __traits(getOverloads, TheClass, memberName))
				{
					// We are looking for getters
					static if(isDependencyProperty!member && !is(ReturnType!member == void))
					{
						alias PropertyType = ReturnType!member;

						// We get an invoker for the getter
						PropertyType delegate(TheClass) getter = (instance) { return __traits(getMember, instance, memberName)(); };

						// Now we will go for the setter, we try to compile to test if it has an available setter method
						void delegate(TheClass, PropertyType) setter = null;
						static if(__traits(compiles, setter = (instance, value) { __traits(getMember, instance, memberName)(value); }))
						{
							setter = (instance, value) { __traits(getMember, instance, memberName)(value); };
						}

						// Build and add the new property descriptor
						auto propDesc = new DependencyPropertyDescriptorSpecialized!(TheClass, PropertyType)(memberName, getter, setter);
						properties[memberName] = propDesc;
						break;
					}
				}
			}
		}

		// Get the descriptor for the base class
		auto baseClassTypeInfo = typeid(__traits(parent, TheClass));
		ClassDescriptor baseClassDescriptor = null;
		if(baseClassTypeInfo in classDescriptors)
		{
			baseClassDescriptor = classDescriptors[baseClassTypeInfo];
		}

		// Build and registers the new class descriptor
		auto classDesc = new ClassDescriptor(__traits(identifier, TheClass), typeid(TheClass), baseClassDescriptor, properties);
		classDescriptors[typeid(TheClass)] = classDesc;
	}

	override @property IObservable!PropertyChange propertyChanged() { return subjectPropertyChanged; }
}
