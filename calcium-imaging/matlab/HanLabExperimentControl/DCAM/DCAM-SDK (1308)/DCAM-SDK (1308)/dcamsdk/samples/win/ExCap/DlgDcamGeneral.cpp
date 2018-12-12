// DlgDcamGeneral.cpp : implementation file
//

#include "stdafx.h"
#include "resource.h"
#include "DlgDcamGeneral.h"

#include "ExCapApp.h"
#include "mainfrm.h"
#include "showdcamerr.h"

#ifdef _DEBUG
#define new DEBUG_NEW
#undef THIS_FILE
static char THIS_FILE[] = __FILE__;
#endif

/////////////////////////////////////////////////////////////////////////////
// CDlgDcamGeneral dialog

CDlgDcamGeneral::CDlgDcamGeneral(CWnd* pParent /*=NULL*/ )
	: CDialog(CDlgDcamGeneral::IDD, pParent )
{
	//{{AFX_DATA_INIT(CDlgDcamGeneral )
	m_nBinning = -1;
	m_nTriggerMode = -1;
	m_nTriggerPolarity = -1;
	m_fExposureTime = 0.0;
	m_bAutoAdjustExposureTime = FALSE;
	//}}AFX_DATA_INIT

	m_bCreateDialog			= FALSE;
	m_hdcam					= NULL;

	m_dwCapability = 0;
	m_bModifiedBinning			= FALSE;
	m_bModifiedExposureTime		= FALSE;
	m_bModifiedTriggerMode		= FALSE;
	m_bModifiedTriggerPolarity	= FALSE;
}

// ----------------

HDCAM CDlgDcamGeneral::set_hdcam( HDCAM hdcam )
{
	HDCAM	old = m_hdcam;
	m_hdcam = hdcam;

	update_values();

	if( IsWindow( GetSafeHwnd() ) && IsWindowVisible() )
	{
		setup_controls();
		update_controls();
	}

	return old;
}

BOOL CDlgDcamGeneral::toggle_visible()
{
	if( ! IsWindow( GetSafeHwnd() ) )
	{
		if( ! Create() )
		{
			ASSERT( 0 );
			return FALSE;
		}
	}
	else
	if( IsWindowVisible() )
	{
		ShowWindow( SW_HIDE );
	}
	else
	{
		SetWindowPos( &CWnd::wndTop, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_SHOWWINDOW );
	}

	return TRUE;
}

void CDlgDcamGeneral::update_values()
{
	if( m_hdcam == NULL )
	{
		m_dwCapability		= 0;
		m_nBinning			= 0;
		m_nTriggerMode		= 0;
		m_nTriggerPolarity	= 0;
		m_fExposureTime		= 0;
	}
	else
	{
		VERIFY( dcam_getcapability(		m_hdcam, &m_dwCapability, 0	) );
		VERIFY( dcam_getbinning(		m_hdcam, &m_nBinning		) );
		VERIFY( dcam_gettriggermode(	m_hdcam, &m_nTriggerMode	) );
				dcam_gettriggerpolarity(m_hdcam, &m_nTriggerPolarity);	// if the camera does not support external trigger mode, this can return FALSE.
				dcam_getexposuretime(	m_hdcam, &m_fExposureTime	);	// if the camera does not support exopsure time, this can return FALSE.

		update_binning_capability();
	}
}

// ----------------

long insert_with_order( CDWordArray& a, DWORD vNew )
{
	int	i, n = (int) a.GetSize();
	for( i = 0; i < n; i++ )
	{
		DWORD	v = a.GetAt( i );
		if( v > vNew )
			break;

		if( v == vNew )
			return i;
	}

	a.InsertAt( i, vNew );
	return i;
}

long text2array( LPCTSTR p, CDWordArray& a )
{
	long	n = 0;
	do {
		// skip non digit charactors
		while( *p && ! isdigit( *p ) )
			p++;

		if( *p == '\0' )
			break;

		// get number
		long	v = atoi( p );
		a.Add( v );
		n++;

		// skip digit charactors
		while( *p && isdigit( *p ) )
			p++;

	} while( *p );

	return n;
}

