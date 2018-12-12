// dcamex.cpp
//

#include "stdafx.h"
#include "dcamex.h"

// ----------------------------------------------------------------

long dcamex_getimagewidth( HDCAM hdcam )
{
	SIZE	sz;
	if( ! dcam_getdatasize( hdcam, &sz ) )
		return 0;

	return sz.cx;
}

long dcamex_getimageheight( HDCAM hdcam )
{
	SIZE	sz;
	if( ! dcam_getdatasize( hdcam, &sz ) )
		return 0;

	return sz.cy;
}

long dcamex_getcolortype( HDCAM hdcam )
{
	DCAM_DATATYPE	datatype;
	if( ! dcam_getdatatype( hdcam, &datatype ) )
		return 0;

	switch( datatype )
	{
	default:
		ASSERT( 0 );
	case DCAM_DATATYPE_UINT8:
	case DCAM_DATATYPE_UINT16:
		return DCAMPROP_COLORTYPE__BW;

	case DCAM_DATATYPE_RGB24:
	case DCAM_DATATYPE_RGB48:
		return DCAMPROP_COLORTYPE__RGB;

	case DCAM_DATATYPE_BGR24:
	case DCAM_DATATYPE_BGR48:
		return DCAMPROP_COLORTYPE__BGR;
	}
}

long dcamex_getbitsperchannel( HDCAM hdcam )
{
	int32	vmax, vmin;
	if( ! dcam_getdatarange( hdcam, &vmax, &vmin ) )
		return 0;

	int	i;
	for( i = 0; vmax > 0; i++ )
		vmax >>= 1;

	return i;
}

// ----------------------------------------------------------------

BOOL dcamex_is_sensormode_area( HDCAM hdcam )
{
	int32	mode;
	if( ! dcam_gettriggermode( hdcam, &mode ) )
		return TRUE;	// must be AREA.

	switch( mode )
	{
	case DCAM_TRIGMODE_TDI:
	case DCAM_TRIGMODE_TDIINTERNAL:
		return FALSE;	// not AREA sensor

	default:
		ASSERT( 0 );
	case DCAM_TRIGMODE_INTERNAL:
	case DCAM_TRIGMODE_EDGE:
	case DCAM_TRIGMODE_LEVEL:
	case DCAM_TRIGMODE_SOFTWARE:
	case DCAM_TRIGMODE_FASTREPETITION:
	case DCAM_TRIGMODE_START:
	case DCAM_TRIGMODE_SYNCREADOUT:
		return TRUE;	// AREA sensor
	}
}

BOOL dcamex_is_rgbratio_writable( HDCAM hdcam )
{
	DCAM_PARAM_RGBRATIO	param;

	memset( &param, 0, sizeof( param ));

	param.hdr.cbSize	= sizeof( param);
	param.hdr.id		= DCAM_IDPARAM_RGBRATIO;
	param.hdr.iFlag		= dcamparam_rgbratio_exposure
						| dcamparam_rgbratio_gain
						;

	if( ! dcam_extended( hdcam, DCAM_IDMSG_GETPARAM, &param, sizeof( param ) )
	 || param.hdr.oFlag == 0 )
		return FALSE;

	return TRUE;
}

// ----------------------------------------------------------------

BOOL dcamex_getreadoutspeedinq( HDCAM hdcam, int32& maxspeed )
{
	DCAM_PARAM_SCANMODE_INQ inq;
	memset( &inq, 0, sizeof( inq ) );

	inq.hdr.cbSize	= sizeof( inq );
	inq.hdr.id		= DCAM_IDPARAM_SCANMODE_INQ;
	inq.hdr.iFlag	= dcamparam_scanmodeinq_speedmax;
	
	if( ! dcam_extended( hdcam, DCAM_IDMSG_GETPARAM, &inq, sizeof( inq ) ) )
	{
		maxspeed = 1;
	}
	else
	{
		maxspeed = inq.speedmax;
	}

	return TRUE;
}

