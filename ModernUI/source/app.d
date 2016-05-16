module winmain;

import core.runtime;
import core.sys.windows.windows;
import modernui.core;

extern (Windows)
int WinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int nCmdShow)
{
	if(!Runtime.initialize())
	{
		return -1;
	}

	try
	{
		version(unittest)
		{
			if(!runModuleUnitTests())
			{
				Runtime.terminate();
				return -1;
			}
		}

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

int myWinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int nCmdShow)
{
	return 0;
}
