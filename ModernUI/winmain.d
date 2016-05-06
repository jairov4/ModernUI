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

class Element : DependencyObject
{
	@property @DependencyProperty @Getter double width() {return 0;}
	@property @DependencyProperty @Setter void width(double value) {}

	static this()
	{
		registerProperties!Element();
	}
}

int myWinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int nCmdShow)
{
    auto element = new Element;

    return 0;
}
