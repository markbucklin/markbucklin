// ExCapApp.cpp : Defines the class behaviors for the application.
//

#include "stdafx.h"
#include "ExCap.h"
#include "ExCapApp.h"
#include "MainFrm.h"

#include "ChildFrm.h"
#include "ExCapDoc.h"
#include "ExCapView.h"

#include "DlgDcamAbout.h"
#include "DlgDcamOpen.h"
#include "DlgDcamProperty.h"
#include "DlgExcapLUT.h"

#include "DlgDcamGeneral.h"
#include "DlgDcamScanmode.h"
#include "DlgDcamSubarray.h"
#include "DlgDcamFeatures.h"
#include "DlgDcamRGBRatio.h"
#include "DlgDcamInterval.h"
#include "DlgExcapFramerate.h"
#include "DlgExcapStatus.h"

#include "dcamex.h"
#include "luttable.h"
#include "excapuidll.h"

#ifdef _DEBUG
#define new DEBUG_NEW
#endif


/////////////////////////////////////////////////////////////////////////////
// inlines

inline BOOL is_window_visible( CWnd* pWnd )
{
	return IsWindow( pWnd->GetSafeHwnd() ) && pWnd->IsWindowVisible();
}

inline void destroy_dialog( CDialog* pDlg )
{
	if( IsWindow( pDlg->GetSafeHwnd() ) )
		pDlg->DestroyWindow();
}

/////////////////////////////////////////////////////////////////////////////
// CExCapApp

IMPLEMENT_DYNAMIC(CExCapApp, CWinApp)

BEGIN_MESSAGE_MAP(CExCapApp, CWinApp)
	//{{AFX_MSG_MAP(CExCapApp)
	ON_COMMAND(ID_APP_ABOUT, OnAppAbout)
	ON_UPDATE_COMMAND_UI(ID_SETUP_PROPERTIES, OnUpdateSetupProperties)
	ON_COMMAND(ID_SETUP_PROPERTIES, OnSetupProperties)
	ON_UPDATE_COMMAND_UI(ID_SETUP_GENERAL, OnUpdateSetupGeneral)
	ON_COMMAND(ID_SETUP_GENERAL, OnSetupGeneral)
	ON_UPDATE_COMMAND_UI(ID_SETUP_SCANMODE, OnUpdateSetupScanmode)
	ON_COMMAND(ID_SETUP_SCANMODE, OnSetupScanmode)
	ON_UPDATE_COMMAND_UI(ID_SETUP_SUBARRAY, OnUpdateSetupSubarray)
	ON_COMMAND(ID_SETUP_SUBARRAY, OnSetupSubarray)
	ON_UPDATE_COMMAND_UI(ID_SETUP_FEATURES, OnUpdateSetupFeatures)
	ON_COMMAND(ID_SETUP_FEATURES, OnSetupFeatures)
	ON_UPDATE_COMMAND_UI(ID_SETUP_RGBRATIO, OnUpdateSetupRgbratio)
	ON_COMMAND(ID_SETUP_RGBRATIO, OnSetupRgbratio)
	ON_COMMAND(ID_SETUP_INTERVAL, OnSetupInterval)
	ON_UPDATE_COMMAND_UI(ID_SETUP_INTERVAL, OnUpdateSetupInterval)
	ON_COMMAND(ID_VIEW_LUT, OnViewLut)
	ON_UPDATE_COMMAND_UI(ID_VIEW_LUT, OnUpdateViewLut)
	ON_COMMAND(ID_VIEW_FRAMERATE, OnViewFramerate)
	ON_UPDATE_COMMAND_UI(ID_VIEW_FRAMERATE, OnUpdateViewFramerate)
	ON_COMMAND(ID_VIEW_STATUS, OnViewStatus)
	ON_UPDATE_COMMAND_UI(ID_VIEW_STATUS, OnUpdateViewStatus)
	//}}AFX_MSG_MAP
	// Standard file based document commands
	ON_COMMAND(ID_FILE_NEW, CWinApp::OnFileNew)
	ON_COMMAND(ID_FILE_OPEN, CWinApp::OnFileOpen)
END_MESSAGE_MAP()


// CExCapApp construction

CExCapApp::~CExCapApp()
{
	if( m_excapuidll	!= NULL )	delete m_excapuidll;

	if( m_dlg.property	!= NULL )	delete m_dlg.property;
	if( m_dlg.lut		!= NULL )	delete m_dlg.lut;
	if( m_dlg.framerate	!= NULL )	delete m_dlg.framerate;
	if( m_dlg.status	!= NULL )	delete m_dlg.status;

	if( m_dlg.general	!= NULL )	delete m_dlg.general;
	if( m_dlg.scanmode	!= NULL )	delete m_dlg.scanmode;
	if( m_dlg.subarray	!= NULL )	delete m_dlg.subarray;
	if( m_dlg.features	!= NULL )	delete m_dlg.features;
	if( m_dlg.rgbratio	!= NULL )	delete m_dlg.rgbratio;
	if( m_dlg.interval	!= NULL )	delete m_dlg.interval;
}

