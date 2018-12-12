// DYNDCAM.C : wrapper for dynamic linking

#include "stdafx.h"

#include "dcamapi.h"

/* ---------------------------------------------------------------- */

typedef int32 DCAMAPI proc_getlasterror( HDCAM h, char* buf, DWORD bytesize );
typedef BOOL DCAMAPI proc_init( void* hInst, int32* pCount, LPCSTR reserved );
typedef BOOL DCAMAPI proc_uninit( void* hInst, LPCSTR reserved );
typedef BOOL DCAMAPI proc_getmodelinfo( int32 index, int32 dwStringID, char* buf, DWORD bytesize );
typedef BOOL DCAMAPI proc_open( HDCAM* ph, int32 index, LPCSTR reserved );
typedef BOOL DCAMAPI proc_close( HDCAM h );
typedef BOOL DCAMAPI proc_getstring( HDCAM h, int32 dwStringID, char* buf, DWORD bytesize );
typedef BOOL DCAMAPI proc_getcapability( HDCAM h, DWORD* pCapability, DWORD dwCapTypeID );
typedef BOOL DCAMAPI proc_getdatatype( HDCAM h, DCAM_DATATYPE* pType );
typedef BOOL DCAMAPI proc_getbitstype( HDCAM h, DCAM_BITSTYPE* pType );
typedef BOOL DCAMAPI proc_setdatatype( HDCAM h, DCAM_DATATYPE type );
typedef BOOL DCAMAPI proc_setbitstype( HDCAM h, DCAM_BITSTYPE type );
typedef BOOL DCAMAPI proc_getdatasize( HDCAM h, SIZE* pSize );
typedef BOOL DCAMAPI proc_getbitssize( HDCAM h, SIZE* pSize );
typedef BOOL DCAMAPI proc_queryupdate( HDCAM h, DWORD* pFlag, DWORD dwReserved );
typedef BOOL DCAMAPI proc_getbinning( HDCAM h, int32* pBinning );
typedef BOOL DCAMAPI proc_getexposuretime( HDCAM h, double* pSec );
typedef BOOL DCAMAPI proc_gettriggermode( HDCAM h, int32* pMode );
typedef BOOL DCAMAPI proc_gettriggerpolarity( HDCAM h, int32* pPolarity );
typedef BOOL DCAMAPI proc_setbinning( HDCAM h, int32 binning );
typedef BOOL DCAMAPI proc_setexposuretime( HDCAM h, double sec );
typedef BOOL DCAMAPI proc_settriggermode( HDCAM h, int32 mode );
typedef BOOL DCAMAPI proc_settriggerpolarity( HDCAM h, int32 polarity );
typedef BOOL DCAMAPI proc_precapture( HDCAM h, DCAM_CAPTUREMODE mode );
typedef BOOL DCAMAPI proc_getdatarange( HDCAM h, int32* pMax, int32* pMin );
typedef BOOL DCAMAPI proc_getdataframebytes( HDCAM h, DWORD* pSize );
typedef BOOL DCAMAPI proc_allocframe( HDCAM h, int32 frame );
typedef BOOL DCAMAPI proc_getframecount( HDCAM h, int32* pFrame );
typedef BOOL DCAMAPI proc_capture( HDCAM h );
typedef BOOL DCAMAPI proc_idle( HDCAM h );
typedef BOOL DCAMAPI proc_wait( HDCAM h, DWORD* pCode, DWORD timeout, HANDLE event );
typedef BOOL DCAMAPI proc_getstatus( HDCAM h, DWORD* pStatus );
typedef BOOL DCAMAPI proc_gettransferinfo( HDCAM h, int32* pNewestFrameIndex, int32* pFrameCount );
typedef BOOL DCAMAPI proc_freeframe( HDCAM h );
typedef BOOL DCAMAPI proc_attachbuffer( HDCAM h, void** pTop, DWORD size );
typedef BOOL DCAMAPI proc_releasebuffer( HDCAM h );
typedef BOOL DCAMAPI proc_lockdata( HDCAM h, void** pTop, int32* pRowbytes, int32 frame );
typedef BOOL DCAMAPI proc_lockbits( HDCAM h, BYTE** pTop, int32* pRowbytes, int32 frame );
typedef BOOL DCAMAPI proc_unlockdata( HDCAM h );
typedef BOOL DCAMAPI proc_unlockbits( HDCAM h );
typedef BOOL DCAMAPI proc_setbitsinputlutrange( HDCAM h, int32 inMax, int32 inMin );
typedef BOOL DCAMAPI proc_setbitsoutputlutrange( HDCAM h, BYTE outMax, BYTE outMin );
typedef BOOL DCAMAPI proc_showpanel( HDCAM h, HWND hWnd, DWORD reserved );
typedef BOOL DCAMAPI proc_extended( HDCAM h, UINT iCmd, LPVOID param, DWORD size );
typedef BOOL DCAMAPI proc_firetrigger( HDCAM h );

