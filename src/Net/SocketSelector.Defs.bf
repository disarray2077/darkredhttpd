using System;
using System.Net;

namespace darkredhttpd
{
	extension SocketSelector
	{
		/*
		* Structure used in select() call, taken from the BSD file sys/time.h.
		*/
		[CRepr]
		struct timeval
		{
			public int32 tv_sec;	/* seconds */
			public int32 tv_usec;	/* and microseconds */
		}

#if BF_PLATFORM_WINDOWS
		/*
		* Select uses arrays of SOCKETs.  These macros manipulate such
		* arrays.  FD_SETSIZE may be defined by the user before including
		* this file, but the default here should be >= 64.
		*/
		const int FD_SETSIZE	= 64;

		[CRepr]
		struct fd_set
		{
			public uint32 fd_count; /* how many are SET? */
			public Socket.HSocket[FD_SETSIZE] fd_array; /* an array of SOCKETs */
		}

		static mixin FD_SET(Socket.HSocket fd, fd_set* set)
		{
			uint32 i;
			for (i = 0; i < set.fd_count; i++)
			{
			    if (set.fd_array[i] == fd)
			        break;
			}

			if (i == set.fd_count)
			{
			    if (set.fd_count < FD_SETSIZE)
				{
			        set.fd_array[i] = fd;
			        set.fd_count++;
			    }
			}
		}

		static mixin FD_ZERO(fd_set* set)
		{
			set.fd_count = 0;
		}

		[Import("wsock32.lib"), CLink, CallingConvention(.Stdcall)]
		static extern int32 __WSAFDIsSet(Socket.HSocket fd, fd_set* set);

		static mixin FD_ISSET(Socket.HSocket fd, fd_set* set)
		{
			__WSAFDIsSet(fd, set) == 1
		}
#elif BF_PLATFORM_LINUX
		/*
		* Select uses bit masks of file descriptors in longs.  These macros
		* manipulate such bit fields (the filesystem macros use chars).
		* FD_SETSIZE may be defined by the user, but the default here should
		* be enough for most uses.
		*/
		const int FD_SETSIZE	= 1024;

		/*
		* We don't want to pollute the namespace with select(2) internals.
		* Non-underscore versions are exposed later #if __BSD_VISIBLE
		*/
		const int __NBBY = 8;
		typealias __fd_mask = uint32;
		const int  __NFDBITS = ((uint32)(sizeof(__fd_mask) * __NBBY)); /* bits per mask */

		static int __howmany(int x, int y)
		{
			return (((x) + ((y) - 1)) / (y));
		}

		[CRepr]
		struct fd_set
		{
			//public __fd_mask[__howmany(FD_SETSIZE, __NFDBITS)] fds_bits;
			public __fd_mask[(((FD_SETSIZE) + ((__NFDBITS) - 1)) / (__NFDBITS))] fds_bits;
		}

		static mixin FD_SET(Socket.HSocket fd, fd_set* p)
		{
			FD_SET!((int32)fd, p);
		}

		static mixin FD_SET(int32 fd, fd_set* p)
		{
			p.fds_bits[fd / __NFDBITS] |= (1U << (fd % __NFDBITS));
		}

		static mixin FD_ISSET(Socket.HSocket fd, fd_set* p)
		{
			FD_ISSET!((int32)fd, p)
		}

		static mixin FD_ISSET(int32 fd, fd_set* p)
		{
			(p.fds_bits[fd / __NFDBITS] & (1U << (fd % __NFDBITS))) != 0
		}

		static mixin FD_ZERO(fd_set* p)
		{
			for (int i < p.fds_bits.Count)
				p.fds_bits[i] = 0;
		}
#endif
	}
}