void CDlgDcamGeneral::update_binning_capability()
{
	m_arrayBinning.RemoveAll();

	// all camera supports 1x1 binning
	insert_with_order( m_arrayBinning, 1 );

	if( m_dwCapability & DCAM_CAPABILITY_BINNING2 )			insert_with_order( m_arrayBinning, 2 );
	if( m_dwCapability & DCAM_CAPABILITY_BINNING4 )			insert_with_order( m_arrayBinning, 4 );
	if( m_dwCapability & DCAM_CAPABILITY_BINNING6 )			insert_with_order( m_arrayBinning, 6 );
	if( m_dwCapability & DCAM_CAPABILITY_BINNING8 )			insert_with_order( m_arrayBinning, 8 );
	if( m_dwCapability & DCAM_CAPABILITY_BINNING12)			insert_with_order( m_arrayBinning, 12 );
	if( m_dwCapability & DCAM_CAPABILITY_BINNING16)			insert_with_order( m_arrayBinning, 16 );
	if( m_dwCapability & DCAM_CAPABILITY_BINNING32)			insert_with_order( m_arrayBinning, 32 );

	CString	str;
	str = AfxGetApp()->GetProfileString( _T( "General" ), _T( "binning" ) );

	long	i, n;
	CDWordArray	array;
	n = text2array( str, array );

	for( i = 0; i < n; i++ )
	{
		insert_with_order( m_arrayBinning, array.GetAt( i ) );
	}
}

/////////////////////////////////////////////////////////////////////////////

BOOL CDlgDcamGeneral::Create( CWnd* pParentWnd ) 
{
	// TODO: Add your specialized code here and/or call the base class
	
	m_bCreateDialog = CDialog::Create(IDD, pParentWnd );
	return m_bCreateDialog;
}

// ----

inline void append_item( CComboBox& cb, LPCTSTR txt, DWORD data )
{
	int	i = cb.AddString( txt );
	cb.SetItemData( i, data );
}

inline void select_item( CComboBox& cb, int32 data )
{
	int	i, n;

	n = cb.GetCount();
	cb.EnableWindow( n > 0 );
	for( i = 0; i < n; i++ )
	{
		if( cb.GetItemData( i ) == (DWORD_PTR)data )
		{
			cb.SetCurSel( i );
			return;
		}
	}
}

inline long get_selected_data( CComboBox& cb )
{
	return (long) cb.GetItemData( cb.GetCurSel() );
}

// ----------------

void CDlgDcamGeneral::setup_controls()
{
	m_cbBinning.ResetContent();
	m_cbTrigMode.ResetContent();
	m_cbTrigPol.ResetContent();

	if( m_hdcam == NULL )
	{
		m_cbBinning.ResetContent();
		m_cbTrigMode.ResetContent();
		m_cbTrigPol.ResetContent();
		m_ebExposure.SetWindowText( _T( "" ) );
	}
	else
	{
		// binning
		INT_PTR	i, n;

		n = m_arrayBinning.GetSize();
		for( i = 0; i < n; i++ )
		{
			DWORD	nBinning = m_arrayBinning.GetAt( i );
			CString	str;
			if( nBinning < 100 )
				str.Format( _T( "%dx%d" ), nBinning, nBinning );
			else
				str.Format( _T( "%dx%d" ), nBinning / 100, nBinning % 100 );

			append_item( m_cbBinning, str, nBinning );
		}

		// trigger mode
		append_item( m_cbTrigMode, _T( "Internal" ), DCAM_TRIGMODE_INTERNAL );

		if( m_dwCapability & DCAM_CAPABILITY_TRIGGER_EDGE )				append_item( m_cbTrigMode, _T( "External Edge" ),		DCAM_TRIGMODE_EDGE );
		if( m_dwCapability & DCAM_CAPABILITY_TRIGGER_LEVEL )			append_item( m_cbTrigMode, _T( "External Level" ),		DCAM_TRIGMODE_LEVEL );
		if( m_dwCapability & DCAM_CAPABILITY_TRIGGER_SOFTWARE )			append_item( m_cbTrigMode, _T( "Software" ),			DCAM_TRIGMODE_SOFTWARE );
		if( m_dwCapability & DCAM_CAPABILITY_TRIGGER_FASTREPETITION )	append_item( m_cbTrigMode, _T( "Fast Repetition" ),		DCAM_TRIGMODE_FASTREPETITION );
		if( m_dwCapability & DCAM_CAPABILITY_TRIGGER_TDI )				append_item( m_cbTrigMode, _T( "TDI" ),					DCAM_TRIGMODE_TDI );
		if( m_dwCapability & DCAM_CAPABILITY_TRIGGER_TDIINTERNAL )		append_item( m_cbTrigMode, _T( "TDI internal" ),		DCAM_TRIGMODE_TDIINTERNAL );
		if( m_dwCapability & DCAM_CAPABILITY_TRIGGER_START )			append_item( m_cbTrigMode, _T( "Start" ),				DCAM_TRIGMODE_START );
		if( m_dwCapability & DCAM_CAPABILITY_TRIGGER_SYNCREADOUT )		append_item( m_cbTrigMode, _T( "Synchronous readout" ), DCAM_TRIGMODE_SYNCREADOUT );

		// trigger polarity
		if( m_dwCapability & DCAM_CAPABILITY_TRIGGER_NEGA )	append_item( m_cbTrigPol, _T( "Negative" ),	DCAM_TRIGPOL_NEGATIVE );
		if( m_dwCapability & DCAM_CAPABILITY_TRIGGER_POSI )	append_item( m_cbTrigPol, _T( "Positive" ),	DCAM_TRIGPOL_POSITIVE );
	}

	m_cbBinning. EnableWindow( m_cbBinning. GetCount() > 0 );
	m_cbTrigMode.EnableWindow( m_cbTrigMode.GetCount() > 0 );
	m_cbTrigPol. EnableWindow( m_cbTrigPol. GetCount() > 0 );
	m_cbTrigPol. EnableWindow( m_cbTrigPol. GetCount() > 0 );
	m_ebExposure.EnableWindow( m_hdcam != NULL );
}