/* ---------------------------------------------------------------- */

static HINSTANCE	hDllInstDcamapi;

static struct {
	proc_getlasterror*			getlasterror;
	proc_init*					init;
	proc_uninit*				uninit;
	proc_getmodelinfo*			getmodelinfo;
	proc_open*					open;
	proc_close*					close;
	proc_getstring*				getstring;
	proc_getcapability*			getcapability;
	proc_getdatatype*			getdatatype;
	proc_getbitstype*			getbitstype;
	proc_setdatatype*			setdatatype;
	proc_setbitstype*			setbitstype;
	proc_getdatasize*			getdatasize;
	proc_getbitssize*			getbitssize;
	proc_queryupdate*			queryupdate;
	proc_getbinning*			getbinning;
	proc_getexposuretime*		getexposuretime;
	proc_gettriggermode*		gettriggermode;
	proc_gettriggerpolarity*	gettriggerpolarity;
	proc_setbinning*			setbinning;
	proc_setexposuretime*		setexposuretime;
	proc_settriggermode*		settriggermode;
	proc_settriggerpolarity*	settriggerpolarity;
	proc_precapture*			precapture;
	proc_getdatarange*			getdatarange;
	proc_getdataframebytes*		getdataframebytes;
	proc_allocframe*			allocframe;
	proc_getframecount*			getframecount;
	proc_capture*				capture;
	proc_idle*					idle;
	proc_wait*					wait;
	proc_getstatus*				getstatus;
	proc_gettransferinfo*		gettransferinfo;
	proc_freeframe*				freeframe;
	proc_attachbuffer*			attachbuffer;
	proc_releasebuffer*			releasebuffer;
	proc_lockdata*				lockdata;
	proc_lockbits*				lockbits;
	proc_unlockdata*			unlockdata;
	proc_unlockbits*			unlockbits;
	proc_setbitsinputlutrange*	setbitsinputlutrange;
	proc_setbitsoutputlutrange*	setbitsoutputlutrange;
	proc_showpanel*				showpanel;
	proc_extended*				extended;
	proc_firetrigger*			firetrigger;
} entry;


static BOOL unload_dcamapidll()
{
	if( hDllInstDcamapi == NULL )
	{
		FreeLibrary( hDllInstDcamapi );
		hDllInstDcamapi = NULL;
	}

	memset( &entry, 0, sizeof( entry ) );

	return FALSE;
}

/* ---------------------------------------------------------------- */

int32 DCAMAPI dcam_getlasterror( HDCAM h, char* buf, DWORD bytesize )
{
	if( hDllInstDcamapi == NULL )
	{
		return DCAMERR_NOMODULE;
	}

	if( entry.getlasterror == NULL )
	{
		entry.getlasterror = (proc_getlasterror*)GetProcAddress( hDllInstDcamapi, "dcam_getlasterror" );
		if( entry.getlasterror == NULL )
		{
			unload_dcamapidll();
			return DCAMERR_NOMODULE;
		}
	}

	return entry.getlasterror( h, buf, bytesize );
}

BOOL DCAMAPI dcam_init( void* hInst, int32* pCount, LPCSTR reserved )
{
	if( hDllInstDcamapi == NULL )
	{
		hDllInstDcamapi = LoadLibrary( _T("dcamapi.dll") );
		if( hDllInstDcamapi == NULL )
			return FALSE;
	}

	if( entry.init == NULL )
	{
		entry.init = (proc_init*)GetProcAddress( hDllInstDcamapi, "dcam_init" );
		if( entry.init == NULL )
		{
			FreeLibrary( hDllInstDcamapi );
			hDllInstDcamapi = NULL;

			return FALSE;
		}
	}

	return entry.init( hInst, pCount, reserved );
}

