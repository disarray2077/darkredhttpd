using System;
using System.Diagnostics;
using System.Net;
using System.IO;
using System.Collections;
using darkredhttpd.Helpers;

namespace darkredhttpd
{
	class Connection
	{
		public enum State
		{
			RecvRequest,   // receiving request
			SendHeader,    // sending generated header */
			SendReply,     // sending reply
			Done           // connection closed, need to remove from queue
		}

		public Socket Socket;
		public State State;
		public DateTime LastActive;
		public bool Close;
		public Request Request;
		public Response Response;
		
		public bool HeaderOnly;
		public int64 HeaderSent;
		public int64 ResponseSent;

		public DateTime LastBurst;
		public int32 BurstSize;

		public bool IsWaitingNextBurst
		{
			get
			{
				return DateTime.Now - LastBurst <= TimeSpan(0, 0, 1) &&
					   BurstSize == 0;
			}
		}

		public String KeepAliveHeader
		{
			get
			{
				return Close ? "Connection: close\r\n" : HttpListener.KeepAliveField;
			}
		}

		public this()
		{
			LastActive = DateTime.Now;
			Close = true;

			// Make it harmless so it gets garbage-collected if it should, for some
			// reason, fail to be correctly filled out.
			State = .Done;
		}

		public ~this()
		{
			Free();
		}

		public void Log()
		{
			if (HttpListener.Settings.NoLog ||
				Request == null || Response == null || Request.Method == .Unknown)
				return;
			
			let logText = scope String();
			logText.AppendF("{0} - - [{1:dd/MMM/yyyy:H:mm:ss zzz}] \"{2} {3} HTTP/1.1\" {4} {5} \"{6}\" \"{7}\"",
					Socket.GetAddressText(.. scope .()),
					DateTime.Now,
					Request.Method,
					Request.Url,
					Response.Code,
					Response.Length,
					Request.Headers.TryGetValue("referer", .. var s1) ?? "null",
					Request.Headers.TryGetValue("user-agent", .. var s2) ?? "null");

			if (HttpListener.LogFile != null)
			{
				HttpListener.LogFile.Write(logText);
				HttpListener.LogFile.Write(Environment.NewLine);
				HttpListener.LogFile.Flush();
			}
			else
			{
				Console.WriteLine(logText);
			}
		}

		public void Free(bool freeSocket = true)
		{
			if (freeSocket && Constants.DEBUG)
				Console.WriteLine("free connection({0})", (int32)Socket.NativeSocket);

			Log();

			if (freeSocket && Socket != null)
			{
				Socket.Close();
				delete Socket;
			}

			DeleteAndNullify!(Request);
			DeleteAndNullify!(Response);

			/* If we ran out of sockets, try to resume accepting. */
			HttpListener.Accepting = true;

			if (!HttpListener.Settings.AuthKey.IsEmpty && freeSocket)
				ClearLoginAttempts();
		}

		// Recycle a finished connection for HTTP/1.1 Keep-Alive.
		public void Recycle()
		{
			if (Constants.DEBUG)
			    Console.WriteLine("recycle connection({0})", (int32)Socket.NativeSocket);

			Free(false);

			Close = true;
			HeaderOnly = false;
			HeaderSent = 0;
			//ResponseStart = 0;
			ResponseSent = 0;

			State = .RecvRequest; /* ready for another */
		}

		// If a connection has been idle for more than TimeoutSecs, it will be
		// marked as .Done and killed off in Poll().
		public void PollCheckTimeout()
		{
			if (HttpListener.Settings.TimeoutSecs > 0)
			{
				if (DateTime.Now - LastActive >= TimeSpan(0, 0, HttpListener.Settings.TimeoutSecs))
				{
					if (Constants.DEBUG)
						Console.WriteLine("poll_check_timeout({0}) closing connection", (int32)Socket.NativeSocket);
					Close = true;
					State = .Done;
				}
			}
		}

