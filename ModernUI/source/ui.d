module modernui.ui;

import modernui.core;
import modernui.rx;
import modernui.collections;

import std.algorithm.iteration;
import std.container.array;

import aurora.directx;

pragma(lib, "gdi32.lib");
pragma(lib, "D2d1.lib");

abstract class RenderContext
{
	abstract void drawText(double x, double y, string text);
}

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

abstract class Visual : DependencyObject
{
	static this() { registerClass!(typeof(this)); }
	this()
	{
		myVisualChildren = new ReactiveList!Visual;
		myInvalidMeasure = new Subject!None;
		myInvalidArrangement = new Subject!None;
		visualChildren.itemsAdded.then!(ItemsAdded!Visual)(&onVisualChildrenAdded);
		visualChildren.itemsRemoved.then!(ItemsRemoved!Visual)(&onVisualChildrenRemoved);
	}

	mixin DefineDependencyPropertyReadOnly!(Visual, "visualParent");
	mixin DefineDependencyPropertyReadOnly!(Size, "desiredSize");
	mixin DefineDependencyPropertyReadOnly!(Rect, "actualRect");

	private ReactiveList!Visual myVisualChildren;
	protected @property ReactiveList!Visual visualChildren() { return myVisualChildren; }

	private Subject!None myInvalidMeasure;
	@property Observable!None invalidMeasure() { return myInvalidMeasure; }

	private Subject!None myInvalidArrangement;
	@property Observable!None invalidArrangement() { return myInvalidArrangement; }

	protected void invalidateMeasurement() { myInvalidMeasure.next(None.val); }
	protected void invalidateArrangement() { myInvalidArrangement.next(None.val); }

	protected abstract Size measure(const Size measure);

	protected abstract void arrange(const Rect site);

	protected abstract void render(RenderContext context);

	private void onVisualChildrenAdded(ItemsAdded!Visual info)
	{
		foreach(newItem; info.newItems)
		{
			newItem.visualParent = this;
		}

		invalidateMeasurement();
	}

	private void onVisualChildrenRemoved(ItemsRemoved!Visual info)
	{
		foreach(oldItem; info.oldItems)
		{
			oldItem.visualParent = null;
		}

		invalidateMeasurement();
	}
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

abstract class UIElement : Visual
{
	static this() { registerClass!(typeof(this)); }

	mixin DefineDependencyProperty!(Thickness, "border");
	mixin DefineDependencyProperty!(Thickness, "padding");
	mixin DefineDependencyProperty!(Thickness, "margin");
	mixin DefineDependencyProperty!(double, "width");
	mixin DefineDependencyProperty!(double, "height");
	mixin DefineDependencyProperty!(HorizontalAlignment, "horizontalAlignment");
	mixin DefineDependencyProperty!(VerticalAlignment, "verticalAlignment");
	mixin DefineDependencyProperty!(bool, "isVisible");
	mixin DefineDependencyProperty!(bool, "isCollapsible");

	// assumes children already measured, no recursive impl.
	protected override Size measure(const Size sizeAvailable)
	{
		import std.math : isNaN;
		auto size = Size.init;
		if(isCollapsible && !isVisible)
		{
			desiredSize = size;
			return size;
		}

		if(isNaN(width) || isNaN(height))
		{
			foreach(v; this.visualChildren[])
			{
				size = size.unionWith(v.desiredSize);
			}
		}

		immutable auto r = [margin, border, padding];
		if(isNaN(width))
		{
			size.width = width;
		} else {
			size.width += r.map!(x => x.widthContribution).sum;
		}

		if(isNaN(height))
		{
			size.height = height;
		} else {
			size.height += r.map!(x => x.heightContribution).sum;
		}

		desiredSize = size;
		return size;
	}

	// actualRect is relative to parent.
	protected override void arrange(const Rect site)
	{
		// skips unuseful recursion
		if(site == actualRect) return;

		actualRect = site;
		immutable auto r = [margin, border, padding];
		auto left = r.map!(x => x.left).sum;
		auto right = r.map!(x => x.right).sum;
		auto top = r.map!(x => x.top).sum;
		auto bottom = r.map!(x => x.bottom).sum;

		auto location = Point(left, top);
		auto size = site.size.shrink(Size(left + right, top + bottom));
		auto childrenSite = Rect(location, size);
		foreach(v; visualChildren[])
		{
			v.arrange(childrenSite);
		}
	}
}

class TextElement : UIElement
{
	static this() { registerClass!(typeof(this)); }