BOOL DCAMAPI dcam_uninit( void* hInst, LPCSTR reserved )
{
	if( hDllInstDcamapi == NULL )
	{
		return TRUE;
	}

	if( entry.uninit == NULL )
	{
		entry.uninit = (proc_uninit*)GetProcAddress( hDllInstDcamapi, "dcam_uninit" );
		if( entry.uninit == NULL )
			return unload_dcamapidll();
	}

	return entry.uninit( hInst, reserved );
}


/* ---------------- */

BOOL DCAMAPI dcam_getmodelinfo( int32 index, int32 dwStringID, char* buf, DWORD bytesize )
{
	if( hDllInstDcamapi == NULL )
		return FALSE;

	if( entry.getmodelinfo == NULL )
	{
		entry.getmodelinfo = (proc_getmodelinfo*)GetProcAddress( hDllInstDcamapi, "dcam_getmodelinfo" );
		if( entry.getmodelinfo == NULL )
			return unload_dcamapidll();
	}

	return entry.getmodelinfo( index, dwStringID, buf, bytesize );
}

/* ---------------- */

BOOL DCAMAPI dcam_open( HDCAM* ph, int32 index, LPCSTR reserved )
{
	if( hDllInstDcamapi == NULL )
		return FALSE;

	if( entry.open == NULL )
	{
		entry.open = (proc_open*)GetProcAddress( hDllInstDcamapi, "dcam_open" );
		if( entry.open == NULL )
			return unload_dcamapidll();
	}

	return entry.open( ph, index, reserved );
}

/* ---------------- */

BOOL DCAMAPI dcam_close( HDCAM h )
{
	if( hDllInstDcamapi == NULL )
		return FALSE;

	if( entry.close == NULL )
	{
		entry.close = (proc_close*)GetProcAddress( hDllInstDcamapi, "dcam_close" );
		if( entry.close == NULL )
			return unload_dcamapidll();
	}

	return entry.close( h );
}

/* ---------------- */

BOOL DCAMAPI dcam_getstring( HDCAM h, int32 dwStringID, char* buf, DWORD bytesize )
{
	if( hDllInstDcamapi == NULL )
		return FALSE;

	if( entry.getstring == NULL )
	{
		entry.getstring = (proc_getstring*)GetProcAddress( hDllInstDcamapi, "dcam_getstring" );
		if( entry.getstring == NULL )
			return unload_dcamapidll();
	}

	return entry.getstring( h, dwStringID, buf, bytesize );
}

/* ---------------- */

BOOL DCAMAPI dcam_getcapability( HDCAM h, DWORD* pCapability, DWORD dwCapTypeID )
{
	if( hDllInstDcamapi == NULL )
		return FALSE;

	if( entry.getcapability == NULL )
	{
		entry.getcapability = (proc_getcapability*)GetProcAddress( hDllInstDcamapi, "dcam_getcapability" );
		if( entry.getcapability == NULL )
			return unload_dcamapidll();
	}

	return entry.getcapability( h, pCapability, dwCapTypeID );
}

/* ---------------- */

BOOL DCAMAPI dcam_getdatatype( HDCAM h, DCAM_DATATYPE* pType )
{
	if( hDllInstDcamapi == NULL )
		return FALSE;

	if( entry.getdatatype == NULL )
	{
		entry.getdatatype = (proc_getdatatype*)GetProcAddress( hDllInstDcamapi, "dcam_getdatatype" );
		if( entry.getdatatype == NULL )
			return unload_dcamapidll();
	}

	return entry.getdatatype( h, pType );
}

/* ---------------- */

BOOL DCAMAPI dcam_getbitstype( HDCAM h, DCAM_BITSTYPE* pType )
{
	if( hDllInstDcamapi == NULL )
		return FALSE;

	if( entry.getbitstype == NULL )
	{
		entry.getbitstype = (proc_getbitstype*)GetProcAddress( hDllInstDcamapi, "dcam_getbitstype" );
		if( entry.getbitstype == NULL )
			return unload_dcamapidll();
	}

	return entry.getbitstype( h, pType );
}

/* ---------------- */

BOOL DCAMAPI dcam_setdatatype( HDCAM h, DCAM_DATATYPE type )
{
	if( hDllInstDcamapi == NULL )
		return FALSE;

	if( entry.setdatatype == NULL )
	{
		entry.setdatatype = (proc_setdatatype*)GetProcAddress( hDllInstDcamapi, "dcam_setdatatype" );
		if( entry.setdatatype == NULL )
			return unload_dcamapidll();
	}

	return entry.setdatatype( h, type );
}

