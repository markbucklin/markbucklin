// tempctrl.c :
//
//
// Sensor cooler and Temperature control functions
// Copyright (c) 2007, Hamamatsu Photonics K.K.

#include "../console.h"

////////////////////////////////////////////////////////////////
//
//	helper function for DCAM 2.1.3

// set SENSORCOOLER by DCAM_PARAM_FEATURE
BOOL dcamex_setfeature_sensorcooler( HDCAM hdcam, BOOL bOn )
{
	DCAM_PARAM_FEATURE	param;

	memset( &param, 0, sizeof( param ));
	param.hdr.cbSize = sizeof( param );
	param.hdr.id	= DCAM_IDPARAM_FEATURE;
	param.hdr.iFlag = dcamparam_feature_featureid
					| dcamparam_feature_flags
					;

	param.featureid = DCAM_IDFEATURE_TEMPERATURE;
	if ( bOn )
		param.flags	= DCAM_FEATURE_FLAGS_COOLING_ON;
	else
		param.flags	= DCAM_FEATURE_FLAGS_COOLING_OFF;

	return dcam_extended( hdcam, DCAM_IDMSG_SETPARAM, &param, sizeof( param ) );
}

// get current SENSORCOOLER by DCAM_PARAM_FEATURE
BOOL dcamex_getfeature_sensorcooler( HDCAM hdcam, BOOL& bOn )
{
	DCAM_PARAM_FEATURE	param;

	memset( &param, 0, sizeof( param ));
	param.hdr.cbSize = sizeof( param );
	param.hdr.id	= DCAM_IDPARAM_FEATURE;
	param.hdr.iFlag = dcamparam_feature_featureid
					| dcamparam_feature_flags
					;

	param.featureid = DCAM_IDFEATURE_TEMPERATURE;
	if( ! dcam_extended( hdcam, DCAM_IDMSG_GETPARAM, &param, sizeof( param ) )
	 || ( param.hdr.oFlag & dcamparam_feature_flags ) == 0 )
		return FALSE;

	if( param.flags & DCAM_FEATURE_FLAGS_OFF )
		bOn = FALSE;
	else
		bOn = TRUE;

	return TRUE;
}

// query SENSORCOOLER by DCAM_PARAM_FEATURE
BOOL dcamex_queryfeature_sensorcooler( HDCAM hdcam, BOOL bOn )
{
	DCAM_PARAM_FEATURE_INQ	param;

	memset( &param, 0, sizeof( param ));
	param.hdr.cbSize = sizeof( param );
	param.hdr.id	= DCAM_IDPARAM_FEATURE_INQ;
	param.hdr.iFlag = dcamparam_featureinq_featureid
					| dcamparam_featureinq_capflags
					;

	param.featureid = DCAM_IDFEATURE_TEMPERATURE;
	if( ! dcam_extended( hdcam, DCAM_IDMSG_GETPARAM, &param, sizeof( param ) )
	 || ( param.hdr.oFlag & dcamparam_featureinq_capflags ) == 0 )
	{
		// SENSORCOOLER is not supported
		return FALSE;
	}

	if( bOn )
	{
		if( param.capflags & (DCAM_FEATURE_FLAGS_AUTO | DCAM_FEATURE_FLAGS_MANUAL) )
			return TRUE;
		else
			return FALSE;
	}
	else
	{
		if( param.capflags & DCAM_FEATURE_FLAGS_ONOFF )
			return TRUE;
		else
			return FALSE;
	}
}

// get SENSORTEMPERATURETARGET by DCAM_PARAM_FEATURE
BOOL dcamex_getfeature_temperaturetarget( HDCAM hdcam, double& fTemp )
{
	DCAM_PARAM_FEATURE	param;

	memset( &param, 0, sizeof( param ));
	param.hdr.cbSize = sizeof( param );
	param.hdr.id	= DCAM_IDPARAM_FEATURE;
	param.hdr.iFlag = dcamparam_feature_featureid
					| dcamparam_feature_featurevalue
					;

	param.featureid = DCAM_IDFEATURE_TEMPERATURETARGET;

	if( ! dcam_extended( hdcam, DCAM_IDMSG_GETPARAM, &param, sizeof( param ) )
	 || ( param.hdr.oFlag & dcamparam_feature_featurevalue ) == 0 )
		return FALSE;

	fTemp = param.featurevalue;
	return TRUE;
}

