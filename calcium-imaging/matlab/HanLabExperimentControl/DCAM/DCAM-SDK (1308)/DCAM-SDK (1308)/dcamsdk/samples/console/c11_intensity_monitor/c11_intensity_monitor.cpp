// c15_whitebalance.cpp :
//
//
// Sample program to initialize DCAM-API and open camera handle.
// Copyright (c) 2009, Hamamatsu Photonics K.K.

#include "../console.h"
#include <stdio.h>

#include "hdcamsignal.h"
#include "qthread.h"

////////////////////////////////////////////////////////////////

// declaration of console helper functions
BOOL console_prompt( const char* prompt, char* buf, int32 bufsize );

// declaration of DCAM helper functions
void dcamcon_show_dcamerr( HDCAM hdcam, const char* apiname, const char* fmt = NULL, ...  );
HDCAM dcamcon_init_open();
void dcamcon_show_camera_information( HDCAM hdcam );
BOOL dcamcon_setreadoutspeed( HDCAM hdcam, int32 speed, BOOL bStrict=FALSE );

// declaration of DCAM sample routines
void dcamcon_run_intensity_monitor( HDCAM hdcam );

////////////////////////////////////////////////////////////////
//
//	main routine
//

int main(int argc, char* argv[])
{
	HDCAM	hdcam;

	// initialize DCAM-API and get HDCAM camera handle.
	hdcam = dcamcon_init_open();

	if( hdcam != NULL )
	{
		// show camera information by text.
		dcamcon_show_camera_information( hdcam );

		// prepare capturing
		if( ! dcamcon_setreadoutspeed( hdcam, dcamparam_scanmode_speed_fastest ) )
			dcamcon_show_dcamerr( hdcam, "dcamcon_setreadoutspeed( FASTEST )" );
		else
		if( ! dcam_setexposuretime( hdcam, 1 ) )
			dcamcon_show_dcamerr( hdcam, "dcam_setexposuretime( 1 )" );
		else
		if( ! dcam_precapture( hdcam, DCAM_CAPTUREMODE_SEQUENCE ) )
			dcamcon_show_dcamerr( hdcam, "dcam_precapture( DCAM_CAPTUREMODE_SEQUENCE )" );
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
					// run intensity monitor
					dcamcon_run_intensity_monitor( hdcam );

					// stop capturing
					dcam_idle( hdcam );
				}
				// release capturing buffer
				dcam_freeframe( hdcam );
			}
		}

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
//	console helper functions
//

