// c08_directemgain.cpp : modified from c03_featurelist.cpp
//
//
// Sample program to use Direct EM-Gain.
// Copyright (c) 2007, Hamamatsu Photonics K.K.

#include "../console.h"
#include <stdio.h>

////////////////////////////////////////////////////////////////

// declaration of console helper functions
BOOL console_prompt( const char* prompt, char* buf, int32 bufsize );

// declaration of DCAM helper functions
void dcamcon_show_dcamerr( HDCAM hdcam, const char* apiname, const char* fmt = NULL, ...  );
HDCAM dcamcon_init_open();
void dcamcon_show_camera_information( HDCAM hdcam );

// declaration of DCAM sample routines
void dcamcon_show_all_feature_list( HDCAM hdcam );
BOOL dcamcon_getfeatureinq( HDCAM hdcam, int32 featureid, DCAM_PARAM_FEATURE_INQ& inq );
BOOL dcamcon_getfeature( HDCAM hdcam, int32 featureid, double& value, int32& flags );
void dcamcon_show_featureinq( const DCAM_PARAM_FEATURE_INQ& inq, double value, int32 flags );
BOOL dcamcon_setgetfeature( HDCAM hdcam, int32 featureid, double& value );

BOOL dcamcon_directemgain_mode_on( HDCAM hdcam );	// add for c08_directemgain

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

		// turn "DIRECT EM GAIN MODE" on if possible.
		dcamcon_directemgain_mode_on( hdcam );	// add for c08_directemgain

		// show all feature list that the camera supports.
		dcamcon_show_all_feature_list( hdcam );

		char	buf[ 256 ];
		while( console_prompt( "Enter feature id>", buf, sizeof( buf ) ) )
		{
			int	featureid = atoi( buf );
			if( featureid == 0 )
				break;

			/* Get feature information. */
			DCAM_PARAM_FEATURE_INQ	inq;
			if( ! dcamcon_getfeatureinq( hdcam, featureid, inq ) )
			{
				printf( "feature %d does not exist\n", featureid );
				continue;
			}

			/* Get feature value. */
			double	value;
			int32	flags;
			if( ! dcamcon_getfeature( hdcam, featureid, value, flags ) )
			{
				printf( "internal error: feature %d cannot be read\n", featureid );
				continue;
			}

			/* Show feature information. */
			dcamcon_show_featureinq( inq, value, flags );

			if( ! console_prompt( "Enter value>", buf, sizeof( buf ) ) )
				break;

			value = atof( buf );
			if( dcamcon_setgetfeature( hdcam, featureid, value ) )
				printf( "value becomes %g\n", value );
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
//	DCAM sample routines
//

// get a feature information
BOOL dcamcon_getfeatureinq( HDCAM hdcam, int32 featureid, DCAM_PARAM_FEATURE_INQ& inq )
{
	memset( &inq, 0, sizeof( inq ) );
	inq.hdr.cbSize = sizeof( inq );				/* size of whole structure */
	inq.hdr.id		= DCAM_IDPARAM_FEATURE_INQ;	/* specify the kind of this structure */
	inq.hdr.iFlag	= 0							/* specify the member to be requested */
					| dcamparam_featureinq_featureid
					| dcamparam_featureinq_capflags
					| dcamparam_featureinq_min
					| dcamparam_featureinq_max
					| dcamparam_featureinq_step
					| dcamparam_featureinq_defaultvalue
					| dcamparam_featureinq_units
					;

	inq.featureid = featureid;
	return dcam_extended( hdcam, DCAM_IDMSG_GETPARAM, &inq, sizeof( inq ) );
}

// get a feature status
BOOL dcamcon_getfeature( HDCAM hdcam, int32 featureid, double& value, int32& flags )
{
	DCAM_PARAM_FEATURE	param;
	memset( &param, 0, sizeof( param ) );
	param.hdr.cbSize = sizeof( param );			/* size of whole structure */
	param.hdr.id	= DCAM_IDPARAM_FEATURE;		/* specify the kind of this structure */
	param.hdr.iFlag	= 0							/* specify the member to be requested */
					| dcamparam_feature_featureid
					| dcamparam_feature_flags
					| dcamparam_feature_featurevalue
					;

	param.featureid = featureid;
	if( ! dcam_extended( hdcam, DCAM_IDMSG_GETPARAM, &param, sizeof( param ) ) )
		return FALSE;

	// check output status.
	if( param.hdr.oFlag & dcamparam_feature_featurevalue )
		value = param.featurevalue;

	if( param.hdr.oFlag & dcamparam_feature_flags )
		flags = param.flags;

	return TRUE;
}

// setget a feature value
BOOL dcamcon_setgetfeature( HDCAM hdcam, int32 featureid, double& value )
{
	DCAM_PARAM_FEATURE	param;
	memset( &param, 0, sizeof( param ) );
	param.hdr.cbSize = sizeof( param );			/* size of whole structure */
	param.hdr.id	= DCAM_IDPARAM_FEATURE;		/* specify the kind of this structure */
	param.hdr.iFlag	= 0							/* specify the member to be requested */
					| dcamparam_feature_featureid
					| dcamparam_feature_featurevalue
					;

	param.featureid = featureid;
	param.featurevalue = (float)value;
	if( ! dcam_extended( hdcam, DCAM_IDMSG_SETGETPARAM, &param, sizeof( param ) ) )
		return FALSE;

	// check output status.
	if( param.hdr.oFlag & dcamparam_feature_featurevalue )
		value = param.featurevalue;

	return TRUE;
}

// turn "DIRECT EM GAIN MODE" on if possible.
BOOL dcamcon_directemgain_mode_on( HDCAM hdcam )	// add for c08_directemgain
{
	double	value;
	value = DCAMPROP_MODE__ON;
	if( ! dcam_querypropertyvalue( hdcam, DCAM_IDPROP_DIRECTEMGAIN_MODE, &value ) )
		return FALSE;	// cannot set "ON" to "DIRECT EM GAIN MODE".

	if( ! dcam_setpropertyvalue( hdcam, DCAM_IDPROP_DIRECTEMGAIN_MODE, DCAMPROP_MODE__ON ) )
		return FALSE;	// should be successed.

	return TRUE;
}

// feature list and text

struct features {
	int32	id;
	const char*	name;
} features[] = {
	DCAM_IDFEATURE_GAIN,				"GAIN",
	DCAM_IDFEATURE_EXPOSURETIME,		"EXPOSURETIME",
	DCAM_IDFEATURE_TEMPERATURE,			"TEMPERATURE",
	DCAM_IDFEATURE_LIGHTMODE,			"LIGHTMODE",
	DCAM_IDFEATURE_OFFSET,				"OFFSET",
	DCAM_IDFEATURE_SENSITIVITY,			"SENSITIVITY",
	DCAM_IDFEATURE_TRIGGERTIMES,		"TRIGGERTIMES",
	0
};

const char* getfeaturetext( int32 featureid )
{
	int	i;
	for( i = 0; features[ i ].id != 0; i++ )
	{
		if( features[ i ].id == featureid )
			return features[ i ].name;
	}

	ASSERT( 0 );	// this should not happen

	return "(unknown)";
}

// show feature information
void dcamcon_show_featureinq( const DCAM_PARAM_FEATURE_INQ& inq, double value, int32 flags )
{
	_DWORD	capflags;

	// inq.hdr.oFlag shows the member to be gotten by module */

	if( inq.hdr.oFlag & dcamparam_featureinq_capflags )
		capflags = inq.capflags;
	else
		capflags = 0;

	printf( "%2d:%-12s", inq.featureid, getfeaturetext( inq.featureid ) );

	printf( " [%s%s%s%s]"
		, ( capflags & DCAM_FEATURE_FLAGS_READ_OUT ) ? "R" : "-"	// feature values is readable
		, ( capflags & DCAM_FEATURE_FLAGS_ONOFF )    ? "F" : "-"	// feature can be turned off.
		, ( capflags & DCAM_FEATURE_FLAGS_AUTO )     ? "A" : "-"	// feature is controled automatically by camera 
		, ( capflags & DCAM_FEATURE_FLAGS_MANUAL )   ? "M" : "-"	// feature is controled automatically by camera 
		);

	if( flags & DCAM_FEATURE_FLAGS_OFF )
		printf( " off\n" );
	else
	if( flags & DCAM_FEATURE_FLAGS_AUTO )
		printf( " auto\n" );
	else
	if( flags & DCAM_FEATURE_FLAGS_MANUAL )
		printf( " manual\n" );
	else
		ASSERT( 0 );	// this should not happen

	printf( "current=%g", value );

	if( ( inq.hdr.oFlag & dcamparam_featureinq_min ) 
	 && ( inq.hdr.oFlag & dcamparam_featureinq_max ) )
	{
		printf( " min=%g max=%g", inq.min, inq.max);
	}

	if( ( inq.hdr.oFlag & dcamparam_featureinq_step ) )
	{
		printf( " step=%g", inq.step );
	}

	if( ( inq.hdr.oFlag & dcamparam_featureinq_defaultvalue ) )
	{
		printf( " default=%g", inq.defaultvalue );
	}

	printf( "\n" );
}

// show all feature list that the camera supports.
void dcamcon_show_all_feature_list( HDCAM hdcam )
{
	int	i;
	for( i = 0; features[ i ].id != 0; i++ )
	{
		/* Get feature information. */
		DCAM_PARAM_FEATURE_INQ	inq;
		if( dcamcon_getfeatureinq( hdcam, features[ i ].id, inq ) )
		{
			// show feature name
			printf( "%2d:%-s\n", inq.featureid, getfeaturetext( inq.featureid ) );
		}
	}
}