		// Receiving request.
		public void PollRecvRequest()
		{
			Debug.Assert(State == .RecvRequest);

			char8[1<<15] buf = ?;
			let recvd = Socket.Recv(&buf[0], buf.Count);

			if (recvd < 1)
			{
				if (recvd == -1)
				{
					int32 err = Socket.[Friend]GetLastError();
#if BF_PLATFORM_WINDOWS
					if (err == 10035) /* WSAEWOULDBLOCK */
#elif BF_PLATFORM_LINUX
					if (err == EAGAIN)
#endif
					{
						if (Constants.DEBUG)
							Console.WriteLine("poll_recv_request would have blocked");
						return;
					}
					if (Constants.DEBUG)
						Console.WriteLine("recv({0}) error: {1}", (int32)Socket.NativeSocket, CurrentPlatform.GetErrorMessage(err, .. scope .()));
				}
				Close = true;
				State = .Done;
				return;
			}

			LastActive = DateTime.Now;

			if (Request == null)
				Request = new .();

			Request.AddData(buf, recvd);

			HttpListener.TotalIN += recvd;

			if (Request.Length > Constants.MAX_REQUEST_LENGTH)
			{
				/* Drop connection right away, we don't want to receive even more data. */
			    SetDefaultReply(413, "Request Entity Too Large",
			    	"Your request was dropped because it was too long.");
				Close = true;
				State = .SendHeader;
			}
			else if (Request.IsComplete)
			{
				HttpListener.NumRequests++;
				ProcessRequest();
			}

			// if we've moved on to the next state, try to send right away, instead of
			// going through another iteration of the select() loop.
			if (State == .SendHeader)
			    PollSendHeader();
		}

		// Sending header.
		public void PollSendHeader()
		{
			Debug.Assert(State == .SendHeader);
			Debug.Assert(Response != null);
			
			int32 sent = Socket.Send(
				Response.Headers.Ptr + HeaderSent,
				Response.Headers.Length - HeaderSent);

			if (sent < 1)
			{
				if (sent == -1)
				{
					int32 err = Socket.[Friend]GetLastError();
#if BF_PLATFORM_WINDOWS
					if (err == 10035) /* WSAEWOULDBLOCK */
#elif BF_PLATFORM_LINUX
					if (err == EAGAIN)
#endif
					{
						if (Constants.DEBUG)
							Console.WriteLine("poll_send_header would have blocked");
						return;
					}
					if (Constants.DEBUG)
						Console.WriteLine("send({0}) error: {1}", (int32)Socket.NativeSocket, CurrentPlatform.GetErrorMessage(err, .. scope .()));
				}
				Close = true;
				State = .Done;
				return;
			}

			if (Constants.DEBUG)
				Console.WriteLine("poll_send_header({0}) sent {1} bytes", (int32)Socket.NativeSocket, sent);

			LastActive = DateTime.Now;

			Debug.Assert(sent > 0);

			HeaderSent += sent;
			HttpListener.TotalOUT += sent;

			// check if we're done sending header
			if (HeaderSent == Response.Headers.Length)
			{
			    if (HeaderOnly)
			        State = .Done;
			    else
				{
			        State = .SendReply;
			        // go straight on to body, don't go through another iteration of
			        // the select() loop.
			        PollSendReply();
			    }
			}
		}

