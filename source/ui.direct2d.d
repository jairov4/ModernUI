module modernui.ui.direct2d;

import modernui.ui.core;
import modernui.ui.render;

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

private class Direct2DRenderContext : RenderContext {
	private HWND myHwnd;
	private ID2D1HwndRenderTarget myRenderTarget;
	private IDWriteFactory1 myDirectWriteFactory;

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
	}

	~this()
	{
		if(myRenderTarget !is null) myRenderTarget.Release();
		if(myDirectWriteFactory !is null) myDirectWriteFactory.Release();
	}

	void resize()
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
		IDWriteTextFormat format;
		auto hr = myDirectWriteFactory.CreateTextFormat("Gabriola", null, DWRITE_FONT_WEIGHT_NORMAL, DWRITE_FONT_STYLE_NORMAL, DWRITE_FONT_STRETCH_NORMAL, 72.0f, "en-us", &format);
		if(hr != S_OK) throw new Error("DirectWrite unable to create text format");
		format.Release();
		// TODO
		return null;
	}

	override TextLayout createTextLayout(TextFormat format, string text="", Size box=Size(0.0, 0.0))
	{
		// TODO
		return null;
	}

	override ImageBrush createImageBrush(Image image)
	{
		// TODO
		return null;
	}

	override void drawText(double x, double y, TextLayout textLayout)
	{
		// TODO
	}
}