// c09_emgainprotect.cpp :
//
//
// Sample program to control EM-GAIN PROTECT.
// Copyright (c) 2007, Hamamatsu Photonics K.K.

#include "../console.h"
#include <stdio.h>

////////////////////////////////////////////////////////////////

// declaration of DCAM helper functions
void dcamcon_show_dcamerr( HDCAM hdcam, const char* apiname, const char* fmt = NULL, ...  );
HDCAM dcamcon_init_open();
void dcamcon_show_camera_information( HDCAM hdcam );

// declaration of DCAM sample routines
BOOL dcamcon_enable_emgain_protect( HDCAM hdcam );
void dcamcon_check_emgain_status( HDCAM hdcam, int nTimes );

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

		// enable EM GAIN PROTECT if possible.
		if( ! dcamcon_enable_emgain_protect( hdcam ) )
		{
			printf( "This camera does not support EM GAIN PROTECT.\n" );
		}
		else
		{
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
						// test dcam_wait()
						dcamcon_check_emgain_status( hdcam, 100 );

						// stop capturing
						dcam_idle( hdcam );
					}
					// release capturing buffer
					dcam_freeframe( hdcam );
				}
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

BOOL dcamcon_enable_emgain_protect( HDCAM hdcam )
{
	double	value;
	if( ! dcam_getpropertyvalue( hdcam, DCAM_IDPROP_EMGAINWARNING_STATUS, &value ) )
	{
		dcamcon_show_dcamerr( hdcam, "dcam_getpropertyvalue( DCAM_IDPROP_EMGAINWARNING_STATUS )" );
		return FALSE;
	}

	if( ! dcam_setpropertyvalue( hdcam, DCAM_IDPROP_EMGAINWARNING_ALARM, DCAMPROP_MODE__ON ) )
		dcamcon_show_dcamerr( hdcam, "dcam_setpropertyvalue( DCAM_IDPROP_EMGAINWARNING_ALARAM )", "does not support DCAMPROP_MODE__ON\n" );

	if( ! dcam_setpropertyvalue( hdcam, DCAM_IDPROP_EMGAINPROTECT_MODE, DCAMPROP_MODE__ON ) )
		dcamcon_show_dcamerr( hdcam, "dcam_setpropertyvalue( DCAM_IDPROP_EMGAINPROTECT_MODE )", "does not support DCAMPROP_MODE__ON\n" );

//	you can use default DCAM_IDPROP_EMGAINWARNING_LEVEL as strongest protection.
//	you can use default DCAM_IDPROP_EMGAINPROTECT_FRAMESAFTER as strongest protection.

	return TRUE;
}

void dcamcon_check_emgain_status( HDCAM hdcam, int nTimes )
{
	int	i;
	int32	timeout = 100;	// 100 msec

	for( i = 0; i < nTimes; i++ )
	{
		char	c;
		_DWORD	dw = DCAM_EVENT_FRAMEEND;

		if( dcam_wait( hdcam, &dw, timeout, NULL ) )
		{
			switch( dw )
			{
			case DCAM_EVENT_FRAMEEND:		c = 'F';	break;
			default:						c = 'n';	break;	// never happen
			}
		}
		else
		{
			int32	err;
			err = dcam_getlasterror( hdcam );
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

		// The following if statement can select the method to check EMGAIN WARNING STATUS or PROTECTED.

		if( 1 )
		{
			// check EMGAIN WARNING STATUS

			int32	idprop = DCAM_IDPROP_EMGAINWARNING_STATUS;
			double	value;
			if( ! dcam_getpropertyvalue( hdcam, idprop, &value ) )
			{
				dcamcon_show_dcamerr( hdcam, "dcam_getpropertyvalue( DCAM_IDPROP_EMGAINWARNING_STATUS )" );
			}
			else
			{
				// The variable 'value' should be one of following.
				//	DCAMPROP_EMGAINWARNING_STATUS__NORMAL
				//	DCAMPROP_EMGAINWARNING_STATUS__WARNING
				//	DCAMPROP_EMGAINWARNING_STATUS__PROTECTED

				char	valuetext[ 64 ];

				DCAM_PROPERTYVALUETEXT	pvt;
				memset( &pvt, 0, sizeof( pvt ) );
				pvt.iProp	= idprop;
				pvt.value	= value;
				pvt.text	= valuetext;
				pvt.textbytes	= sizeof( valuetext );

				if( ! dcam_getpropertyvaluetext( hdcam, &pvt ) )
				{
					dcamcon_show_dcamerr( hdcam, "dcam_getpropertyvaluetext( DCAM_IDPROP_EMGAINWARNING_STATUS )" );
				}
				else
				{
					printf( "%c: dcam_getpropertyvaluetext( DCAM_IDPROP_EMGAINWARNING_STATUS ) = %s\n", c, valuetext );
				}
			}
		}
		else
		{
			// check EMGAIN PROTECTED

			if( c == 'F' )
			{
				// DCAM_EVENT_FRAMEEND happens.

				unsigned short*	top;
				int32			rowbytes;

				if( ! dcam_lockdata( hdcam, (void**)&top, &rowbytes, -1 ) )
					dcamcon_show_dcamerr( hdcam, "dcam_lockdata()" );
				else
				{
					if( top[ 0 ] == 0 )
					{
						// if locked data is '\0', then EM GAIN is PROTECTED.

						printf( "%c: EM GAIN is PROTECTED.\n", c );
					}
					else
					{
						printf( "%c: EM GAIN is NORMAL.\n", c );
					}
					dcam_unlockdata( hdcam );
				}
			}
			else
			{
				// DCAM_EVENT_FRAMEEND does not happen.

				putchar( c );
			}
		}
	}

	printf( "\n" );
}
