// bitmap.h
//

inline long getrowbytes( const BITMAPINFOHEADER& bmih )
{
	long	rowbytes;

	switch( bmih.biBitCount )
	{
	default:	ASSERT( 0 );
	case 8:		rowbytes = bmih.biWidth;		break;
	case 24:	rowbytes = bmih.biWidth * 3;	break;
	}

	if( rowbytes % 4 )
		rowbytes += 4 - rowbytes % 4;

	return bmih.biHeight < 0 ? rowbytes : -rowbytes;
}

// ----

long copybits_bw8( BYTE* dsttopleft, long dstrowbytes
				  , const BYTE* srctopleft, long srcrowbytes
				  , long srcox, long srcoy, long srcwidth, long srcheight );

long copybits_bw16( BYTE* dsttopleft, long dstrowbytes, long nShift
				  , const WORD* srctopleft, long srcrowbytes
				  , long srcox, long srcoy, long srcwidth, long srcheight );

long copybits_bw16( BYTE* dsttopleft, long dstrowbytes, const BYTE* lut
				  , const WORD* srctopleft, long srcrowbytes
				  , long srcox, long srcoy, long srcwidth, long srcheight );

// ----

long copybits_bgr8( BYTE* dsttopleft, long dstrowbytes
				  , const BYTE* srctopleft, long srcrowbytes
				  , long srcox, long srcoy, long srcwidth, long srcheight );

long copybits_bgr16( BYTE* dsttopleft, long dstrowbytes, long nShift
				  , const WORD* srctopleft, long srcrowbytes
				  , long srcox, long srcoy, long srcwidth, long srcheight );

long copybits_bgr16( BYTE* dsttopleft, long dstrowbytes, const BYTE* lut
				  , const WORD* srctopleft, long srcrowbytes
				  , long srcox, long srcoy, long srcwidth, long srcheight );

// ----

long copybits_rgb8( BYTE* dsttopleft, long dstrowbytes
				  , const BYTE* srctopleft, long srcrowbytes
				  , long srcox, long srcoy, long srcwidth, long srcheight );

long copybits_rgb16( BYTE* dsttopleft, long dstrowbytes, long nShift
				  , const WORD* srctopleft, long srcrowbytes
				  , long srcox, long srcoy, long srcwidth, long srcheight );

long copybits_rgb16( BYTE* dsttopleft, long dstrowbytes, const BYTE* lut
				  , const WORD* srctopleft, long srcrowbytes
				  , long srcox, long srcoy, long srcwidth, long srcheight );
/*
long copybits( BYTE* dsttopleft, long dstrowbytes
		 , const void* srctopleft, long srcrowbytes
		 , long srcox, long srcoy, long srcwidth, long srcheight
		 , BOOL bRGB, long bitperchannel, long nShift, const BYTE* lut );
*/
