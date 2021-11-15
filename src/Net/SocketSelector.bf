// based on SocketSelector.cpp from SFML
// https://github.com/SFML/SFML/blob/master/src/SFML/Network/SocketSelector.cpp

using System;
using System.Net;

namespace darkredhttpd
{
	class SocketSelector
	{
		private fd_set mRecvSockets;
		private fd_set mSendSockets;
		private Socket.HSocket mMaxSocket;
#if BF_PLATFORM_WINDOWS
		private int32 mSocketCount;
#endif

		public this()
		{
			Clear();
		}

		public void Clear()
		{
			FD_ZERO!(&mRecvSockets);
			FD_ZERO!(&mSendSockets);
			mMaxSocket = 0;
#if BF_PLATFORM_WINDOWS
			mSocketCount = 0;
#endif
		}

		public bool AddRecv(Socket socket)
		{
			if (!socket.IsOpen)
				return false;

			let handle = socket.NativeSocket;

#if BF_PLATFORM_WINDOWS				
			if (mSocketCount >= FD_SETSIZE)
			    return false;

			if (FD_ISSET!(handle, &mRecvSockets))
			    return true;

			mSocketCount++;
#else
			if ((int)handle >= FD_SETSIZE)
			    return false;

			// SocketHandle is an int in POSIX
			mMaxSocket = Math.Max(mMaxSocket, handle);
#endif

			FD_SET!(handle, &mRecvSockets);

			return true;
		}

		public bool AddSend(Socket socket)
		{
			if (!socket.IsOpen)
				return false;

			let handle = socket.NativeSocket;

#if BF_PLATFORM_WINDOWS				
			if (mSocketCount >= FD_SETSIZE)
			    return false;

			if (FD_ISSET!(handle, &mSendSockets))
			    return true;

			mSocketCount++;
#else
			if ((int)handle >= FD_SETSIZE)
			    return false;

			// SocketHandle is an int in POSIX
			mMaxSocket = Math.Max(mMaxSocket, handle);
#endif

			FD_SET!(handle, &mSendSockets);

			return true;
		}

		[CLink, CallingConvention(.Stdcall)]
		static extern int32 select(int32 nfds, fd_set* readfds, fd_set* writefds, fd_set* exceptfds, timeval* timeout);

		public int32 Wait(int32 timeoutMS)
		{
			timeval time;

			if (timeoutMS >= 0)
			{
				time.tv_sec = timeoutMS / 1000;
				time.tv_usec = (timeoutMS % 1000) * 1000;
			}

			return select((.)mMaxSocket + 1, &mRecvSockets, &mSendSockets, null, timeoutMS >= 0 ? &time : null);
		}

		public bool IsRecvReady(Socket socket)
		{
			if (!socket.IsOpen)
				return false;

			let handle = socket.NativeSocket;

#if !BF_PLATFORM_WINDOWS
			if ((int)handle >= FD_SETSIZE)
				return false;
#endif

			return FD_ISSET!(handle, &mRecvSockets);
		}

		public bool IsSendReady(Socket socket)
		{
			if (!socket.IsOpen)
				return false;

			let handle = socket.NativeSocket;

#if !BF_PLATFORM_WINDOWS
			if ((int)handle >= FD_SETSIZE)
				return false;
#endif

			return FD_ISSET!(handle, &mSendSockets);
		}
	}
}
