using System;
using System.IO;
using darkredhttpd.Helpers;

namespace darkredhttpd
{
	extension HttpListener
	{
		public static class Settings
		{
			public static String BindAddr;
#if BF_PLATFORM_WINDOWS
			public static int32 BindPort = 80;
#else
			public static int32 BindPort = 8080;
#endif
			public static int32 MaxConnections = -1;
			public static int32 TimeoutSecs = 0;

			public static bool WantKeepAlive = true;
			public static bool WantServerID = true;
			public static bool NoListing = false;
			public static bool NoLog = false;
			
			public static readonly String LogFileName = new .() ~ delete _;
			public static readonly String WWWRoot = new .() ~ delete _;
			public static readonly String IndexName = new .("index.html") ~ delete _;
			public static readonly String AuthKey = new .() ~ delete _;

			public static int32 ThrottleBPS = -1;

			private static int32 TryParseNumber(StringView str)
			{
				if (int32.Parse(str) case .Ok(let val))
					return val;

				Program.ExitWithError(1, "number \"{0}\" is invalid", str);
				return 0;
			}

			public static void ParseCommandLine(Span<String> args)
			{
#if !BF_PLATFORM_WINDOWS
				if (CurrentPlatform.IsRoot())
					HttpListener.Settings.BindPort = 80;
#endif

				HttpListener.Settings.WWWRoot.Set(args[0]);

				if (!Directory.Exists(HttpListener.Settings.WWWRoot))
					Program.ExitWithError(1, "specified wwwroot path doesn't exist");

				// walk through the remainder of the arguments (if any)
				for (int i = 1; i < args.Length; i++)
				{
					switch (args[i])
					{
					case "--port":
						if (++i >= args.Length)
							Program.ExitWithError(1, "missing number after --port");
						BindPort = TryParseNumber(args[i]);

					case "--addr":
						if (++i >= args.Length)
							Program.ExitWithError(1, "missing ip after --addr");
						BindAddr = args[i];

					case "--maxconn":
						if (++i >= args.Length)
							Program.ExitWithError(1, "missing number after --maxconn");
						MaxConnections = TryParseNumber(args[i]);

					case "--no-log":
						NoLog = true;

					case "--log":
						if (++i >= args.Length)
							Program.ExitWithError(1, "missing filename after --log");
						LogFileName.Set(args[i]);

#if BF_PLATFORM_LINUX
					case "--chroot":
						Runtime.NotImplemented(); // TODO

					case "--daemon":
						Runtime.NotImplemented(); // TODO
#endif

					case "--index":
						if (++i >= args.Length)
							Program.ExitWithError(1, "missing filename after --index");
						IndexName.Set(args[i]);

					case "--no-listing":
						NoListing = true;

					case "--mimetypes":
						Runtime.NotImplemented(); // TODO

					case "--default-mimetype":
						Runtime.NotImplemented(); // TODO

#if BF_PLATFORM_LINUX
					case "--uid":
						Runtime.NotImplemented(); // TODO

					case "--pidfile":
						Runtime.NotImplemented(); // TODO
#endif

					case "--no-keepalive":
						WantKeepAlive = false;

					case "--forward":
						Runtime.NotImplemented(); // TODO

					case "--forward-all":
						Runtime.NotImplemented(); // TODO

					case "--no-server-id":
						WantServerID = false;

					case "--timeout":
						if (++i >= args.Length)
							Program.ExitWithError(1, "missing number after --timeout");
						TimeoutSecs = TryParseNumber(args[i]);

					case "--throttle":
						if (++i >= args.Length)
							Program.ExitWithError(1, "missing number after --throttle");
						ThrottleBPS = TryParseNumber(args[i]);

					case "--auth":
						if (++i >= args.Length || !args[i].Contains(':'))
							Program.ExitWithError(1, "missing 'user:pass' after --auth");
						Base64Encoder.Encode(args[i], AuthKey);
						AuthKey.Insert(0, "Basic ");

#if HAVE_INET6
					case "--ipv6:
						Runtime.NotImplemented(); // TODO
#endif
					}
				}
			}
		}
	}
}
