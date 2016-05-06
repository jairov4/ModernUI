module ModernUI;

import std.traits;
import std.variant;
import Rx;

class PropertyChange
{
}

interface INotifyPropertyChanged
{
	@property IObservable!PropertyChange propertyChanged();
}

interface IDependencyPropertyDescriptor
{
	@property TypeInfo valueType();

	@property TypeInfo ownerType();

	@property string name();

	@property bool hasSetter();

	Variant getValue(DependencyObject owner);

	void setValue(DependencyObject owner, Variant value);
}

interface IDependencyPropertyDescriptorSpecialized(TOwner, T) : IDependencyPropertyDescriptor
{
	T getValueTyped(TOwner owner);

	void setValueTyped(TOwner owner, T value);
}

class DependencyPropertyDescriptor(TOwner, T) : IDependencyPropertyDescriptorSpecialized!(TOwner, T)
{
	private string myName;
	alias Getter = T delegate(TOwner);
	alias Setter = void delegate(TOwner,T);
	private Getter myGetValue;
	private Setter mySetValue;

	this(string name, Getter getter, Setter setter)
	{
		this.myName = name;
		this.myGetValue = getter;
		this.mySetValue = setter;
	}

	override @property TypeInfo valueType() { return typeid(T); }

	override @property TypeInfo ownerType() { return typeid(TOwner); }

	override @property string name() { return this.myName; }

	override @property bool hasSetter() { return this.mySetValue != null; }

	override Variant getValue(DependencyObject owner)
	{
		Variant value = this.myGetValue(cast(TOwner)owner);
		return value;
	}

	override T getValueTyped(TOwner owner)
	{
		return this.myGetValue(owner);
	}

	override void setValue(DependencyObject owner, Variant value)
	{
		this.mySetValue(cast(TOwner)owner, value.get!T());
	}

	override void setValueTyped(TOwner owner, T value)
	{
		this.mySetValue(owner, value);
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
enum Getter;
enum Setter;

alias helper(alias A) = A;

template isDependencyProperty(alias T) 
{
	enum bool isDependencyProperty = isCallable!T && hasUDA!(T, DependencyProperty);
}

class ClassDescriptor
{
	private string myName;
	private TypeInfo myType;
	private ClassDescriptor myBase;
	private IDependencyPropertyDescriptor[string] myDependencyPropertiesByName;

	public this(string name, TypeInfo type, ClassDescriptor base, IDependencyPropertyDescriptor[string] dependencyPropertiesByName)
	{
		myName = name;
		myType = type;
		myBase = base;
		myDependencyPropertiesByName = dependencyPropertiesByName;
	}
}

class DependencyObject : INotifyPropertyChanged
{
	private Subject!PropertyChange subjectPropertyChanged;

	private static ClassDescriptor[TypeInfo] classDescriptors;

	protected static void registerProperties(TheClass)()
	{
		// Populate the descriptors for each dependency property
		IDependencyPropertyDescriptor[string] properties;
		foreach(memberName; __traits(allMembers, TheClass))
		{
			foreach(member; __traits(getOverloads, TheClass, memberName))
			{
				// We are looking for getters
				static if(isDependencyProperty!member && !is(ReturnType!member == void))
				{
					alias PropertyType = ReturnType!member;

					// We get an invoker for the getter
					PropertyType delegate(TheClass) getter = (instance) { return __traits(getMember, instance, memberName)(); };

					// Now we will try for the setter, we try to compile to test if it has an available setter method
					void delegate(TheClass, PropertyType) setter = null;
					static if(__traits(compiles, setter = (instance, value) { __traits(getMember, instance, memberName)(value); }))
					{
						setter = (instance, value) { __traits(getMember, instance, memberName)(value); };
						break;
					}

					auto propDesc = new DependencyPropertyDescriptor!(TheClass, PropertyType)(memberName, getter, setter);
					properties[memberName] = propDesc;
					break;
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

		// build and registers the new descriptor
		auto classDesc = new ClassDescriptor(__traits(identifier, TheClass), typeid(TheClass), baseClassDescriptor, properties);
		classDescriptors[typeid(TheClass)] = classDesc;
	}

	override @property IObservable!PropertyChange propertyChanged() { return subjectPropertyChanged; }
}
