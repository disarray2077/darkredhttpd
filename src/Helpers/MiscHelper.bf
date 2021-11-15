using System;

namespace darkredhttpd.Helpers
{
	public static class MiscHelper
	{
		// Truncate that can retain an specified digit count.
		public static double Truncate(double value, int digits)
		{
		    double mult = Math.Pow(10.0, digits);
		    return Math.Truncate(value * mult) / mult;
		}

		/// Returns how many digits there are to the left of the decimal point.
		public static int CountDigits(double value)
		{
			var value;
		    int digits = 0;

		    while (value >= 1)
			{
		        digits++;
		        value /= 10;
		    }

		    return digits;
		}

		/// Returns how many digits there are to the left of the decimal point.
		public static int CountDigits(double value, int max)
		{
			var value;
		    int digits = 0;

		    while (value >= 1 && digits < max)
			{
		        digits++;
		        value /= 10;
		    }

		    return digits;
		}

		// Converts a numeric value into a string that represents the number expressed as a size value in bytes, kilobytes, megabytes, or gigabytes, depending on the size.
		public static void FormatByteSize(int64 bytes, bool si, String outString)
		{
		    var unit = si
		        ? 1000
		        : 1024;

		    if (bytes < unit)
		    {
		        outString.AppendF($"{bytes} B");
				return;
		    }

		    var exp = (int) (Math.Log(bytes) / Math.Log(unit));
			var size = bytes / Math.Pow(unit, exp);

#if BF_32_BIT
			// Currently Beef gives a linker error in Truncate in 32 bits mode.
			outString.AppendF($"{size:F2} ");
#else
			var digits = CountDigits(size, 3);
			if (digits == 1)
				outString.AppendF($"{Truncate(size, 2):F2} ");
			else if (digits == 2)
				outString.AppendF($"{Truncate(size, 1):F1} ");
			else if (digits >= 3)
				outString.AppendF($"{Math.Truncate(size)} ");
#endif

			outString.Append((si ? "kMGTPE" : "KMGTPE")[exp - 1]);
			if (si)
				outString.Append('i');
			outString.Append('B');
		}
	}
}
