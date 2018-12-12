// c06_dcamwaitabort.cpp : 
//
//
// Sample program to test dcam_wait() and abort handle.
// Copyright (c) 2007, Hamamatsu Photonics K.K.

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

// declaration of DCAM sample routines
void dcamcon_run_dcamwait( HDCAM hdcam, HDCAMSIGNAL hAbort, HDCAMSIGNAL hDead );

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
					HDCAMSIGNAL	hAbort	= create_hdcamsignal();
					HDCAMSIGNAL	hDead	= create_hdcamsignal();

					printf( "Hit return key to abort capturing\n" );

					// test dcam_wait()
					dcamcon_run_dcamwait( hdcam, hAbort, hDead );

					char	buf[ 512 ];
					console_prompt( "", buf, sizeof( buf ) );

					set_hdcamsignal( hAbort );
					wait_hdcamsignal( hDead, 10000 );

					destroy_hdcamsignal( hAbort );
					destroy_hdcamsignal( hDead );

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

////////////////////////////////////////////////////////////////
//
//	DCAM sample routine
//

// wait loof for DCAM event. This calls from another thread.
void dcamcon_test_dcamwait( HDCAM hdcam, HDCAMSIGNAL hAbort )
{
	int32	timeout = 100;	// 100 msec
	int32	nFRAMESTART = 0;
	int32	nFRAMEEND	= 0;
	int32	nCYCLEEND	= 0;
	int32	nVVALIDBEGIN= 0;
	int32	nUNKNOWNEVENT = 0;
	int32	nTIMEOUT	= 0;
	int32	nERROR		= 0;

	for( ;; )
	{
		char	c;
		_DWORD	dw = 0
					| DCAM_EVENT_FRAMESTART
					| DCAM_EVENT_FRAMEEND
					| DCAM_EVENT_CYCLEEND
					| DCAM_EVENT_VVALIDBEGIN
					;

		if( dcam_wait( hdcam, &dw, timeout, hAbort ) )
		{
			switch( dw )
			{
			case DCAM_EVENT_FRAMESTART:		c = 'S';	nFRAMESTART++;	break;
			case DCAM_EVENT_FRAMEEND:		c = 'F';	nFRAMEEND++;	break;
			case DCAM_EVENT_CYCLEEND:		c = 'C';	nCYCLEEND++;	break;
			case DCAM_EVENT_VVALIDBEGIN:	c = 'V';	nVVALIDBEGIN++;	break;
			default:						c = 'n';	nUNKNOWNEVENT++;break;	// never happen
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
				nTIMEOUT++;
			}
			else
			{
				// unexpected error happened.
				c = 'e';
				nERROR++;
			}
		}

		putchar( c );
	}

	printf( "\n" );
	printf( "FRAMESTART:"	"\t%d\n", nFRAMESTART	);
	printf( "FRAMEEND:"		"\t%d\n", nFRAMEEND		);
	printf( "CYCLEEND:"		"\t%d\n", nCYCLEEND		);
	printf( "VVALIDBEGIN:"	"\t%d\n", nVVALIDBEGIN	);
	if( nUNKNOWNEVENT != 0 )
	printf( "UNKNOWNEVENT:"	"\t%d\n", nUNKNOWNEVENT	);
	printf( "TIMEOUT:"		"\t%d\n", nTIMEOUT		);
	if( nERROR != 0 )
	printf( "ERROR:"		"\t%d\n", nERROR		);
}

// declare mythread to wait DCAM event in back ground.
struct mythread : public qthread
{
	HDCAM	hdcam;
	HDCAMSIGNAL	hAbort;
	HDCAMSIGNAL	hDead;

// override
	long main()
	{
		dcamcon_test_dcamwait( hdcam, hAbort );
		set_hdcamsignal( hDead );

		return 0;
	}
};

// test dcam_wait()
void dcamcon_run_dcamwait( HDCAM hdcam, HDCAMSIGNAL hAbort, HDCAMSIGNAL hDead )
{
	mythread*	pThread = new mythread;

	pThread->hdcam	= hdcam;
	pThread->hAbort	= hAbort;
	pThread->hDead	= hDead;

	if( ! pThread->start() )
		delete pThread;
}
