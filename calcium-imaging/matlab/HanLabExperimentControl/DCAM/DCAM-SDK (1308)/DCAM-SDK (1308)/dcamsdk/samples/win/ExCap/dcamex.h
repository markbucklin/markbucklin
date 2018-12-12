// dcamex.h : DCAM-API helper functions
//

// ----------------------------------------------------------------

long dcamex_getimagewidth( HDCAM hdcam );
long dcamex_getimageheight( HDCAM hdcam );
long dcamex_getcolortype( HDCAM hdcam );
long dcamex_getbitsperchannel( HDCAM hdcam );

BOOL dcamex_is_sensormode_area( HDCAM hdcam );
BOOL dcamex_is_rgbratio_writable( HDCAM hdcam );

BOOL dcamex_getexposuretimerange( HDCAM hdcam, double& max, double& min );

BOOL dcamex_is_internallinerate_writable( HDCAM hdcam );
BOOL dcamex_getinternallineraterange( HDCAM hdcam, double& max, double& min );
BOOL dcamex_getinternallinerate( HDCAM hdcam, double& value );
BOOL dcamex_setinternallinerate( HDCAM hdcam, double value );

// ----------------------------------------------------------------

BOOL dcamex_getreadoutspeedinq( HDCAM hdcam, long& maxspeed );
BOOL dcamex_getreadoutspeed( HDCAM hdcam, long& speed );
BOOL dcamex_setreadoutspeed( HDCAM hdcam, long  speed );

// ----

BOOL dcamex_getfeatureinq( HDCAM hdcam, long idfeature
		, long& capflags
		, double& min
		, double& max
		, double& step
		, double& defaultvalue );
BOOL dcamex_getfeature( HDCAM hdcam, long idfeature, double& featurevalue );
BOOL dcamex_getfeature( HDCAM hdcam, long idfeature, double& featurevalue, long& featureflags );
BOOL dcamex_setfeature( HDCAM hdcam, long idfeature, double featurevalue, long featureflags );
BOOL dcamex_setfeaturevalue( HDCAM hdcam, long idfeature, double featurevalue );
BOOL dcamex_setfeatureflags( HDCAM hdcam, long idfeature, long featureflags );

// ----

BOOL dcamex_getsubarrayrectinq( HDCAM hdcam
	   , long& hposunit, long& hunit, long& hmax
	   , long& vposunit, long& vunit, long& vmax );
BOOL dcamex_getsubarrayrect( HDCAM hdcam, long& left, long& top, long& width, long& height );
BOOL dcamex_setsubarrayrect( HDCAM hdcam, long  left, long  top, long  width, long  height );

// ----------------------------------------------------------------

BOOL dcamex_getproperty_valuemax( HDCAM hdcam, long idprop, long& valuemax );
BOOL dcamex_getproperty_valuemax( HDCAM hdcam, long idprop, double& valuemax );