	mixin DefineDependencyProperty!(string, "text");

	protected override void render(RenderContext context)
	{
		context.drawText(20, 20, "Hola mundo");
	}

	this()
	{
		propertyChanged.then!PropertyChange((x) {
			if(x.name != nameof!text) return;
			invalidateMeasurement();
		});
	}
}

abstract class ContentControl : UIElement
{
	static this() { registerClass!(typeof(this)); }

	mixin DefineDependencyProperty!(Visual, "content");

	protected void changeChild(Visual child)
	{
		if(visualChildren.length == 0)
		{
			visualChildren.add(child);
		}
		else
		{
			visualChildren[0] = child;
		}

		invalidateMeasurement();
	}

	this()
	{
		propertyChanged.then!PropertyChange((x) {
			if(x.name != nameof!content) return;
			changeChild(content);
		});
	}
}

import core.sys.windows.windows;

version(Unicode)
{
	import std.utf : toUTF16z;
	alias toTStringz = toUTF16z;
} 
else
{
	import std.string : toStringz;
	alias toTStringz = toStringz;
}

HRESULT D2D1CreateFactory(Factory)(D2D1_FACTORY_TYPE factoryType, /*out*/ Factory* factory)
{
	return D2D1CreateFactory(factoryType, mixin("&IID_"~Factory.stringof), null, cast(void**)factory);
}

extern(Windows)
{
	HRESULT D2D1CreateFactory(D2D1_FACTORY_TYPE factoryType, REFIID riid, void* factoryOptions, void **ppIFactory);
}

private class WindowRenderContext : RenderContext {
	private HWND myHwnd;
	private PAINTSTRUCT myPs;
	private HDC myDc;
	private ID2D1Factory1 myFactory;

	this(HWND hwnd)
	{
		myHwnd = hwnd;
		auto hr = D2D1CreateFactory!ID2D1Factory1(D2D1_FACTORY_TYPE.SINGLE_THREADED, &myFactory);
		if(hr != S_OK)
		{
			throw new Error("Direct2D unable to start");
		}
	}

	void begin()
	{
		myDc = BeginPaint(myHwnd, &myPs);
		RECT r;
		GetClientRect(myHwnd, &r);
	}

	void end()
	{
		EndPaint(myHwnd, &myPs);
	}

	override void drawText(double x, double y, string text)
	{
		HFONT font = CreateFont(80, 0, 0, 0, FW_EXTRABOLD, FALSE, FALSE,
								FALSE, ANSI_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS,
								ANTIALIASED_QUALITY, DEFAULT_PITCH | FF_DONTCARE, "Arial");
		HGDIOBJ old = SelectObject(myDc, cast(HGDIOBJ)font);
		SetTextAlign(myDc, TA_CENTER | TA_BASELINE);
		TextOut(myDc, cast(int)x, cast(int)y, text.toTStringz, cast(int)text.length);
		DeleteObject(SelectObject(myDc, old));
	}
}

class Window : ContentControl
{
	static this() { registerClass!(typeof(this)); }

	static bool isClassRegistered = false;

	static immutable string className = "ModernUIWindow";

	private struct DescendantInfo {
		int level;
		Array!Subscription subscriptions;
	}

	private DescendantInfo[Visual] descendants;
	private Window selfReference;

	private HINSTANCE hInstance = null;
	private HWND hWnd = null;

