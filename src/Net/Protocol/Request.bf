using System;
using System.IO;
using System.Diagnostics;
using System.Collections;
using darkredhttpd.Helpers;

namespace darkredhttpd
{
	class Request
	{
		public HttpMethod Method;
		public String Url = new .() ~ delete _;
		public String Protocol = new .() ~ delete _;
		public List<char8> Data = new .(512) ~ delete _;
		public int32 Length;
		public int64? RangeBegin;
		public int64? RangeEnd;
		
		public Dictionary<String, String> Query = new .() ~ DeleteDictionaryAndKeysAndValues!(_);
		public Dictionary<String, String> Headers = new .() ~ DeleteDictionaryAndKeysAndValues!(_);

		public bool IsComplete
		{
			get
			{
				return (Data.Count > 2 && Internal.MemCmp(Data.Ptr + Data.Count - 2, (.)"\n\n", 2) == 0) ||
					   (Data.Count > 4 && Internal.MemCmp(Data.Ptr + Data.Count - 4, (.)"\r\n\r\n", 4) == 0);
			}
		}

		public this()
		{

		}

		public void AddData(Span<char8> data, int32 length)
		{
			Data.AddRange(data.Slice(0, length));
			Length += length;
		}

		// Parse an HTTP request like "GET / HTTP/1.1" to get the method (GET), the
		// url (/), the referer (if given) and the user-agent (if given).
		public Result<void> Parse()
		{
			Debug.Assert(Data != null);
			Debug.Assert(Length == Data.Count);

			StringView dataView = .(Data.Ptr, Data.Count);
			StringView lineView = .();

			if (dataView.GetFirstLine() case .Ok(out lineView))
			{
				var splitter = lineView.Split(' ');
	
				StringView methodStr;
				if (!(splitter.GetNext() case .Ok(out methodStr)))
					return .Err;
	
				if (!(Enum.Parse<HttpMethod>(methodStr, true) case .Ok(out Method)))
					return .Err;
	
				StringView urlStr;
				if (!(splitter.GetNext() case .Ok(out urlStr)))
					return .Err;

				if (urlStr.Contains('?'))
				{
					ParseQuery(urlStr.Substring(urlStr.IndexOf('?') + 1));
					HttpHelper.DecodeUrl(urlStr.Substring(0, urlStr.IndexOf('?')), Url);
				}
				else
					HttpHelper.DecodeUrl(urlStr, Url);
	
				StringView protocolStr;
				if (!(splitter.GetNext() case .Ok(out protocolStr)))
					return .Err;
	
				Protocol.Set(protocolStr);
			}
			else
			{
				// couldn't understand first line
				return .Err;
			}

			while (dataView.GetNextLine(lineView) case .Ok(out lineView))
			{
				if (lineView.IsEmpty)
					break;

				var splitter = lineView.Split(':', 2);

				StringView headerKey;
				if (!(splitter.GetNext() case .Ok(out headerKey)))
					return .Err;

				StringView headerValue;
				if (!(splitter.GetNext() case .Ok(out headerValue)))
					return .Err;

				Headers.Add(new String(headerKey)..ToLower(), new String(headerValue..Trim()));
			}

			// Data is not needed anymore.
			DeleteAndNullify!(Data);

			if (Headers.TryGetValue("range", let val))
				ParseRangeField(val);

			return .Ok;
		}

		// Parse a url query (anything after the "?")
		private void ParseQuery(StringView queryStr)
		{
			// Url contains only "?"
			if (queryStr.IsEmpty)
				return;

			String decodedQueryStr = scope .(queryStr.Length);
			HttpHelper.DecodeUrl(queryStr, decodedQueryStr);

			for (var kvPair in decodedQueryStr.Split('&'))
			{
				var splitter = kvPair.Split('=', 2);

				StringView keyStr;
				if (!(splitter.GetNext() case .Ok(out keyStr)))
					continue;
				
				StringView valueStr;
				if (!(splitter.GetNext() case .Ok(out valueStr)))
					Query.Add(new .(keyStr), null);
				else
					Query.Add(new .(keyStr), new .(valueStr));
			}
		}

		// Parse a Range: field into range_begin and range_end.  Only handles the
		// first range if a list is given.
		private void ParseRangeField(StringView rangeValue)
		{
			// Ignore if range format is invalid.
			if (!rangeValue.StartsWith("bytes="))
				return;

			var rangeValue;
			rangeValue.Adjust(6); // skip "bytes="

			let commaIndex = rangeValue.IndexOf(',');
			if (commaIndex != -1)
				rangeValue.RemoveToEnd(commaIndex);

			var splitter = rangeValue.Split('-', 2);

			StringView rangeBeginStr;
			if (!(splitter.GetNext() case .Ok(out rangeBeginStr)))
				return;

			if (!rangeBeginStr.IsEmpty)
			{
				if (int64.Parse(rangeBeginStr) case .Ok(let val))
					RangeBegin = val;
				else
					return;
			}

			StringView rangeEndStr;
			if (!(splitter.GetNext() case .Ok(out rangeEndStr)))
				return;

			if (!rangeEndStr.IsEmpty)
			{
				if (int64.Parse(rangeEndStr) case .Ok(let val))
					RangeEnd = val;
				else
					return;
			}
		}
	}
}