/* ---------------- */

BOOL DCAMAPI dcam_setbitstype( HDCAM h, DCAM_BITSTYPE type )
{
	if( hDllInstDcamapi == NULL )
		return FALSE;

	if( entry.setbitstype == NULL )
	{
		entry.setbitstype = (proc_setbitstype*)GetProcAddress( hDllInstDcamapi, "dcam_setbitstype" );
		if( entry.setbitstype == NULL )
			return unload_dcamapidll();
	}

	return entry.setbitstype( h, type );
}

/* ---------------- */

BOOL DCAMAPI dcam_getdatasize( HDCAM h, SIZE* pSize )
{
	if( hDllInstDcamapi == NULL )
		return FALSE;

	if( entry.getdatasize == NULL )
	{
		entry.getdatasize = (proc_getdatasize*)GetProcAddress( hDllInstDcamapi, "dcam_getdatasize" );
		if( entry.getdatasize == NULL )
			return unload_dcamapidll();
	}

	return entry.getdatasize( h, pSize );
}

/* ---------------- */

BOOL DCAMAPI dcam_getbitssize( HDCAM h, SIZE* pSize )
{
	if( hDllInstDcamapi == NULL )
		return FALSE;

	if( entry.getbitssize == NULL )
	{
		entry.getbitssize = (proc_getbitssize*)GetProcAddress( hDllInstDcamapi, "dcam_getbitssize" );
		if( entry.getbitssize == NULL )
			return unload_dcamapidll();
	}

	return entry.getbitssize( h, pSize );
}

/* ---------------- */

BOOL DCAMAPI dcam_queryupdate( HDCAM h, DWORD* pFlag, DWORD dwReserved )
{
	if( hDllInstDcamapi == NULL )
		return FALSE;

	if( entry.queryupdate == NULL )
	{
		entry.queryupdate = (proc_queryupdate*)GetProcAddress( hDllInstDcamapi, "dcam_queryupdate" );
		if( entry.queryupdate == NULL )
			return unload_dcamapidll();
	}

	return entry.queryupdate( h, pFlag, dwReserved );
}

/* ---------------- */

BOOL DCAMAPI dcam_getbinning( HDCAM h, int32* pBinning )
{
	if( hDllInstDcamapi == NULL )
		return FALSE;

	if( entry.getbinning == NULL )
	{
		entry.getbinning = (proc_getbinning*)GetProcAddress( hDllInstDcamapi, "dcam_getbinning" );
		if( entry.getbinning == NULL )
			return unload_dcamapidll();
	}

	return entry.getbinning( h, pBinning );
}

/* ---------------- */

BOOL DCAMAPI dcam_getexposuretime( HDCAM h, double* pSec )
{
	if( hDllInstDcamapi == NULL )
		return FALSE;

	if( entry.getexposuretime == NULL )
	{
		entry.getexposuretime = (proc_getexposuretime*)GetProcAddress( hDllInstDcamapi, "dcam_getexposuretime" );
		if( entry.getexposuretime == NULL )
			return unload_dcamapidll();
	}

	return entry.getexposuretime( h, pSec );
}

/* ---------------- */

BOOL DCAMAPI dcam_gettriggermode( HDCAM h, int32* pMode )
{
	if( hDllInstDcamapi == NULL )
		return FALSE;

	if( entry.gettriggermode == NULL )
	{
		entry.gettriggermode = (proc_gettriggermode*)GetProcAddress( hDllInstDcamapi, "dcam_gettriggermode" );
		if( entry.gettriggermode == NULL )
			return unload_dcamapidll();
	}

	return entry.gettriggermode( h, pMode );
}

/* ---------------- */

BOOL DCAMAPI dcam_gettriggerpolarity( HDCAM h, int32* pPolarity )
{
	if( hDllInstDcamapi == NULL )
		return FALSE;

	if( entry.gettriggerpolarity == NULL )
	{
		entry.gettriggerpolarity = (proc_gettriggerpolarity*)GetProcAddress( hDllInstDcamapi, "dcam_gettriggerpolarity" );
		if( entry.gettriggerpolarity == NULL )
			return unload_dcamapidll();
	}

	return entry.gettriggerpolarity( h, pPolarity );
}

/* ---------------- */