void CDlgDcamGeneral::update_controls()
{
	if( m_hdcam != NULL )
	{
		select_item( m_cbBinning,  m_nBinning );
		select_item( m_cbTrigMode, m_nTriggerMode );
		select_item( m_cbTrigPol,  m_nTriggerPolarity );

		CString	str;
		str.Format( _T( "%g" ), m_fExposureTime );
		SetDlgItemText( IDC_DLGDCAMGENERAL_EBEXPOSURE, str );
	}

	m_bModifiedBinning			= FALSE;
	m_bModifiedExposureTime		= FALSE;
	m_bModifiedTriggerMode		= FALSE;
	m_bModifiedTriggerPolarity	= FALSE;
}

// ----------------

void CDlgDcamGeneral::DoDataExchange(CDataExchange* pDX )
{
	CDialog::DoDataExchange(pDX );
	//{{AFX_DATA_MAP(CDlgDcamGeneral )
	DDX_Control(pDX, IDC_DLGDCAMGENERAL_EBEXPOSURE, m_ebExposure);
	DDX_Control(pDX, IDC_DLGDCAMGENERAL_CBTRIGPOL, m_cbTrigPol );
	DDX_Control(pDX, IDC_DLGDCAMGENERAL_CBTRIGMODE, m_cbTrigMode );
	DDX_Control(pDX, IDC_DLGDCAMGENERAL_CBBINNING, m_cbBinning );
	DDX_Text(pDX, IDC_DLGDCAMGENERAL_EBEXPOSURE, m_fExposureTime );
	DDX_Check(pDX, IDC_DLGDCAMGENERAL_BTNADJUSTEXPOTIME, m_bAutoAdjustExposureTime );
	//}}AFX_DATA_MAP
}

BEGIN_MESSAGE_MAP(CDlgDcamGeneral, CDialog )
	//{{AFX_MSG_MAP(CDlgDcamGeneral )
	ON_WM_DESTROY()
	ON_EN_CHANGE(IDC_DLGDCAMGENERAL_EBEXPOSURE, OnChangeEbExposure )
	ON_CBN_SELCHANGE(IDC_DLGDCAMGENERAL_CBBINNING, OnSelchangeGeneralCbBinning )
	ON_BN_CLICKED(IDC_DLGDCAMGENERAL_BTNADJUSTEXPOTIME, OnGeneralBtnAdjustExpotime )
	ON_CBN_SELCHANGE(IDC_DLGDCAMGENERAL_CBTRIGMODE, OnSelchangeDlgdcamgeneralCbtrigmode)
	ON_CBN_SELCHANGE(IDC_DLGDCAMGENERAL_CBTRIGPOL, OnSelchangeDlgdcamgeneralCbtrigpol)
	//}}AFX_MSG_MAP