		// Sending reply.
		public void PollSendReply()
		{
			Debug.Assert(State == .SendReply);
			Debug.Assert(!HeaderOnly);
			Debug.Assert(Response != null);

			int32 sent = 0;

			if (Response.Type == .Generated)
			{
				Debug.Assert(Response.Length >= ResponseSent);
				sent = Socket.Send(
					Response.TextContentView.Ptr + ResponseSent,
					Response.TextContentView.Length - ResponseSent);
				Debug.Assert(sent < 1 || sent == Response.TextContentView.Length - ResponseSent);
			}
			else
			{
				if (HttpListener.Settings.ThrottleBPS > 0)
				{
					if (IsWaitingNextBurst)
						return;

					if (BurstSize == 0)
					{
						LastBurst = DateTime.Now;
						BurstSize = HttpListener.Settings.ThrottleBPS;
					}
				}

				errno() = 0;
				Debug.Assert(Response.Length >= ResponseSent);
				Debug.Assert(Response.Start + ResponseSent >= 0);

				// Must be less or equal to int32.MaxValue - 1 (Windows' TransmitFile limitation)
				const int maxChunkSize = 1 << 15;
				
				let offset = Response.Start + ResponseSent;
				let size = Response.Length - ResponseSent;
				int32 chunkSize = (.)Math.Min(maxChunkSize, size);

				if (HttpListener.Settings.ThrottleBPS > 0 && chunkSize > BurstSize)
					chunkSize = BurstSize;

#if BF_PLATFORM_WINDOWS
				Response.ContentFileStream.Position = offset;
				// TODO: Figure out why this is slower than the generic approach.
				//sent = Socket.SendFile(Response.ContentFileStream.Handle, (.)chunkSize);
				
				uint8[maxChunkSize] buf = ?;
				int numread;
				if (!(Response.ContentFileStream.TryRead(.(&buf[0], chunkSize)) case .Ok(out numread)) ||
					numread != chunkSize)
				{
					Console.WriteLine("file read failed: {}", CurrentPlatform.GetLastErrorMessage(.. scope .()));
					Close = true;
					State = .Done;
					return;
				}

				sent = Socket.Send(&buf[0], chunkSize);
#elif BF_PLATFORM_LINUX
				// TODO: This may give problems with offsets larger than 32-bits...
				sent = Socket.SendFile(Response.ContentFileStream.Handle, (.)offset, chunkSize);
#endif

				Debug.Assert(sent < 1 || sent == chunkSize);
			}

			LastActive = DateTime.Now;

			if (sent < 1)
			{
				if (sent == -1)
				{
					int32 err = Socket.[Friend]GetLastError();
#if BF_PLATFORM_WINDOWS
					if (err == 10035) /* WSAEWOULDBLOCK */
#elif BF_PLATFORM_LINUX
					if (err == EAGAIN)
#endif
					{
						if (Constants.DEBUG)
							Console.WriteLine("poll_send_reply would have blocked");
						return;
					}
					if (Constants.DEBUG)
						Console.WriteLine("send({0}) error: {1}", (int32)Socket.NativeSocket, CurrentPlatform.GetErrorMessage(err, .. scope .()));
				}
				else if (sent == 0)
				{
					if (Constants.DEBUG)
						Console.WriteLine("sent({0}) closure", (int32)Socket.NativeSocket);
				}
				Close = true;
				State = .Done;
				return;
			}

			if (Response.Type != .Generated && HttpListener.Settings.ThrottleBPS > 0)
			{
				Debug.Assert(BurstSize >= sent);
				BurstSize -= sent;
			}

			ResponseSent += sent;
			HttpListener.TotalOUT += sent;

			if (Constants.DEBUG)
				Console.WriteLine("poll_send_reply({0}) sent {1}: {2}+[{3}-{4}] of {5} (remaining: {6})",
					(int32)Socket.NativeSocket, sent,
					(int64)Response.Start + sent - 1, ResponseSent,
					(int64)ResponseSent + sent - 1, Response.Length,
					(int64)Response.Length - ResponseSent);

			if (ResponseSent == Response.Length)
				State = .Done;
		}

		// Process a request: build the header and reply, advance state.
		private void ProcessRequest()
		{
			if (Request.Parse() case .Err)
			{
				SetDefaultReply(400, "Bad Request",
					"You sent a request that the server couldn't understand.");
			}
			else if (HttpHelper.EnsureSafeUrl(Request.Url) case .Err)
			{
				SetDefaultReply(400, "Bad Request",
            		"You requested an invalid URL.");
			}
			else if (!HttpListener.Settings.AuthKey.IsEmpty &&
					 CheckAuthRateLimit(Socket.GetAddressText(.. scope .())))
			{
				SetDefaultReply(403, "Forbidden",
					"Too many failed login attempts. Try again in 5 minutes.");
			}
			else if (!HttpListener.Settings.AuthKey.IsEmpty &&
					 Request.Headers.TryGetValue("authorization", .. var auth) != HttpListener.Settings.AuthKey)
			{
				if (DoAuthRateLimit(Socket.GetAddressText(.. scope .())))
				{
					SetDefaultReply(403, "Forbidden",
						"Too many failed login attempts. Try again in 5 minutes.");
				}
				else
				{
					SetDefaultReply(401, "Unauthorized",
						"Access denied due to invalid credentials.");
				}
			}
			else
			{
				// the request is valid and is ready to be processed
				if (Request.Protocol == "HTTP/1.1")
					Close = false;
	
				if (Request.Headers.TryGetValue("connection", var val))
				{
					if (val == "close")
						Close = true;
					else if (val == "keep-alive")
						Close = false;
				}
	
				// cmdline flag can be used to deny keep-alive
				if (!HttpListener.Settings.WantKeepAlive)
					Close = true;
	
				if (Request.Method == .GET)
				{
					ProcessGet();
				}
				else if (Request.Method == .HEAD)
				{
					ProcessGet();
					HeaderOnly = true;
				}
				else
				{
					SetDefaultReply(501, "Not Implemented",
						"The method you specified is not implemented.");
				}
			}

			// advance state
			State = .SendHeader;
		}

