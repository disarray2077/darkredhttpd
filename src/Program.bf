using System;
using System.Collections;

namespace darkredhttpd
{
	class Program
	{
		public static int Main(String[] args)
		{
			Console.WriteLine("{0}, {1}.", Constants.PKG_NAME, Constants.COPYRIGHT);

			if (args.Count < 1 || (args.Count == 1 && args[0] == "--help"))
			{
				WriteUsage(Environment.GetExecutableFilePath(.. scope .()));
				Environment.Exit(0);
			}

			HttpListener.ParseDefaultExtensionMap();
			HttpListener.Settings.ParseCommandLine(args);
			HttpListener.Initialize();
			HttpListener.Listen();
			return 0;
		}

		public static void ExitWithError(int32 code, String fmt, params Object[] args)
		{
			Console.WriteLine(fmt, params args);
			Environment.Exit(code);
		}

		public static void ExitWithError(int32 code, String message)
		{
			Console.WriteLine(message);
			Environment.Exit(code);
		}

		public static void ExitWithOSError(int32 code, String fmt, params Object[] args)
		{
			int32 err = CurrentPlatform.GetLastError();
			Console.Write(fmt, params args);
			Console.WriteLine(" ({0}: {1})", err, CurrentPlatform.GetErrorMessage(err, .. scope .()));
			Environment.Exit(code);
		}

		public static void ExitWithOSError(int32 code, String message)
		{
			int32 err = CurrentPlatform.GetLastError();
			Console.WriteLine("{0} ({1}: {2})", message, err, CurrentPlatform.GetErrorMessage(err, .. scope .()));
			Environment.Exit(code);
		}

		public static void ExitWithOSError(int32 code, int32 err, String fmt, params Object[] args)
		{
			Console.Write(fmt, params args);
			Console.WriteLine(" ({0}: {1})", err, CurrentPlatform.GetErrorMessage(err, .. scope .()));
			Environment.Exit(code);
		}

		public static void ExitWithOSError(int32 code, int32 err, String message)
		{
			Console.WriteLine("{0} ({1}: {2})", message, err, CurrentPlatform.GetErrorMessage(err, .. scope .()));
			Environment.Exit(code);
		}

		public static void WriteUsage(String arg0)
		{
			Console.WriteLine("usage:\t{0} /path/to/wwwroot [flags]\n", arg0);
			Console.WriteLine(
				"""
				flags:\t--port number (default: {0}, or 80 if running as root)
				\t\tSpecifies which port to listen on for connections.
				\t\tPass 0 to let the system choose any free port for you.\n
				""",
				HttpListener.Settings.BindPort);
			Console.WriteLine(
				"""
				\t--addr ip (default: all)
				\t\tIf multiple interfaces are present, specifies
				\t\twhich one to bind the listening port to.\n
				""");
			Console.WriteLine(
				"""
				\t--maxconn number (default: system maximum)
				\t\tSpecifies how many concurrent connections to accept.\n
				""");
			Console.WriteLine(
				"""
				\t--no-log
				\t\tDisables any kind of logging (even to the stdout).\n
				""");
			Console.WriteLine(
				"""
				\t--log filename (default: stdout)
				\t\tSpecifies which file to append the request log to.\n
				""");
			Console.WriteLine(
				"""
				\t--syslog
				\t\tUse syslog for request log.\n
				""");
#if BF_PLATFORM_LINUX
			Console.WriteLine(
				"""
				\t--chroot (default: don't chroot)
				\t\tLocks server into wwwroot directory for added security.\n
				""");
			Console.WriteLine(
				"""
				\t--daemon (default: don't daemonize)
				\t\tDetach from the controlling terminal and run in the background.\n
				""");
#endif
			Console.WriteLine(
				"""
				\t--index filename (default: {0})
				\t\tDefault file to serve when a directory is requested.\n
				""",
			    HttpListener.Settings.IndexName);
			Console.WriteLine("""
				\t--no-listing
				\t\tDo not serve listing if directory is requested.\n
				""");
			Console.WriteLine(
				"""
				\t--mimetypes filename (optional)
				\t\tParses specified file for extension-MIME associations.\n
				""");
			Console.WriteLine(
				"""
				\t--default-mimetype string (optional, default: {0})
				\t\tFiles with unknown extensions are served as this mimetype.\n
				""",
			    HttpListener.OctetStream);
#if BF_PLATFORM_LINUX
			Console.WriteLine(
				"""
				\t--uid uid/uname, --gid gid/gname (default: don't privdrop)
				\t\tDrops privileges to given uid:gid after initialization.\n
				""");
			Console.WriteLine(
				"""
				\t--pidfile filename (default: no pidfile)
				\t\tWrite PID to the specified file.  Note that if you are
				\t\tusing --chroot, then the pidfile must be relative to,
				\t\tand inside the wwwroot.\n
				""");
#endif
			Console.WriteLine(
				"""
				\t--no-keepalive
				\t\tDisables HTTP Keep-Alive functionality.\n
				""");
			Console.WriteLine(
				"""
				\t--forward host url (default: don't forward)
				\t\tWeb forward (301 redirect).
				\t\tRequests to the host are redirected to the corresponding url.
				\t\tThe option may be specified multiple times, in which case
				\t\tthe host is matched in order of appearance.\n
				""");
			Console.WriteLine(
				"""
				\t--forward-all url (default: don't forward)
				\t\tWeb forward (301 redirect).
				\t\tAll requests are redirected to the corresponding url.\n
				""");
			Console.WriteLine(
				"""
				\t--no-server-id
				\t\tDon't identify the server type in headers
				\t\tor directory listings.\n
				""");
			Console.WriteLine(
				"""
				\t--timeout secs (default: {0})
				\t\tIf a connection is idle for more than this many seconds,
				\t\tit will be closed. Set to zero to disable timeouts.\n
				""",
				HttpListener.Settings.TimeoutSecs);
			Console.WriteLine(
				"""
				\t--throttle BytesPerSec (default: don't throttle)
				\t\tSets a limit on how many bytes can be sent per second.\n
				""",
				HttpListener.Settings.TimeoutSecs);
			Console.WriteLine(
				"""
				\t--auth username:password
				\t\tEnable basic authentication.\n
				""");
#if HAVE_INET6
			Console.WriteLine(
				"""
				\t--ipv6
				\t\tListen on IPv6 address.\n
				""");
#else
			Console.WriteLine("\t(This binary was built without IPv6 support: -DNO_IPV6)\n");
#endif
		}
	}
}