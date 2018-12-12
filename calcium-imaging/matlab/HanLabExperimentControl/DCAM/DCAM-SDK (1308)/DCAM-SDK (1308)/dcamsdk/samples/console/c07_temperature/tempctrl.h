/* tempctrl.h */

BOOL dcamex_setpropertyvalue_sensorcooler( HDCAM hdcam, int32 mode );
BOOL dcamex_getpropertyvalue_sensorcooler( HDCAM hdcam, int32& mode );
BOOL dcamex_querypropertyvalue_sensorcooler( HDCAM hdcam, int32 mode );

BOOL dcamex_getpropertyvalue_sensortemperaturetarget( HDCAM hdcam, double& fTemp);

BOOL dcamex_getpropertyvalue_sensortemperature( HDCAM hdcam, double& fTemp);