// get SENSORTEMPERATURE by DCAM_PARAM_FEATURE
BOOL dcamex_getfeature_temperature( HDCAM hdcam, double& fTemp)
{
	DCAM_PARAM_FEATURE	param;

	memset( &param, 0, sizeof( param ));
	param.hdr.cbSize = sizeof( param );
	param.hdr.id	= DCAM_IDPARAM_FEATURE;
	param.hdr.iFlag = dcamparam_feature_featureid
					| dcamparam_feature_featurevalue
					;

	param.featureid = DCAM_IDFEATURE_TEMPERATURE;

	if( ! dcam_extended( hdcam, DCAM_IDMSG_GETPARAM, &param, sizeof( param ) )
	 || ( param.hdr.oFlag & dcamparam_feature_featurevalue ) == 0 )
		return FALSE;

	fTemp = param.featurevalue;
	return TRUE;
}

////////////////////////////////////////////////////////////////

#include "tempctrl.h"

BOOL dcamex_setpropertyvalue_sensorcooler( HDCAM hdcam, int32 mode )
{
	if( dcam_setpropertyvalue( hdcam, DCAM_IDPROP_SENSORCOOLER, (double)mode ) )
		return TRUE;

	if( mode == DCAMPROP_SENSORCOOLER__OFF )
		return dcamex_setfeature_sensorcooler( hdcam, FALSE );

	if( mode == DCAMPROP_SENSORCOOLER__ON )
		return dcamex_setfeature_sensorcooler( hdcam, TRUE );

	// DCAMPROP_SENSORCOOLER__MAX is not supported
	return FALSE;
}

BOOL dcamex_getpropertyvalue_sensorcooler( HDCAM hdcam, int32& mode )
{
	double	value;
	if( dcam_getpropertyvalue( hdcam, DCAM_IDPROP_SENSORCOOLER, &value ) )
	{
		// DCAM_IDPROP_SENSORCOOLER is DCAMPROP_TYPE_MODE so the value can be int32.
		mode = (int32)value;
		return TRUE;
	}

	BOOL	bOn;
	if( ! dcamex_getfeature_sensorcooler( hdcam, bOn ) )
	{
		// SENSORCOOLER is not changable.
		return FALSE;
	}

	mode = ( bOn ? DCAMPROP_SENSORCOOLER__ON : DCAMPROP_SENSORCOOLER__OFF );
	return TRUE;
}

BOOL dcamex_querypropertyvalue_sensorcooler( HDCAM hdcam, int32 mode )
{
	double	value = mode;
	if( dcam_querypropertyvalue( hdcam, DCAM_IDPROP_SENSORCOOLER, &value ) )
		return TRUE;

	if( mode == DCAMPROP_SENSORCOOLER__OFF )
		return dcamex_queryfeature_sensorcooler( hdcam, FALSE );

	if( mode == DCAMPROP_SENSORCOOLER__ON )
		return dcamex_queryfeature_sensorcooler( hdcam, TRUE );

	// DCAMPROP_SENSORCOOLER__MAX is not supported
	return FALSE;
}

BOOL dcamex_getpropertyvalue_sensortemperaturetarget( HDCAM hdcam, double& fTemp)
{
	if( dcam_getpropertyvalue( hdcam, DCAM_IDPROP_SENSORTEMPERATURETARGET, &fTemp ) )
		return TRUE;

	return dcamex_getfeature_temperaturetarget( hdcam, fTemp );
}

BOOL dcamex_getpropertyvalue_sensortemperature( HDCAM hdcam, double& fTemp)
{
	if( dcam_getpropertyvalue( hdcam, DCAM_IDPROP_SENSORTEMPERATURE, &fTemp ) )
		return TRUE;

	return dcamex_getfeature_temperature( hdcam, fTemp );
}
