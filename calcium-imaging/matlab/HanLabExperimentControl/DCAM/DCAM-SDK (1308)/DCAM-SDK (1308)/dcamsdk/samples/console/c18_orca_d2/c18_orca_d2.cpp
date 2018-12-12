// c18_orca_d2.cpp : 
//
//
// Sample program to test ORCA-D2 new functions.
// Copyright (c) 2010, Hamamatsu Photonics K.K.

#include "../console.h"
#include <stdio.h>
#include <math.h>

#ifndef CR
#define	CR	"\x0d"
#endif

inline double my_random( DCAM_PROPERTYATTR& attr )
{
	ASSERT( attr.attribute & DCAMPROP_ATTR_HASRANGE );
	ASSERT( attr.attribute & DCAMPROP_ATTR_HASSTEP );

	double	fMax = ( attr.valuemin != attr.valuedefault ? attr.valuedefault : attr.valuemax );
	double	fMin = attr.valuemin;
	double	fStep= attr.valuestep;
	ASSERT( fStep > 0 );

	int32	nIndex = (int32)( rand() * floor( (fMax - fMin) / fStep ) / RAND_MAX );
	return nIndex * fStep + fMin;
}

////////////////////////////////////////////////////////////////

// declaration of DCAM helper functions
void dcamcon_show_dcamerr( HDCAM hdcam, const char* apiname, const char* fmt = NULL, ...  );
HDCAM dcamcon_init_open( const char* DCAMINITOPTION = NULL );
void dcamcon_show_camera_information( HDCAM hdcam );

// ORCA-D2 related samples
void dcamcon_show_opticalblock_information( HDCAM hdcam );
void dcamcon_sample_property_of_view( HDCAM hdcam );
void dcamcon_sample_backfocuspos( HDCAM hdcam );
void dcamcon_sample_backfocuscalib( HDCAM hdcam, int32 iBank = -1 );

////////////////////////////////////////////////////////////////
//
//	main routine
//

#define	DCAMINIT_MULTIVIEW_OFF	"|multiview=off"

int main(int argc, char* argv[])
{
	HDCAM	hdcam;

	// initialize DCAM-API and get HDCAM camera handle.
	hdcam = dcamcon_init_open( DCAMINIT_APIVER_0310 DCAMINIT_MULTIVIEW_OFF );

	if( hdcam != NULL )
	{
		// show camera information by text.
		dcamcon_show_camera_information( hdcam );

	// Begin --- ORCA-D2 related samples

		// show ORCA-D2 optical block information by text.
		dcamcon_show_opticalblock_information( hdcam );

		// sample routine for accessing properties
		dcamcon_sample_property_of_view( hdcam );

		// sample routine for controlling back focus position
		dcamcon_sample_backfocuspos( hdcam );

		// sample routine for back focus calibration.
		dcamcon_sample_backfocuscalib( hdcam );

	// End --- ORCA-D2 related samples

		// close HDCAM handle
		dcam_close( hdcam );

		// terminate DCAM-API
		dcam_uninit( NULL, NULL );
	}

	printf( "Hit return key to Exit>" );
	getchar();

	return 0;
}

////////////////////////////////////////////////////////////////
//
//	DCAM helper functions
//

// show DCAM error code
void dcamcon_show_dcamerr( HDCAM hdcam, const char* apiname, const char* fmt, ...  )
{
	char	buf[ 256 ];
	memset( buf, 0, sizeof( buf ) );

	// get error information
	int32	err = dcam_getlasterror( hdcam, buf, sizeof( buf ) );
	printf( "failure: %s returns 0x%08X\n", apiname, err );
	if( buf[ 0 ] )	printf( "%s\n", buf );

	if( fmt != NULL )
	{
		va_list	arg;
		va_start(arg,fmt);
		vprintf( fmt, arg );
		va_end(arg);
	}
}

