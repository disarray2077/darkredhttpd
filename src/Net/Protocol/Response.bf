using System;
using System.IO;
using System.Diagnostics;

namespace darkredhttpd
{
	class Response
	{
		public enum Type
		{
			Generated,
			FromFile
		}

		public Type Type;
		public int32 Code;
		public String Headers ~ delete _;
		private String _content ~ delete _;
		private UnbufferedFileStream _contentFileStream ~ delete _;

		public int64 Start;
		public int64 Length;

		public StringView TextContentView
		{
			get
			{
				Debug.Assert(Type == .Generated);
				return .(_content.Ptr + Start, (int)Length);
			}
		}

		public String TextContent
		{
			set
			{
				_content = value;
				Length = value.Length;
				Type = .Generated;
			}
		}

		public UnbufferedFileStream ContentFileStream
		{
			get
			{
				Debug.Assert(Type == .FromFile);
				return _contentFileStream;
			}
			set
			{
				_contentFileStream = value;
				Length = _contentFileStream.Length;
				Type = .FromFile;
			}
		}
	}
}
