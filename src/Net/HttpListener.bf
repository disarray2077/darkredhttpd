using System;
using System.Diagnostics;
using System.Collections;
using System.Net;
using System.IO;

namespace darkredhttpd
{
	[StaticInitAfter(typeof(HttpListener.Settings))]
	public static class HttpListener
	{
		private static Socket _sockin = new .() ~ delete _;
		private static SocketSelector _selector = new .() ~ delete _;
		public static bool Running = false;
		public static bool Accepting = false;

		private static readonly List<Connection> _connections = new .() ~ DeleteContainerAndItems!(_);

		private static readonly Dictionary<String, String> _mimeMap = new .() ~ DeleteDictionaryAndKeysAndValues!(_);
		public const String OctetStream = "application/octet-stream";
		public static String DefaultMimeType = OctetStream;

		public static FileStream LogFile ~ delete _;

		public static readonly String ServerHDR = new .() ~ delete _;
		public static readonly String KeepAliveField = new .() ~ delete _;

		public static int32 NumRequests;
		public static int32 TotalIN;
		public static int32 TotalOUT;

		public static ~this()
		{
			Socket.Uninit();
		}

		// Associates an extension with a mimetype in the mime_map.  Entries are in
		// unsorted order.  Makes copies of extension and mimetype strings.
		public static void AddMimeMapping(StringView ext, StringView mimeType)
		{
			Debug.Assert(ext.Length > 0);
			Debug.Assert(mimeType.Length > 0);

			if (_mimeMap.TryAddAlt(ext, let keyPtr, let valuePtr))
			{
				*keyPtr = new .(ext);
				*valuePtr = new .(mimeType);
			}
			else
			{
				(*valuePtr).Set(mimeType);
			}
		}

		// Adds contents of default_extension_map[] to mime_map list.
		public static void ParseDefaultExtensionMap()
		{
			for (let line in Constants.DEFAULT_EXTENSION_MAP.Split('\n'))
			{
				ParseMimetypeLine(line);
			}
		}

		// Parses a mime.types line and adds the parsed data to the mime_map.
		private static void ParseMimetypeLine(StringView line)
		{
			if (line.IsEmpty)
				return;

			var split = line.Split(' ');
			
			StringView mimeType;
			if (!(split.GetNext() case .Ok(out mimeType)))
				return;

			StringView ext;
			while (split.GetNext() case .Ok(out ext))
			{
				AddMimeMapping(ext, mimeType);
			}
		}

		public static void Initialize()
		{
			KeepAliveField.AppendF("Keep-Alive: timeout={}\r\n", Settings.TimeoutSecs);

			if (Settings.WantServerID)
				ServerHDR.AppendF("Server: {}\r\n", Constants.PKG_NAME);
			
			Socket.Init();

			_sockin.ReuseAddr = true;
			_sockin.NoDelay = true;

			OpenLogfile();
		}

		public static void OpenLogfile()
		{
			if (Settings.LogFileName.IsEmpty)
				return;

			LogFile = new .();
			if (LogFile.Open(Settings.LogFileName, .Append, .Write, .ReadWrite) case .Err)
				DeleteAndNullify!(LogFile);
		}

		public static void Listen()
		{
			_sockin.Port = Settings.BindPort;

			if (_sockin.Listen(Settings.MaxConnections) case .Err(let err))
				Program.ExitWithOSError(1, err, "failed to listen.");

			Console.WriteLine("listening on: http://{}:{}/", _sockin.GetAddressText(.. scope .()), Settings.BindPort);
			Running = true;
			Accepting = true;

#if BF_PLATFORM_LINUX
			if (signal(SIGPIPE, SIG_IGN) == SIG_ERR)
			    Program.ExitWithOSError(1, "signal(ignore SIGPIPE)");
#endif
			if (signal(SIGINT, => Stop) == SIG_ERR)
			    Program.ExitWithOSError(1, "signal(SIGINT)");
			if (signal(SIGTERM, => Stop) == SIG_ERR)
			    Program.ExitWithOSError(1, "signal(SIGTERM)");

			while (Running)
			{
				Pool();
			}
		}

		public static void Stop(int32 sig)
		{
			Running = false;
		}

