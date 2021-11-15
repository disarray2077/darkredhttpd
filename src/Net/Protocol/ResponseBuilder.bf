using System;
using System.Diagnostics;
using System.IO;

namespace darkredhttpd
{
	class ResponseBuilder
	{
		public int32 Code;
		public String Headers = new .(512) ~ delete _;
		public String Content ~ delete _;
		public UnbufferedFileStream FileStream ~ delete _;
		public bool Range;
		public int64 RangeStart;
		public int64 RangeEnd;
		public bool Finalized;

		public this(int32 code, String codeName)
		{
			Code = code;
			Headers.AppendF("HTTP/1.1 {} {}\r\n", code, codeName);
		}

		// Appends a text directly to the header.
		public void AppendHeader(String str)
		{
			Debug.Assert(!Finalized);
			Headers.Append(str);
		}

		// Appends a custom field to the header.
		public void AppendHeader(String key, String value)
		{
			Debug.Assert(!Finalized);
			Headers.AppendF("{}: {}\r\n", key, value);
		}

		public void AddTextContent(String str)
		{
			Debug.Assert(!Finalized);
			Content = str;
			Headers.AppendF("Content-Length: {}\r\n", Content.Length);
			Headers.Append("Content-Type: text/html; charset=UTF-8\r\n");
		}

		public void AddFileRange(UnbufferedFileStream fileStream, StringView mimeType, int64 from, int64 to)
		{
			Debug.Assert(!Finalized);
			FileStream = fileStream;
			Range = true;
			RangeStart = from;
			RangeEnd = to;
			Headers.AppendF("Content-Length: {}\r\n", to - from + 1);
			Headers.AppendF("Content-Range: bytes {}-{}/{}\r\n", from, to, fileStream.Length);
			Headers.AppendF("Content-Type: {}\r\n", mimeType);
		}

		public void AddFile(UnbufferedFileStream fileStream, StringView mimeType)
		{
			Debug.Assert(!Finalized);
			FileStream = fileStream;
			Headers.AppendF("Content-Length: {}\r\n", fileStream.Length);
			Headers.AppendF("Content-Type: {}\r\n", mimeType);
		}

		public Response Build()
		{
			if (!Finalized)
			{
				Finalized = true;
				Headers.Append("\r\n");
			}
			else
			{
				Runtime.FatalError("Tried to use already finalized ResponseBuilder!");
			}

			Response response = new .()
			{
				Code = Code,
				Headers = Headers
			};

			if (Content != null)
				response.TextContent = Content;

			if (FileStream != null)
				response.ContentFileStream = FileStream;

			if (Range)
			{
				response.Start = RangeStart;
				response.Length = RangeEnd - RangeStart + 1;
			}

			// Response is now the owner of these objects.
			Headers = null;
			Content = null;
			FileStream = null;

			return response;
		}

		public void Date(String str)
		{
			Debug.Assert(!Finalized);
			Headers.AppendF("Date: {}\r\n", str);
		}

		public void Server(String str)
		{
			Debug.Assert(!Finalized);
			Headers.AppendF("Server: {}\r\n", str);
		}

		public void AcceptRanges(String str)
		{
			Debug.Assert(!Finalized);
			Headers.AppendF("Accept-Ranges: {}\r\n", str);
		}

		public void Location(String str)
		{
			Debug.Assert(!Finalized);
			Headers.AppendF("Location: {}\r\n", str);
		}

		public void KeepAlive(String str)
		{
			Debug.Assert(!Finalized);
			Headers.AppendF("Keep-Alive: {}\r\n", str);
		}

		public void LastModified(String str)
		{
			Debug.Assert(!Finalized);
			Headers.AppendF("Last-Modified: {}\r\n", str);
		}
	}
}
