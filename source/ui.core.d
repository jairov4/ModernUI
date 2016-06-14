module modernui.ui.core;

struct Size
{
	double width;
	double height;
}

Size unionWith(Size a, Size b)
{
	import std.algorithm.comparison : max;
	return Size(max(a.width, b.width), max(a.height, b.height));
}

Size shrink(Size a, Size b)
{
	return Size(a.width - b.width, a.height - b.height);
}

struct Point
{
	double x;
	double y;
}

Point offset(Point a, Point b)
{
	return Point(a.x+b.x, a.y+b.y);
}

struct Rect
{
	Point location;
	Size size;
}

struct Color {
	float r;
	float g;
	float b;
}

struct Thickness 
{
	double left;
	double top;
	double right;
	double bottom;
}

double widthContribution(Thickness t)
{
	return t.left + t.right;
}

double heightContribution(Thickness t)
{
	return t.top + t.bottom;
}

enum HorizontalAlignment 
{
	Stretch, Center, Left, Right
}

enum VerticalAlignment 
{
	Stretch, Center, Top, Bottom
}