// c10_mechanicalshutter.cpp : 
//
//
// Sample program to control MECHANICALSHUTTER
// Copyright (c) 2007, Hamamatsu Photonics K.K.

#include "../console.h"
#include <stdio.h>

#include "mechctrl.h"

////////////////////////////////////////////////////////////////

// declaration of local function
BOOL has_word( const char* src, const char* test );
void show_help( BOOL bSupportAuto, BOOL bSupportClose, BOOL bSupportOpen );

// declaration of console helper functions
BOOL console_prompt( const char* prompt, char* buf, int32 bufsize );

// declaration of DCAM helper functions
void dcamcon_show_dcamerr( HDCAM hdcam, const char* apiname, const char* fmt = NULL, ...  );
HDCAM dcamcon_init_open();
void dcamcon_show_camera_information( HDCAM hdcam );

// declaration of DCAM sample routines
void dcamcon_show_currentmechanicalshutter( HDCAM hdcam );

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

		BOOL bSupportAuto, bSupportClose, bSupportOpen;

		printf( "MECHANICALSHUTTER:\n" );

		// show which valus the camera supports as MECHANICALSHUTTER
		printf( " support:" );

		bSupportAuto	= dcamex_querypropertyvalue_mechanicalshutter( hdcam, DCAMPROP_MECHANICALSHUTTER__AUTO );
		bSupportClose	= dcamex_querypropertyvalue_mechanicalshutter( hdcam, DCAMPROP_MECHANICALSHUTTER__CLOSE);
		bSupportOpen	= dcamex_querypropertyvalue_mechanicalshutter( hdcam, DCAMPROP_MECHANICALSHUTTER__OPEN );

		if( ! bSupportAuto && ! bSupportClose && ! bSupportOpen )
		{
			printf( " none\n" );
		}
		else
		{
			if( bSupportAuto )	printf( " AUTO" );
			if( bSupportClose)	printf( " CLOSE" );
			if( bSupportOpen )	printf( " OPEN" );

			// show current MECHANICALSHUTTER value
			printf( "\n current: " );

			// loop for mechanical shutter control
			for( ;; )
			{
				int32	mode;

				// show current MECHANICALSHUTTER mode
				if( ! dcamex_getpropertyvalue_mechanicalshutter( hdcam, mode ) )	// This should succeed.
				{
					dcamcon_show_dcamerr( hdcam, "dcamex_getpropertyvalue_mechanicalshutter()");
					break;
				}

				printf( "MECHANICALSHUTTER: " );
				switch( mode )
				{
				case DCAMPROP_MECHANICALSHUTTER__AUTO:	printf( "AUTO\n"  );	break;
				case DCAMPROP_MECHANICALSHUTTER__CLOSE:	printf( "CLOSE\n" );	break;
				case DCAMPROP_MECHANICALSHUTTER__OPEN:	printf( "OPEN\n"  );	break;
				default:								printf( "unknown(%d)\n", mode );	break;
				}

				// input command.
				char	buf[ 256 ];
				if( ! console_prompt( " >", buf, sizeof( buf ) ) )
					break;		// error happend or Ctrl+Z

				if( isspace( buf[ 0 ] ) )
					continue;	// show current status.

				if( has_word( buf, "exit" ) )
					break;		// exit loop

				// check input text
				mode = 0;
				if( has_word( buf, "auto" ) )	mode = DCAMPROP_MECHANICALSHUTTER__AUTO;
				if( has_word( buf, "close" ) )	mode = DCAMPROP_MECHANICALSHUTTER__CLOSE;
				if( has_word( buf, "open" ) )	mode = DCAMPROP_MECHANICALSHUTTER__OPEN;

				if( mode == 0 )
				{
					// show help
					show_help( bSupportAuto, bSupportClose, bSupportOpen );
					continue;
				}

				// change MECHANICALSHUTTER mode
				if( ! dcamex_setpropertyvalue_mechanicalshutter( hdcam, mode ) )		// This should succeed.
				{
					dcamcon_show_dcamerr( hdcam, "dcamex_setpropertyvalue_mechanicalshutter()" );
				}
			}
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

void show_help( BOOL bSupportAuto, BOOL bSupportClose, BOOL bSupportOpen )
{
	char	support[ 256 ];
	sprintf_s( _secure_buf( support ), "%s%s%s"
		, bSupportAuto  ? " auto"  : ""
		, bSupportClose ? " close" : ""
		, bSupportOpen  ? " open"  : "" );

	printf( "/*****************************************************/\n" );
	printf( " %-16s: show current MECHANICALSHUTTER.\n", "empty line" );
	printf( " %-16s: set MECHANICALSHUTTER mode.\n",      support     );
	printf( " %-16s: show help.\n",                      "other word" );
	printf( " %-16s: end program.\n",                    "Ctrl-z"     );
	printf( "/*****************************************************/\n" );
}
