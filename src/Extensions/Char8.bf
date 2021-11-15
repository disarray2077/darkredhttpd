namespace System
{
	extension Char8
	{
		public bool IsXDigit
		{
			get
			{
				return ((this >= '0' && this <= '9') || 
		                (this >= 'a' && this <= 'f') || 
		                (this >= 'A' && this <= 'F'));
			}
		}
	}
}
