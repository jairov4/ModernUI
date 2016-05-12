module modernui.ui;

import modernui;

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

	protected abstract Visual visualParent;

	@property Size desiredSize();

	@property double actualWidth();
	@property double actualHeight();

	protected void invalidateLayout();

	protected abstract Size measure(Size measure);

	protected abstract void arrange(Rect site);

	protected abstract void render(RenderContext context);
}