		private mixin GetRFC1123Date()
		{
			DateTime.UtcNow.ToString(.. scope:mixin .(), "R")
		}

		// Process a GET/HEAD request.
		private void ProcessGet()
		{
			String target = ?;
			StringView mimeType = HttpListener.DefaultMimeType;

			// does it end in a slash? serve up url/index_name
			if (Request.Url.EndsWith('/'))
			{
				target = scope:: $"{HttpListener.Settings.WWWRoot}{Request.Url}{HttpListener.Settings.IndexName}";
				if (!File.Exists(target))
				{
					target.RemoveFromEnd(HttpListener.Settings.IndexName.Length);
					if (!Directory.Exists(target) || HttpListener.Settings.NoListing)
					{
						// Return 404 instead of 403 to make --no-listing
						// indistinguishable from the directory not existing.
						// i.e.: Don't leak information.
						SetDefaultReply(404, "Not Found",
		                	"The URL you requested was not found.");
		                return;
					}
					GenerateDirListing(target);
					return;
				}

				if (HttpListener.Settings.IndexName.Contains("."))
					mimeType = HttpListener.GetContentType(HttpListener.Settings.IndexName);
			}
			else
			{
				target = scope:: $"{HttpListener.Settings.WWWRoot}{Request.Url}";

				if (Request.Url.Contains("."))
					mimeType = HttpListener.GetContentType(Request.Url);
			}

			if (Constants.DEBUG)
				Console.WriteLine("url=\"{0}\", target=\"{1}\", content-type=\"{2}\"",
					Request.Url, target, mimeType);

			if (Directory.Exists(target))
			{
				Redirect(scope $"{Request.Url}/");
				return;
			}

			UnbufferedFileStream fs = new .();
			defer { delete fs; }

			if (fs.Open(target, .Read, .ReadWrite) case .Err(let err))
			{
				switch (err)
				{
				case .NotFile:
					SetDefaultReply(403, "Forbidden", "Not a regular file.");
					break;
				case .NotFound:
					SetDefaultReply(404, "Not Found", "The URL you requested was not found.");
					break;
				// TODO idk how to check if we have permission...
				//case :
				//	SetDefaultReply(403, "Forbidden", "You don't have permission to access this URL.");
				//	break;
				case .SharingViolation, .Unknown:
					SetDefaultReply(500, "Internal Server Error", scope $"The URL you requested cannot be returned: {CurrentPlatform.GetLastErrorMessage(.. scope .())}.");
					break;
				}
				return;
			}

			DateTime lastWriteTime;
			if (!(File.GetLastWriteTimeUtc(target) case .Ok(out lastWriteTime)))
			{
				SetDefaultReply(500, "Internal Server Error",
					scope $"Failed to get file information: {CurrentPlatform.GetLastErrorMessage(.. scope .())}.");
				return;
			}

			String lastMod = lastWriteTime.ToString(.. scope .(), "R");

			if (Request.Headers.TryGetValue("if-modified-since", let ifModSince) &&
				ifModSince == lastMod)
			{
				if (Constants.DEBUG)
					Console.WriteLine("not modified since {0}", ifModSince);

				var builder = scope ResponseBuilder(304, "Not Modified")
					..Date(GetRFC1123Date!())
					..AppendHeader(HttpListener.ServerHDR)
					..AcceptRanges("bytes")
					..AppendHeader(KeepAliveHeader);

				Response = builder.Build();

				HeaderOnly = true;
				return;
			}

			if (Request.RangeBegin.HasValue || Request.RangeEnd.HasValue)
			{
				int64 from = ?, to = ?;

				if (Request.RangeBegin.HasValue && Request.RangeEnd.HasValue)
				{
					// 100-200
					from = Request.RangeBegin.Value;
					to = Request.RangeEnd.Value;

					// clamp end to filestat.st_size-1
					if (to > (fs.Length - 1))
						to = fs.Length - 1;
				}
				else if (Request.RangeBegin.HasValue && !Request.RangeEnd.HasValue)
				{
					// 100- :: yields 100 to end
					from = Request.RangeBegin.Value;
					to = fs.Length - 1;
				}
				else if (!Request.RangeBegin.HasValue && Request.RangeEnd.HasValue)
				{
					// -200 :: yields last 200
					to = fs.Length - 1;
					from = to - Request.RangeEnd.Value + 1;

					// clamp start
					if (from < 0)
						from = 0;
				}

				if (from >= fs.Length)
				{
					SetDefaultReply(416, "Requested Range Not Satisfiable",
						"You requested a range outside of the file.");
					return;
				}

				if (to < from)
				{
					SetDefaultReply(416, "Requested Range Not Satisfiable",
						"You requested a backward range.");
					return;
				}

				var builder = scope ResponseBuilder(206, "Partial Content")
					..Date(GetRFC1123Date!())
					..AppendHeader(HttpListener.ServerHDR)
					..AcceptRanges("bytes")
					..AppendHeader(KeepAliveHeader);

				builder.AddFileRange(fs, mimeType, from, to);
				builder.LastModified(lastMod);

				Response = builder.Build();

				if (Constants.DEBUG)
					Console.WriteLine("sending {0}-{1}/{2}", from, to, fs.Length);
			}
			else
			{
				// no range stuff
				var builder = scope ResponseBuilder(200, "OK")
					..Date(GetRFC1123Date!())
					..AppendHeader(HttpListener.ServerHDR)
					..AcceptRanges("bytes")
					..AppendHeader(KeepAliveHeader);

				builder.AddFile(fs, mimeType);
				builder.LastModified(lastMod);

				Response = builder.Build();
			}

			// Avoid fs being deleted.
			fs = null;
		}