BOOL DCAMAPI dcam_setbinning( HDCAM h, int32 binning )
{
	if( hDllInstDcamapi == NULL )
		return FALSE;

	if( entry.setbinning == NULL )
	{
		entry.setbinning = (proc_setbinning*)GetProcAddress( hDllInstDcamapi, "dcam_setbinning" );
		if( entry.setbinning == NULL )
			return unload_dcamapidll();
	}

	return entry.setbinning( h, binning );
}

/* ---------------- */

BOOL DCAMAPI dcam_setexposuretime( HDCAM h, double sec )
{
	if( hDllInstDcamapi == NULL )
		return FALSE;

	if( entry.setexposuretime == NULL )
	{
		entry.setexposuretime = (proc_setexposuretime*)GetProcAddress( hDllInstDcamapi, "dcam_setexposuretime" );
		if( entry.setexposuretime == NULL )
			return unload_dcamapidll();
	}

	return entry.setexposuretime( h, sec );
}

/* ---------------- */

BOOL DCAMAPI dcam_settriggermode( HDCAM h, int32 mode )
{
	if( hDllInstDcamapi == NULL )
		return FALSE;

	if( entry.settriggermode == NULL )
	{
		entry.settriggermode = (proc_settriggermode*)GetProcAddress( hDllInstDcamapi, "dcam_settriggermode" );
		if( entry.settriggermode == NULL )
			return unload_dcamapidll();
	}

	return entry.settriggermode( h, mode );
}

/* ---------------- */

BOOL DCAMAPI dcam_settriggerpolarity( HDCAM h, int32 polarity )
{
	if( hDllInstDcamapi == NULL )
		return FALSE;

	if( entry.settriggerpolarity == NULL )
	{
		entry.settriggerpolarity = (proc_settriggerpolarity*)GetProcAddress( hDllInstDcamapi, "dcam_settriggerpolarity" );
		if( entry.settriggerpolarity == NULL )
			return unload_dcamapidll();
	}

	return entry.settriggerpolarity( h, polarity );
}

/* ---------------- */

BOOL DCAMAPI dcam_precapture( HDCAM h, DCAM_CAPTUREMODE mode )
{
	if( hDllInstDcamapi == NULL )
		return FALSE;

	if( entry.precapture == NULL )
	{
		entry.precapture = (proc_precapture*)GetProcAddress( hDllInstDcamapi, "dcam_precapture" );
		if( entry.precapture == NULL )
			return unload_dcamapidll();
	}

	return entry.precapture( h, mode );
}

/* ---------------- */

BOOL DCAMAPI dcam_getdatarange( HDCAM h, int32* pMax, int32* pMin )
{
	if( hDllInstDcamapi == NULL )
		return FALSE;

	if( entry.getdatarange == NULL )
	{
		entry.getdatarange = (proc_getdatarange*)GetProcAddress( hDllInstDcamapi, "dcam_getdatarange" );
		if( entry.getdatarange == NULL )
			return unload_dcamapidll();
	}

	return entry.getdatarange( h, pMax, pMin );
}

/* ---------------- */

BOOL DCAMAPI dcam_getdataframebytes( HDCAM h, DWORD* pSize )
{
	if( hDllInstDcamapi == NULL )
		return FALSE;

	if( entry.getdataframebytes == NULL )
	{
		entry.getdataframebytes = (proc_getdataframebytes*)GetProcAddress( hDllInstDcamapi, "dcam_getdataframebytes" );
		if( entry.getdataframebytes == NULL )
			return unload_dcamapidll();
	}

	return entry.getdataframebytes( h, pSize );
}

/* ---------------- */

BOOL DCAMAPI dcam_allocframe( HDCAM h, int32 frame )
{
	if( hDllInstDcamapi == NULL )
		return FALSE;

	if( entry.allocframe == NULL )
	{
		entry.allocframe = (proc_allocframe*)GetProcAddress( hDllInstDcamapi, "dcam_allocframe" );
		if( entry.allocframe == NULL )
			return unload_dcamapidll();
	}

	return entry.allocframe( h, frame );
}

/* ---------------- */

BOOL DCAMAPI dcam_getframecount( HDCAM h, int32* pFrame )
{
	if( hDllInstDcamapi == NULL )
		return FALSE;

	if( entry.getframecount == NULL )
	{
		entry.getframecount = (proc_getframecount*)GetProcAddress( hDllInstDcamapi, "dcam_getframecount" );
		if( entry.getframecount == NULL )
			return unload_dcamapidll();
	}

	return entry.getframecount( h, pFrame );
}

