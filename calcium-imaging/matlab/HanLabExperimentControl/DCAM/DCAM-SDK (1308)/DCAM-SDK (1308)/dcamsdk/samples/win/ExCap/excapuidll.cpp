// excapuidll.cpp
//

#include "stdafx.h"

#include "excapuidll.h"
#include "excapui.h"

#ifdef _DEBUG
#define new DEBUG_NEW
#undef THIS_FILE
static char THIS_FILE[] = __FILE__;
#endif

// ----------------------------------------------------------------
//

typedef EXCAPUIERR PASCAL EXPORT type_excapui_entry( HDCAM hdcam, UINT iCmd, LONG lparam, void* pparam, long pparambytes );

struct var_excapuidll
{
	HINSTANCE			hLibInst;
	type_excapui_entry*	entry;
};

// ----------------

excapuidll::~excapuidll()
{
	delete m_var_excapuidll;
}

excapuidll::excapuidll()
{
	m_var_excapuidll = new var_excapuidll;
	memset( m_var_excapuidll, 0, sizeof( *m_var_excapuidll ) );
}

static BOOL findfile( LPTSTR path, long nChar, LPCTSTR mask )
{
	BOOL	bRet = FALSE;

	WIN32_FIND_DATA	ff;
	memset( &ff, 0, sizeof( ff ) );

	HANDLE	hFind = FindFirstFile( _T("EXCAPUI*.DLL"), &ff );
	if( hFind != INVALID_HANDLE_VALUE )
	{
		do
		{
			if( ! ( ff.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY ) )
			{
				long	nPath = lstrlen( ff.cFileName ) + 1;
				lstrcpyn( path, ff.cFileName, nPath );
				bRet = TRUE;
				break;
			}
		} while( FindNextFile( hFind, &ff ) );

		FindClose( hFind );
	}

	return bRet;
}

BOOL excapuidll::load_dll()
{
	ASSERT( m_var_excapuidll->hLibInst == NULL );

	TCHAR	path[ MAX_PATH ];
	if( ! findfile( path, MAX_PATH, _T( "EXCAPUI*.DLL" ) ) )
		return FALSE;

	m_var_excapuidll->hLibInst = LoadLibrary( _T( "EXCAPUI.DLL" ) );
	if( m_var_excapuidll->hLibInst != NULL )
	{
		ASSERT( m_var_excapuidll->entry == NULL );
		m_var_excapuidll->entry = (type_excapui_entry*)GetProcAddress( m_var_excapuidll->hLibInst, "excapui_entry" );

		if( m_var_excapuidll->entry != NULL )
		{
			return TRUE;
		}

		FreeLibrary( m_var_excapuidll->hLibInst );
		m_var_excapuidll->hLibInst = NULL;
	}

	return FALSE;
}

BOOL excapuidll::unload_dll()
{
	if( m_var_excapuidll->hLibInst != NULL )
	{
		FreeLibrary( m_var_excapuidll->hLibInst );
		memset( m_var_excapuidll, 0, sizeof( *m_var_excapuidll ) );
	}

	return TRUE;
}

BOOL excapuidll::call_dll( HDCAM hdcam, UINT iCmd, LONG lparam, void* pparam, long pparambytes )
{
	if( m_var_excapuidll->entry == NULL )
		return FALSE;

	EXCAPUIERR	err = (*m_var_excapuidll->entry)( hdcam, iCmd, lparam, pparam, pparambytes );

	return ! failed( err );
}

BOOL excapuidll::query_supportdialog( HDCAM hdcam, long lparam )
{
	return call_dll( hdcam, EXCAPUICMD_QUERYSUPPORTDIALOG, lparam );
}

BOOL excapuidll::modal_dialog( HDCAM hdcam, long lparam )
{
	return call_dll( hdcam, EXCAPUICMD_MODALDIALOG, lparam );
}

BOOL excapuidll::on_open_camera( HDCAM hdcam )
{
	return call_dll( hdcam, EXCAPUICMD_PREPARECAMERA, EXCAPUI_PREPARECAMERA_ONOPEN );
}

BOOL excapuidll::on_close_camera( HDCAM hdcam )
{
	return call_dll( hdcam, EXCAPUICMD_PREPARECAMERA, EXCAPUI_PREPARECAMERA_ONCLOSE );
}