BOOL console_prompt( const char* prompt, char* buf, int32 bufsize )
{
	fputs( prompt, stdout );
	if( fgets( buf, bufsize, stdin ) == NULL )
		return FALSE;

	return TRUE;
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
HDCAM dcamcon_init_open()
{
	char	buf[ 256 ];
	int32	nDevice;
	int32	iDevice;

	// initialize DCAM-API
	if( ! dcam_init( NULL, &nDevice, NULL ) )
	{
		dcamcon_show_dcamerr( NULL, "dcam_init()" );

		// failure
		return NULL;
	}

	ASSERT( nDevice > 0 );	// nDevice must be larger than 0

	// show all camera information by text
	for( iDevice = 0; iDevice < nDevice; iDevice++ )
	{
		printf( "%d: ", iDevice ); 

		dcam_getmodelinfo( iDevice, DCAM_IDSTR_VENDOR,		buf, sizeof( buf ) );
		printf( "%s", buf );

		dcam_getmodelinfo( iDevice, DCAM_IDSTR_MODEL,		buf, sizeof( buf ) );
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

// change readout speed
BOOL dcamcon_setreadoutspeed( HDCAM hdcam, int32 speed, BOOL bStrict )
{
	if( ! bStrict )
	{
		DCAM_PARAM_SCANMODE_INQ		inq;
		memset( &inq, 0, sizeof( inq ) );
		inq.hdr.cbSize	= sizeof( inq );
		inq.hdr.id		= DCAM_IDPARAM_SCANMODE_INQ;
		inq.hdr.iFlag	= dcamparam_scanmodeinq_speedmax;
		
		if( ! dcam_extended( hdcam, DCAM_IDMSG_GETPARAM, &inq, sizeof( inq ) )
		 || ! ( inq.hdr.oFlag & dcamparam_scanmodeinq_speedmax ) )
			return TRUE;
	}

	DCAM_PARAM_SCANMODE	param;
	memset( &param, 0, sizeof( param ) );
	param.hdr.cbSize	= sizeof( param );
	param.hdr.id		= DCAM_IDPARAM_SCANMODE;
	param.hdr.iFlag		= dcamparam_scanmode_speed;
	
	param.speed = speed;
	if( ! dcam_extended( hdcam, DCAM_IDMSG_SETPARAM, &param, sizeof( param ) )
	 || ! ( param.hdr.oFlag & dcamparam_scanmode_speed ) )
		return FALSE;
		
	return TRUE;
}

////////////////////////////////////////////////////////////////
//
//	DCAM sample routine
//

BOOL dcamcon_show_intensity( HDCAM hdcam )
{
	DCAM_SIZE	sz;
	char*	top;
	int32	rowbytes;
	int32	x, y;

	if( ! dcam_getdatasizeex( hdcam, &sz ) )
	{
		dcamcon_show_dcamerr( hdcam, "dcam_getdatasizeex()" );
		return FALSE;
	}

	if( ! dcam_lockdata( hdcam, (void**)&top, &rowbytes, -1 ) )
	{
		dcamcon_show_dcamerr( hdcam, "dcam_getdatasizeex()" );
		return FALSE;
	}

	unsigned short min, max;

	min = max = *(unsigned short*)top;
	for( y = sz.cy; y-- > 0; )
	{
		unsigned short*	p = (unsigned short*)(top + y * rowbytes );
		for( x = sz.cx; x-- > 0; )
		{
			if( min > *p )	min = *p;
			if( max < *p )	max = *p;
			p++;
		}
	}

	printf( "\n%d - %d:", min, max );
	
	BOOL	ret = ( 32 <= min && max < 4096 );

	if( ! ret )
	{
		// stop capturing
		dcam_idle( hdcam );

		for( y = 0; y < sz.cy; y++ )
		{
			unsigned short*	p = (unsigned short*)(top + y * rowbytes );
			for( x = 0; x < sz.cx; x++ )
			{
				if( *p < 32 || 4096 < *p )
					printf( "(%d, %d) = %d\n", x, y, *p );
				p++;
			}
		}
	}

	dcam_unlockdata( hdcam );
	return ret;
}

// wait loop for DCAM event. This calls from another thread.
void dcamcon_proc_intensity_monitor( HDCAM hdcam, HDCAMSIGNAL hAbort )
{
	int32	timeout = 100;	// 100 msec

	for( ;; )
	{
		char	c;
		_DWORD	dw = DCAM_EVENT_FRAMEEND;

		if( dcam_wait( hdcam, &dw, timeout, hAbort ) )
		{
			if( ! dcamcon_show_intensity( hdcam ) )
			{
				break;	// terminate;
			}
		}
		else
		{
			int32	err;
			err = dcam_getlasterror( hdcam );
			if( err == DCAMERR_ABORT )
			{
				break;
			}
			else
			if( err == DCAMERR_TIMEOUT )
			{
				// event did not happened
				c = '.';
			}
			else
			{
				// unexpected error happened.
				c = 'e';
			}
		}

		putchar( c );
	}

	printf( "\n" );
}

// declare mythread to wait DCAM event in back ground.
struct thread_intensity_monitor : public qthread
{
	HDCAM	hdcam;
	HDCAMSIGNAL	hAbort;
	HDCAMSIGNAL	hDead;

// override
	long main()
	{
		dcamcon_proc_intensity_monitor( hdcam, hAbort );
		set_hdcamsignal( hDead );

		return 0;
	}
};

// monitor intensity in another thread
void dcamcon_run_intensity_monitor( HDCAM hdcam )
{
	HDCAMSIGNAL	hAbort	= create_hdcamsignal();
	HDCAMSIGNAL	hDead	= create_hdcamsignal();

	printf( "Hit return key to abort capturing\n" );

	thread_intensity_monitor*	pThread;
	pThread = new thread_intensity_monitor;

	pThread->hdcam	= hdcam;
	pThread->hAbort	= hAbort;
	pThread->hDead	= hDead;

	if( ! pThread->start() )
	{
		delete pThread;
	}
	else
	{
		char	buf[ 512 ];
		console_prompt( "", buf, sizeof( buf ) );

		set_hdcamsignal( hAbort );
		wait_hdcamsignal( hDead, 10000 );
	}

	destroy_hdcamsignal( hAbort );
	destroy_hdcamsignal( hDead );
}