BOOL dcamex_getreadoutspeed( HDCAM hdcam, int32& speed )
{
	DCAM_PARAM_SCANMODE		param;
	memset( &param, 0, sizeof( param ) );
	param.hdr.cbSize	= sizeof( param );
	param.hdr.id		= DCAM_IDPARAM_SCANMODE;
	param.hdr.iFlag		= dcamparam_scanmode_speed;

	if( ! dcam_extended( hdcam, DCAM_IDMSG_GETPARAM, &param, sizeof( param ) ) )
		speed = 1;
	else
		speed = param.speed;

	return TRUE;
}

BOOL dcamex_setreadoutspeed( HDCAM hdcam, long speed )
{
	DCAM_PARAM_SCANMODE		param;
	memset( &param, 0, sizeof( param ) );
	param.hdr.cbSize	= sizeof( param );
	param.hdr.id		= DCAM_IDPARAM_SCANMODE;
	param.hdr.iFlag		= dcamparam_scanmode_speed;

	param.speed = speed;

	return dcam_extended( hdcam, DCAM_IDMSG_SETPARAM, &param, sizeof( param ) );
}

// ----------------------------------------------------------------

BOOL dcamex_getfeatureinq( HDCAM hdcam, long idfeature
		, long& capflags
		, double& min
		, double& max
		, double& step
		, double& defaultvalue )
{
	DCAM_PARAM_FEATURE_INQ	inq;
	memset( &inq, 0, sizeof( inq ) );
	inq.hdr.cbSize	= sizeof( inq );
	inq.hdr.id		= DCAM_IDPARAM_FEATURE_INQ;
	inq.hdr.iFlag	= dcamparam_featureinq_featureid
					| dcamparam_featureinq_capflags
					| dcamparam_featureinq_min
					| dcamparam_featureinq_max
					| dcamparam_featureinq_step
					| dcamparam_featureinq_defaultvalue
					| dcamparam_featureinq_units
					;
	inq.featureid	= idfeature;
				
	if( ! dcam_extended( hdcam, DCAM_IDMSG_GETPARAM, &inq, sizeof( inq ) ) )
		return FALSE;

	if( inq.hdr.oFlag & dcamparam_featureinq_capflags )		capflags	= inq.capflags;
	if( inq.hdr.oFlag & dcamparam_featureinq_min )			min			= inq.min;
	if( inq.hdr.oFlag & dcamparam_featureinq_max )			max			= inq.max;
	if( inq.hdr.oFlag & dcamparam_featureinq_step )			step		= inq.step;
	if( inq.hdr.oFlag & dcamparam_featureinq_defaultvalue )	defaultvalue= inq.defaultvalue;

	return TRUE;
}

// ----

BOOL dcamex_getfeature( HDCAM hdcam, long idfeature, double& featurevalue )
{
	DCAM_PARAM_FEATURE	param;
	memset( &param, 0, sizeof( param ));

	param.hdr.cbSize	= sizeof( param);
	param.hdr.id		= DCAM_IDPARAM_FEATURE;
	param.hdr.iFlag		= dcamparam_feature_featureid
					//	| dcamparam_feature_flags
						| dcamparam_feature_featurevalue
						;

	param.featureid		= idfeature;

	if( ! dcam_extended( hdcam, DCAM_IDMSG_GETPARAM, &param, sizeof( param ) ) )
		return FALSE;

	featurevalue	= param.featurevalue;

	return TRUE;
}

