using System;
using System.Diagnostics;

namespace darkredhttpd.Helpers
{
	// Base64 encoder from: https://github.com/ramonsmits/Base64Encoder
	// (with some changes to simplify it)
	public static class Base64Encoder
	{
		const char8 PaddingChar = '=';
		static readonly uint8[123] Map = CreateMap();

		const String CharacterSet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
		const bool PaddingEnabled = true;

		private static uint8[123] CreateMap()
		{
			Debug.Assert(CharacterSet.Length <= uint8.MaxValue);

			uint8[123] map = .();
			for (uint8 i < (.)CharacterSet.Length)
				map[(int)CharacterSet[i]] = i;

			return map;
		}

		public static void Encode(Span<char8> data, String outString) =>
			Encode(Span<uint8>((.)data.Ptr, data.Length), outString);

		public static void Encode(Span<uint8> data, String outString)
		{
			int length;
			if (0 == (length = data.Length))
			{
				outString.Clear();
				return;
			}

			uint8* d = data.Ptr;

			int padding = length % 3;
			if (padding > 0)
				padding = 3 - padding;
			int blocks = (length - 1) / 3 + 1;

			int l = blocks * 4;

			outString.Reserve(l);

			char8* sp = outString.Ptr;
			uint8 b1, b2, b3;

			for (int i = 1; i < blocks; i++)
			{
				b1 = *d++;
				b2 = *d++;
				b3 = *d++;

				*sp++ = CharacterSet[(b1 & 0xFC) >> 2];
				*sp++ = CharacterSet[(b2 & 0xF0) >> 4 | (b1 & 0x03) << 4];
				*sp++ = CharacterSet[(b3 & 0xC0) >> 6 | (b2 & 0x0F) << 2];
				*sp++ = CharacterSet[b3 & 0x3F];
			}

			bool pad2 = padding == 2;
			bool pad1 = padding > 0;

			b1 = *d++;
			b2 = pad2 ? (uint8)0 : *d++;
			b3 = pad1 ? (uint8)0 : *d++;

			*sp++ = CharacterSet[(b1 & 0xFC) >> 2];
			*sp++ = CharacterSet[(b2 & 0xF0) >> 4 | (b1 & 0x03) << 4];
			*sp++ = pad2 ? '=' : CharacterSet[(b3 & 0xC0) >> 6 | (b2 & 0x0F) << 2];
			*sp++ = pad1 ? '=' : CharacterSet[b3 & 0x3F];

			if (!PaddingEnabled)
			{
				if (pad2) l--;
				if (pad1) l--;
			}
			
			outString.[Friend]mLength = (.)l;
		}
	}
}
