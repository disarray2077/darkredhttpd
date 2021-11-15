using System.Text;
using System.Diagnostics;
namespace System
{
	extension String
	{
		public void PadLeft(int totalWidth, char8 paddingChar)
		{
			Insert(0, paddingChar, totalWidth - Length);
		}

		public void PadRight(int totalWidth, char8 paddingChar)
		{
			Append(paddingChar, totalWidth - Length);
		}

		public mixin ToScopedNativeWCStr()
		{
			int encodedLen = UTF16.GetEncodedLen(this);
			char16* buf;
			if (encodedLen < 128)
			{
				buf = scope:mixin char16[encodedLen + 1]* ( ? );
			}
			else
			{
				buf = new char16[encodedLen + 1]* ( ? );
				defer:mixin delete buf;
			}

			UTF16.Encode(this, buf, encodedLen);
			buf[encodedLen] = 0;
			buf
		}

		public int UTF8Length
		{
			get
			{
				int length = 0;
				for (let ch in RawChars)
				{
					if (((int)ch & 0xc0) != 0x80)
						length += 1;
				}
				return length;
			}
		}

		// Returns the number slice of the string starting at the supplied index.
		public Result<StringView> GetNumberSlice(int index = 0, bool supportHex = false)
		{
			Debug.Assert(Length > index && index >= 0);

			int i = index;
			for (; i < Length; i++)
			{
				if (!this[i].IsDigit || (supportHex && !this[i].IsXDigit))
					break;
			}

			if (i == index)
				return .Err;

			return .Ok(.(Ptr + index, i - index));
		}


		// Code ported from wine's StrCmpLogicalW implementation.
		public static int CompareNumeric(String str, String other)
		{
		    if (!String.IsNullOrEmpty(str) && !String.IsNullOrEmpty(other))
		    {
		        int strIndex = 0, otherIndex = 0;
		 
		        while (strIndex < str.Length)
		        {
		            if (otherIndex >= other.Length)
		                return 1;
		 
		            if (str[strIndex].IsDigit)
		            {
		                if (!other[otherIndex].IsDigit)
		                    return -1;

						StringView strValueView = str.GetNumberSlice(strIndex);
						StringView otherValueView = other.GetNumberSlice(otherIndex);
		 
		                int64 strValue = 0L, otherValue = 0L;

						if (!(int64.Parse(strValueView) case .Ok(out strValue)))
						{
							// overflow?
							strValue = int64.MaxValue;
						}

						if (!(int64.Parse(otherValueView) case .Ok(out otherValue)))
						{
							// overflow?
							otherValue = int64.MaxValue;
						}
		 
		                if (strValue < otherValue)
		                    return -1;
		                else if (strValue > otherValue)
		                    return 1;

						strIndex += strValueView.Length;
						otherIndex += otherValueView.Length;
		            }
		            else if (other[otherIndex].IsDigit)
		                return 1;
		            else
		            {
		                int diff = String.Compare(str.Ptr + strIndex, 1, other.Ptr + otherIndex, 1, true);
		 
		                if (diff > 0)
		                    return 1;
		                else if (diff < 0)
		                    return -1;
		 
		                strIndex++;
		                otherIndex++;
		            }
		        }
		 
		        if (otherIndex < other.Length)
		            return -1;
		    }
		 
		    return 0;
		}
	}
}
