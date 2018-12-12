// bitmap.cpp

#include "stdafx.h"
#include "bitmap.h"

#ifdef _DEBUG
#define new DEBUG_NEW
#undef THIS_FILE
static char THIS_FILE[] = __FILE__;
#endif

/////////////////////////////////////////////////////////////////////////////

long copybits_bw8( BYTE* dsttopleft, long dstrowbytes
				  , const BYTE* srctopleft, long srcrowbytes
				  , long srcox, long srcoy, long srcwidth, long srcheight )
{
	long	lines = 0;
	const BYTE*	src = srctopleft + srcrowbytes * srcoy + srcox;
	BYTE* dst = dsttopleft;

	int	x, y;
	for( y = srcheight; y-- > 0; )
	{
		const BYTE*	s = src;
		BYTE*	d = dst;

		for( x = srcwidth; x-- > 0; )
		{
			*d++ = *s++;
		}

		src += srcrowbytes;
		dst += dstrowbytes;
		lines++;
	}

	return lines;
}

long copybits_bw16( BYTE* dsttopleft, long dstrowbytes, long nShift
				  , const WORD* srctopleft, long srcrowbytes
				  , long srcox, long srcoy, long srcwidth, long srcheight )
{
	long	lines = 0;
	const BYTE*	src = (const BYTE*)srctopleft + srcrowbytes * srcoy + srcox * sizeof( WORD );
	BYTE* dst = dsttopleft;

	int	x, y;
	for( y = srcheight; y-- > 0; )
	{
		const WORD*	s = (const WORD*)src;
		BYTE*	d = dst;

		for( x = srcwidth; x-- > 0; )
		{
			*d++ = *s++ >> nShift;
		}

		src += srcrowbytes;
		dst += dstrowbytes;
		lines++;
	}

	return lines;
}

long copybits_bw16( BYTE* dsttopleft, long dstrowbytes, const BYTE* lut
				  , const WORD* srctopleft, long srcrowbytes
				  , long srcox, long srcoy, long srcwidth, long srcheight )
{
	long	lines = 0;
	const BYTE*	src = (const BYTE*)srctopleft + srcrowbytes * srcoy + srcox * sizeof( WORD );
	BYTE* dst = dsttopleft;

	int	x, y;
	for( y = srcheight; y-- > 0; )
	{
		const WORD*	s = (const WORD*)src;
		BYTE*	d = dst;

		for( x = srcwidth; x-- > 0; )
		{
			*d++ = lut[ *s++ ];
		}

		src += srcrowbytes;
		dst += dstrowbytes;
		lines++;
	}

	return lines;
}

// ----------------

long copybits_bgr8( BYTE* dsttopleft, long dstrowbytes
				  , const BYTE* srctopleft, long srcrowbytes
				  , long srcox, long srcoy, long srcwidth, long srcheight )
{
	long	lines = 0;
	const BYTE*	src = srctopleft + srcrowbytes * srcoy + srcox * 3;
	BYTE* dst = dsttopleft;

	int	x, y;
	for( y = srcheight; y-- > 0; )
	{
		const BYTE*	s = src;
		BYTE*	d = dst;

		for( x = srcwidth; x-- > 0; )
		{
			*d++ = *s++;
			*d++ = *s++;
			*d++ = *s++;
		}

		src += srcrowbytes;
		dst += dstrowbytes;
		lines++;
	}

	return lines;
}


long copybits_bgr16( BYTE* dsttopleft, long dstrowbytes, long nShift
				  , const WORD* srctopleft, long srcrowbytes
				  , long srcox, long srcoy, long srcwidth, long srcheight )
{
	long	lines = 0;
	const BYTE*	src = (const BYTE*)srctopleft + srcrowbytes * srcoy + srcox * 3 * sizeof( WORD );
	BYTE* dst = dsttopleft;

	int	x, y;
	for( y = srcheight; y-- > 0; )
	{
		const WORD*	s = (const WORD*)src;
		BYTE*	d = dst;

		for( x = srcwidth; x-- > 0; )
		{
			*d++ = *s++ >> nShift;
			*d++ = *s++ >> nShift;
			*d++ = *s++ >> nShift;
		}

		src += srcrowbytes;
		dst += dstrowbytes;
		lines++;
	}

	return lines;
}

long copybits_bgr16( BYTE* dsttopleft, long dstrowbytes, const BYTE* lut
				  , const WORD* srctopleft, long srcrowbytes
				  , long srcox, long srcoy, long srcwidth, long srcheight )
{
	long	lines = 0;
	const BYTE*	src = (const BYTE*)srctopleft + srcrowbytes * srcoy + srcox * 3 * sizeof( WORD );
	BYTE* dst = dsttopleft;

	int	x, y;
	for( y = srcheight; y-- > 0; )
	{
		const WORD*	s = (const WORD*)src;
		BYTE*	d = dst;

		for( x = srcwidth; x-- > 0; )
		{
			*d++ = lut[ *s++ ];
			*d++ = lut[ *s++ ];
			*d++ = lut[ *s++ ];
		}

		src += srcrowbytes;
		dst += dstrowbytes;
		lines++;
	}

	return lines;
}

