// c07_temperature.cpp : 
//
//
// Sample program controling SENSORCOOLER and checking SENSORTEMPERATURE
// Copyright (c) 2007, Hamamatsu Photonics K.K.

#include "../console.h"
#include <stdio.h>

#include "tempctrl.h"

////////////////////////////////////////////////////////////////

// declaration of DCAM helper functions
void dcamcon_show_dcamerr( HDCAM hdcam, const char* apiname, const char* fmt = NULL, ...  );
HDCAM dcamcon_init_open();
void dcamcon_show_camera_information( HDCAM hdcam );

// declaration of DCAM sample routines
void dcamcon_show_currentcoolerstatus( HDCAM hdcam, BOOL bSENSORMODE, BOOL bSENSORTEMPERATURETARGET );
void dcamcon_ask_turning_cooler_on( HDCAM hdcam, BOOL bSupportOn, BOOL bSupportMax );
void dcamcon_loop_temperaturecontrol( HDCAM hdcam, BOOL bSupportOff, BOOL bSupportOn, BOOL bSupportMax );

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

		BOOL bSupportOff, bSupportOn, bSupportMax;

		printf( "SENSORCOOLER:\n" );

		// show which valus the camera supports as SENSORCOOLER
		printf( " support:" );

		bSupportOff = dcamex_querypropertyvalue_sensorcooler( hdcam, DCAMPROP_SENSORCOOLER__OFF );
		bSupportOn  = dcamex_querypropertyvalue_sensorcooler( hdcam, DCAMPROP_SENSORCOOLER__ON  );
		bSupportMax = dcamex_querypropertyvalue_sensorcooler( hdcam, DCAMPROP_SENSORCOOLER__MAX );

		if( ! bSupportOff && ! bSupportOn && ! bSupportMax )
		{
			printf( " none\n" );
		}
		else
		{
			if( bSupportOff )	printf( " OFF" );
			if( bSupportOn )	printf( " ON" );
			if( bSupportMax )	printf( " MAX" );

			// show current SENSORCOOLER value
			printf( "\n current: " );

			int32	mode	= 0;
			if( ! dcamex_getpropertyvalue_sensorcooler( hdcam, mode ) )		// This should succeed.
			{
				dcamcon_show_dcamerr( hdcam, "dcamex_getpropertyvalue_sensorcooler()");
			}
			else
			{
				switch( mode )
				{
				case DCAMPROP_SENSORCOOLER__MAX:
					printf( "MAX\n" );
					break;

				case DCAMPROP_SENSORCOOLER__ON:
					printf( "ON\n" );
					break;

				case DCAMPROP_SENSORCOOLER__OFF:
					printf( "OFF\n" );
					// if camera supports SENSORCOOLER ON or MAX but current is OFF, it is better to ask turn cooler ON to user at begining of application.
					if( bSupportOn || bSupportMax )
						dcamcon_ask_turning_cooler_on( hdcam, bSupportOn, bSupportMax );

					break;

				default:
					printf( "unknown(%d)\n", mode );
					break;
				}
			}

			// show current SENSORTEMPERATURETARGET
			dcamcon_show_currentcoolerstatus( hdcam, FALSE, TRUE );

			// show SENSORTEMPERATURE and control SENSORCOOLER mode as user request.
			dcamcon_loop_temperaturecontrol( hdcam, bSupportOff, bSupportOn, bSupportMax );
		}

		// close HDCAM handle
		dcam_close( hdcam );

		// terminate DCAM-API
		dcam_uninit( NULL, NULL );
	}

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