BOOL dcamex_getfeature( HDCAM hdcam, long idfeature, double& featurevalue, long& featureflags )
{
	DCAM_PARAM_FEATURE	param;
	memset( &param, 0, sizeof( param ));

	param.hdr.cbSize	= sizeof( param);
	param.hdr.id		= DCAM_IDPARAM_FEATURE;
	param.hdr.iFlag		= dcamparam_feature_featureid
						| dcamparam_feature_flags
						| dcamparam_feature_featurevalue
						;

	param.featureid		= idfeature;

	if( ! dcam_extended( hdcam, DCAM_IDMSG_GETPARAM, &param, sizeof( param ) ) )
		return FALSE;

	featurevalue	= param.featurevalue;
	featureflags	= param.flags;

	return TRUE;
}
BOOL dcamex_setfeature( HDCAM hdcam, DCAM_PARAM_FEATURE& param, long idfeature )
{
	memset( &param, 0, sizeof( param ));
	param.hdr.cbSize	= sizeof( param);
	param.hdr.id		= DCAM_IDPARAM_FEATURE;
	param.hdr.iFlag		= dcamparam_feature_featureid
						| dcamparam_feature_flags
						| dcamparam_feature_featurevalue
						;

	param.featureid		= idfeature;

	return dcam_extended( hdcam, DCAM_IDMSG_GETPARAM, &param, sizeof( param ) );
}

// ----

BOOL dcamex_setfeature( HDCAM hdcam, long idfeature, double featurevalue, long flags )
{
	DCAM_PARAM_FEATURE	param;
	memset( &param, 0, sizeof( param ));

	param.hdr.cbSize	= sizeof( param);
	param.hdr.id		= DCAM_IDPARAM_FEATURE;
	param.hdr.iFlag		= dcamparam_feature_featureid
						| dcamparam_feature_flags
						| dcamparam_feature_featurevalue
						;

	param.featureid		= idfeature;
	param.featurevalue	= (float)featurevalue;
	param.flags			= flags;

	return dcam_extended( hdcam, DCAM_IDMSG_SETPARAM, &param, sizeof( param ) );
}

BOOL dcamex_setfeaturevalue( HDCAM hdcam, long idfeature, double featurevalue )
{
	DCAM_PARAM_FEATURE	param;
	memset( &param, 0, sizeof( param ));

	param.hdr.cbSize	= sizeof( param);
	param.hdr.id		= DCAM_IDPARAM_FEATURE;
	param.hdr.iFlag		= dcamparam_feature_featureid
					//	| dcamparam_feature_flags
						| dcamparam_feature_featurevalue
						;

	param.featureid		= idfeature;
	param.featurevalue	= (float)featurevalue;
//	param.flags			= DCAM_FEATURE_FLAGS_MANUAL;

	return dcam_extended( hdcam, DCAM_IDMSG_SETPARAM, &param, sizeof( param ) );
}

BOOL dcamex_setfeatureflags( HDCAM hdcam, long idfeature, long flags )
{
	DCAM_PARAM_FEATURE	param;
	memset( &param, 0, sizeof( param ));

	param.hdr.cbSize	= sizeof( param);
	param.hdr.id		= DCAM_IDPARAM_FEATURE;
	param.hdr.iFlag		= dcamparam_feature_featureid
						| dcamparam_feature_flags
					//	| dcamparam_feature_featurevalue
						;

	param.featureid		= idfeature;
	param.flags			= flags;

	return dcam_extended( hdcam, DCAM_IDMSG_SETPARAM, &param, sizeof( param ) );
}

// ----------------------------------------------------------------

BOOL dcamex_getsubarrayrectinq( HDCAM hdcam
		, int32& hposunit, int32& hunit, int32& hmax
		, int32& vposunit, int32& vunit, int32& vmax )
{
	DCAM_PARAM_SUBARRAY_INQ inq;
	memset( &inq, 0, sizeof( inq ) );

	inq.hdr.cbSize	= sizeof( inq );
	inq.hdr.id		= DCAM_IDPARAM_SUBARRAY_INQ;
	inq.hdr.iFlag	=  dcamparam_subarrayinq_hmax
					 | dcamparam_subarrayinq_vmax
					 | dcamparam_subarrayinq_hposunit
					 | dcamparam_subarrayinq_vposunit
					 | dcamparam_subarrayinq_hunit
					 | dcamparam_subarrayinq_vunit;
			
	VERIFY( dcam_extended( hdcam, DCAM_IDMSG_GETPARAM, &inq, sizeof( inq ) ) );

	hposunit= inq.hposunit;
	vposunit= inq.vposunit;
	hunit	= inq.hunit;
	vunit	= inq.vunit;
	hmax	= inq.hmax;
	vmax	= inq.vmax;

	return TRUE;
}