		private static String _generatedOn = new .() ~ delete _;
		private mixin GeneratedOn(String date)
		{
			String ret = "";
			if (HttpListener.Settings.WantServerID)
			{
				ret = _generatedOn;
				ret.Clear();
				ret.AppendF("Generated by {} on {}", Constants.PKG_NAME, date);
			}
			ret
		}

		private void Redirect(String targetUrl)
		{
			Debug.Assert(Response == null);

			String rfc1123Date = GetRFC1123Date!();

			var builder = scope ResponseBuilder(301, "Moved Permanently")
				..Date(rfc1123Date)
				..AppendHeader(HttpListener.ServerHDR)
				/* ..AcceptRanges("bytes") - not relevant here */
				..Location(targetUrl)
				..AppendHeader(KeepAliveHeader);

			builder.AddTextContent(
				new $"""
				<html><head><title>301 Moved Permanently</title></head><body>
				<h1>Moved Permanently</h1>
				Moved to: <a href=\"{targetUrl}\">{targetUrl}</a>
				<hr>
				{GeneratedOn!(rfc1123Date)}
				</body></html>\n
				""");

			Response = builder.Build();
		}

		/* A default reply for any (erroneous) occasion. */
		private void SetDefaultReply(int32 errCode, String errName, String errMsg)
		{
			Debug.Assert(Response == null);

			String rfc1123Date = GetRFC1123Date!();

			var builder = scope ResponseBuilder(errCode, errName)
				..Date(rfc1123Date)
				..AppendHeader(HttpListener.ServerHDR)
				..AcceptRanges("bytes")
				..AppendHeader(KeepAliveHeader);

			builder.AddTextContent(
				new $"""
				<html><head><title>{errCode} {errName}</title></head><body>
				<h1>{errName}</h1>
				{errMsg}
				<hr>
				{GeneratedOn!(rfc1123Date)}
				</body></html>\n
				""");

			if (!HttpListener.Settings.AuthKey.IsEmpty)
				builder.AppendHeader("WWW-Authenticate: Basic realm=\"User Visible Realm\"\r\n");

			Response = builder.Build();
		}