CExCapApp::CExCapApp()
{
	memset( &m_active, 0, sizeof( m_active ) );
	memset( &m_dlg, 0, sizeof( m_dlg ) );
	memset( &m_available, 0, sizeof( m_available ) );

	// initialize dialogs
	m_dlg.property	= new CDlgDcamProperty;
	m_dlg.lut		= new CDlgExcapLUT;
	m_dlg.framerate	= new CDlgExcapFramerate;
	m_dlg.status	= new CDlgExcapStatus;

	m_dlg.general	= new CDlgDcamGeneral;
	m_dlg.scanmode	= new CDlgDcamScanmode;
	m_dlg.subarray	= new CDlgDcamSubarray;
	m_dlg.features	= new CDlgDcamFeatures;
	m_dlg.rgbratio	= new CDlgDcamRGBRatio;
	m_dlg.interval	= new CDlgDcamInterval;

	m_excapuidll	= new excapuidll;
}


// The one and only CExCapApp object

CExCapApp theApp;


// CExCapApp initialization

BOOL CExCapApp::InitInstance()
{
#if _MFC_VER <= 0x0600
	AfxOleInit();
#else
	// InitCommonControlsEx() is required on Windows XP if an application
	// manifest specifies use of ComCtl32.dll version 6 or later to enable
	// visual styles.  Otherwise, any window creation will fail.
	INITCOMMONCONTROLSEX InitCtrls;
	InitCtrls.dwSize = sizeof(InitCtrls);
	// Set this to include all the common control classes you want to use
	// in your application.
	InitCtrls.dwICC = ICC_WIN95_CLASSES;
	InitCommonControlsEx(&InitCtrls);

	CWinApp::InitInstance();
#endif
	// Standard initialization
	// If you are not using these features and wish to reduce the size
	// of your final executable, you should remove from the following
	// the specific initialization routines you do not need.

	// Change the registry key under which our settings are stored.
	// TODO: You should modify this string to be something appropriate
	// such as the name of your company or organization.
	SetRegistryKey(_T("Hamamatsu"));
	LoadStdProfileSettings();  // Load standard INI file options (including MRU)

	{
		CString	str;
		str = GetProfileString( _T("Settings"), _T("option.dcaminit"), _T(DCAMINIT_DEFAULT) );
#ifdef _UNICODE
		::WideCharToMultiByte(CP_THREAD_ACP, 0, str, str.GetLength()+1, m_option.dcaminit, sizeof(m_option.dcaminit), NULL, NULL );
#else
		strcpy_s( m_option.dcaminit, sizeof(m_option.dcaminit), str );
#endif
	}

	// Register the application's document templates.  Document templates
	//  serve as the connection between documents, frame windows and views.

	m_excapuidll->load_dll();

	CMultiDocTemplate* pDocTemplate;
	pDocTemplate = new CMultiDocTemplate(
		IDR_EXCAPTYPE,
		RUNTIME_CLASS(CExCapDoc),
		RUNTIME_CLASS(CChildFrame), // custom MDI child frame
		RUNTIME_CLASS(CExCapView));
	if (!pDocTemplate)
		return FALSE;
	AddDocTemplate(pDocTemplate);

	// create main MDI Frame window
	CMainFrame* pMainFrame = new CMainFrame;
	if (!pMainFrame || !pMainFrame->LoadFrame(IDR_MAINFRAME))
	{
		delete pMainFrame;
		return FALSE;
	}
	m_pMainWnd = pMainFrame;
	// call DragAcceptFiles only if there's a suffix
	//  In an MDI app, this should occur immediately after setting m_pMainWnd

	// Parse command line for standard shell commands, DDE, file open
	CCommandLineInfo cmdInfo;
	ParseCommandLine(cmdInfo);
//	if( cmdInfo.m_nShellCommand == CCommandLineInfo::FileNew )
//		cmdInfo.m_nShellCommand = CCommandLineInfo::FileNothing;

	// Dispatch commands specified on the command line.  Will return FALSE if
	// app was launched with /RegServer, /Register, /Unregserver or /Unregister.
	if (!ProcessShellCommand(cmdInfo))
		return FALSE;

	// The main window has been initialized, so show and update it
	pMainFrame->ShowWindow(m_nCmdShow);
	pMainFrame->UpdateWindow();
	// Enable drag/drop open
	pMainFrame->DragAcceptFiles();

	return TRUE;
}

// CExCapApp message handlers

