// showdcamerr.cpp
//

#include "stdafx.h"

#ifdef _DEBUG
#define new DEBUG_NEW
#undef THIS_FILE
static char THIS_FILE[] = __FILE__;
#endif

#define	CRLF	"\x0d\x0a"

/////////////////////////////////////////////////////////////////////////////

void show_dcamerrorbox( HDCAM hdcam, const char* function )
{
	char	msg[ 256 ];
	memset( msg, 0, sizeof( msg ) );

	long	err = dcam_getlasterror( hdcam, msg, sizeof( msg ) );

	char	buf[ 256 ];
	sprintf_s( buf, sizeof( buf ), "error code 0x%08X" CRLF "%s", err, msg );

	CString	str;
	str = buf;

	CString	strTitle;
	strTitle = function;

	::MessageBox( NULL, str, strTitle, MB_ICONERROR | MB_OK );
}