	private void registerWindowClass() {
		HWND hWnd;
		MSG  msg;
		WNDCLASS wndclass;

		wndclass.style         = CS_OWNDC | CS_HREDRAW | CS_VREDRAW;
		wndclass.lpfnWndProc   = &WindowProc;
		wndclass.cbClsExtra    = 0;
		wndclass.cbWndExtra    = 0;
		wndclass.hInstance     = hInstance;
		wndclass.hIcon         = LoadIcon(null, IDI_APPLICATION);
		wndclass.hCursor       = LoadCursor(null, IDC_ARROW);
		wndclass.hbrBackground = cast(HBRUSH)GetStockObject(WHITE_BRUSH);
		wndclass.lpszMenuName  = null;
		wndclass.lpszClassName = className.toTStringz;

		if (!RegisterClass(&wndclass))
		{
			throw new Error("Error registering the window class");
		}
	}

	private void createWindow()
	{
		Window* wnd = &selfReference;
		hWnd = CreateWindowEx(
					0, 
					className.toTStringz,  // window class name
					"test".toTStringz,    // window caption
					WS_THICKFRAME   |
					WS_MAXIMIZEBOX  |
					WS_MINIMIZEBOX  |
					WS_SYSMENU      |
					WS_VISIBLE,           // window style
					CW_USEDEFAULT,        // initial x position
					CW_USEDEFAULT,        // initial y position
					600,                  // initial x size
					400,                  // initial y size
					HWND_DESKTOP,         // parent window handle
					null,                 // window menu handle
					hInstance,            // program instance handle
					wnd);                 // creation parameters;

		if(hWnd is null)
		{
			throw new Error("Could not create window");
		}
	}

	this()
	{
		selfReference = this;
		hInstance = GetModuleHandle(null);
		if(!isClassRegistered) 
		{
			registerWindowClass();
			isClassRegistered = true;
		}

		createWindow();

		auto desc = DescendantInfo.init;
		desc.level = 0;
		descendants[this] = desc;

		visualChildren.itemsAdded.then!(ItemsAdded!Visual)(&onDescendantsAdded);
		visualChildren.itemsRemoved.then!(ItemsRemoved!Visual)(&onDescendantsRemoved);
	}

	void onDescendantsAdded(ItemsAdded!Visual x)
	{
		foreach(newItem; x.newItems)
		{
			auto desc = DescendantInfo.init;
			auto subscription = newItem.visualChildren.itemsAdded.then!(ItemsAdded!Visual)(&onDescendantsAdded);
			desc.subscriptions.insertBack(subscription);
			subscription = newItem.visualChildren.itemsRemoved.then!(ItemsRemoved!Visual)(&onDescendantsRemoved);
			desc.subscriptions.insertBack(subscription);
			desc.level = descendants[newItem.visualParent].level + 1;
			descendants[newItem] = desc;
		}
	}

	void onDescendantsRemoved(ItemsRemoved!Visual x)
	{
		foreach(oldItem; x.oldItems)
		{
			auto desc = descendants[oldItem];
			foreach(subscription; desc.subscriptions)
			{
				subscription.release;
			}
			descendants.remove(oldItem);
		}
	}

	void show()
	{
		ShowWindow(hWnd, SW_SHOWDEFAULT);
		UpdateWindow(hWnd);
	}

	void messageLoop()
	{
		MSG  msg;
		while (GetMessageA(&msg, null, 0, 0))
		{
			TranslateMessage(&msg);
			DispatchMessageA(&msg);
		}
	}

	protected override void render(RenderContext rc)
	{
		foreach(child; visualChildren) child.render(rc);
	}

	extern(Windows)
	static LRESULT WindowProc(HWND hWnd, UINT message, WPARAM wParam, LPARAM lParam) nothrow
	{
		switch (message)
		{
			case WM_NCCREATE:
				auto pCreate = cast(CREATESTRUCT*)lParam;
				auto wnd = cast(Window*)pCreate.lpCreateParams;
				SetWindowLongPtr(hWnd, GWLP_USERDATA, cast(size_t)wnd);
				return true;

			case WM_PAINT:
				auto wnd = cast(Window*)GetWindowLongPtr(hWnd, GWLP_USERDATA);
				try{
					auto rc = new WindowRenderContext(hWnd);
					rc.begin;
					wnd.render(rc);
					scope(exit) rc.end;
				} catch {
				}
				break;

			case WM_DESTROY:
				PostQuitMessage(0);
				break;

			default:
				return DefWindowProcA(hWnd, message, wParam, lParam);
		}

		return 0;
	}
}