		// Main loop of the httpd - a select() and then delegation to accept
		// connections, handle receiving of requests, and sending of replies.
		public static void Pool()
		{
			_selector.Clear();

			if (Accepting)
				_selector.AddRecv(_sockin);
			
			bool botherWithTimeout = false;
			int32 timeout = Settings.TimeoutSecs * 1000;

			for (let conn in _connections)
			{
				switch (conn.State)
				{
				case .Done:
					/* do nothing */
					break;

				case .RecvRequest:
					_selector.AddRecv(conn.Socket);
					botherWithTimeout = true;
					break;

				case .SendHeader:
					_selector.AddSend(conn.Socket);
					botherWithTimeout = true;
					break;

				case .SendReply:
					// If the current socket is waiting the next burst,
					// we don't want to consider it in the current select loop.
					if (Settings.ThrottleBPS <= 0 || !conn.IsWaitingNextBurst)
						_selector.AddSend(conn.Socket);
					else
					{
						// To allow a quick response, the timeout is changed to 10ms.
						// Otherwise, if this was the only active connection,
						// we would have to wait the full timeout before the next burst.
						timeout = 10;
					}
					botherWithTimeout = true;
					break;
				}
			}

			if (timeout == 0)
				botherWithTimeout = false;

			/*Stopwatch sw = ?;
			if (Constants.DEBUG)
			{
				Console.WriteLine("select() with max_fd {0} timeout {1}", (int32)_selector.[Friend]mMaxSocket, bother_with_timeout ? Settings.TimeoutSecs : 0);
				sw = Stopwatch.StartNew();
				defer:: delete sw;
			}*/

			let ret = _selector.Wait(botherWithTimeout ? timeout : -1);
			if (ret == 0)
			{
				if (!botherWithTimeout)
					Program.ExitWithError(1, "select() timed out");
			}
			else if (ret == -1)
			{
#if BF_PLATFORM_WINDOWS
				int32 err = Windows.GetLastError();
#else
				int32 err = errno();
				if (err == EINTR)
					return;
				else
#endif
				{
					Program.ExitWithOSError(1, err, "select() failed.");
				}
			}

			//  if (Constants.DEBUG)
			//  	Console.WriteLine("select() returned after {} secs", sw.ElapsedMilliseconds / 1000);

			if (_selector.IsRecvReady(_sockin))
				AcceptConnection();
			
			for (let conn in _connections)
			{
				conn.PollCheckTimeout();

				switch (conn.State)
				{
				case .RecvRequest:
				    if (_selector.IsRecvReady(conn.Socket))
						conn.PollRecvRequest();
				    break;
	
				case .SendHeader:
				    if (_selector.IsSendReady(conn.Socket))
						conn.PollSendHeader();
				    break;
	
				case .SendReply:
				    if (_selector.IsSendReady(conn.Socket))
						conn.PollSendReply();
				    break;
	
				case .Done:
					// (handled later; ignore for now as it's a valid state)
				    break;
				}

				// Handling SEND_REPLY could have set the state to done.
				if (conn.State == .Done)
				{
				    // clean out finished connection
				    if (conn.Close)
					{
				        @conn.RemoveFast();
				        delete conn;
				    }
					else
					{
						conn.Recycle();
				    }
				}
			}
		}

		// Accept a connection from sockin and add it to the connection queue.
		public static void AcceptConnection()
		{
			Socket sock = new .();
			
			if (sock.AcceptFrom(_sockin) case .Err(let err))
			{
				// Failed to accept, but try to keep serving existing connections.
				if (err == EMFILE || err == ENFILE)
					Accepting = false;
				if (Constants.DEBUG)
					Console.WriteLine("Failed to accept connection. ({}: {})", err, CurrentPlatform.GetErrorMessage(err, .. scope .()));
				delete sock;
				return;
			}

			sock.Blocking = false;

			Connection conn = new .()
			{
				Socket = sock,
				State = .RecvRequest
			};

			_connections.Add(conn);

			if (Constants.DEBUG)
			{
				Console.WriteLine("accepted connection from {0}:{1} (fd {2})",
					               StringView(Socket.[Friend]inet_ntoa(sock.[Friend]mAddress.sin_addr)),
					               Socket.[Friend]ntohs(sock.[Friend]mAddress.sin_port),
					               (int32)sock.NativeSocket);
			}
			
			// Try to read straight away rather than going through another iteration
			// of the select() loop.
			conn.PollRecvRequest();
		}

		public static StringView GetContentType(String file)
		{
			String fileExt = scope .(file.Substring(file.LastIndexOf('.') + 1))..ToLower();
			if (_mimeMap.TryGetValue(fileExt, var mimeType))
				return mimeType;
			return DefaultMimeType;
		}
	}
}
