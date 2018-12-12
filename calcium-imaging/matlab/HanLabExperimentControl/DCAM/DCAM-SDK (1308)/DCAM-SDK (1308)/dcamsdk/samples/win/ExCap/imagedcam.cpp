// imagedcam.cpp
//

#include "stdafx.h"
#include "image.h"
#include "dcamex.h"

#include "bitmap.h"

#ifdef _DEBUG
#define new DEBUG_NEW
#undef THIS_FILE
static char THIS_FILE[] = __FILE__;
#endif

template <class T>
inline BOOL myalloc( T*& p, size_t count )
{
	p = (T*)malloc( sizeof( T ) * count );
	return p != NULL;
}

inline void myfree( void* p )
{
	free( p );
}

/////////////////////////////////////////////////////////////////////////////
// imagedcam

class imagedcam : public image
{
public:
	~imagedcam();
	imagedcam( HDCAM hdcam );

// override from class iamge
public:
			BOOL	release();	// TRUE means still object is exist.

			BOOL	allocateframes( long framecount, BOOL bUser );
			BOOL	freeframes();
			void**	getframes();
			void*	getframe( long index, int32& rowbytes );
public:
			BOOL	get_bitmapinfoheader( BITMAPINFOHEADER& bmih ) const;
			long	copybits( BYTE* dsttopleft, long rowbytes, long iFrame, long srcwidth, long srcheight, long hOffset, long vOffset, const BYTE* lut = NULL );

			long	width() const;
			long	height() const;
			long	colortype() const;
			long	pixelperchannel() const;

			long	numberof_frames() const;

			BOOL	is_bitmap_updated();
			void	clear_bitmap_updated();

protected:
			void	check_bmpupdated();
			long	_copybits( BYTE* dsttopleft, long dstrowbytes, const void* src, long srcrowbytes, long src_ox, long src_oy, long srcwidth, long srcheight, const BYTE* lut );

protected:
	struct {
		HDCAM	hdcam;
		BOOL	bmpupdated;
		long	newestFrameIndex;
		long	totalFrameCount;

		char**	chunkbuffers;
		long	nChunkBuffer;

		void**	userframes;
		long	nUserFrame;
	} var_imagedcam;
};

// ----

imagedcam::~imagedcam()
{
}

imagedcam::imagedcam( HDCAM hdcam )
{
	memset( &var_imagedcam, 0, sizeof( var_imagedcam ) );

	var_imagedcam.hdcam = hdcam;
	var_imagedcam.newestFrameIndex = -1;
}

BOOL imagedcam::release()
{
	freeframes();

	return image::release();
}

BOOL imagedcam::allocateframes( long framecount, BOOL bUser )
{
	freeframes();

	if( ! bUser )
	{
		if( ! dcam_allocframe( var_imagedcam.hdcam, framecount ) )
			return FALSE;

		var_imagedcam.nUserFrame = framecount;
		return TRUE;
	}

	size_t	dataframebytes;
	{
		DWORD	dw;
		if( ! dcam_getdataframebytes( var_imagedcam.hdcam, &dw ) && dw > 0 )
			return FALSE;

		dataframebytes = dw;
	}

	if( myalloc( var_imagedcam.userframes, framecount ) )
	{
		memset( var_imagedcam.userframes, 0, sizeof( *var_imagedcam.userframes ) * framecount );
#ifndef _WIN64
		const int size_chunkblock = 0x04000000;	// 64 MB.
		long	frame_per_chunkblock = (long)( size_chunkblock / dataframebytes );
#else
		long	frame_per_chunkblock = framecount;
#endif
		long	nChunkBuffer = framecount / frame_per_chunkblock;
		if( framecount % frame_per_chunkblock )
			nChunkBuffer++;
		if( myalloc( var_imagedcam.chunkbuffers, nChunkBuffer ) )
		{
			memset( var_imagedcam.chunkbuffers, 0, sizeof( *var_imagedcam.chunkbuffers ) * nChunkBuffer );

			int	i;
			for( i = 0; i < nChunkBuffer; i++ )
			{
				if( ! myalloc( var_imagedcam.chunkbuffers[ i ], dataframebytes * frame_per_chunkblock ) )
					break;
			}

			if( i == nChunkBuffer )
			{
				int	j, k;

				k = 0;
				for( i = 0; i < nChunkBuffer; i++ )
				{
					for( j = 0; j < frame_per_chunkblock; j++ )
					{
						var_imagedcam.userframes[ k++ ] = var_imagedcam.chunkbuffers[ i ] + dataframebytes * j;
						if( k >= framecount )
							break;
					}
				}

				var_imagedcam.nUserFrame = framecount;
				var_imagedcam.nChunkBuffer = nChunkBuffer;

				return TRUE;
			}
		}

		freeframes();
	}

	return FALSE;
}