END_MESSAGE_MAP()

/////////////////////////////////////////////////////////////////////////////
// CDlgDcamGeneral message handler

BOOL CDlgDcamGeneral::OnInitDialog() 
{
	CDialog::OnInitDialog();

	update_values();

	setup_controls();
	update_controls();

	return TRUE;  // return TRUE unless you set the focus to a control
	              // EXCEPTION: OCX Property Pages should return FALSE
}

void CDlgDcamGeneral::OnDestroy() 
{
	CDialog::OnDestroy();
	
	//  TODO: Add your message handler code here

	m_bCreateDialog = FALSE;
}

void CDlgDcamGeneral::OnOK() 
{
	// TODO: Add extra validation here
	
	if( ! m_bCreateDialog )
	{
		// If this dialog is called from CWnd::DoModal(), the main routine should set 
		CDialog::OnOK();
		return;
	}

	if( ! UpdateData() )
		return;

	BOOL	bFinish = TRUE;

	// update variables
	m_nBinning = get_selected_data( m_cbBinning );
	m_nTriggerMode	= get_selected_data( m_cbTrigMode );
	m_nTriggerPolarity	= get_selected_data( m_cbTrigPol );

	if( m_bModifiedBinning
	 || m_bModifiedExposureTime
	 || m_bModifiedTriggerMode
	 || m_bModifiedTriggerPolarity )
	{
		// set parameter to camera.

		CExCapApp*	app = afxGetApp();

		long	param = app->suspend_capturing();
		if( param == 0 )
		{
			// error happens in suspend_capturing();
			bFinish = FALSE;
		}
		else
		{
			if( m_bModifiedBinning
			 && ! dcam_setbinning( m_hdcam, m_nBinning ) )
			{
				show_dcamerrorbox( m_hdcam, "dcam_setbinning()" );
				bFinish = FALSE;
			}

			if( m_bModifiedTriggerMode
			 && ! dcam_settriggermode( m_hdcam, m_nTriggerMode ) )
			{
				show_dcamerrorbox( m_hdcam, "dcam_settriggermode()" );
				bFinish = FALSE;
			}

			if( m_bModifiedTriggerPolarity
			 && ! dcam_settriggerpolarity( m_hdcam, m_nTriggerPolarity ) )
			{
				show_dcamerrorbox( m_hdcam, "dcam_settriggerpolarity()" );
				bFinish = FALSE;
			}

			if( m_bModifiedExposureTime
			 && ! dcam_setexposuretime( m_hdcam, m_fExposureTime ) )
			{
				show_dcamerrorbox( m_hdcam, "dcam_setexposuretime()" );
				bFinish = FALSE;
			}

			app->resume_capturing( param );
			app->update_availables();
		}
	}

	if( bFinish )
		DestroyWindow();
}

void CDlgDcamGeneral::OnCancel() 
{
	// TODO: Add extra cleanup here	
	if( m_bCreateDialog )
		DestroyWindow();
	else
		CDialog::OnCancel();
}

void CDlgDcamGeneral::OnSelchangeGeneralCbBinning() 
{
	m_bModifiedBinning	= TRUE;

	if( m_bAutoAdjustExposureTime )
	{
		CString	str;
		GetDlgItemText( IDC_DLGDCAMGENERAL_EBEXPOSURE, str );

		double	expo = atof( str );

		expo *= m_nBinning * m_nBinning;

		m_nBinning	= get_selected_data( m_cbBinning );

		expo /= m_nBinning * m_nBinning;

		str.Format( _T( "%g" ), expo );
		SetDlgItemText( IDC_DLGDCAMGENERAL_EBEXPOSURE, str );
	}	
}

void CDlgDcamGeneral::OnGeneralBtnAdjustExpotime() 
{
	m_bAutoAdjustExposureTime = ! m_bAutoAdjustExposureTime;
}

void CDlgDcamGeneral::OnChangeEbExposure() 
{
	m_bModifiedExposureTime = TRUE;
}

void CDlgDcamGeneral::OnSelchangeDlgdcamgeneralCbtrigmode() 
{
	m_bModifiedTriggerMode = TRUE;
}

void CDlgDcamGeneral::OnSelchangeDlgdcamgeneralCbtrigpol() 
{
	m_bModifiedTriggerPolarity = TRUE;
}