// initialize DCAM-API and get HDCAM camera handle.
HDCAM dcamcon_init_open( const char* DCAMINITOPTION )
{
	char	buf[ 256 ];
	char	vendor[ 256 ];
	int32	nDevice;
	int32	iDevice;

	// initialize DCAM-API
	if( ! dcam_init( NULL, &nDevice, DCAMINITOPTION ) )
	{
		if( DCAMINITOPTION == NULL )
			dcamcon_show_dcamerr( NULL, "dcam_init()" );
		else
			dcamcon_show_dcamerr( NULL, "dcam_init()", "option is %s" CR, DCAMINITOPTION );

		// failure
		return NULL;
	}

	ASSERT( nDevice > 0 );	// nDevice must be larger than 0

	// show all camera information by text
	for( iDevice = 0; iDevice < nDevice; iDevice++ )
	{
		printf( "%d: ", iDevice ); 

		dcam_getmodelinfo( iDevice, DCAM_IDSTR_VENDOR, vendor, sizeof( vendor ) );

		dcam_getmodelinfo( iDevice, DCAM_IDSTR_MODEL,		buf, sizeof( buf ) );
		if( _strnicmp( vendor, buf, strlen( vendor ) ) != 0 )
			printf( "%s ", vendor);

		printf( "%s", buf );
		
		dcam_getmodelinfo( iDevice, DCAM_IDSTR_CAMERAID,	buf, sizeof( buf ) );
		printf( "(%s)", buf );
		
		dcam_getmodelinfo( iDevice, DCAM_IDSTR_BUS,			buf, sizeof( buf ) );
		printf( " on %s\n", buf );
	}

	if( nDevice > 1 )
	{
		// choose one camera from the list if there are two or more cameras.

		printf( "choose one of camera from above list by index (0-%d) >", nDevice-1 );

		iDevice = -1;
		while( fgets( buf, sizeof( buf ), stdin ) != NULL )
		{
			iDevice = atoi( buf );
			if( 0 <= iDevice && iDevice < nDevice )
				break;
		}
	}
	else
	{
		iDevice = 0;
	}

	if( 0 <= iDevice && iDevice < nDevice )
	{
		// open specified camera

		HDCAM	hdcam;
		if( dcam_open( &hdcam, iDevice, NULL ) )
		{
			// success
			return hdcam;
		}

		dcamcon_show_dcamerr( NULL, "dcam_open()", "index is %d\n", iDevice );
	}

	// uninitialize DCAM-API
	dcam_uninit( NULL, NULL );

	// failure
	return NULL;
}

// show HDCAM camera information by text.
void dcamcon_show_camera_information( HDCAM hdcam )
{
	char	buf[ 256 ];

	dcam_getstring( hdcam, DCAM_IDSTR_VENDOR,			buf, sizeof( buf ) );
	printf( "DCAM_IDSTR_VENDOR         = %s\n", buf );

	dcam_getstring( hdcam, DCAM_IDSTR_MODEL,			buf, sizeof( buf ) );
	printf( "DCAM_IDSTR_MODEL          = %s\n", buf );
	
	dcam_getstring( hdcam, DCAM_IDSTR_CAMERAID,			buf, sizeof( buf ) );
	printf( "DCAM_IDSTR_CAMERAID       = %s\n", buf );
	
	dcam_getstring( hdcam, DCAM_IDSTR_BUS,				buf, sizeof( buf ) );
	printf( "DCAM_IDSTR_BUS            = %s\n", buf );
	
	dcam_getstring( hdcam, DCAM_IDSTR_CAMERAVERSION,	buf, sizeof( buf ) );
	printf( "DCAM_IDSTR_CAMERAVERSION  = %s\n", buf );
	
	dcam_getstring( hdcam, DCAM_IDSTR_DRIVERVERSION,	buf, sizeof( buf ) );
	printf( "DCAM_IDSTR_DRIVERVERSION  = %s\n", buf );
	
	dcam_getstring( hdcam, DCAM_IDSTR_MODULEVERSION,	buf, sizeof( buf ) );
	printf( "DCAM_IDSTR_MODULEVERSION  = %s\n", buf );
	
	dcam_getstring( hdcam, DCAM_IDSTR_DCAMAPIVERSION,	buf, sizeof( buf ) );
	printf( "DCAM_IDSTR_DCAMAPIVERSION = %s\n", buf );
}