BOOL imagedcam::freeframes()
{
	if( var_imagedcam.chunkbuffers != NULL )
	{
		int	i;
		for( i = 0; i < var_imagedcam.nChunkBuffer; i++ )
		{
			if( var_imagedcam.chunkbuffers[ i ] != NULL )
			{
				myfree( var_imagedcam.chunkbuffers[ i ] );
			}
		}
		myfree( var_imagedcam.chunkbuffers );
		var_imagedcam.chunkbuffers = NULL;
		var_imagedcam.nChunkBuffer = 0;
	}

	if( var_imagedcam.userframes != NULL )
	{
		myfree( var_imagedcam.userframes );
		var_imagedcam.userframes = NULL;
		var_imagedcam.nUserFrame = 0;
	}

	return TRUE;
}

void** imagedcam::getframes()
{
	return var_imagedcam.userframes;
}


void* imagedcam::getframe( long index, int32& rowbytes )
{
	if( index < 0 || var_imagedcam.nUserFrame <= index )
		return NULL;

	SIZE	szData;
	dcam_getdatasize( var_imagedcam.hdcam, &szData );

	long	bitperchannel = dcamex_getbitsperchannel( var_imagedcam.hdcam );
	long	colortype = dcamex_getcolortype( var_imagedcam.hdcam );

	rowbytes = szData.cx * ( colortype == colortype_bw ? 1 : 3 ) * int( ( bitperchannel + 7 ) / 8 );
	return var_imagedcam.userframes[ index ];
}

BOOL imagedcam::get_bitmapinfoheader( BITMAPINFOHEADER& bmih ) const
{
	if( var_imagedcam.hdcam == NULL )
		return FALSE;

	bmih.biWidth		= dcamex_getimagewidth( var_imagedcam.hdcam );
    bmih.biHeight		= dcamex_getimageheight( var_imagedcam.hdcam );
    bmih.biPlanes		= 1;
	bmih.biBitCount		= ( dcamex_getcolortype( var_imagedcam.hdcam ) == DCAMPROP_COLORTYPE__BW ? 8 : 24 );
    bmih.biCompression	= BI_RGB;
    bmih.biSizeImage	= 0;
    bmih.biXPelsPerMeter= 3780;	// 96dpi
    bmih.biYPelsPerMeter= 3780;	// 96dpi
    bmih.biClrUsed		= ( bmih.biBitCount == 8 ? 256 : 0 );
    bmih.biClrImportant	= bmih.biClrUsed;

	return TRUE;
}

