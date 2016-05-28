module modernui.ui;

import modernui.core;
import modernui.collections;

abstract class RenderContext
{
}

struct Size
{
	double width;
	double height;
}

struct Point
{
	double x;
	double y;
}

struct Rect
{
	Point location;
	Size size;
}

abstract class Visual : DependencyObject
{
	static this() { registerClass!(typeof(this)); }

	private Visual myVisualParent;
	@property Visual visualParent() { return myVisualParent; }
	private @property void visualParent(Visual value) { this.setProperty!visualParent(this.myVisualParent, value); }

	private ReactiveList!Visual myChildren;

	private Size myDesiredSize;
	@property Size desiredSize() { return this.myDesiredSize; }

	private double  myActualWidth;
	@property double actualWidth() { return this.myActualWidth; }

	private double myActualHeight;
	@property double actualHeight() { return this.myActualHeight; }

	bool myIsMeasurementValid;
	@property bool isMeasurementValid() { return this.myIsMeasurementValid; }

	bool myIsArrangementValid;
	@property bool isArrangementValid() { return this.myIsArrangementValid; }

	protected void invalidateLayout()
	{
		this.setProperty!isMeasurementValid(this.myIsMeasurementValid, true);
		this.setProperty!isArrangementValid(this.myIsArrangementValid, true);
	}

	protected abstract Size measure(Size measure);

	protected abstract void arrange(Rect site);

	protected abstract void render(RenderContext context);
}