// show OPTICAL BLOCK information by text.
void dcamcon_show_opticalblock_information( HDCAM hdcam )
{
	char	buf[ 256 ];

	if( dcam_getstring( hdcam, DCAM_IDSTR_OPTICALBLOCK_MODEL,		buf, sizeof( buf ) ) )
		printf( "DCAM_IDSTR_OPTICALBLOCK_MODEL      = %s\n", buf );
	
	if( dcam_getstring( hdcam, DCAM_IDSTR_OPTICALBLOCK_ID,			buf, sizeof( buf ) ) )
		printf( "DCAM_IDSTR_OPTICALBLOCK_ID	        = %s\n", buf );
	
	if( dcam_getstring( hdcam, DCAM_IDSTR_OPTICALBLOCK_DESCRIPTION,	buf, sizeof( buf ) ) )
		printf( "DCAM_IDSTR_OPTICALBLOCK_DESCRIPTION= %s\n", buf );
	
	if( dcam_getstring( hdcam, DCAM_IDSTR_OPTICALBLOCK_CHANNEL_1,	buf, sizeof( buf ) ) )
		printf( "DCAM_IDSTR_OPTICALBLOCK_CHANNEL_1  = %s\n", buf );
	
	if( dcam_getstring( hdcam, DCAM_IDSTR_OPTICALBLOCK_CHANNEL_2,	buf, sizeof( buf ) ) )
		printf( "DCAM_IDSTR_OPTICALBLOCK_CHANNEL_2  = %s\n", buf );
}

////////////////////////////////////////////////////////////////
//
//	Sample code to access each view property
//

BOOL dcamcon_get_second_view_info( HDCAM hdcam, int32& ofs, int32& rowbytes, int32& width, int32& height );
BOOL dcamcon_sample_fire_and_lock( HDCAM hdcam, void*& p, int32& rowbytes );
void _get_histgoram_text( char* buf, int32 bufsize, WORD* p, int32 rowbytes, int32 width, int32 height, int32 maxIntensity );

void dcamcon_show_intensity_with_chaginge_property_values( HDCAM hdcam, int32 idProp )
{
	// get information of camera image;
	DCAM_SIZE	sz;
	dcam_getdatasizeex( hdcam, &sz );			// never fail

	int32	nMax, nMin;
	dcam_getdatarange( hdcam, &nMax, &nMin );	// never fail

	// this sample supports only DATATYPE_BW16
	if( nMax < 256 )
		return;

	// get image offset for second view
	DCAM_SIZE	sz2;
	int32		topofs2 = 0;
	int32		rowbytes2 = 0;

	if( ! dcamcon_get_second_view_info( hdcam, topofs2, rowbytes2, sz2.cx, sz2.cy ) )
	{
		// this happens when at least one of view information is wrong.
		// if the camera only has singleve view, above function returns TRUE

		return;
	}

	// get property name from property id
	char	propname[ 64 ];
	if( ! dcam_getpropertyname( hdcam, idProp, propname, sizeof( propname ) ) )
		sprintf_s( _secure_buf(propname), "Unknown (0x%08X)", idProp );

	printf( "\nProperty: %s\n", propname );

	DCAM_PROPERTYATTR	attr;
	memset( &attr, 0, sizeof( attr ) );
	attr.cbSize	= sizeof( attr );
	attr.iProp	= idProp;

	if( ! dcam_getpropertyattr( hdcam, &attr ) )
	{
		// this camera does not support property 'idProp'.
		dcamcon_show_dcamerr( hdcam, "dcam_getpropertyattr()" );
		return;
	}
	printf( "range: %g - %g, default: %g\n", attr.valuemin, attr.valuemax, attr.valuedefault );

	double	value = attr.valuedefault;
	int32	teststep;
	int32	iView = 0;
	for( teststep = 1; teststep > 0; teststep++ )
	{
		fprintf( stdout, "Set Property: VIEW=%d, IDPROP=%s, value=%g\n", iView, propname, value );
		if( ! dcam_setpropertyvalue( hdcam, idProp | DCAM_IDPROP__VIEW * iView, value ) )
		{
			dcamcon_show_dcamerr( hdcam, "dcam_setpropertyvalue()", "VIEW=%d, IDPROP=%s, value=%g", iView, propname, value );
			return;
		}

		// show current intensity.
		int32	i;
		for( i = 10; i-- > 0; )	// do three times
		{
			void*	p;
			int32	rowbytes;

			if( ! dcamcon_sample_fire_and_lock( hdcam, p, rowbytes ) )
				return;	

			char	buf[ 81 ];
			int32	len = sprintf_s( _secure_buf(buf), "  %d", i );
			memset( buf+len, ' ', 80-len );

			if( topofs2 > 0 )
				_get_histgoram_text( buf+44, 32, (WORD*)((char*)p + topofs2), rowbytes2, sz2.cx, sz2.cy, nMax+1 );

			_get_histgoram_text( buf+8, 32, (WORD*)p, rowbytes, sz.cx, sz.cy, nMax+1 );
			buf[ 76 ] = 0x0d;
			buf[ 77 ] = 0;

			fputs( buf, stdout );
			fflush( stdout );
		}
		fputs( "\n", stdout );

		// check property attribute of second view access
		if( attr.attribute & DCAMPROP_ATTR_HASVIEW )
		{
			// this property can control property individually

			if( teststep <= 3 )
			{
				value = my_random( attr );

				if( teststep == 3 )
					iView = 0;
				else
					iView = teststep;
			}
			else
				teststep = -1;	// finish
		}
		else
		{
			// this property cannot control property individually

			if( teststep < 2 )
			{
				value = my_random( attr );
			}
			else
				teststep = -1;	// finish
		}
	}

	printf( "Set Property: VIEW=%d, IDPROP=%s, value=%g(default)\n", iView, propname, attr.valuedefault );
	if( ! dcam_setpropertyvalue( hdcam, idProp, attr.valuedefault ) )
		dcamcon_show_dcamerr( hdcam, "dcam_setpropertyvalue()", "IDPROP=%s, value=%g(default) at end", propname, attr.valuedefault );
}

