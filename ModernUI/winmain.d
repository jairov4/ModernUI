module winmain;

import core.runtime;
import core.sys.windows.windows;
import ModernUI;

extern (Windows)
int WinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int nCmdShow)
{
	if(!Runtime.initialize())
	{
		return -1;
	}

    try
    {
        auto result = myWinMain(hInstance, hPrevInstance, lpCmdLine, nCmdShow);
        Runtime.terminate();
		return result;
    }
    catch (Throwable o) // catch any uncaught exceptions
    {
        MessageBoxA(null, cast(char *)o.toString(), "Error", MB_OK | MB_ICONEXCLAMATION);
		return -1;
    }
}

class Element : DependencyObject!Element
{
	private double myWidth;
	@property @DependencyProperty double width() {return myWidth;}
	@property void width(double value) { this.setProperty!width(this.myWidth, value); }
}

int myWinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int nCmdShow)
{
    auto element = new Element;
	element.width = 34;

    return 0;
}
