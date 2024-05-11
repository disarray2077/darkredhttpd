using System;

namespace darkredhttpd
{
	static
	{
#if BF_PLATFORM_WINDOWS
		[CLink]
#elif BF_PLATFORM_MACOS
		[LinkName("__error")]
#else
		[LinkName("__errno_location")]
#endif
		static extern int32* _errno();
		public static ref int32 errno() => ref *_errno();

		public const int EINTR = 4;
		public const int EAGAIN = 11;

		public const int ENFILE = 23;
		public const int EMFILE = 24;

		// signal.h
		typealias signal_t = function void(int32);

		public const int SIGINT = 2; // interrupt
		public const int SIGPIPE = 13;
		public const int SIGTERM = 15; // Software termination signal from kill

		public static readonly signal_t SIG_IGN = ((signal_t)(void*)1); // ignore signal
		public static readonly signal_t SIG_ERR = ((signal_t)(void*)-1); // signal error value

		[CLink]
		public static extern signal_t signal(int32 signal, signal_t func);
	}
}