/* ---------------- */

BOOL DCAMAPI dcam_capture( HDCAM h )
{
	if( hDllInstDcamapi == NULL )
		return FALSE;

	if( entry.capture == NULL )
	{
		entry.capture = (proc_capture*)GetProcAddress( hDllInstDcamapi, "dcam_capture" );
		if( entry.capture == NULL )
			return unload_dcamapidll();
	}

	return entry.capture( h );
}

/* ---------------- */

BOOL DCAMAPI dcam_idle( HDCAM h )
{
	if( hDllInstDcamapi == NULL )
		return FALSE;

	if( entry.idle == NULL )
	{
		entry.idle = (proc_idle*)GetProcAddress( hDllInstDcamapi, "dcam_idle" );
		if( entry.idle == NULL )
			return unload_dcamapidll();
	}

	return entry.idle( h );
}

/* ---------------- */

BOOL DCAMAPI dcam_wait( HDCAM h, DWORD* pCode, DWORD timeout, HANDLE event )
{
	if( hDllInstDcamapi == NULL )
		return FALSE;

	if( entry.wait == NULL )
	{
		entry.wait = (proc_wait*)GetProcAddress( hDllInstDcamapi, "dcam_wait" );
		if( entry.wait == NULL )
			return unload_dcamapidll();
	}

	return entry.wait( h, pCode, timeout, event );
}

/* ---------------- */

BOOL DCAMAPI dcam_getstatus( HDCAM h, DWORD* pStatus )
{
	if( hDllInstDcamapi == NULL )
		return FALSE;

	if( entry.getstatus == NULL )
	{
		entry.getstatus = (proc_getstatus*)GetProcAddress( hDllInstDcamapi, "dcam_getstatus" );
		if( entry.getstatus == NULL )
			return unload_dcamapidll();
	}

	return entry.getstatus( h, pStatus );
}

/* ---------------- */

BOOL DCAMAPI dcam_gettransferinfo( HDCAM h, int32* pNewestFrameIndex, int32* pFrameCount )
{
	if( hDllInstDcamapi == NULL )
		return FALSE;

	if( entry.gettransferinfo == NULL )
	{
		entry.gettransferinfo = (proc_gettransferinfo*)GetProcAddress( hDllInstDcamapi, "dcam_gettransferinfo" );
		if( entry.gettransferinfo == NULL )
			return unload_dcamapidll();
	}

	return entry.gettransferinfo( h, pNewestFrameIndex, pFrameCount );
}

/* ---------------- */

BOOL DCAMAPI dcam_freeframe( HDCAM h )
{
	if( hDllInstDcamapi == NULL )
		return FALSE;

	if( entry.freeframe == NULL )
	{
		entry.freeframe = (proc_freeframe*)GetProcAddress( hDllInstDcamapi, "dcam_freeframe" );
		if( entry.freeframe == NULL )
			return unload_dcamapidll();
	}

	return entry.freeframe( h );
}

/* ---------------- */

BOOL DCAMAPI dcam_attachbuffer( HDCAM h, void** pTop, DWORD size )
{
	if( hDllInstDcamapi == NULL )
		return FALSE;

	if( entry.attachbuffer == NULL )
	{
		entry.attachbuffer = (proc_attachbuffer*)GetProcAddress( hDllInstDcamapi, "dcam_attachbuffer" );
		if( entry.attachbuffer == NULL )
			return unload_dcamapidll();
	}

	return entry.attachbuffer( h, pTop, size );
}

/* ---------------- */

BOOL DCAMAPI dcam_releasebuffer( HDCAM h )
{
	if( hDllInstDcamapi == NULL )
		return FALSE;

	if( entry.releasebuffer == NULL )
	{
		entry.releasebuffer = (proc_releasebuffer*)GetProcAddress( hDllInstDcamapi, "dcam_releasebuffer" );
		if( entry.releasebuffer == NULL )
			return unload_dcamapidll();
	}

	return entry.releasebuffer( h );
}

/* ---------------- */

BOOL DCAMAPI dcam_lockdata( HDCAM h, void** pTop, int32* pRowbytes, int32 frame )
{
	if( hDllInstDcamapi == NULL )
		return FALSE;

	if( entry.lockdata == NULL )
	{
		entry.lockdata = (proc_lockdata*)GetProcAddress( hDllInstDcamapi, "dcam_lockdata" );
		if( entry.lockdata == NULL )
			return unload_dcamapidll();
	}

	return entry.lockdata( h, pTop, pRowbytes, frame );
}

