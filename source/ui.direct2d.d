module modernui.ui.direct2d;

import modernui.ui.core;
import modernui.ui.render;

import std.string;

version(Windows) 
{

import core.sys.windows.windows;
import directx.d2d1;
import directx.d2d1helper;
import directx.dwrite_2;

pragma(lib, "User32");
pragma(lib, "gdi32");
pragma(lib, "D2d1");
pragma(lib, "Dwrite");

version(Unicode)
{
	import std.utf : toUTF16z;
	private alias toTStringz = toUTF16z;
} 
else
{
	import std.string : toStringz;
	private alias toTStringz = toStringz;
}

private extern(Windows) HRESULT D2D1CreateFactory(D2D1_FACTORY_TYPE factoryType, REFIID riid, void* factoryOptions, IUnknown* ppIFactory);

private extern(Windows) HRESULT DWriteCreateFactory(DWRITE_FACTORY_TYPE FactoryType, REFIID IID, IUnknown* ppFactory);

private HRESULT D2D1CreateFactory(Factory : ID2D1Factory)(D2D1_FACTORY_TYPE factoryType, /*out*/ Factory* factory)
{
	return D2D1CreateFactory(factoryType, mixin("&IID_"~Factory.stringof), null, cast(IUnknown*)factory);
}

private HRESULT DWriteCreateFactory(Factory : IDWriteFactory)(DWRITE_FACTORY_TYPE factoryType, /*out*/ Factory* factory)
{
	return DWriteCreateFactory(factoryType, mixin("&IID_"~Factory.stringof), cast(IUnknown*)factory);
}

class Direct2DRenderContext_TextFormat : TextFormat
{
	private IDWriteTextFormat myField;

	this(IDWriteFactory directWriteFactory, string fontFamily, float size, FontStyle style=FontStyle.normal, int weight=400, FontStretch stretch=FontStretch.normal) 
	{
		int d2dStyle;
		switch(style) 
		{
			case FontStyle.normal: d2dStyle = DWRITE_FONT_STYLE_NORMAL; break;
			case FontStyle.italic: d2dStyle = DWRITE_FONT_STYLE_ITALIC; break;
			case FontStyle.oblique: d2dStyle = DWRITE_FONT_STYLE_OBLIQUE; break;
			default: throw new Error("Invalid style");
		}

		int d2dFontStretch;
		switch(stretch) {
			case FontStretch.ultraCondensed: d2dFontStretch = DWRITE_FONT_STRETCH_ULTRA_CONDENSED; break;
			case FontStretch.extraCondensed: d2dFontStretch = DWRITE_FONT_STRETCH_EXTRA_CONDENSED; break;
			case FontStretch.condensed: d2dFontStretch = DWRITE_FONT_STRETCH_CONDENSED; break;
			case FontStretch.semiCondensed: d2dFontStretch = DWRITE_FONT_STRETCH_SEMI_CONDENSED; break;
			case FontStretch.normal: d2dFontStretch = DWRITE_FONT_STRETCH_NORMAL; break;
			case FontStretch.semiExpanded: d2dFontStretch = DWRITE_FONT_STRETCH_SEMI_EXPANDED; break;
			case FontStretch.expanded: d2dFontStretch = DWRITE_FONT_STRETCH_EXPANDED; break;
			case FontStretch.extraExpanded: d2dFontStretch = DWRITE_FONT_STRETCH_EXTRA_EXPANDED; break;
			case FontStretch.ultraExpanded: d2dFontStretch = DWRITE_FONT_STRETCH_ULTRA_EXPANDED; break;
			default: throw new Error("Invalid stretch");
		}

		auto hr = directWriteFactory.CreateTextFormat(toTStringz(fontFamily), null, weight, d2dStyle, d2dFontStretch, size, "en-us", &myField);
		if(hr != S_OK) throw new Error("DirectWrite unable to create text format");
	}

	~this() { myField.Release(); }
}

class Direct2DRenderContext_TextLayout : TextLayout
{
	private IDWriteTextLayout myField;
	private Size myLayoutBox;
	private Size myLayoutSize;
	private bool loadedMetrics;
	private string myText;

	this(IDWriteFactory1 factory, Direct2DRenderContext_TextFormat format, string text="", Size box=Size(0.0, 0.0))
	{
		loadedMetrics = false;
		myText = text;
		myLayoutBox = box;
		auto hr = factory.CreateTextLayout(toTStringz(text), cast(int)text.length, format.myField, cast(float)box.width, cast(float)box.height, &myField); 
		if(hr != S_OK) throw new Error("DirectWrite unable to create text layout");
	}

	~this() { myField.Release(); }

	private void ensureMetrics()
	{
		if(loadedMetrics) return;
		DWRITE_TEXT_METRICS metrics;
		auto hr = myField.GetMetrics(&metrics);
		if(hr != S_OK) throw new Error("DirectWrite unable to get metrics for text layout");
		myLayoutSize.width = metrics.width;
		myLayoutSize.height = metrics.height;
		loadedMetrics = true;
	}

	override @property string text() { return myText; }
	override @property Size layoutBox() { return myLayoutBox; }
	override @property Size layoutSize() { ensureMetrics(); return myLayoutSize; }
}

class Direct2DRenderContext : RenderContext
{
	private HWND myHwnd;
	private ID2D1HwndRenderTarget myRenderTarget;
	private IDWriteFactory1 myDirectWriteFactory;
	private ID2D1SolidColorBrush myBlackBrush; // TODO: temporary

	this(HWND hwnd)
	{
		myHwnd = hwnd;

		ID2D1Factory d2dFactory;
		scope(exit) d2dFactory.Release();
		auto hr = D2D1CreateFactory!ID2D1Factory(D2D1_FACTORY_TYPE_SINGLE_THREADED, &d2dFactory);
		if(hr != S_OK) throw new Error("Direct2D unable to start");

		auto d2drtProperties = D2D1.RenderTargetProperties();
		d2drtProperties.type = D2D1_RENDER_TARGET_TYPE_DEFAULT;

		auto hwndrtProperties = D2D1_HWND_RENDER_TARGET_PROPERTIES.init;
		hwndrtProperties.hwnd = myHwnd;

		RECT rc;
		GetClientRect(myHwnd, &rc);
		hwndrtProperties.pixelSize = D2D_SIZE_U(rc.right - rc.left, rc.bottom - rc.top);

		hr = d2dFactory.CreateHwndRenderTarget(&d2drtProperties, &hwndrtProperties, &myRenderTarget);
		if(hr != S_OK) throw new Error("Direct2D unable to create render target");

		hr = DWriteCreateFactory!IDWriteFactory1(DWRITE_FACTORY_TYPE_ISOLATED, &myDirectWriteFactory);
		if(hr != S_OK) throw new Error("Direct2D unable to create render target");

		auto col = D2D1.ColorF(D2D1.ColorF.Black).color;
		hr = myRenderTarget.CreateSolidColorBrush(&col, null, &myBlackBrush);
		if(hr != S_OK) throw new Error("Direct2D unable to create a solid brush");
	}

	~this()
	{
		if(myRenderTarget !is null) myRenderTarget.Release();
		if(myDirectWriteFactory !is null) myDirectWriteFactory.Release();
	}

	override void resize()
	{
		RECT rc;
		GetClientRect(myHwnd, &rc);
		auto newSize = D2D1_SIZE_U(rc.right - rc.left, rc.bottom - rc.top);
		auto hr = myRenderTarget.Resize(&newSize);
		if(hr != S_OK) throw new Error("Direct2D unable to resize render target");
	}

	override void begin()
	{
		myRenderTarget.BeginDraw();
	}

	override void end()
	{
		myRenderTarget.EndDraw();
	}

	override void clear(Color color)
	{
		auto col = D2D1.ColorF(color.r, color.g, color.b);
		myRenderTarget.Clear(&col.color);
	}

	override TextFormat createTextFormat(string fontFamily, float size, FontStyle style=FontStyle.normal, int weight=400, FontStretch stretch=FontStretch.normal)
	{
		auto tf = new Direct2DRenderContext_TextFormat(myDirectWriteFactory, fontFamily, size, style, weight, stretch);
		return tf;
	}

	override TextLayout createTextLayout(TextFormat format, string text="", Size box=Size(0.0, 0.0))
	{
		auto tl = new Direct2DRenderContext_TextLayout(myDirectWriteFactory, cast(Direct2DRenderContext_TextFormat) format, text, box);
		return tl;
	}

	override ImageBrush createImageBrush(Image image)
	{
		// TODO
		return null;
	}

	override void drawText(double x, double y, TextLayout textLayout)
	{
		auto tl = cast(Direct2DRenderContext_TextLayout) textLayout;
		myRenderTarget.DrawTextLayout(D2D1.Point2F(x, y), tl.myField, myBlackBrush);
	}
}

}