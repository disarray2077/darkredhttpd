using System;

namespace darkredhttpd.Helpers
{
	public static class HtmlHelper
	{
		public static void EscapeString(String inString, String outString)
		{
			for (int pos < inString.Length)
			{
			    switch (inString[pos])
				{
			        case '<':
			            outString.Append("&lt;");
			            break;
			        case '>':
			            outString.Append("&gt;");
			            break;
			        case '&':
			            outString.Append("&amp;");
			            break;
			        case '\'':
			            outString.Append("&apos;");
			            break;
			        case '"':
			            outString.Append("&quot;");
			            break;
			        default:
			            outString.Append(inString[pos]);
						break;
			    }
			}
		}
	}
}