/* ---------------- */

BOOL DCAMAPI dcam_lockbits( HDCAM h, BYTE** pTop, int32* pRowbytes, int32 frame )
{
	if( hDllInstDcamapi == NULL )
		return FALSE;

	if( entry.lockbits == NULL )
	{
		entry.lockbits = (proc_lockbits*)GetProcAddress( hDllInstDcamapi, "dcam_lockbits" );
		if( entry.lockbits == NULL )
			return unload_dcamapidll();
	}

	return entry.lockbits( h, pTop, pRowbytes, frame );
}

/* ---------------- */

BOOL DCAMAPI dcam_unlockdata( HDCAM h )
{
	if( hDllInstDcamapi == NULL )
		return FALSE;

	if( entry.unlockdata == NULL )
	{
		entry.unlockdata = (proc_unlockdata*)GetProcAddress( hDllInstDcamapi, "dcam_unlockdata" );
		if( entry.unlockdata == NULL )
			return unload_dcamapidll();
	}

	return entry.unlockdata( h );
}

/* ---------------- */

BOOL DCAMAPI dcam_unlockbits( HDCAM h )
{
	if( hDllInstDcamapi == NULL )
		return FALSE;

	if( entry.unlockbits == NULL )
	{
		entry.unlockbits = (proc_unlockbits*)GetProcAddress( hDllInstDcamapi, "dcam_unlockbits" );
		if( entry.unlockbits == NULL )
			return unload_dcamapidll();
	}

	return entry.unlockbits( h );
}

/* ---------------- */

BOOL DCAMAPI dcam_setbitsinputlutrange( HDCAM h, int32 inMax, int32 inMin )
{
	if( hDllInstDcamapi == NULL )
		return FALSE;

	if( entry.setbitsinputlutrange == NULL )
	{
		entry.setbitsinputlutrange = (proc_setbitsinputlutrange*)GetProcAddress( hDllInstDcamapi, "dcam_setbitsinputlutrange" );
		if( entry.setbitsinputlutrange == NULL )
			return unload_dcamapidll();
	}

	return entry.setbitsinputlutrange( h, inMax, inMin );
}

/* ---------------- */

BOOL DCAMAPI dcam_setbitsoutputlutrange( HDCAM h, BYTE outMax, BYTE outMin )
{
	if( hDllInstDcamapi == NULL )
		return FALSE;

	if( entry.setbitsoutputlutrange == NULL )
	{
		entry.setbitsoutputlutrange = (proc_setbitsoutputlutrange*)GetProcAddress( hDllInstDcamapi, "dcam_setbitsoutputlutrange" );
		if( entry.setbitsoutputlutrange == NULL )
			return unload_dcamapidll();
	}

	return entry.setbitsoutputlutrange( h, outMax, outMin );
}

/* ---------------- */

BOOL DCAMAPI dcam_showpanel( HDCAM h, HWND hWnd, DWORD reserved )
{
	if( hDllInstDcamapi == NULL )
		return FALSE;

	if( entry.showpanel == NULL )
	{
		entry.showpanel = (proc_showpanel*)GetProcAddress( hDllInstDcamapi, "dcam_showpanel" );
		if( entry.showpanel == NULL )
			return unload_dcamapidll();
	}

	return entry.showpanel( h, hWnd, reserved );
}

/* ---------------- */

BOOL DCAMAPI dcam_extended( HDCAM h, UINT iCmd, LPVOID param, DWORD size )
{
	if( hDllInstDcamapi == NULL )
		return FALSE;

	if( entry.extended == NULL )
	{
		entry.extended = (proc_extended*)GetProcAddress( hDllInstDcamapi, "dcam_extended" );
		if( entry.extended == NULL )
			return unload_dcamapidll();
	}

	return entry.extended( h, iCmd, param, size );
}

/* ---------------- */

BOOL DCAMAPI dcam_firetrigger( HDCAM h )
{
	if( hDllInstDcamapi == NULL )
		return FALSE;

	if( entry.firetrigger == NULL )
	{
		entry.firetrigger = (proc_firetrigger*)GetProcAddress( hDllInstDcamapi, "dcam_firetrigger" );
		if( entry.firetrigger == NULL )
			return unload_dcamapidll();
	}

	return entry.firetrigger( h );
}

/* ---------------- */
