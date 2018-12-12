// console.h

#ifdef _WIN32

#include	<windows.h>

#elif defined( MACOSX ) || __ppc64__ || __i386__ || __x86_64__

// Mac

#ifndef LINUX
#include	<Carbon/Carbon.h>
#endif

#endif

// #define	DCAMAPI_VER		3100

#ifdef LINUX
#include	<stdint.h>
#include	<stdio.h>
#include	<stdlib.h>
#include	<stdarg.h>
#include	<string.h>
#include	<pthread.h>
#include	<time.h>
#include	<sys/time.h>
#include	<unistd.h>
#include	"dcamapi.h"
#include	"dcamprop.h"

#ifndef DWORD
#define DWORD uint32_t
#endif

#ifndef LPBYTE
#define LPBYTE unsigned char*
#endif

#else

#include "../../../inc/dcamapi.h"
#include "../../../inc/dcamprop.h"

#endif //LINUX

#ifndef min
#ifdef __cplusplus
template <class C>
inline C min( C a, C b )	{ return a < b ? a : b; }
#else
#define min( a , b ) ( ( a ) < ( b ) ? ( a ) : ( b ) )
#endif
#endif // min

// ----------------------------------------------------------------
// portable

#if defined( _WIN64 )
#pragma comment(lib,"../../../lib/win64/dcamapi.lib")
#elif defined( _WIN32 )
#pragma comment(lib,"../../../lib/win32/dcamapi.lib")
#endif

// ----------------------------------------------------------------


// define common macro

#ifndef ASSERT
#define	ASSERT(c)
#endif

// absorb different function

#ifdef _WIN32

#define	strcmpi	_strcmpi

#elif defined( MACOSX ) || __ppc64__ || __i386__ || __x86_64__

#define	strcmpi		strcasecmp
#define	_strnicmp	strncasecmp

#endif

// absorb Visual Studio 2005

#if defined( WIN32 ) && _MSC_VER >= 1400

#define	_secure_buf(buf)		buf,sizeof( buf )
#define	_secure_ptr(ptr,size)	ptr,size

#else

#define	memcpy_s				memcpy
#define	sprintf_s				sprintf
#define	strcat_s				strcat
#define	_secure_buf(buf)		buf
#define	_secure_ptr(ptr,size)	ptr

#endif
