// hdcamsignal.h
//

#ifndef _INCLUDE_DCAMAPI_H_
#error	dcamapi.h must be included
#endif

HDCAMSIGNAL	create_hdcamsignal();
BOOL destroy_hdcamsignal( HDCAMSIGNAL hSignal );
BOOL set_hdcamsignal( HDCAMSIGNAL hSignal );
long wait_hdcamsignal( HDCAMSIGNAL hSignal, _DWORD dwTimeout );

#ifdef DCAM_TARGETOS_IS_WIN32

inline HDCAMSIGNAL create_hdcamsignal()
{
	return CreateEvent( NULL, FALSE, FALSE, NULL );
}

inline BOOL destroy_hdcamsignal( HDCAMSIGNAL hSignal )
{
	return CloseHandle( hSignal );
}

inline BOOL set_hdcamsignal( HDCAMSIGNAL hSignal )
{
	return SetEvent( hSignal );
}

inline long wait_hdcamsignal( HDCAMSIGNAL hSignal, _DWORD dwTimeout )
{
	DWORD	dw = WaitForSingleObject( hSignal, dwTimeout );

	if( dw == WAIT_OBJECT_0 )
		return DCAMERR_SUCCESS;

	if( dw == WAIT_TIMEOUT )
		return DCAMERR_TIMEOUT;

	return DCAMERR_ABORT;
}

#endif // DCAM_TARGETOS_IS_WIN32

#ifdef DCAM_TARGETOS_IS_MACOSX

#ifndef __MULTIPROCESSING__
#error Multiprocessing.h is necessary
#endif

inline HDCAMSIGNAL create_hdcamsignal()
{
	MPEventID	id;
	if( MPCreateEvent( &id ) != noErr )
		return NULL;
	
	return id;
}

inline BOOL destroy_hdcamsignal( HDCAMSIGNAL hSignal )
{
	return MPDeleteEvent( hSignal ) == noErr;
}

inline BOOL set_hdcamsignal( HDCAMSIGNAL hSignal )
{
	return MPSetEvent( hSignal, 1 );
}

inline long wait_hdcamsignal( HDCAMSIGNAL hSignal, _DWORD dwTimeout )
{
	OSErr	dw = MPWaitForEvent( hSignal, NULL, dwTimeout * kDurationMillisecond );

	if( dw == noErr )
		return DCAMERR_SUCCESS;

	if( dw == kMPTimeoutErr )
		return DCAMERR_TIMEOUT;

	return DCAMERR_ABORT;
}

#endif // DCAM_TARGETOS_IS_MACOSX
