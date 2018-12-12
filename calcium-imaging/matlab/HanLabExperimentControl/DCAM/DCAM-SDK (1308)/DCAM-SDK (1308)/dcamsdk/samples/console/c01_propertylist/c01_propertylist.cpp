// c01_propertylist.cpp :
//
//
// Sample program to show a list of all PROPERTY which the camera supports.
// Copyright (c) 2007, Hamamatsu Photonics K.K.

#include "../console.h"
#include <stdio.h>

////////////////////////////////////////////////////////////////

// declaration of DCAM helper functions
void dcamcon_show_dcamerr( HDCAM hdcam, const char* apiname, const char* fmt = NULL, ...  );
HDCAM dcamcon_init_open();
void dcamcon_show_camera_information( HDCAM hdcam );

// declaration of DCAM sample routines
void dcamcon_show_property_list( HDCAM hdcam );
void dcamcon_show_detail_property_list( HDCAM hdcam );
void dcamcon_show_detail_of_a_property( HDCAM hdcam, int32 iProp );

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

		// show all property list that the camera supports.
		dcamcon_show_property_list( hdcam );
	//	dcamcon_show_detail_property_list( hdcam );
		dcamcon_show_detail_of_a_property( hdcam, DCAM_IDPROP_CONTRASTOFFSET );

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
//	DCAM sample routines
//

// show all property list that the camera supports.
void dcamcon_show_property_list( HDCAM hdcam )
{
	int32	iProp;	/* property IDs	*/

	iProp = 0;
	if( dcam_getnextpropertyid( hdcam, &iProp, DCAMPROP_OPTION_SUPPORT ) )
	{
		do {
			/* The iProp value is one of property ID that the device supports */

		/* Getting property name. */
			char	name[ 64 ];
			/* This should succeed, too. */
			dcam_getpropertyname( hdcam, iProp, name, sizeof( name ) );

			printf( "0x%08X: %s property is supported.\n", iProp, name );

		} while( dcam_getnextpropertyid( hdcam, &iProp, DCAMPROP_OPTION_SUPPORT )
			&& iProp != 0 );
	}
}

void print_attr( int32& count, const char* name );

// show all property list that the camera supports.
void show_propertyattr( DCAM_PROPERTYATTR attr )
{
	int32 count = 0;
	//attribute
	printf( "ATTR:\t" );
	if( attr.attribute & DCAMPROP_ATTR_WRITABLE )				print_attr( count, "WRITABLE" );
	if( attr.attribute & DCAMPROP_ATTR_READABLE )				print_attr( count, "READABLE" );
	if( attr.attribute & DCAMPROP_ATTR_DATASTREAM )				print_attr( count, "DATASTREAM" );
	if( attr.attribute & DCAMPROP_ATTR_ACCESSREADY )			print_attr( count, "ACCESSREADY" );
	if( attr.attribute & DCAMPROP_ATTR_ACCESSBUSY )				print_attr( count, "ACCESSBUSY" );
	if( attr.attribute & DCAMPROP_ATTR_HASVIEW )				print_attr( count, "HASVIEW" );
	if( attr.attribute & DCAMPROP_ATTR_HASCHANNEL )				print_attr( count, "HASCHANNEL" );
	if( attr.attribute & DCAMPROP_ATTR_HASRATIO )				print_attr( count, "HASRATIO" );
	if( attr.attribute & DCAMPROP_ATTR_VOLATILE )				print_attr( count, "VOLATILE" );
	if( attr.attribute & DCAMPROP_ATTR_AUTOROUNDING )			print_attr( count, "AUTOROUNDING" );
	if( attr.attribute & DCAMPROP_ATTR_STEPPING_INCONSISTENT )	print_attr( count, "STEPPING_INCONSISTENT" );
	if( count == 0 )	printf( "none" );
	printf( "\n" );

	//mode
	switch( attr.attribute & DCAMPROP_TYPE_MASK )
	{
		case DCAMPROP_TYPE_MODE:	printf( "TYPE:\tMODE\n" ); break;
		case DCAMPROP_TYPE_LONG:	printf( "TYPE:\tLONG\n" ); break;
		case DCAMPROP_TYPE_REAL:	printf( "TYPE:\tREAL\n" ); break;
		default:					printf( "TYPE:\tNONE\n" ); break;
	}

	//range
	if( attr.attribute & DCAMPROP_ATTR_HASRANGE )
	{
		printf( "min:\t%f\n", attr.valuemin );
		printf( "max:\t%f\n", attr.valuemax );
	}
	//step
	if( attr.attribute & DCAMPROP_ATTR_HASSTEP )
	{
		printf( "step:\t%f\n", attr.valuestep );
	}
	//default
	if( attr.attribute & DCAMPROP_ATTR_HASDEFAULT )
	{
		printf( "default:\t%f\n", attr.valuedefault );
	}
}

void print_attr( int32& count, const char* name )
{
	if( count == 0 )
		printf( "%s", name );
	else
		printf( " | %s", name );

	count++;
}

// show all values which the property supports
void show_supportvalues( HDCAM hdcam, int32 iProp, double v )
{
	printf( "Support:\n" );

	int32 pv_index = 0;

	do
	{
		char	pv_text[64];
		DCAM_PROPERTYVALUETEXT pvt;
		memset( &pvt, 0, sizeof( pvt ) );
		pvt.cbSize		= sizeof( pvt );
		pvt.iProp		= iProp;
		pvt.value		= v;
		pvt.text		= pv_text;
		pvt.textbytes	= sizeof( pv_text );

		pv_index++;
		/* This should succeed. */
		if( dcam_getpropertyvaluetext( hdcam, &pvt ) )
			printf( "\t%d:\t%s\n", pv_index, pv_text );

	} while( dcam_querypropertyvalue( hdcam, iProp, &v, DCAMPROP_OPTION_NEXT ) );
}

// show detail information of a property
void dcamcon_show_detail_of_a_property( HDCAM hdcam, int32 iProp )
{
	printf( "IDPROP:\t0x%08x\n", iProp );

/* Getting property name. */
	char	text[ 64 ];
	/* This should succeed. */
	if( dcam_getpropertyname( hdcam, iProp, text, sizeof( text ) ) )
		printf( "NAME:\t%s\n", text );

/* Getting property attribute. */
	DCAM_PROPERTYATTR	attr;

	memset( &attr, 0, sizeof( attr ) );
	attr.cbSize = sizeof( attr );
	attr.iProp = iProp;
	/* This should succeed. */
	if( dcam_getpropertyattr( hdcam, &attr ) )
	{
		show_propertyattr( attr );

		if( ( attr.attribute & DCAMPROP_TYPE_MASK ) == DCAMPROP_TYPE_MODE )
			show_supportvalues( hdcam, iProp, attr.valuemin );
	}
}

// show all property in list with detail information.
void dcamcon_show_detail_property_list( HDCAM hdcam )
{
	int32	iProp;	/* property IDs	*/

	iProp = 0;
	if( dcam_getnextpropertyid( hdcam, &iProp, DCAMPROP_OPTION_SUPPORT ) )
	{
		do
		{
			/* The iProp value is one of property ID that the device supports */
			dcamcon_show_detail_of_a_property( hdcam, iProp );

			printf( "\n" );
		} while( dcam_getnextpropertyid( hdcam, &iProp, DCAMPROP_OPTION_SUPPORT )
			&& iProp != 0 );
	}
}
