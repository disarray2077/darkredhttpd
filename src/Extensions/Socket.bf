using System.Diagnostics;

namespace System.Net
{
	extension Socket
	{
		private SockAddr_in mAddress;
		//public in_addr Address => mAddress.sin_addr;

		private int32 mPort;
		public int32 Port
		{
			get => mPort;
			set
			{
				if (mHandle != INVALID_SOCKET)
					Runtime.FatalError();
				mPort = value;
			}
		}

		private bool mReuseAddr;
		public bool ReuseAddr
		{
			get => mReuseAddr;
			set
			{
				mReuseAddr = value;
				if (mHandle != INVALID_SOCKET)
					SetReuseAddr(mReuseAddr);
			}
		}

		private bool mNoDelay;
		public bool NoDelay
		{
			get => mNoDelay;
			set
			{
				mNoDelay = value;
				if (mHandle != INVALID_SOCKET)
					SetNoDelay(mNoDelay);
			}
		}

		[CLink, CallingConvention(.Stdcall)]
		static extern int32 setsockopt(HSocket s, int32 level, int32 optionName, void* optionValue, uint32 optionLen);

		[CLink, CallingConvention(.Stdcall)]
		static extern int32 getsockname(HSocket s, SockAddr* name, int32* nameLen);

		[CLink, CallingConvention(.Stdcall)]
		static extern char8* inet_ntoa(IPv4Address addr);

		[CLink, CallingConvention(.Stdcall)]
		static extern uint16 ntohs(uint16 netshort);

		[CLink, CallingConvention(.Stdcall)]
		static extern int32 shutdown(HSocket s, int32 how);

		public const int TCP_NODELAY = 1;

		public const int SD_RECEIVE = 0; // Further receives are disallowed
		public const int SD_SEND = 1; // Further sends are disallowed
		public const int SD_BOTH = 2; // Further sends and receives are disallowed

		public void GetAddressText(String outString)
		{
			outString.Append(inet_ntoa(mAddress.sin_addr));
		}

		new void RehupSettings()
		{
			SetBlocking(mIsBlocking);
			SetReuseAddr(mReuseAddr);
			SetNoDelay(mNoDelay);
		}

		void SetReuseAddr(bool reuse)
		{
			int32 param = reuse ? 1 : 0;
			setsockopt(mHandle, SOL_SOCKET, SO_REUSEADDR, &param, sizeof(int32));
		}

		void SetNoDelay(bool noDelay)
		{
			int32 param = noDelay ? 1 : 0;
			setsockopt(mHandle, IPPROTO_TCP, TCP_NODELAY, &param, sizeof(int32));
		}

		public Result<void, int32> Listen(int32 backlog = 5)
		{
			Debug.Assert(mHandle == INVALID_SOCKET);

			mHandle = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
			
			if (mHandle == INVALID_SOCKET)
			{
				int32 err = GetLastError();
				return .Err(err);
			}

			RehupSettings();

			SockAddr_in service = ?;
			service.sin_family = AF_INET;
			service.sin_addr = IPv4Address(0, 0, 0, 0);//in_addr(127, 0, 0, 1);
			service.sin_port = (uint16)htons((int16)mPort);

			if (bind(mHandle, &service, sizeof(SockAddr_in)) == SOCKET_ERROR)
			{
				int32 err = GetLastError();
				Close();
				return .Err(err);
			}

			if (listen(mHandle, backlog) == SOCKET_ERROR)
			{
				int32 err = GetLastError();
				Close();
				return .Err(err);
			}

			mAddress = service;

			return .Ok;
		}

		public new Result<void, int32> AcceptFrom(Socket listenSocket)
		{
			SockAddr_in clientAddr = ?;
			int32 clientAddrLen = sizeof(SockAddr_in);
			mHandle = accept(listenSocket.mHandle, &clientAddr, &clientAddrLen);
			if (mHandle == INVALID_SOCKET)
			{
				int32 err = GetLastError();
				return .Err(err);
			}

			RehupSettings();
			mAddress = clientAddr;
			mIsConnected = true;
			return .Ok;
		}

		public new void Close()
		{
			mAddress = .();
			mIsConnected = false;

			int32 status = shutdown(mHandle, SD_BOTH);
#if BF_PLATFORM_WINDOWS
			if (status == 0)
				closesocket(mHandle);
#else
			if (status == 0)
				close(mHandle);
#endif
			mHandle = INVALID_SOCKET;
		}

		public new int32 Recv(void* ptr, int size)
		{
			int32 result = recv(mHandle, ptr, (int32)size, 0);
			if (result == 0)
				mIsConnected = false;
			else if (result == -1)
				CheckDisconnected();
			return result;
		}

		public new int32 Send(void* ptr, int size)
		{
			int32 result = send(mHandle, ptr, (int32)size, 0);
			if (result == -1)
				CheckDisconnected();
			return result;
		}

#if BF_PLATFORM_WINDOWS
		[Import("mswsock.lib"), CLink, CallingConvention(.Stdcall)]
		static extern int32 TransmitFile(HSocket socket, Windows.Handle file, uint32 numberOfBytesToWrite, uint32 numberOfBytesPerSend, void* overlapped, void* transmitBuffers, uint32 reserved);

		public int32 SendFile(Windows.Handle file, uint32 count)
		{
			Debug.Assert(count <= int32.MaxValue - 1);
			return TransmitFile(mHandle, file, count, 0, null, null, 0) == 1 ? (.)count : 0;
		}
#elif BF_PLATFORM_LINUX
		[CLink]
		public static extern int32 sendfile(int32 outfd, int32 infd, int32* offset, int32 count);

		public int32 SendFile(int fd, int32 offset, int32 count)
		{
			var offset;
			return sendfile((.)mHandle, (.)fd, &offset, count);
		}
#endif
	}
}