BOOL dcamcon_sample_fire_and_lock( HDCAM hdcam, void*& p, int32& rowbytes )
{
	if( ! dcam_firetrigger( hdcam ) )
	{
		// this should not happen
		dcamcon_show_dcamerr( hdcam, "dcam_firetrigger()" );
		return FALSE;
	}

	int32	total_timeout = 3000;
	for( ;; )
	{
		int32	timeout = 500;
		DWORD	events = DCAM_EVENT_FRAMEEND;

		if( dcam_wait( hdcam, &events, timeout, NULL ) )
			break;

		DCAMERR	err = (DCAMERR)dcam_getlasterror( hdcam );
		if( err == DCAMERR_TIMEOUT )
		{
			total_timeout -= timeout;
			if( total_timeout > 0 )
				continue;	
		}
		dcamcon_show_dcamerr( hdcam, "dcam_wait()" );
		return FALSE;		// give up.
	}

	// lock latest frame.
	if( ! dcam_lockdata( hdcam, &p, &rowbytes, -1 ) )
	{
		dcamcon_show_dcamerr( hdcam, "dcam_lockdata()" );
		return FALSE;
	}

	return TRUE;
}

BOOL dcamcon_getpropertyvalue_view2( HDCAM hdcam, int32 idProp, int32& value )
{
	DCAM_PROPERTYATTR	attr;
	memset( &attr, 0, sizeof( attr ) );
	attr.cbSize	= sizeof( attr );
	attr.iProp	= idProp;

	if( ! dcam_getpropertyattr( hdcam, &attr ) )
		return FALSE;

	double	v;
	if( attr.attribute & DCAMPROP_ATTR_HASVIEW )
		idProp |= DCAM_IDPROP__VIEW * 2;

	if( ! dcam_getpropertyvalue( hdcam, idProp, &v ) )
		return FALSE;

	value = (int32)v;
	return TRUE;
}

