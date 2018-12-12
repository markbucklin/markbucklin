// mechctrl.cpp :
//
//
// Mechanical shutter control functions
// Copyright (c) 2007, Hamamatsu Photonics K.K.

#include "../console.h"

////////////////////////////////////////////////////////////////
//
//	helper function for DCAM 2.1.3

// get current MECHANICALSHUTTER by DCAM_PARAM_FEATURE
BOOL dcamex_queryfeature_mechanicalshutter( HDCAM hdcam, int32& mode )
{
	DCAM_PARAM_FEATURE_INQ	inq;

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

	inq.featureid = DCAM_IDFEATURE_MECHANICALSHUTTER;

	if( ! dcam_extended( hdcam, DCAM_IDMSG_GETPARAM, &inq, sizeof( inq )) )
		return FALSE;

	if( mode == DCAMPROP_MECHANICALSHUTTER__OPEN )
	{
		if( inq.capflags & DCAM_FEATURE_FLAGS_ONOFF )
			return TRUE;	// OPEN is selectable.

		return FALSE;
	}

	if( mode == DCAMPROP_MECHANICALSHUTTER__AUTO )
	{
		if( inq.capflags & DCAM_FEATURE_FLAGS_AUTO )
			return TRUE;	// AUTO is selectable.

		return FALSE;
	}

	if( mode == DCAMPROP_MECHANICALSHUTTER__CLOSE )
	{
		if( inq.capflags & DCAM_FEATURE_FLAGS_MANUAL )
			return TRUE;	// CLOSE is selectable.

		return FALSE;
	}

	// unknown mode.
	return FALSE;
}

// get current MECHANICALSHUTTER by DCAM_PARAM_FEATURE
BOOL dcamex_getfeature_mechanicalshutter( HDCAM hdcam, int32& mode )
{
	DCAM_PARAM_FEATURE	param;

	memset( &param, 0, sizeof( param ));
	param.hdr.cbSize = sizeof( param );
	param.hdr.id	= DCAM_IDPARAM_FEATURE;
	param.hdr.iFlag = dcamparam_feature_featureid
					| dcamparam_feature_flags
					| dcamparam_feature_featurevalue
					;

	param.featureid = DCAM_IDFEATURE_MECHANICALSHUTTER;

	if( ! dcam_extended( hdcam, DCAM_IDMSG_GETPARAM, &param, sizeof( param )) )
		return FALSE;

	// exchange from FEATURE values to PROPERTY values
	if( param.flags & DCAM_FEATURE_FLAGS_MECHANICALSHUTTER_OPEN )
		mode = DCAMPROP_MECHANICALSHUTTER__OPEN;
	else
	if( param.flags & DCAM_FEATURE_FLAGS_MECHANICALSHUTTER_AUTO )
		mode = DCAMPROP_MECHANICALSHUTTER__AUTO;
	else
	if( param.flags & DCAM_FEATURE_FLAGS_MECHANICALSHUTTER_CLOSE )
	{
		/* param.featurevalue must be 0 */

		mode = DCAMPROP_MECHANICALSHUTTER__CLOSE;
	}

	return TRUE;
}

// set MECHANICALSHUTTER by DCAM_PARAM_FEATURE
BOOL dcamex_setfeature_mechanicalshutter( HDCAM hdcam, int32 mode )
{
	DCAM_PARAM_FEATURE	param;

	memset( &param, 0, sizeof( param ));
	param.hdr.cbSize = sizeof( param );
	param.hdr.id	= DCAM_IDPARAM_FEATURE;
	param.hdr.iFlag = dcamparam_feature_featureid
					| dcamparam_feature_flags
					| dcamparam_feature_featurevalue
					;

	param.featureid = DCAM_IDFEATURE_MECHANICALSHUTTER;

	// exchange from PROPERTY values to FEATURE values
	if( mode == DCAMPROP_MECHANICALSHUTTER__OPEN )
	{
		param.flags = DCAM_FEATURE_FLAGS_MECHANICALSHUTTER_OPEN;
		/* param.featurevalue doesn't matter */
	}
	else
	if( mode == DCAMPROP_MECHANICALSHUTTER__AUTO )
	{
		param.flags = DCAM_FEATURE_FLAGS_MECHANICALSHUTTER_AUTO;
		param.flags|= DCAM_FEATURE_FLAGS_MECHANICALSHUTTER_CLOSE;	// AUTO has priority than CLOSE
		/* param.featurevalue doesn't matter */
	}
	else
	if( mode == DCAMPROP_MECHANICALSHUTTER__CLOSE )
	{
		param.flags = DCAM_FEATURE_FLAGS_MECHANICALSHUTTER_CLOSE;
		param.featurevalue = 0;		/* param.featurevalue must be 0 */
	}
	else
		return FALSE;	// unknown value

	if( ! dcam_extended( hdcam, DCAM_IDMSG_SETPARAM, &param, sizeof( param )) )
	{
		/* failure to set cooling switch on or off */
		return FALSE;
	}

	return TRUE;
}

////////////////////////////////////////////////////////////////

#include "mechctrl.h"

BOOL dcamex_querypropertyvalue_mechanicalshutter( HDCAM hdcam, int32 mode )
{
	double	v;
	v = mode;
	if( dcam_querypropertyvalue( hdcam, DCAM_IDPROP_MECHANICALSHUTTER, &v ) )
		return TRUE;

	if( dcamex_queryfeature_mechanicalshutter( hdcam, mode ) )
		return TRUE;

	return FALSE;
}

BOOL dcamex_getpropertyvalue_mechanicalshutter( HDCAM hdcam, int32& mode )
{
	double	v;
	if( dcam_getpropertyvalue( hdcam, DCAM_IDPROP_MECHANICALSHUTTER, &v ) )
	{
		mode = (long)v;
		return TRUE;
	}

	if( dcamex_getfeature_mechanicalshutter( hdcam, mode ) )
		return TRUE;

	return FALSE;
}

BOOL dcamex_setpropertyvalue_mechanicalshutter( HDCAM hdcam, int32  mode )
{
/*
	if( dcam_setpropertyvalue( hdcam, DCAM_IDPROP_MECHANICALSHUTTER, (double)mode ) )
	{
		return TRUE;
	}
*/
	if( dcamex_setfeature_mechanicalshutter( hdcam, mode ) )
		return TRUE;

	return FALSE;
}