		private void GenerateDirListing(String target)
		{
			Debug.Assert(Response == null);

			List<(String, bool, int64)> dirList = scope .();

			for (var entry in Directory.EnumerateDirectories(target))
			{
				dirList.Add((entry.GetFileName(.. scope:: .()), entry.IsDirectory, entry.GetFileSize()));
			}

			for (var entry in Directory.EnumerateFiles(target))
			{
				dirList.Add((entry.GetFileName(.. scope:: .()), entry.IsDirectory, entry.GetFileSize()));
			}

			dirList.Sort(scope (lhs, rhs) => {
				if (!lhs.1 && rhs.1)
					return 1;
				if (lhs.1 && !rhs.1)
					return -1;
				return String.CompareNumeric(lhs.0, rhs.0);
			});
			dirList.Insert(0, ("..", true, 0));

			int maxLen = 0;
			for (var entry in dirList)
				maxLen = Math.Max(maxLen, entry.0.UTF8Length);

			String listing = new .(4096);
			listing.Append("<html>\n<head>\n<title>");
			HtmlHelper.EscapeString(Request.Url, listing);
			listing.Append(
				"""
				</title>
				<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">
				</head>\n<body>\n<h1>
				""");
			HtmlHelper.EscapeString(Request.Url, listing);
			listing.Append("</h1>\n<tt><pre>\n");

			for (var entry in dirList)
			{
				listing.Append("<a href=\"");
				HttpHelper.EncodeUrl(entry.0, listing);
				listing.Append("\">");
				HtmlHelper.EscapeString(entry.0, listing);
				listing.Append("</a>");

				if (entry.1)
					listing.Append("/\n");
				else
				{
					listing.Append(' ', maxLen - entry.0.UTF8Length);
					listing.AppendF("{0,10}\n", MiscHelper.FormatByteSize(entry.2, false, .. scope .()));
				}
			}

			listing.Append(
				"""
				</pre></tt>
				<hr>\n
				""");

			String rfc1123Date = GetRFC1123Date!();
			listing.Append(GeneratedOn!(rfc1123Date));
			listing.Append("</body>\n</html>\n");

			var builder = scope ResponseBuilder(200, "OK")
				..Date(rfc1123Date)
				..AppendHeader(HttpListener.ServerHDR)
				..AcceptRanges("bytes")
				..AppendHeader(KeepAliveHeader);

			builder.AddTextContent(listing);

			Response = builder.Build();
		}

		private typealias LoginAttemptInfo = (DateTime firstAttempt, DateTime banTime, uint32 attemps);
		private static readonly Dictionary<int, LoginAttemptInfo> _loginAttempts = new .() ~ delete _;
		private static DateTime _lastLoginAttemptsClear;

		private static bool CheckAuthRateLimit(String ipAddress)
		{
			if (_loginAttempts.TryGetValue(ipAddress.GetHashCode(), let attempt))
			{
				if (DateTime.Now - attempt.banTime <= TimeSpan(0, 5, 0))
					return true;
			}

			return false;
		}

		private static bool DoAuthRateLimit(String ipAddress)
		{
			if (_loginAttempts.ContainsKey(ipAddress.GetHashCode()))
			{
				var attemptRef = ref _loginAttempts[ipAddress.GetHashCode()];

				if (DateTime.Now - attemptRef.banTime <= TimeSpan(0, 5, 0))
					return true;

				if (++attemptRef.attemps % 10 == 0)
				{
					attemptRef.banTime = DateTime.Now;
					return true;
				}

				return false;
			}

			_loginAttempts[ipAddress.GetHashCode()] = (DateTime.Now, .(), 1);

			return false;
		}

		private static void ClearLoginAttempts()
		{
			if (DateTime.Now - _lastLoginAttemptsClear <= TimeSpan(0, 1, 0))
				return;

			_lastLoginAttemptsClear = DateTime.Now;

			for (let attempt in _loginAttempts.Values)
			{
				TimeSpan timeSinceFirstAttempt = DateTime.Now - attempt.firstAttempt;

				if (timeSinceFirstAttempt >= TimeSpan(0, 5, 0) &&
					DateTime.Now - attempt.banTime >= TimeSpan(0, 5, 0))
				{
					@attempt.Remove();
					continue;
				}
			}
		}
	}
}
