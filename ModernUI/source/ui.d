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

	private IList!Visual myChildren;

	@property Size desiredSize();

	@property double actualWidth();
	@property double actualHeight();

	protected void invalidateLayout();

	protected abstract Size measure(Size measure);

	protected abstract void arrange(Rect site);

	protected abstract void render(RenderContext context);
}