BOOL dcamex_getsubarrayrect( HDCAM hdcam, int32& left, int32& top, int32& width, int32& height )
{
	DCAM_PARAM_SUBARRAY		param;
	memset( &param, 0, sizeof( param ) );
	param.hdr.cbSize	= sizeof( param );
	param.hdr.id		= DCAM_IDPARAM_SUBARRAY;
	param.hdr.iFlag		= dcamparam_subarray_hpos
						| dcamparam_subarray_vpos	
						| dcamparam_subarray_hsize
						| dcamparam_subarray_vsize
						;

	VERIFY( dcam_extended( hdcam, DCAM_IDMSG_GETPARAM, &param, sizeof( param ) ) );

	left	= param.hpos;
	top		= param.vpos;
	width	= param.hsize;
	height	= param.vsize;

	return TRUE;
}

BOOL dcamex_setsubarrayrect( HDCAM hdcam, long left, long top, long width, long height )
{
	DCAM_PARAM_SUBARRAY		param;
	memset( &param, 0, sizeof( param ) );
	param.hdr.cbSize	= sizeof( param );
	param.hdr.id		= DCAM_IDPARAM_SUBARRAY;
	param.hdr.iFlag		= dcamparam_subarray_hpos
						| dcamparam_subarray_vpos	
						| dcamparam_subarray_hsize
						| dcamparam_subarray_vsize
						;

	param.hpos	= left;
	param.vpos	= top;
	param.hsize	= width;
	param.vsize	= height;

	return dcam_extended( hdcam, DCAM_IDMSG_SETPARAM, &param, sizeof( param ) );
}

// ----------------------------------------------------------------

BOOL dcamex_getexposuretimerange( HDCAM hdcam, double& max, double& min )
{
	long	capflags;
	double	step, defaultvalue;

	if( ! dcamex_getfeatureinq( hdcam, DCAM_IDFEATURE_EXPOSURETIME
					, capflags, min, max, step, defaultvalue ) )
		return FALSE;

	return TRUE;
}

// ----------------------------------------------------------------

BOOL dcamex_is_internallinerate_writable( HDCAM hdcam )
{
	DCAM_PROPERTYATTR	attr;
	memset( &attr, 0, sizeof( attr ) );
	attr.cbSize = sizeof( attr );
	attr.iProp	= DCAM_IDPROP_INTERNALLINERATE;

	if( ! dcam_getpropertyattr( hdcam, &attr )
	 || ( attr.attribute & DCAMPROP_ATTR_WRITABLE ) == 0 )
		return FALSE;

	return TRUE;
}

BOOL dcamex_getinternallineraterange( HDCAM hdcam, double& max, double& min )
{
	DCAM_PROPERTYATTR	attr;
	memset( &attr, 0, sizeof( attr ) );
	attr.cbSize = sizeof( attr );
	attr.iProp	= DCAM_IDPROP_INTERNALLINERATE;

	if( ! dcam_getpropertyattr( hdcam, &attr )
	 || ( attr.attribute & DCAMPROP_ATTR_WRITABLE ) == 0 )
		return FALSE;

	max = attr.valuemax;
	min = attr.valuemin;

	return TRUE;
}

BOOL dcamex_getinternallinerate( HDCAM hdcam, double& value )
{
	return dcam_getpropertyvalue( hdcam, DCAM_IDPROP_INTERNALLINERATE, &value );
}

BOOL dcamex_setinternallinerate( HDCAM hdcam, double value )
{
	return dcam_setpropertyvalue( hdcam, DCAM_IDPROP_INTERNALLINERATE, value );
}
