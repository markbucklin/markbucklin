// c28_fire_wait_lock.cpp : 
//
//
// Sample program to show how DCAM STATUS is changed.
// Copyright (c) 2011, Hamamatsu Photonics K.K.

#include "../console.h"
#include <stdio.h>

////////////////////////////////////////////////////////////////

// declaration of DCAM helper functions
void dcamcon_show_dcamerr( HDCAM hdcam, const char* apiname, const char* fmt = NULL, ...  );
HDCAM dcamcon_init_open();
void dcamcon_show_camera_information( HDCAM hdcam );
void dcamcon_show_dcamstatus( HDCAM hdcam );

// sample routine
void dcamcon_sample_fire_wait_lock( HDCAM hdcam );

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
		dcamcon_show_dcamstatus( hdcam );

		// show camera information by text.
		dcamcon_show_camera_information( hdcam );
		
		// ----------------
		// call sample routine of capturing and copying
		
		dcamcon_sample_fire_wait_lock( hdcam );

		// ----------------
		// closing operation
		
		// close HDCAM handle
		printf( "dcam_close()\n" );
		dcam_close( hdcam );
		
		// terminate DCAM-API
		printf( "dcam_uninit()\n" );
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
HDCAM dcamcon_init_open()
{
	char	buf[ 256 ];
	int32	nDevice;
	int32	iDevice;
	
	// initialize DCAM-API
	if( ! dcam_init( NULL, &nDevice, DCAMINIT_DEFAULT ) )
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
		printf( "on %s\n", buf );
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

void dcamcon_show_dcamstatus( HDCAM hdcam )
{
	_DWORD	stat;
	if( ! dcam_getstatus( hdcam, &stat ) )
		dcamcon_show_dcamerr( hdcam, "dcam_getstatus()" );
	else
	{
		const char*	fmt;
		switch( stat )
		{
			case DCAM_STATUS_BUSY:		fmt = "status is BUSY\n";			break;
			case DCAM_STATUS_READY:		fmt = "status is READY\n";			break;
			case DCAM_STATUS_STABLE:	fmt = "status is STABLE\n";			break;
			case DCAM_STATUS_UNSTABLE:	fmt = "status is UNSTABLE\n";		break;
			default:					fmt = "Ustatus is NKNOWN(%d)\n";	break;
		}
		
		printf( fmt, stat );
	}
}

void do_fire_wait_lock( HDCAM hdcam )
{
	// fire trigger.
	printf( "dcam_firetrigger()\n" );
	if( ! dcam_firetrigger( hdcam ) )
	{
		dcamcon_show_dcamerr( hdcam, "dcam_firetrigger()" );
		return;
	}
	

	// wait frame coming.
	int32	timeout	= 10000;
	_DWORD	dw		= DCAM_EVENT_FRAMEEND;
	printf( "dcam_wait( FRAMEEND, 10s )\n" );
	if( ! dcam_wait( hdcam, &dw, timeout, NULL ) )
	{
		dcamcon_show_dcamerr( hdcam, "dcam_wait()" );
		return;
	}

	unsigned char*	pTop;
	int32	rowbytes;
	printf( "dcam_lockdata( -1 )\n" );
	if( ! dcam_lockdata( hdcam, (void**)&pTop, &rowbytes, -1 ) )
	{
		dcamcon_show_dcamerr( hdcam, "dcam_lockdata()" );
		return;
	}

	// dump data.
	int32	i, len = min( 16, rowbytes );
	for( i = 0; i < len; i++ )
	{
		printf( " %02X", pTop[i] );
	}

	printf( "\n" );
	printf( "dcam_unlockdata()\n" );
	if( ! dcam_unlockdata( hdcam ) )
	{
		dcamcon_show_dcamerr( hdcam, "dcam_unlockdata()" );
	}
}

void dcamcon_sample_fire_wait_lock( HDCAM hdcam )
{
	dcamcon_show_dcamstatus( hdcam );

	// test SOFTWARE trigger mode
	if( ! dcam_settriggermode( hdcam, DCAM_TRIGMODE_SOFTWARE ) )
	{
		dcamcon_show_dcamerr( hdcam, "dcam_settriggermode( SOFTWARE )" );
		return;
	}

	// test SEQUENCE mode
	printf( "dcam_precapture( SEQUENCE )\n" );
	if( ! dcam_precapture( hdcam, DCAM_CAPTUREMODE_SEQUENCE ) )
	{
		dcamcon_show_dcamerr( hdcam, "dcam_precapture( SEQUENCE )" );
	}
	else
	{
		dcamcon_show_dcamstatus( hdcam );

		// allocate frame buffers in DCAM-API
		int32	nAllocFrame = 3;	// the number of internal frame buffers
		printf( "dcam_allocframe( %d )\n", nAllocFrame );
		if( ! dcam_allocframe( hdcam, nAllocFrame ) )
		{
			dcamcon_show_dcamerr( hdcam, "dcam_allocframe()" );
		}
		else
		{
			dcamcon_show_dcamstatus( hdcam );

			// start capturing
			printf( "dcam_capture()\n" );
			if( ! dcam_capture( hdcam ) )
			{
				dcamcon_show_dcamerr( hdcam, "dcam_capture()" );
			}
			else
			{
				dcamcon_show_dcamstatus( hdcam );

				// get try count
				printf( "Enter number of try (Default=1, QUIT for exit) >" );

				char	buf[ 256 ];
				while( fgets( buf, sizeof( buf ), stdin ) != NULL )
				{
					if( _strnicmp( buf, "QUIT", 4 ) == 0
					 || _strnicmp( buf, "EXIT", 4 ) == 0 )
						break;

					int32	n  = atoi( buf );
					if( n == 0 )
						n = 1;

					while( n-- > 0 )
						do_fire_wait_lock( hdcam );

					dcamcon_show_dcamstatus( hdcam );
				}

				// stop capturing
				printf( "dcam_idle()\n" );
				dcam_idle( hdcam );

				dcamcon_show_dcamstatus( hdcam );
			}

			// free DCAM internal buffer
			printf( "dcam_freeframe()\n" );
			dcam_freeframe( hdcam );
			dcamcon_show_dcamstatus( hdcam );
		}
	}
}