long imagedcam::_copybits( BYTE* dsttopleft, long dstrowbytes, const void* srctopleft, long srcrowbytes, long srcox, long srcoy, long srcwidth, long srcheight, const BYTE* lut )
{
	long	bitperchannel = dcamex_getbitsperchannel( var_imagedcam.hdcam );
	long	colortype = dcamex_getcolortype( var_imagedcam.hdcam );

	if( colortype == DCAMPROP_COLORTYPE__RGB )
	{
		if( bitperchannel == 8 )
		{
			return copybits_rgb8( dsttopleft, dstrowbytes
					, (const BYTE*)srctopleft, srcrowbytes
					, srcox, srcoy, srcwidth, srcheight );
		}
		else
		if( lut != NULL )
		{
			return copybits_rgb16( dsttopleft, dstrowbytes, lut
					, (const WORD*)srctopleft, srcrowbytes
					, srcox, srcoy, srcwidth, srcheight );
		}
		else
		{
			ASSERT( 8 < bitperchannel && bitperchannel <= 16 );

			long	nShift = bitperchannel - 8;
			return copybits_rgb16( dsttopleft, dstrowbytes, nShift
					, (const WORD*)srctopleft, srcrowbytes
					, srcox, srcoy, srcwidth, srcheight );
		}
	}
	else
	if( colortype == DCAMPROP_COLORTYPE__BGR )
	{
		if( bitperchannel == 8 )
		{
			return copybits_bgr8( dsttopleft, dstrowbytes
					, (const BYTE*)srctopleft, srcrowbytes
					, srcox, srcoy, srcwidth, srcheight );
		}
		else
		if( lut != NULL )
		{
			return copybits_bgr16( dsttopleft, dstrowbytes, lut
					, (const WORD*)srctopleft, srcrowbytes
					, srcox, srcoy, srcwidth, srcheight );
		}
		else
		{
			ASSERT( 8 < bitperchannel && bitperchannel <= 16 );

			long	nShift = bitperchannel - 8;
			return copybits_bgr16( dsttopleft, dstrowbytes, nShift
					, (const WORD*)srctopleft, srcrowbytes
					, srcox, srcoy, srcwidth, srcheight );
		}
	}
	else
	{
		ASSERT( colortype == DCAMPROP_COLORTYPE__BW );

		if( bitperchannel == 8 )
		{
			return copybits_bw8( dsttopleft, dstrowbytes
					, (const BYTE*)srctopleft, srcrowbytes
					, srcox, srcoy, srcwidth, srcheight );
		}
		else
		if( lut != NULL )
		{
			return copybits_bw16( dsttopleft, dstrowbytes, lut
					, (const WORD*)srctopleft, srcrowbytes
					, srcox, srcoy, srcwidth, srcheight );
		}
		else
		{
			ASSERT( 8 < bitperchannel && bitperchannel <= 16 );

			long	nShift = bitperchannel - 8;
			return copybits_bw16( dsttopleft, dstrowbytes, nShift
					, (const WORD*)srctopleft, srcrowbytes
					, srcox, srcoy, srcwidth, srcheight );
		}
	}
}