int CExCapApp::ExitInstance() 
{
	m_excapuidll->unload_dll();

	// Destroy dialogs
	destroy_dialog( m_dlg.property );
	destroy_dialog( m_dlg.lut );
	destroy_dialog( m_dlg.framerate );
	destroy_dialog( m_dlg.status );

	destroy_dialog( m_dlg.general  );
	destroy_dialog( m_dlg.scanmode );
	destroy_dialog( m_dlg.subarray );
	destroy_dialog( m_dlg.features );
	destroy_dialog( m_dlg.rgbratio );
	destroy_dialog( m_dlg.interval );

	return CWinApp::ExitInstance();
}

void CExCapApp::get_active_objects( HDCAM& hdcam, CExCapDoc*& doc, luttable*& lut ) const
{
	hdcam	= m_active.hdcam;
	doc		= m_active.docForHDCAM;
	lut		= m_active.lut;
}

void CExCapApp::set_active_objects( HDCAM hdcam, CExCapDoc* doc, luttable* lut ) 
{
	if( m_active.hdcam != hdcam
	 || m_active.docForHDCAM != doc )
	{
		m_active.hdcam = hdcam;
		m_active.docForHDCAM = doc;

		if( hdcam == NULL )
		{
			memset( m_active.dcamapiver, 0, sizeof( m_active.dcamapiver ) );
			memset( m_active.cameraname, 0, sizeof( m_active.cameraname ) );
		}
		else
		{
			dcam_getstring( hdcam, DCAM_IDSTR_DCAMAPIVERSION, m_active.dcamapiver, sizeof( m_active.dcamapiver ) );
			dcam_getstring( hdcam, DCAM_IDSTR_MODEL,          m_active.cameraname, sizeof( m_active.cameraname ) );
		}

		m_dlg.status->set_hdcamdoc( hdcam, doc );

		m_dlg.property ->set_hdcam( hdcam );
		m_dlg.framerate->set_hdcam( hdcam );
		m_dlg.subarray ->set_hdcam( hdcam );

		m_dlg.general ->set_hdcam( hdcam );
		m_dlg.scanmode->set_hdcam( hdcam );
		m_dlg.features->set_hdcam( hdcam );
		m_dlg.rgbratio->set_hdcam( hdcam );
		m_dlg.interval->set_hdcam( hdcam );
	}

	if( m_active.lut != lut )
	{
		m_active.lut = lut;
		m_dlg.lut->set_luttable( lut );
	}
}

void CExCapApp::update_availables() 
{
	m_available.property	= ( _stricmp( m_active.dcamapiver, "3.0" ) >= 0 );
	m_available.framerate	= TRUE;
	m_available.status		= TRUE;

	m_available.general		= TRUE;

	long	maxspeed;
	m_available.scanmode	= ( dcamex_getreadoutspeedinq( m_active.hdcam, maxspeed ) && maxspeed > 1 );

	m_available.subarray	= TRUE;
	m_available.features	= TRUE;
	m_available.rgbratio	= dcamex_is_rgbratio_writable( m_active.hdcam );
	m_available.interval	= dcamex_is_internallinerate_writable( m_active.hdcam );
}

void CExCapApp::on_close_document( CExCapDoc* doc )
{
	ASSERT( doc != NULL );
	if( m_active.docForHDCAM == doc )
	{
		set_active_objects( NULL, NULL, NULL );
		update_availables();
	}
}

long CExCapApp::suspend_capturing()
{
	if( m_active.docForHDCAM == NULL )
		return 0;

	return m_active.docForHDCAM->suspend_capturing();
}

void CExCapApp::resume_capturing( long param )
{
	if( m_active.docForHDCAM != NULL )
		m_active.docForHDCAM->resume_capturing( param );
}

long CExCapApp::number_of_visible_controldialogs()
{
	long	nShown = 0;

	if( is_window_visible( m_dlg.property ) )	nShown++;
	if( is_window_visible( m_dlg.general ) )	nShown++;
	if( is_window_visible( m_dlg.scanmode ) )	nShown++;
	if( is_window_visible( m_dlg.subarray ) )	nShown++;
	if( is_window_visible( m_dlg.features ) )	nShown++;
	if( is_window_visible( m_dlg.rgbratio ) )	nShown++;
	if( is_window_visible( m_dlg.interval ) )	nShown++;

	return nShown;
}

BOOL CExCapApp::query_supportdialog( HDCAM hdcam, long lparam )
{
	return m_excapuidll->query_supportdialog( hdcam, lparam );
}

BOOL CExCapApp::modal_dialog( HDCAM hdcam )
{
	return m_excapuidll->modal_dialog( hdcam, 0 );
}

BOOL CExCapApp::on_open_camera( HDCAM hdcam )
{
	return m_excapuidll->on_open_camera( hdcam );
}

