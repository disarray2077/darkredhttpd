using System;

#if !BF_PLATFORM_WINDOWS
namespace darkredhttpd
{
	class CurrentPlatform
	{
		[CLink, CallingConvention(.Stdcall)]
		public static extern uint getuid();

		public static bool IsRoot()
		{
			return getuid() == 0;
		}

		public static int32 GetLastError()
		{
			return errno();
		}
		
		[CLink, CallingConvention(.Stdcall)]
		public static extern char8* strerror(int32 errnum);

		public static void GetErrorMessage(int32 errno, String outString)
		{
			outString.Append(strerror(errno));
		}

		public static void GetLastErrorMessage(String outString) =>
			GetErrorMessage(GetLastError(), outString);
	}
}
#endif