BOOL dcamcon_get_second_view_info( HDCAM hdcam, int32& ofs, int32& rowbytes, int32& width, int32& height )
{
	double	v;
	if( ! dcam_getpropertyvalue( hdcam, DCAM_IDPROP_IMAGE_FRAMEBYTES | ( DCAM_IDPROP__VIEW * 2 ), &v ) )
	{
		// this HDCAM does not have second view.
		ofs = rowbytes = width = height = 0;
		return TRUE;
	}

	// this HDCAM has second view.
	ofs = (int32)v;

	if( ! dcamcon_getpropertyvalue_view2( hdcam, DCAM_IDPROP_IMAGE_WIDTH, width ) )
	{
		dcamcon_show_dcamerr( hdcam, "dcam_getpropertyvalue( IMAGE_WIDTH ) for second view" );
		return FALSE;
	}

	if( ! dcamcon_getpropertyvalue_view2( hdcam, DCAM_IDPROP_IMAGE_HEIGHT, height ) )
	{
		// this should not happen.
		dcamcon_show_dcamerr( hdcam, "dcam_getpropertyvalue( IMAGE_HEIGHT ) for second view" );
		return FALSE;
	}

	if( ! dcamcon_getpropertyvalue_view2( hdcam, DCAM_IDPROP_IMAGE_ROWBYTES, rowbytes ) )
	{
		// this should not happen.
		dcamcon_show_dcamerr( hdcam, "dcam_getpropertyvalue( IMAGE_ROWBYTES ) for second view" );
		return FALSE;
	}

	return TRUE;
}

// show check intensity of coming image.
void dcamcon_sample_property_of_view( HDCAM hdcam )
{
	if( ! dcam_settriggermode( hdcam, DCAM_TRIGMODE_SOFTWARE ) )
		dcamcon_show_dcamerr( hdcam, "dcam_settriggermode( SOFTWARE )" );
	else
	if( ! dcam_precapture( hdcam, DCAM_CAPTUREMODE_SEQUENCE ) )
		dcamcon_show_dcamerr( hdcam, "dcam_precapture()" );
	else
	{
		// allocate capturing buffer
		if( ! dcam_allocframe( hdcam, 3 ) )
			dcamcon_show_dcamerr( hdcam, "dcam_allocframe( 3 )" );
		else
		{
			// start capturing
			if( ! dcam_capture( hdcam ) )
				dcamcon_show_dcamerr( hdcam, "dcam_capture()" );
			else
			{
				dcamcon_show_intensity_with_chaginge_property_values( hdcam, DCAM_IDPROP_EXPOSURETIME );
				dcamcon_show_intensity_with_chaginge_property_values( hdcam, DCAM_IDPROP_CONTRASTGAIN );

				// stop capturing
				dcam_idle( hdcam );
			}
			// release capturing buffer
			dcam_freeframe( hdcam );
		}
	}

	dcam_settriggermode( hdcam, DCAM_TRIGMODE_INTERNAL );
}

void calc_histogram( int32* histogram, int32 histsize, const WORD* src, int32 rowbytes, int32 width, int32 height, int32 maxIntensity )
{
	while( height-- > 0 )
	{
		const WORD*	s = src;
		int32	x = width;
		while( x-- > 0 )
		{
			histogram[ *s++ * histsize / maxIntensity ]++;
		}
		src = (const WORD*)( (const char*)src + rowbytes );
	}
}

void _histogram_to_text( const int32* histogram, int32 histsize, char* dst )	// dst must have enough space
{
	int32	histmax = *histogram;
	int32	i;

	for( i = 1; i < histsize; i++ )
	{
		if( histmax < histogram[ i ] )
			histmax = histogram[ i ];
	}

	if( histmax == 0 )
		memset( dst, '_', histsize );
	else
	{
		for( i = 0; i < histsize; i++ )
		{
			switch( histogram[ i ] * 4 / histmax )
			{
			default:
			case 3:
			case 2:	dst[ i ] = '*';	break;
			case 1:	dst[ i ] = '-';	break;
			case 0:	dst[ i ] = '_';	break;
			}
		}
	}
}


// show intensity
void _get_histgoram_text( char* buf, int32 bufsize, WORD* p, int32 rowbytes, int32 width, int32 height, int32 maxIntensity )
{
	const int	histogram_size = 32;

	ASSERT( bufsize <= histogram_size );

	int32	histogram[ histogram_size ];
	memset( histogram, 0, sizeof( histogram ) );
	calc_histogram( histogram, histogram_size, (WORD*)p, rowbytes, width, height, maxIntensity );

	_histogram_to_text( histogram, histogram_size, buf );
}

// ----------------
// opeartion of backfocus.