// ----------------

long copybits_rgb8( BYTE* dsttopleft, long dstrowbytes
				  , const BYTE* srctopleft, long srcrowbytes
				  , long srcox, long srcoy, long srcwidth, long srcheight )
{
	long	lines = 0;
	const BYTE*	src = srctopleft + srcrowbytes * srcoy + srcox * 3;
	BYTE* dst = dsttopleft;

	int	x, y;
	for( y = srcheight; y-- > 0; )
	{
		const BYTE*	s = src;
		BYTE*	d = dst;

		for( x = srcwidth; x-- > 0; )
		{
			register BYTE	r = *s++;
			register BYTE	g = *s++;
			register BYTE	b = *s++;
			*d++ = b;
			*d++ = g;
			*d++ = r;
		}

		src += srcrowbytes;
		dst += dstrowbytes;
		lines++;
	}

	return lines;
}


long copybits_rgb16( BYTE* dsttopleft, long dstrowbytes, long nShift
				  , const WORD* srctopleft, long srcrowbytes
				  , long srcox, long srcoy, long srcwidth, long srcheight )
{
	long	lines = 0;
	const BYTE*	src = (const BYTE*)srctopleft + srcrowbytes * srcoy + srcox * 3 * sizeof( WORD );
	BYTE* dst = dsttopleft;

	int	x, y;
	for( y = srcheight; y-- > 0; )
	{
		const WORD*	s = (const WORD*)src;
		BYTE*	d = dst;

		for( x = srcwidth; x-- > 0; )
		{
			register BYTE	r = *s++ >> nShift;
			register BYTE	g = *s++ >> nShift;
			register BYTE	b = *s++ >> nShift;
			*d++ = b;
			*d++ = g;
			*d++ = r;
		}

		src += srcrowbytes;
		dst += dstrowbytes;
		lines++;
	}

	return lines;
}

long copybits_rgb16( BYTE* dsttopleft, long dstrowbytes, const BYTE* lut
				  , const WORD* srctopleft, long srcrowbytes
				  , long srcox, long srcoy, long srcwidth, long srcheight )
{
	long	lines = 0;
	const BYTE*	src = (const BYTE*)srctopleft + srcrowbytes * srcoy + srcox * 3 * sizeof( WORD );
	BYTE* dst = dsttopleft;

	int	x, y;
	for( y = srcheight; y-- > 0; )
	{
		const WORD*	s = (const WORD*)src;
		BYTE*	d = dst;

		for( x = srcwidth; x-- > 0; )
		{
			register BYTE	r = lut[ *s++ ];
			register BYTE	g = lut[ *s++ ];
			register BYTE	b = lut[ *s++ ];
			*d++ = b;
			*d++ = g;
			*d++ = r;
		}

		src += srcrowbytes;
		dst += dstrowbytes;
		lines++;
	}

	return lines;
}

// ----------------
/*
long copybits( BYTE* dsttopleft, long dstrowbytes
		 , const void* srctopleft, long srcrowbytes
		 , long srcox, long srcoy, long srcwidth, long srcheight
		 , BOOL bRGB, long bitperchannel, long nShift, const BYTE* lut )
{
	long	lines;

	if( bRGB )
	{
		if( bitperchannel == 8 )
		{
			lines = copybits_rgb8( dsttopleft, dstrowbytes
				, (const BYTE*)srctopleft, srcrowbytes
				, srcox, srcoy, srcwidth, srcheight );
		}
		else
		{
			ASSERT( bitperchannel <= 16 );

			if( lut == NULL )
			{
				lines = copybits_rgb16( dsttopleft, dstrowbytes, nShift
					, (const WORD*)srctopleft, srcrowbytes
					, srcox, srcoy, srcwidth, srcheight );
			}
			else
			{
				lines = copybits_rgb16( dsttopleft, dstrowbytes, lut
					, (const WORD*)srctopleft, srcrowbytes
					, srcox, srcoy, srcwidth, srcheight );
			}
		}
	}
	else
	{
		if( bitperchannel == 8 )
		{
			lines = copybits_bw8( dsttopleft, dstrowbytes
				, (const BYTE*)srctopleft, srcrowbytes
				, srcox, srcoy, srcwidth, srcheight );
		}
		else
		{
			ASSERT( bitperchannel <= 16 );

			if( lut == NULL )
			{
				lines = copybits_bw16( dsttopleft, dstrowbytes, nShift
					, (const WORD*)srctopleft, srcrowbytes
					, srcox, srcoy, srcwidth, srcheight );
			}
			else
			{
				lines = copybits_bw16( dsttopleft, dstrowbytes, lut
					, (const WORD*)srctopleft, srcrowbytes
					, srcox, srcoy, srcwidth, srcheight );
			}
		}
	}

	return lines;
}
*/
