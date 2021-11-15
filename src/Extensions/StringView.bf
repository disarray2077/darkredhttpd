using System.Diagnostics;
using System.Text;

namespace System
{
	extension StringView
	{
		public Result<StringView> GetFirstLine()
		{
			if (IsEmpty)
				return .Err;

			int i = 0;
			repeat
			{
				char8 ch = this[i];
		        // Note the following common line feed char8s:
		        // \n - UNIX   \r\n - DOS   \r - Mac
				if (ch == '\r' || ch == '\n')
				{
					StringView strView = .(Ptr, i);
					return .Ok(strView);
				}
				i++;
			}
		    while (i < Length);

			StringView strView = .(Ptr, Length);
			return .Ok(strView);
		}

		public Result<StringView> GetNextLine(StringView previousLine)
		{
			if (IsEmpty)
				return .Err;

			Debug.Assert(previousLine.Ptr == null || (Ptr <= previousLine.Ptr && EndPtr >= previousLine.EndPtr));

			int charPos = previousLine.Ptr == null ? 0 : ((int)(void*)previousLine.EndPtr - (int)(void*)Ptr);
			char8 ch = this[charPos];

			if (charPos > 0 && (ch == '\r' || ch == '\n'))
			{
				charPos += 1;
				if (ch == '\r' && charPos < Length)
				{
					if (this[charPos] == '\n')
						charPos++;
				}
			}

			int i = charPos;
			repeat
			{
				ch = this[i];
		        // Note the following common line feed char8s:
		        // \n - UNIX   \r\n - DOS   \r - Mac
				if (ch == '\r' || ch == '\n')
				{
					StringView strView = .(Ptr + charPos, i - charPos);
					return .Ok(strView);
				}
				i++;
			}
		    while (i < Length);

			StringView strView = .(Ptr + charPos, Length - charPos);
			return .Ok(strView);
		}
	}
}
