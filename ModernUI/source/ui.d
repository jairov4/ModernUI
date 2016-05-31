module modernui.ui;

import modernui.core;
import modernui.collections;

pragma(lib, "gdi32.lib");

abstract class RenderContext
{
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

	mixin DefineDependencyPropertyReadOnly!(Visual, "visualParent");
	mixin DefineDependencyPropertyReadOnly!(Size, "desiredSize");
	mixin DefineDependencyPropertyReadOnly!(Rect, "actualRect");
	mixin DefineDependencyPropertyReadOnly!(bool, "isMeasurementValid");
	mixin DefineDependencyPropertyReadOnly!(bool, "isArrangementValid");

	private ReactiveList!Visual myChildren;

	protected void invalidateLayout()
	{
		isMeasurementValid = false;
		isArrangementValid = false;
	}

	protected abstract Size measure(const Size measure);

	protected abstract void arrange(const Rect site);

	protected abstract void render(RenderContext context);
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

	protected void changeChild(Visual child)
	{
		if(this.myChildren.length == 0)
		{
			this.myChildren.add(child);
		}
		else
		{
			this.myChildren[0] = child;
		}

		invalidateLayout();
	}

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
			foreach(v; this.myChildren[])
			{
				auto childSize = v.measure(sizeAvailable);
				size = childSize.unionWith(size);
			}
		}

		if(isNaN(width))
		{
			size.width = width;
		} else {
			size.width += margin.widthContribution + border.widthContribution + padding.widthContribution;
		}

		if(isNaN(height))
		{
			size.height = height;
		} else {
			size.height += margin.heightContribution + border.heightContribution + padding.heightContribution;
		}

		desiredSize = size;
		return size;
	}

	protected override void arrange(const Rect site)
	{
		actualRect = site;
		auto location = site.location.offset(Point(margin.left + border.left + padding.left, margin.top + border.top + padding.top));
		auto size = site.size.shrink(Size(location.x + margin.right + border.right + padding.right, location.y + margin.bottom + border.bottom + padding.bottom));
		auto childrenSite = Rect(location, size);
		foreach(v; this.myChildren[])
		{
			v.arrange(childrenSite);
		}
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

class Window : Visual
{
	static this() { registerClass!(typeof(this)); }

	static bool isClassRegistered = false;

	static immutable string className = "ModernUIWindow";

	private HINSTANCE hInstance = null;
	private HWND hWnd = null;

	override protected Size measure(const Size measure)
	{
		return Size.init;
	}

	override protected void arrange(const Rect site)
	{
	}

	override protected void render(RenderContext context)
	{
	}

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
		wndclass.hCursor       = LoadCursor(null, IDC_CROSS);
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
		hWnd = CreateWindow(className.toTStringz,  // window class name
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
					 null);                // creation parameters);

		if(hWnd is null)
		{
			throw new Error("Could not create window");
		}
	}

	this()
	{
		hInstance = GetModuleHandle(null);
		if(!isClassRegistered) 
		{
			registerWindowClass();
			isClassRegistered = true;
		}

		createWindow();
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

	extern(Windows)
	static LRESULT WindowProc(HWND hWnd, UINT message, WPARAM wParam, LPARAM lParam) nothrow
	{
		switch (message)
		{
			case WM_COMMAND:
				{
					switch (LOWORD(wParam))
					{
						default:
					}

					break;
				}

			case WM_PAINT:
				{
					const text = "Jairo";
					PAINTSTRUCT ps;

					HDC  dc = BeginPaint(hWnd, &ps);
					scope(exit) EndPaint(hWnd, &ps);
					RECT r;
					GetClientRect(hWnd, &r);
					
					HFONT font = CreateFont(80, 0, 0, 0, FW_EXTRABOLD, FALSE, FALSE,
											 FALSE, ANSI_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS,
											 ANTIALIASED_QUALITY, DEFAULT_PITCH | FF_DONTCARE, "Arial");
					HGDIOBJ old = SelectObject(dc, cast(HGDIOBJ) font);
					SetTextAlign(dc, TA_CENTER | TA_BASELINE);
					// nothrow
					try { TextOut(dc, r.right / 2, r.bottom / 2, text.toTStringz, text.length); } catch {}
					DeleteObject(SelectObject(dc, old));
					break;
				}

			case WM_DESTROY:
				PostQuitMessage(0);
				break;

			default:
				break;
		}

		return DefWindowProcA(hWnd, message, wParam, lParam);
	}
}
