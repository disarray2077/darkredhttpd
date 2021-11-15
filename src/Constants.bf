using System;

namespace darkredhttpd
{
	public static class Constants
	{
		public static readonly String PKG_NAME = "darkredhttpd/1.13.from.git";
		public static readonly String COPYRIGHT = "copyright (c) 2021 disarray, 2003-2021 Emil Mikulic (darkhttpd)";
		
#if DEBUG
		public const bool DEBUG = true;
#else
		public const bool DEBUG = false;
#endif

		// Be aware that many strings are allocated on the stack, so a very large MAX_REQUEST_VALUE
		// would require refactoring them from scope to new:ScopedAlloc!
		public static readonly int MAX_REQUEST_LENGTH = 4096;

		public static readonly String DEFAULT_EXTENSION_MAP =
			"""
			application/emg emg
			application/pdf pdf
			application/wasm wasm
			application/xml xsl xml
			application/xml-dtd dtd
			application/xslt+xml xslt
			application/zip zip
			audio/flac flac
			audio/mpeg mp2 mp3 mpga
			audio/ogg ogg
			audio/opus opus
			image/gif gif
			image/jpeg jpeg jpe jpg
			image/png png
			image/svg+xml svg
			text/css css
			text/html html htm
			text/javascript js
			text/plain txt asc
			text/vtt vtt
			video/mpeg mpeg mpe mpg
			video/ogg daala ogv
			video/divx divx
			video/quicktime qt mov
			video/x-matroska mkv
			video/x-msvideo avi
			video/mp4 mp4
			""";
	}
}
