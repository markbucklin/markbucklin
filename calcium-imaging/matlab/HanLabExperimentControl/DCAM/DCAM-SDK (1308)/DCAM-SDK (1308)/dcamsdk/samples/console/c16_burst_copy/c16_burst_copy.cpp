// c16_burst_copy.cpp :
//
//
// Sample program for burst copy.
// Copyright (c) 2009, Hamamatsu Photonics K.K.

#include "../console.h"
#include <stdio.h>

////////////////////////////////////////////////////////////////

// declaration of DCAM helper functions
void dcamcon_show_dcamerr( HDCAM hdcam, const char* apiname, const char* fmt = NULL, ...  );
HDCAM dcamcon_init_open();
void dcamcon_show_camera_information( HDCAM hdcam );

// declaration of helper functions for this sample
int prepare_contiguousbuffer( void**& frames, int32 nFrame, int32 framebyte );
void cleanup_contiguousbuffer( void** frames, int32 nFrame, int32 framebyte );

// declaration of DCAM sample routines
void burstcopy_allocframe( HDCAM hdcam, int32 nPrimaryBuffer, void** localframes, int32 nLocalFrame, int32 framebyte );
void burstcopy_attachbuffer( HDCAM hdcam, int32 nPrimaryBuffer, void** localframes, int32 nLocalFrame, int32 framebyte );

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

		// you can use TDI internal trigger mode if camera supports
	//	dcam_settriggermode( hdcam, DCAM_TRIGMODE_TDIINTERNAL );

		_DWORD	framebyte;
		dcam_getdataframebytes( hdcam, &framebyte );

		int32	nLocalFrame = 100;
		void**	localframes;

		// prepare capturing
		if( ! dcam_precapture( hdcam, DCAM_CAPTUREMODE_SEQUENCE ) )
			dcamcon_show_dcamerr( hdcam, "dcam_precapture()" );
		else
		if( prepare_contiguousbuffer( localframes, nLocalFrame, framebyte ) )
		{
			int	bUseAttachbuffer = 0;

			if( bUseAttachbuffer )
			{
				// call routine of burst copy with attachbuffer.
				burstcopy_attachbuffer( hdcam, 10, localframes, nLocalFrame, framebyte );
			}
			else
			{
				// call routine of burst copy with allocframe.
				burstcopy_allocframe( hdcam, 10, localframes, nLocalFrame, framebyte );
			}

			cleanup_contiguousbuffer( localframes, nLocalFrame, framebyte );
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
//	helper functions for this sample
//

int prepare_contiguousbuffer( void**& frames, int32 nFrame, int32 framebyte )
{
	int32	bufsize = sizeof( *frames ) * ( nFrame + 1 ) + framebyte * nFrame;
	char*	buf = new char[ bufsize ];

	if( buf == NULL )
		return 0;

	memset( buf, 0, bufsize );

	frames = (void**) buf;
	frames[ 0 ] = buf + sizeof( *frames ) * ( nFrame + 1 );

	int32	i;
	for( i = 1; i < nFrame; i++ )
	{
		frames[ i ] = (char*)frames[ i-1 ] + framebyte;
	}

	return ! 0;
}

void cleanup_contiguousbuffer( void** frames, int32 nFrame, int32 framebyte )
{
	if( frames != NULL )
		delete (char*)frames;
}


////////////////////////////////////////////////////////////////
//
//	DCAM sample routine
//

void burstcopy_allocframe( HDCAM hdcam, int32 nPrimaryBuffer, void** localframes, int32 nLocalFrame, int32 framebyte )
{
	{
		// allocate capturing buffer
		if( ! dcam_allocframe( hdcam, nPrimaryBuffer ) )
			dcamcon_show_dcamerr( hdcam, "dcam_allocframe()", "%d frames", nPrimaryBuffer );
		else
		{
			// start capturing
			if( ! dcam_capture( hdcam ) )
				dcamcon_show_dcamerr( hdcam, "dcam_capture()" );
			else
			{
				int32	iNextcopy;
				for( iNextcopy = 0; iNextcopy < nLocalFrame; )
				{
					// wait FRAMEEND
					_DWORD	dw = 0
						| DCAM_EVENT_FRAMEEND
						;

					if( ! dcam_wait( hdcam, &dw, DCAM_WAIT_INFINITE, NULL ) )
					{
						// dcam_wait() returns false when hdcam is closed so this part is never called.
						break;
					}

					// burst copy
					int32	index, total;
					dcam_gettransferinfo( hdcam, &index, &total );	// should be true.

					if( total > nLocalFrame )
						total = nLocalFrame;

					while( iNextcopy < total )
					{
						void*	top;
						int32	rowbytes;

						dcam_lockdata( hdcam, &top, &rowbytes, iNextcopy % nPrimaryBuffer );	// should be true
						memcpy( localframes[ iNextcopy ], top, framebyte );

						iNextcopy++;
					}
					dcam_unlockdata( hdcam );
				}

				// stop capturing
				dcam_idle( hdcam );
			}
			// release capturing buffer
			dcam_freeframe( hdcam );
		}
	}
}

void burstcopy_attachbuffer( HDCAM hdcam, int32 nPrimaryBuffer, void** localframes, int32 nLocalFrame, int32 framebyte )
{
	void**	primaryframes;

	if( prepare_contiguousbuffer( primaryframes, nPrimaryBuffer, framebyte ) )
	{
		// allocate capturing buffer
		if( ! dcam_attachbuffer( hdcam, primaryframes, sizeof( *primaryframes ) * nPrimaryBuffer ) )
			dcamcon_show_dcamerr( hdcam, "dcam_attachbuffer()", "%d frames", nPrimaryBuffer );
		else
		{
			// start capturing
			if( ! dcam_capture( hdcam ) )
				dcamcon_show_dcamerr( hdcam, "dcam_capture()" );
			else
			{
				int32	iNextcopy;
				for( iNextcopy = 0; iNextcopy < nLocalFrame; )
				{
					// wait FRAMEEND
					_DWORD	dw = 0
						| DCAM_EVENT_FRAMEEND
						;

					if( ! dcam_wait( hdcam, &dw, DCAM_WAIT_INFINITE, NULL ) )
					{
						// dcam_wait() returns false when hdcam is closed so this part is never called.
						break;
					}

					// burst copy
					int32	index, total;
					dcam_gettransferinfo( hdcam, &index, &total );	// should be true.

					if( total > nLocalFrame )
						total = nLocalFrame;

					while( iNextcopy / nPrimaryBuffer != total / nPrimaryBuffer )
					{
						int32	index = iNextcopy % nPrimaryBuffer;
						int32	nCopyFrame = nPrimaryBuffer - index;
						memcpy( localframes[ iNextcopy ], primaryframes[ index ], framebyte * nCopyFrame );

						iNextcopy += nCopyFrame;
					}

					if( iNextcopy != total )
					{
						int32	index = iNextcopy % nPrimaryBuffer;
						int32	nCopyFrame = total - iNextcopy;
						memcpy( localframes[ iNextcopy ], primaryframes[ index ], framebyte * nCopyFrame );

						iNextcopy += nCopyFrame;
					}
				}

				// stop capturing
				dcam_idle( hdcam );
			}
			// release capturing buffer
			dcam_freeframe( hdcam );
		}
		cleanup_contiguousbuffer( primaryframes, nPrimaryBuffer, framebyte );
	}
}
