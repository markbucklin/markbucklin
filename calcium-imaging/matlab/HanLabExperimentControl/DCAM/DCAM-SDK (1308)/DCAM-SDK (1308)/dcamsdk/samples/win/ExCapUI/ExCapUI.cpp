// ExCapUI.cpp : Defines the initialization routines for the DLL.
//

#include "stdafx.h"
#include "ExCapUI.h"

#ifdef _DEBUG
#define new DEBUG_NEW
#undef THIS_FILE
static char THIS_FILE[] = __FILE__;
#endif

	BOOL is_type_of( const char* pattern, const char* target )
	{
		for( int i = 0; pattern[i] != '\0' && pattern[i] != '*'; i++ )
		{
			if( pattern[i] == '?' )
				continue;

			if( pattern[i] == '#' && isdigit( target[ i ] ) )
				continue;

			if( pattern[i] != target[i] )
				return FALSE;
		}
		return TRUE;
	}


/////////////////////////////////////////////////////////////////////////////

#define	CRLF	_T( "\x0d\x0a" )

void	show_dcamerrorbox(HDCAM hdcam, const char* function)
{
	char	buf[ 256 ];
	memset( buf, 0, sizeof( buf ) );

	long	err	= dcam_getlasterror( hdcam, buf, sizeof( buf ) );
	CString	strErr( buf );

	CString	str;
	str.Format( _T( "error code 0x%08X" ) CRLF _T( "%s" ), err, (LPCTSTR)strErr );

	CString	strTitle;
	strTitle = function;

	::MessageBox (NULL, str, strTitle, MB_ICONERROR | MB_OK);
}

/////////////////////////////////////////////////////////////////////////////
// DCAMSTRINGS
//

DCAMSTRINGS::~DCAMSTRINGS()
{
	if( m_model	!= NULL )	delete m_model;
	if( m_ver		!= NULL )	delete m_ver;
}

DCAMSTRINGS::DCAMSTRINGS()
{
	m_model = NULL;
	m_ver = NULL;
}

void DCAMSTRINGS::safe_strdup( char*& dst, const char* src )
{
	if( dst == NULL )
		delete dst;

	if( src == NULL )
	{
		dst = NULL;
	}
	else
	{
		size_t	len = strlen( src ) + 1;
		dst = new char[ len ];
		memcpy( dst, src, len );
	}
}

EXCAPUIERR DCAMSTRINGS::initialize( HDCAM hdcam )
{
	char	buf[ 256 ];

	if( ! dcam_getstring( hdcam, DCAM_IDSTR_MODEL, buf, sizeof(buf) ) )
	{
		ASSERT( 0 );
		return EXCAPUIERR_NOTSUPPORT;
	}
	safe_strdup( m_model, buf );

	if( ! dcam_getstring( hdcam, DCAM_IDSTR_CAMERAVERSION, buf, sizeof(buf) ) )
	{
		ASSERT( 0 );
		return EXCAPUIERR_NOTSUPPORT;
	}
	safe_strdup( m_ver, buf );

	return EXCAPUIERR_SUCCESS;
}

BOOL DCAMSTRINGS::is_model( const char* pattern ) const
{
	return is_type_of( pattern, m_model );
}

BOOL DCAMSTRINGS::is_equal_or_newer_than( const char* ver ) const
{
	return _stricmp( m_ver, ver ) >= 0;
}

/////////////////////////////////////////////////////////////////////////////
// CExCapUIApp
//

class CExCapUIApp : public CWinApp
{
public:
	CExCapUIApp();

// Overrides
	// ClassWizard generated virtual function overrides
	//{{AFX_VIRTUAL(CExCapUIApp)
	//}}AFX_VIRTUAL

	//{{AFX_MSG(CExCapUIApp)
		// NOTE - the ClassWizard will add and remove member functions here.
		//    DO NOT EDIT what you see in these blocks of generated code !
	//}}AFX_MSG
	DECLARE_MESSAGE_MAP()

public:
	virtual	EXCAPUIERR	query_supportdialog( HDCAM hdcam, long param = 0 );
	virtual	EXCAPUIERR	modal_dialog( HDCAM hdcam, long param = 0 );
	virtual	EXCAPUIERR	preparecamera( HDCAM hdcam, long param );
};

/////////////////////////////////////////////////////////////////////////////
// CExCapUIApp

