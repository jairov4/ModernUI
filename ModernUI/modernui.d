module ModernUI;

import Rx;

class PropertyChange
{
}

interface INotifyPropertyChanged
{
	@property IObservable!PropertyChange PropertyChanged();
}

interface IDependencyPropertyPublicDescriptor
{
	@property TypeInfo ValueType();

	@property TypeInfo OwnerType();

	@property Object BaseValue();

	@property string Name();

	Object GetValue(DependencyObject owner);
}

interface IDependencyPropertyPublicDescriptorSpecialized(TOwner, T) : IDependencyPropertyPublicDescriptor
{
	@property T BaseValueTyped();

	T GetValueTyped(TOwner owner);
}

interface IDependencyPropertyPrivateDescriptor : IDependencyPropertyPublicDescriptor
{
	void SetValue(DependencyObject owner, Object value);
}

interface IDependencyPropertyPrivateDescriptorSpecialized(TOwner, T) : IDependencyPropertyPrivateDescriptor, IDependencyPropertyPublicDescriptorSpecialized!(TOwner, T)
{
	void SetValueTyped(TOwner owner, T value);
}

class DependencyPropertyDescriptor(TOwner, T) : IDependencyPropertyPrivateDescriptorSpecialized!(TOwner, T)
{
	private string name;
	private T baseValue;
	private T delegate() getValueFunc;
	private void delegate(T) setValueFunc;

	this(string name, T baseValue)
	{
		this.name = name;
		this.baseValue = baseValue;
	}

	override @property TypeInfo ValueType() { return typeid(T); }

	override @property TypeInfo OwnerType() { return typeid(TOwner); }

	override @property T BaseValueTyped() { return this.baseValue; }
	override @property Object BaseValue() { return this.baseValue; }

	override @property string Name() { return this.name; }

	override Object GetValue(DependencyObject owner)
	{
		return null;
	}

	override T GetValueTyped(TOwner owner)
	{
		return null;
	}

	override void SetValue(DependencyObject owner, Object value)
	{
	}

	override void SetValueTyped(TOwner owner, T value)
	{
	}
}

class DependencyObject : INotifyPropertyChanged
{
	private const struct DependencyPropertyKey
	{
		TypeInfo OwnerType;
		string Name;
	}

	private static IDependencyPropertyPrivateDescriptor[DependencyPropertyKey] descriptors;

	private Subject!PropertyChange subjectPropertyChanged;

	protected static IDependencyPropertyPrivateDescriptorSpecialized!(TOwner, T) RegisterProperty(TOwner, T)(string name, T baseValue)
	{
		DependencyPropertyKey key = { OwnerType: typeid(TOwner), Name: name };
		auto descriptor = new DependencyPropertyDescriptor!(TOwner, T)(name, baseValue);
		descriptors[key] = descriptor;
		return descriptor;
	}

	override @property IObservable!PropertyChange PropertyChanged() { return subjectPropertyChanged; }
}