void dcamcon_sample_backfocuspos( HDCAM hdcam )
{
const int32	idPropTarget = DCAM_IDPROP_BACKFOCUSPOS_TARGET;
const int32	idPropCurrent= DCAM_IDPROP_BACKFOCUSPOS_CURRENT;

	// get property name from property id
	char	propname[ 64 ];
	if( ! dcam_getpropertyname( hdcam, idPropTarget, propname, sizeof( propname ) ) )
		sprintf_s( _secure_buf(propname), "Unknown (0x%08X)", idPropTarget );

	DCAM_PROPERTYATTR	attr;
	memset( &attr, 0, sizeof( attr ) );
	attr.cbSize	= sizeof( attr );
	attr.iProp	= idPropTarget;

	if( ! dcam_getpropertyattr( hdcam, &attr ) )
	{
		// this camera does not support BACKFOCUSPOS_TARGET.
		printf( "\nThis camera does not support DCAM_IDPROP_BACKFOCUSPOS_TARGET\n" );
		return;
	}
	
	printf( "\nProperty: %s\n", propname );
	printf( "range: %g - %g, default: %g\n", attr.valuemin, attr.valuemax, attr.valuedefault );

	// get image offset for second view
	DCAM_SIZE	sz2;
	int32		topofs2 = 0;
	int32		rowbytes2 = 0;

	if( ! dcamcon_get_second_view_info( hdcam, topofs2, rowbytes2, sz2.cx, sz2.cy ) )
	{
		// this happens when at least one of view information is wrong.
		// if the camera only has singleve view, above function returns TRUE

		return;
	}

	int32	nMax, nMin;
	dcam_getdatarange( hdcam, &nMax, &nMin );	// never fail

	// this sample supports only DATATYPE_BW16
	if( nMax < 256 )
		return;

	if( ! dcam_settriggermode( hdcam, DCAM_TRIGMODE_SOFTWARE ) )
		dcamcon_show_dcamerr( hdcam, "dcam_settriggermode( SOFTWARE )" );
	else
	if( ! dcam_precapture( hdcam, DCAM_CAPTUREMODE_SEQUENCE ) )
		dcamcon_show_dcamerr( hdcam, "dcam_precapture()" );
	else
	{
		// allocate capturing buffer
		if( ! dcam_allocframe( hdcam, 3 ) )
			dcamcon_show_dcamerr( hdcam, "dcam_allocframe( 3 )" );
		else
		{
			// start capturing
			if( ! dcam_capture( hdcam ) )
				dcamcon_show_dcamerr( hdcam, "dcam_capture()" );
			else
			{
				double	vTarget = attr.valuedefault;
				int32	teststep;
				for( teststep = 1;; teststep++ )
				{
					double	vLast;
					if( ! dcam_getpropertyvalue( hdcam, idPropCurrent, &vLast ) )
					{
						dcamcon_show_dcamerr( hdcam, "dcam_getpropertyvalue( BACKFOCUSPOS_CURRENT )" );
						teststep = -1;
						break;
					}
					fprintf( stdout, "Get Property: BACKFOCUSPOS_CURRENT, Value=%g\n", vLast );

					fprintf( stdout, "Set Property: %s, Value=%g\n", propname, vTarget );
					if( ! dcam_setpropertyvalue( hdcam, idPropTarget, vTarget ) )
					{
						dcamcon_show_dcamerr( hdcam, "dcam_setpropertyvalue()", "IDPROP=%s, value=%g", propname, vTarget );
						teststep = -1;
						break;
					}

					double	vCurrent;
					int32	testtime = 10;

					// show current intensity and check current value
					do
					{
						void*	p;
						int32	rowbytes;

						if( ! dcamcon_sample_fire_and_lock( hdcam, p, rowbytes ) )
							return;	

						// second view is updated.
						char	buf[ 81 ];
						memset( buf, ' ', 80 );

						_get_histgoram_text( buf+44, 32, (WORD*)((char*)p + topofs2), rowbytes2, sz2.cx, sz2.cy, nMax+1 );
						buf[ 76 ] = 0x0d;
						buf[ 77 ] = 0x0;

						fputs( buf, stdout );
						fflush( stdout );

						if( ! dcam_getpropertyvalue( hdcam, idPropCurrent, &vCurrent) )
						{
							dcamcon_show_dcamerr( hdcam, "dcam_getpropertyvalue( BACKFOCUSPOS_CURRENT )" );
							teststep = -1;
							break;
						}

						if( vCurrent == vLast && testtime-- <= 0 )
						{
							fprintf( stdout, "BACKFOCUSPOS_CURRENT does not move. There is something wrong.\n" );
							break;
						}
					} while( vCurrent != vTarget );
					fputs( "\n", stdout );

					if( teststep == 1 )
					{
						vTarget = attr.valuemin;	// goto minimum
					}
					else
					if( teststep == 2 )
					{
						vTarget = attr.valuemax;	// goto maximum
					}
					else
					if( teststep == 3 )
					{
						vTarget = attr.valuedefault;	// back to default
					}
					else
						break;	// finish
				}

				// stop capturing
				dcam_idle( hdcam );
			}
			// release capturing buffer
			dcam_freeframe( hdcam );
		}
	}
	dcam_settriggermode( hdcam, DCAM_TRIGMODE_INTERNAL );
}