BOOL CExCapApp::on_close_camera( HDCAM hdcam )
{
	return m_excapuidll->on_close_camera( hdcam );
}

const char* CExCapApp::get_dcaminit_option() const
{
	return m_option.dcaminit;
}

/////////////////////////////////////////////////////////////////////////////
// CExCapApp message handlers

void CExCapApp::OnAppAbout() 
{
	// TODO: Add your command handler code here
	
	CDlgDcamAbout	dlg( m_active.hdcam );

	dlg.DoModal();
}


void CExCapApp::OnUpdateSetup(CCmdUI* pCmdUI, CDialog* dlg, BOOL bAvailable ) 
{
	BOOL	bEnable = FALSE;
	BOOL	bCheck	= FALSE;

	if( dlg != NULL && m_active.hdcam != NULL )
	{
		long	nShown = number_of_visible_controldialogs();

		if( is_window_visible( dlg ) )
		{
			ASSERT( nShown > 0 );
			nShown--;
			bCheck = TRUE;
		}

		if( nShown == 0 )
			bEnable = bAvailable;
	}

	pCmdUI->Enable( bEnable );
	pCmdUI->SetCheck( bCheck );
}

// ----

void CExCapApp::OnUpdateSetupProperties(CCmdUI* pCmdUI) 
{
	OnUpdateSetup( pCmdUI, m_dlg.property, m_available.property );
}

void CExCapApp::OnSetupProperties() 
{
	ASSERT( m_dlg.property != NULL );
	m_dlg.property->toggle_visible();
}

void CExCapApp::OnUpdateSetupGeneral(CCmdUI* pCmdUI) 
{
	OnUpdateSetup( pCmdUI, m_dlg.general, m_available.general );
}

void CExCapApp::OnSetupGeneral() 
{
	ASSERT( m_dlg.general != NULL );
	m_dlg.general->toggle_visible();
}

void CExCapApp::OnUpdateSetupScanmode(CCmdUI* pCmdUI) 
{
	OnUpdateSetup( pCmdUI, m_dlg.scanmode, m_available.scanmode );
}

void CExCapApp::OnSetupScanmode() 
{
	ASSERT( m_dlg.scanmode != NULL );
	m_dlg.scanmode->toggle_visible();
}

void CExCapApp::OnUpdateSetupSubarray(CCmdUI* pCmdUI) 
{
	OnUpdateSetup( pCmdUI, m_dlg.subarray, m_available.subarray );
}

void CExCapApp::OnSetupSubarray() 
{
	ASSERT( m_dlg.subarray != NULL );
	m_dlg.subarray->toggle_visible();
}

void CExCapApp::OnUpdateSetupFeatures(CCmdUI* pCmdUI) 
{
	OnUpdateSetup( pCmdUI, m_dlg.features, m_available.features );
}

void CExCapApp::OnSetupFeatures() 
{
	ASSERT( m_dlg.features != NULL );
	m_dlg.features->toggle_visible();
}

void CExCapApp::OnUpdateSetupRgbratio(CCmdUI* pCmdUI) 
{
	OnUpdateSetup( pCmdUI, m_dlg.rgbratio, m_available.rgbratio );
}

void CExCapApp::OnSetupRgbratio() 
{
	ASSERT( m_dlg.rgbratio != NULL );
	m_dlg.rgbratio->toggle_visible();
}

void CExCapApp::OnUpdateSetupInterval(CCmdUI* pCmdUI) 
{
	OnUpdateSetup( pCmdUI, m_dlg.interval, m_available.interval );
}

void CExCapApp::OnSetupInterval() 
{
	ASSERT( m_dlg.interval != NULL );
	m_dlg.interval->toggle_visible();
}

void CExCapApp::OnUpdateViewLut(CCmdUI* pCmdUI) 
{
	pCmdUI->Enable( m_active.lut != NULL );
}

void CExCapApp::OnViewLut() 
{
	ASSERT( m_dlg.lut != NULL );
	m_dlg.lut->toggle_visible();
}

void CExCapApp::OnUpdateViewFramerate(CCmdUI* pCmdUI) 
{
	pCmdUI->Enable( m_available.framerate );
	pCmdUI->SetCheck( m_dlg.framerate->is_visible() );
}

void CExCapApp::OnViewFramerate() 
{
	ASSERT( m_dlg.framerate != NULL );
	m_dlg.framerate->toggle_visible();
}

void CExCapApp::OnUpdateViewStatus(CCmdUI* pCmdUI) 
{
	pCmdUI->Enable( m_available.status );
	pCmdUI->SetCheck( m_dlg.status->is_visible() );
}

void CExCapApp::OnViewStatus() 
{
	ASSERT( m_dlg.status != NULL );
	m_dlg.status->toggle_visible();
}