BOOL has_word( const char* src, const char* test )
{
	size_t	len = strlen( test );
	if( _strnicmp( src, test, len ) == 0 )
	{
		if( isspace( src[ len ] ) )
			return TRUE;
	}
	return FALSE;
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
//	DCAM sample routines
//

// ask turning cooler on
void dcamcon_ask_turning_cooler_on( HDCAM hdcam, BOOL bSupportOn, BOOL bSupportMax )
{
	char	buf[ 256 ];

	if( console_prompt( "Camera supports cooling. Do you want to turn cooler on now? (yes/no)", buf, sizeof( buf ) )
	 && has_word( buf, "yes" ) )
	{
		int32	mode;

		if( bSupportOn && bSupportMax )
		{
			console_prompt( "Choose ON,MAX or OFF?", buf, sizeof( buf ) );
			if( has_word( buf, " on" ) )
				mode = DCAMPROP_SENSORCOOLER__ON;
			else
			if( has_word( buf, "max" ) )
				mode = DCAMPROP_SENSORCOOLER__MAX;
			else
				mode = DCAMPROP_SENSORCOOLER__OFF;
		}
		else if( bSupportOn )	mode = DCAMPROP_SENSORCOOLER__ON;
		else if( bSupportMax )	mode = DCAMPROP_SENSORCOOLER__MAX;
		else					mode = DCAMPROP_SENSORCOOLER__OFF;

		if( ! dcamex_setpropertyvalue_sensorcooler( hdcam, mode ) )		// This should succeed.
			dcamcon_show_dcamerr( hdcam, "dcamex_setpropertyvalue_sensorcooler()" );
	}
}

void show_help( BOOL bSupportOff, BOOL bSupportOn, BOOL bSupportMax )
{
	char	support[ 256 ];
	sprintf_s( _secure_buf( support ), "%s%s%s"
		, bSupportOff ? " off" : ""
		, bSupportOn  ? " on"  : ""
		, bSupportMax ? " max" : "" );

	printf( "/*************************************************/\n" );
	printf( " %-12s: show current SENSORTEMPERATURE.\n", "empty line" );
	printf( " %-12s: set SENSORCOOLER mode.\n",           support     );
	printf( " %-12s: show current values.\n",            "?"     );
	printf( " %-12s: show help.\n",                      "other word" );
	printf( " %-12s: end program.\n",                    "Ctrl-z"     );
	printf( "/*************************************************/\n" );
}

void dcamcon_show_currentcoolerstatus( HDCAM hdcam, BOOL bSENSORMODE, BOOL bSENSORTEMPERATURETARGET )
{
	int32	mode;

	// show current SENSORCOOLER mode
	if( bSENSORMODE && dcamex_getpropertyvalue_sensorcooler( hdcam, mode ) )
	{
		printf( "SENSORCOOLER: " );
		switch( mode )
		{
		case DCAMPROP_SENSORCOOLER__MAX:	printf( "MAX\n" );	break;
		case DCAMPROP_SENSORCOOLER__ON:		printf( "ON\n" );	break;
		case DCAMPROP_SENSORCOOLER__OFF:	printf( "OFF\n" );	break;
		default:							printf( "unknown(%d)\n", mode );	break;
		}
	}

	double	fTemp;
	if( bSENSORTEMPERATURETARGET && dcamex_getpropertyvalue_sensortemperaturetarget( hdcam, fTemp ) )
		printf( "SENSORTEMPERATURETARGET: %g\n", fTemp );
}

// test loop for tempearature control
void dcamcon_loop_temperaturecontrol( HDCAM hdcam, BOOL bSupportOff, BOOL bSupportOn, BOOL bSupportMax )
{
	for( ;; )
	{
		double	fTemp;
		if( dcamex_getpropertyvalue_sensortemperature( hdcam, fTemp ) )	// some camera does not support
			printf( "SENSORTEMPERATURE: %g ", fTemp );

		char	buf[ 256 ];
		if( ! console_prompt( " >", buf, sizeof( buf ) ) )
			break;

		if( isspace( buf[ 0 ] ) )
			continue;

		if( has_word( buf, "exit" ) )
			break;

		int32	mode = 0;
		if( has_word( buf, "on" ) )
			mode = DCAMPROP_SENSORCOOLER__ON;
		else
		if( has_word( buf, "max" ) )
			mode = DCAMPROP_SENSORCOOLER__MAX;
		else
		if( has_word( buf, "off" ) )
			mode = DCAMPROP_SENSORCOOLER__OFF;
		else
		if( has_word( buf, "?" ) )
		{
			dcamcon_show_currentcoolerstatus( hdcam, TRUE, TRUE );
			continue;
		}
		else
		{
			// show help
			show_help( bSupportOff, bSupportOn, bSupportMax );
			continue;
		}

		// change SENSORCOOLER mode
		if( ! dcamex_setpropertyvalue_sensorcooler( hdcam, mode ) )		// This should succeed.
			dcamcon_show_dcamerr( hdcam, "dcamex_setpropertyvalue_sensorcooler()" );

		dcamcon_show_currentcoolerstatus( hdcam, TRUE, FALSE );
	}
}
