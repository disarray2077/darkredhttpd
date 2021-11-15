using System;

#if BF_PLATFORM_WINDOWS
namespace darkredhttpd
{
	class CurrentPlatform
	{
		public static int32 GetLastError()
		{
			return Windows.GetLastError();
		}

		[Import("Kernel32.lib"), CLink, CallingConvention(.Stdcall)]
		static extern int32 FormatMessageA(uint32 flags, void* source, uint32 messageId, uint32 languageId, char8* buffer, uint32 size, VarArgs* args);

		const int FORMAT_MESSAGE_ALLOCATE_BUFFER = 0x00000100;
		const int FORMAT_MESSAGE_IGNORE_INSERTS = 0x00000200;
		const int FORMAT_MESSAGE_FROM_SYSTEM = 0x00001000;

		public const int LANG_NEUTRAL = 0x00;
		public const int SUBLANG_DEFAULT = 0x01; // user default

		[Import("Kernel32.lib"), CLink, CallingConvention(.Stdcall)]
		static extern void* LocalFree(void* mem);

		public static void GetErrorMessage(int32 errno, String outString)
		{
			mixin MAKELANGID(var p, var s)
			{
				((((int16)(s)) << 10) | (int16)(p))
			}

		    char8* messageBuffer = null;

		    //Ask Win32 to give us the string version of that message ID.
		    //The parameters we pass in, tell Win32 to create the buffer that holds the message for us (because we don't yet know how long the message string will be).
		    int32 size = FormatMessageA(FORMAT_MESSAGE_ALLOCATE_BUFFER | FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_IGNORE_INSERTS,
		                                null, (.)errno, MAKELANGID!(LANG_NEUTRAL, SUBLANG_DEFAULT), (.)&messageBuffer, 0, null);
		    
		    //Copy the error message into the output string.
			outString.Append(messageBuffer, size);

			//Remove line-breaks.
			outString.Replace("\r\n", "");
		    
		    //Free the Win32's string's buffer.
		    LocalFree(messageBuffer);
		}

		public static void GetLastErrorMessage(String outString) =>
			GetErrorMessage(GetLastError(), outString);
	}
}
#endif