long imagedcam::copybits( BYTE* dsttopleft, long dstrowbytes, long iFrame, long dstwidth, long dstheight, long hOffset, long vOffset, const BYTE* lut )
{
	long	ret = 0;

	if( var_imagedcam.hdcam != NULL )
	{
		int32	newestFrameIndex, totalFrameCount;

		if( dcam_gettransferinfo( var_imagedcam.hdcam, &newestFrameIndex, &totalFrameCount )
		 && totalFrameCount > 0 )
		{
			void*	buffer;
			int32	rowbytes;
#ifdef _EXCAP_SUPPORTS_FRAMEBUNDLE_
			double	value;
#endif // _EXCAP_SUPPORTS_FRAMEBUNDLE_ !
			SIZE	szData;
			dcam_getdatasize( var_imagedcam.hdcam, &szData );

			long	width = dstwidth;
			if( hOffset + width > szData.cx )
				width = szData.cx - hOffset;
			long	height= dstheight;
			if( vOffset + height > szData.cy )
				height = szData.cy - vOffset;

			if( var_imagedcam.userframes != NULL )
			{
				if( iFrame == -1 )
				{
					iFrame = newestFrameIndex;
				}
				else
				if( iFrame != -1 && var_imagedcam.nUserFrame < totalFrameCount )
				{
					iFrame = ( iFrame + totalFrameCount ) % var_imagedcam.nUserFrame;
				}

				// use user buffer.
				long	bitperchannel = dcamex_getbitsperchannel( var_imagedcam.hdcam );
				long	colortype = dcamex_getcolortype( var_imagedcam.hdcam );
	
				buffer = var_imagedcam.userframes[ iFrame ];
				rowbytes = szData.cx * ( colortype == colortype_bw ? 1 : 3 ) * int( ( bitperchannel + 7 ) / 8 );

				ret = _copybits( dsttopleft, dstrowbytes, buffer, rowbytes
							, hOffset, vOffset, width, height, lut );
			}
#ifdef _EXCAP_SUPPORTS_FRAMEBUNDLE_
			else
			if( dcam_getpropertyvalue( var_imagedcam.hdcam, DCAM_IDPROP_FRAMEBUNDLE_MODE, &value )
			 && value == DCAMPROP_MODE__ON )
			{
				VERIFY( dcam_getpropertyvalue( var_imagedcam.hdcam, DCAM_IDPROP_FRAMEBUNDLE_ROWBYTES, &value ) );
				int32	framebundle_rowbytes = (long)value;

				if( dcam_lockdata( var_imagedcam.hdcam, &buffer, &rowbytes, iFrame ) )
				{
					ret = _copybits( dsttopleft, dstrowbytes, buffer, framebundle_rowbytes
								, hOffset, vOffset, width, height, lut );

					dcam_unlockdata( var_imagedcam.hdcam );
				}
			}
#endif // _EXCAP_SUPPORTS_FRAMEBUNDLE_ !
			else
			if( dcam_lockdata( var_imagedcam.hdcam, &buffer, &rowbytes, iFrame ) )
			{
				ret = _copybits( dsttopleft, dstrowbytes, buffer, rowbytes
							, hOffset, vOffset, width, height, lut );

				dcam_unlockdata( var_imagedcam.hdcam );
			}
		}
	}

	return ret;
}

long imagedcam::width() const
{
	if( var_imagedcam.hdcam == NULL )
		return 0;
	else
		return dcamex_getimagewidth( var_imagedcam.hdcam );
}

long imagedcam::height() const
{
	if( var_imagedcam.hdcam == NULL )
		return 0;
	else
		return dcamex_getimageheight( var_imagedcam.hdcam );
}

long imagedcam::colortype() const
{
	switch( dcamex_getcolortype( var_imagedcam.hdcam ) )
	{
	default:	ASSERT( 0 );
	case DCAMPROP_COLORTYPE__BW:	return image::colortype_bw;

	case DCAMPROP_COLORTYPE__RGB:	return image::colortype_rgb;
	case DCAMPROP_COLORTYPE__BGR:	return image::colortype_bgr;
	}
}

long imagedcam::pixelperchannel() const
{
	return dcamex_getbitsperchannel( var_imagedcam.hdcam );
}

long imagedcam::numberof_frames() const
{
	return var_imagedcam.nUserFrame;
}

BOOL imagedcam::is_bitmap_updated()
{
	check_bmpupdated();
	return var_imagedcam.bmpupdated;
}

void imagedcam::clear_bitmap_updated()
{
	var_imagedcam.bmpupdated = FALSE;
}

// ----------------

void imagedcam::check_bmpupdated()
{
	if( var_imagedcam.hdcam != NULL )
	{
		int32	newestFrameIndex, totalFrameCount;

		if( dcam_gettransferinfo( var_imagedcam.hdcam, &newestFrameIndex, &totalFrameCount ) )
		{
			if( var_imagedcam.newestFrameIndex	!= newestFrameIndex
			 || var_imagedcam.totalFrameCount	!= totalFrameCount )
			{
				var_imagedcam.newestFrameIndex	= newestFrameIndex;
				var_imagedcam.totalFrameCount	= totalFrameCount;
				var_imagedcam.bmpupdated		= TRUE;
			}
		}
	}
}

/////////////////////////////////////////////////////////////////////////////

#include "imagedcam.h"

image* new_imagedcam( HDCAM hdcam )
{
	return new imagedcam( hdcam );
}