// do back focus calibration.
void dcamcon_sample_backfocuscalib( HDCAM hdcam, int32 iBank )
{
	if( iBank >= 0 )
	{
		printf( "Set Property: BACKFOCUSPOS_LOADFROMMEMORY=%d\n", iBank );
		if( ! dcam_setpropertyvalue( hdcam, DCAM_IDPROP_BACKFOCUSPOS_LOADFROMMEMORY, iBank ) )
		{
			iBank = -1;
			dcamcon_show_dcamerr( hdcam, "dcam_setpropertyvalue( BACKFOCUSPOS_LOADFROMMEMORY )", "Value=%d", iBank );
		}
	}

	printf( "Set Property: CAPTUREMODE__BACKFOCUSCALIB\n" );
	if( ! dcam_setpropertyvalue( hdcam, DCAM_IDPROP_CAPTUREMODE, DCAMPROP_CAPTUREMODE__BACKFOCUSCALIB ) )
		dcamcon_show_dcamerr( hdcam, "dcam_setpropertyvalue( DCAM_IDPROP_CAPTUREMODE, DCAMPROP_CAPTUREMODE__BACKFOCUSCALIB )" );
	else
	if( ! dcam_precapture( hdcam, DCAM_CAPTUREMODE_SEQUENCE ) )
		dcamcon_show_dcamerr( hdcam, "dcam_precapture()" );
	else
	{
		// allocate capturing buffer
		if( ! dcam_allocframe( hdcam, 1 ) )
			dcamcon_show_dcamerr( hdcam, "dcam_allocframe( 1 )" );
		else
		{
			// start capturing
			if( ! dcam_capture( hdcam ) )
				dcamcon_show_dcamerr( hdcam, "dcam_capture()" );
			else
			{
				int32	total_timeout = 30000;
				for( ;; )
				{
					int32	timeout = 500;
					DWORD	events = DCAM_EVENT_CAPTUREEND;

					if( dcam_wait( hdcam, &events, timeout, NULL ) )
					{
						printf( "Complete!\n" );
						break;
					}

					DCAMERR	err = (DCAMERR)dcam_getlasterror( hdcam );
					if( err == DCAMERR_TIMEOUT )
					{
						putchar( '.' );
						fflush( stdout );
						total_timeout -= timeout;
						if( total_timeout > 0 )
							continue;	
					}
					dcamcon_show_dcamerr( hdcam, "dcam_wait()" );
					iBank = -1;	// not write stage position into memory.
					break;		// give up.
				}

				if( iBank >= 0 )
				{
					printf( "Set Property: BACKFOCUSPOS_STORETOMEMORY=%d\n", iBank );
					if( ! dcam_setpropertyvalue( hdcam, DCAM_IDPROP_BACKFOCUSPOS_STORETOMEMORY, iBank ) )
						dcamcon_show_dcamerr( hdcam, "dcam_setpropertyvalue( BACKFOCUSPOS_STORETOMEMORY )", "Value=%d", iBank );
				}

				// stop capturing
				dcam_idle( hdcam );
			}
			// release capturing buffer
			dcam_freeframe( hdcam );
		}
	}
}
