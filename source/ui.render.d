module modernui.ui.render;

import modernui.ui.core;

abstract class TextFormat
{
}

abstract class TextLayout
{
	abstract @property string text();
	abstract @property Size layoutBox();
	abstract @property Size layoutSize();
}

enum FontStretch
{
	ultraCondensed,
	extraCondensed,
	condensed,
	semiCondensed,
	normal,
	semiExpanded,
	expanded,
	extraExpanded,
	ultraExpanded
}

enum FontStyle
{
	normal, italic, oblique
}

abstract class Image
{
}

abstract class ImageBrush
{
}

struct SolidColorBrush
{
	private Color myColor;

	@property Color color() { return myColor; }
	@property void color(Color value) { myColor = value; }
}

struct GradientColorStop
{
	private float myPosition;
	private Color myColor;

	@property float position() { return myPosition; }
	@property void position(float value) { myPosition = value; }

	@property Color color() { return myColor; }
	@property void color(Color value) { myColor = value; }

	this(float position, Color color)
	{
		myPosition = position;
		myColor = color;
	}
}

class GradientColorBrush
{
	private float myOrientation;
	private GradientColorStop[] myStops;

	@property float orientation() { return myOrientation; }
	@property void orientation(float value) { myOrientation = value; }

	@property const(GradientColorStop[]) stops() { return myStops; }

	this(float orientation, GradientColorStop[] stops)
	{
		myOrientation = orientation;
		myStops = stops;
	}
}

abstract class RenderContext
{
	abstract void begin();
	abstract void end();
	abstract void resize();
	abstract void clear(Color color);
	abstract void drawText(double x, double y, TextLayout textLayout);
	abstract TextFormat createTextFormat(string fontFamily, float size, FontStyle style=FontStyle.normal, int weight=400, FontStretch stretch=FontStretch.normal);
	abstract TextLayout createTextLayout(TextFormat format, string text="", Size box=Size(0.0, 0.0));
	abstract ImageBrush createImageBrush(Image image);
}