BEGIN_MESSAGE_MAP(CExCapUIApp, CWinApp)
	//{{AFX_MSG_MAP(CExCapUIApp)
		// NOTE - the ClassWizard will add and remove mapping macros here.
		//    DO NOT EDIT what you see in these blocks of generated code!
	//}}AFX_MSG_MAP
END_MESSAGE_MAP()

/////////////////////////////////////////////////////////////////////////////
// CExCapUIApp construction

CExCapUIApp::CExCapUIApp()
{
	// TODO: add construction code here,
	// Place all significant initialization in InitInstance
}

/////////////////////////////////////////////////////////////////////////////
// UI support

#include "uiOrca.h"
#include "uiXline.h"
EXCAPUIERR CExCapUIApp::query_supportdialog( HDCAM hdcam, long param )
{
	ASSERT( param == 0 );

	EXCAPUIERR	err;

	DCAMSTRINGS	strs;
	err = strs.initialize( hdcam );		if( failed( err ) )		return err;

	err = uiOrca_query_supportdialog_setup( strs );
	if( err != EXCAPUIERR_UNKNOWNCAMERA )
		return err;

	err = uiXline_query_supportdialog_setup( strs );
	if( err != EXCAPUIERR_UNKNOWNCAMERA )
		return err;

	return EXCAPUIERR_NOTSUPPORT;
}

EXCAPUIERR CExCapUIApp::modal_dialog( HDCAM hdcam, long param )
{
	EXCAPUIERR	err;

	DCAMSTRINGS	strs;
	err = strs.initialize( hdcam );		if( failed( err ) )		return err;

	err = uiOrca_modal_dialog_setup( hdcam, strs );
	if( err != EXCAPUIERR_UNKNOWNCAMERA )
		return err;

	err = uiXline_modal_dialog_setup( hdcam, strs );
	if( err != EXCAPUIERR_UNKNOWNCAMERA )
		return err;

	return EXCAPUIERR_NOTSUPPORT;
}

EXCAPUIERR CExCapUIApp::preparecamera( HDCAM hdcam, long param )
{
	return EXCAPUIERR_NOTSUPPORT;
}

/////////////////////////////////////////////////////////////////////////////
// The one and only CExCapUIApp object

CExCapUIApp theApp;

/////////////////////////////////////////////////////////////////////////////
// ExCapUI entry

//
//TODO: If this DLL is dynamically linked against the MFC DLLs,
//		any functions exported from this DLL which call into
//		MFC must have the AFX_MANAGE_STATE macro added at the
//		very beginning of the function.
//
//		For example:
//
//		extern "C" BOOL PASCAL EXPORT ExportedFunction()
//		{
//			AFX_MANAGE_STATE(AfxGetStaticModuleState());
//			// normal function body here
//		}
//
//		It is very important that this macro appear in each
//		function, prior to any calls into MFC.  This means that
//		it must appear as the first statement within the 
//		function, even before any object variable declarations
//		as their constructors may generate calls into the MFC
//		DLL.
//
//		Please see MFC Technical Notes 33 and 58 for additional
//		details.
//


extern "C" EXCAPUIERR PASCAL EXPORT excapui_entry( HDCAM hdcam, UINT iCmd, LONG lparam, void* pparam, long pparambytes )
{
	AFX_MANAGE_STATE(AfxGetStaticModuleState());

	switch( iCmd )
	{
	case EXCAPUICMD_QUERYSUPPORTDIALOG:
		// in: HDCAM, lParam = 0 reserved, out: none, 
		if( hdcam == NULL )		return EXCAPUIERR_INVALIDHDCAM;
		if( lparam != 0 )		return EXCAPUIERR_INVALIDLPARAM;

		return theApp.query_supportdialog( hdcam );

	case EXCAPUICMD_MODALDIALOG:
		// in: HDCAM, lParam = 0 reserved, out: none, 
		if( hdcam == NULL )		return EXCAPUIERR_INVALIDHDCAM;
		if( lparam != 0 )		return EXCAPUIERR_INVALIDLPARAM;

		return theApp.modal_dialog( hdcam, lparam );

	case EXCAPUICMD_PREPARECAMERA:
		// in: HDCAM, lParam = EXCAPUI_PREPAREACAMERA_*, out: none,
		if( hdcam == NULL )		return EXCAPUIERR_INVALIDHDCAM;

		return theApp.preparecamera( hdcam, lparam );

	default:
		ASSERT( 0 );
		return EXCAPUIERR_UNKNOWNCMD;
	}
}
