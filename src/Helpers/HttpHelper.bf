using System;
using System.Diagnostics;

namespace darkredhttpd.Helpers
{
	public static class HttpHelper
	{
		// Set of safe chars, from RFC 1738.4 minus '+'
		public static bool IsUrlSafeChar(char8 ch)
		{
		    if ((ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z') || (ch >= '0' && ch <= '9'))
		        return true;

		    switch (ch)
			{
		        case '-', '_', '.', '!', '*', '(', ')':
		            return true;
		    }

		    return false;
		}

		private static char8 IntToHex(int n)
		{
		    Debug.Assert(n < 0x10);

		    if (n <= 9)
		        return (.)(n + (int)'0');
		    else
		        return (.)(n - 10 + (int)'a');
		}

		// Encode string to be an RFC3986-compliant URL part.
		// Copied from Microsoft repository and adapted to Beef with some modifications.
		// (https://github.com/microsoft/referencesource/blob/master/System.ServiceModel.Internals/System/Runtime/UrlUtility.cs#L238)
		public static void EncodeUrl(StringView urlStr, String outString)
		{
			int cSpaces = 0;
			int cUnsafe = 0;

			// count them first
			for (char8 ch in urlStr)
			{
			    if (ch == ' ')
			        cSpaces++;
			    else if (!IsUrlSafeChar(ch))
			        cUnsafe++;
			}

			// nothing to expand?
			if (cSpaces == 0 && cUnsafe == 0)
			{
				if (urlStr.Ptr != outString.Ptr)
			   		outString.Append(urlStr);
				return;
			}

			// expand not 'safe' characters into %XX, spaces to %20
			outString.Reserve(urlStr.Length + (cUnsafe + cSpaces) * 2);
			
			for (char8 ch in urlStr)
			{
			    if (IsUrlSafeChar(ch))
			    {
			        outString.Append(ch);
			    }
			    else if (ch == ' ')
			    {
					outString.Append("%20");
			    }
			    else
			    {
			        outString.Append('%');
			        outString.Append((char8)IntToHex(((int)ch >> 4) & 0xf));
			        outString.Append((char8)IntToHex((int)ch & 0x0f));
			    }
			}
		}

		// Decode URL by converting %XX (where XX are hexadecimal digits) to the
		// character it represents.
		public static void DecodeUrl(StringView urlStr, String outString)
		{
			outString.Reserve(urlStr.Length);
			for (int i = 0; i < urlStr.Length; i++)
			{
				if (urlStr[i] == '%' && i+2 < urlStr.Length &&
					urlStr[i+1].IsXDigit && urlStr[i+2].IsXDigit)
				{
					// decode %XX
					outString.Append((char8)int32.Parse(urlStr.Substring(i+1, 2), .Hex));
					i += 2;
				}
				else if (urlStr[i] == '+')
				{
					// white-space
					outString.Append(' ');
				}
				else
				{
					// straight copy
					outString.Append(urlStr[i]);
				}
			}
		}

		/* Resolve /./ and /../ in a URL, in-place.
		 * Returns NULL if the URL is invalid/unsafe, or the original buffer if
		 * successful.
		 * TODO: Make this method safer and more "beefy".
		 * (This is a kind of direct port from the C code)
		 */
		public static Result<void> EnsureSafeUrl(String url)
		{
			mixin ends(var c)
			{
				c == '/' || c == '\0'
			}

			char8* src = url, dst;

			/* URLs not starting with a slash are illegal. */
			if (src[0] != '/')
				return .Err;

			/* Fast case: skip until first double-slash or dot-dir. */
			for (; src != url.Ptr + url.Length; ++src)
			{
			    if (src[0] == '/')
				{
			        if (src[1] == '/')
			            break;
			        else if (src[1] == '.')
					{
			            if (ends!(src[2]))
			                break;
			            else if (src[2] == '.' && ends!(src[3]))
			                break;
			        }
			    }
			}

			/* Copy to dst, while collapsing multi-slashes and handling dot-dirs. */
			dst = src;
			while (src != url.Ptr + url.Length)
			{
			    if (src[0] != '/')
			        (dst++)[0] = (src++)[0];
			    else if ((++src)[0] == '/')
			        continue;
			    else if (src[0] != '.')
			        (dst++)[0] = '/';
			    else if (ends!(src[1]))
			        /* Ignore single-dot component. */
			        ++src;
			    else if (src[1] == '.' && ends!(src[2])) {
			        /* Double-dot component. */
			        src += 2;
			        if (dst == url.Ptr)
			            return .Err; /* Illegal URL */
			        else
					{
			            /* Backtrack to previous slash. */
			            while ((--dst)[0] != '/' && dst > url.Ptr) {}
					}
			    }
			    else
			        (dst++)[0] = '/';
			}

			int removeLength = url.Length - (dst - url.Ptr);
			if (removeLength > 0)
			{
				url.Remove(dst - url.Ptr, removeLength);
			}

			return .Ok;
		}
	}
}
