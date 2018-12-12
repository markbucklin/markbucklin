// DlgDcamSubarray.cpp : implementation file
//

#include "stdafx.h"
#include "resource.h"
#include "DlgDcamSubarray.h"

#include "ExCapApp.h"
#include "dcamex.h"

#ifdef _DEBUG
#define new DEBUG_NEW
#undef THIS_FILE
static char THIS_FILE[] = __FILE__;
#endif

/////////////////////////////////////////////////////////////////////////////
// CDlgDcamSubarray dialog

CDlgDcamSubarray::CDlgDcamSubarray( CWnd* pParent /*=NULL*/ )
	: CDialog( CDlgDcamSubarray::IDD, pParent )
{
	//{{AFX_DATA_INIT( CDlgDcamSubarray )
	m_nLeft = 0;
	m_nTop = 0;
	m_nWidth = 0;
	m_nHeight = 0;
	//}}AFX_DATA_INIT

	m_hmax		= 0;
	m_vmax		= 0;
	m_hposunit	= 0;
	m_vposunit	= 0;
	m_hunit		= 0;
	m_vunit		= 0;

	m_bCreateDialog = FALSE;
	m_hdcam			= NULL;
}

// ----------------

HDCAM CDlgDcamSubarray::set_hdcam( HDCAM hdcam )
{
	HDCAM	old = m_hdcam;
	m_hdcam = hdcam;

//	update_values();

	if( IsWindow( GetSafeHwnd() ) && IsWindowVisible() )
	{
		setup_controls();
		update_controls();
	}

	return old;
}

BOOL CDlgDcamSubarray::toggle_visible()
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

BOOL CDlgDcamSubarray::Create( CWnd* pParentWnd ) 
{
	// TODO: Add your specialized code here and/or call the base class
	
	m_bCreateDialog = CDialog::Create( IDD, pParentWnd );
	return m_bCreateDialog;
}

// ----------------

void CDlgDcamSubarray::setup_controls()
{
	if( m_hdcam != NULL )
	{
		VERIFY( dcamex_getsubarrayrectinq( m_hdcam, m_hposunit, m_hunit, m_hmax, m_vposunit, m_vunit, m_vmax ) );

		SetDlgItemInt( IDC_DLGDCAMSUBARRAY_TXTHPOSUNIT, m_hposunit );
		SetDlgItemInt( IDC_DLGDCAMSUBARRAY_TXTVPOSUNIT, m_vposunit );
		SetDlgItemInt( IDC_DLGDCAMSUBARRAY_TXTHUNIT, m_hunit );
		SetDlgItemInt( IDC_DLGDCAMSUBARRAY_TXTVUNIT, m_vunit );
		SetDlgItemInt( IDC_DLGDCAMSUBARRAY_TXTHMAX,  m_hmax );
		SetDlgItemInt( IDC_DLGDCAMSUBARRAY_TXTVMAX,  m_vmax );
	}
}

BOOL CDlgDcamSubarray::update_controls()
{
	if( m_hdcam == NULL )
		return FALSE;

	VERIFY( dcamex_getsubarrayrect( m_hdcam, m_nLeft, m_nTop, m_nWidth, m_nHeight ) );

	UpdateData( FALSE );

	return TRUE;
}

// ----------------

void CDlgDcamSubarray::DoDataExchange( CDataExchange* pDX )
{
	CDialog::DoDataExchange( pDX );
	//{{AFX_DATA_MAP( CDlgDcamSubarray )
	DDX_Text( pDX, IDC_DLGDCAMSUBARRAY_EBLEFT, m_nLeft );
	DDX_Text( pDX, IDC_DLGDCAMSUBARRAY_EBTOP, m_nTop );
	DDX_Text( pDX, IDC_DLGDCAMSUBARRAY_EBWIDTH, m_nWidth );
	DDX_Text( pDX, IDC_DLGDCAMSUBARRAY_EBHEIGHT, m_nHeight );

	//}}AFX_DATA_MAP

	if( pDX->m_bSaveAndValidate )
	{
		int		nID = 0;

		if( m_nLeft < 0 || ( m_hmax - m_hunit ) < m_nLeft || ( m_hposunit != 0 && ( m_nLeft % m_hposunit ) != 0 ) )
		{
			nID		= IDC_DLGDCAMSUBARRAY_EBLEFT;
		}
		else
		if( m_nTop  < 0 || ( m_vmax - m_vunit ) < m_nTop  || ( m_vposunit != 0 && ( m_nTop  % m_vposunit ) != 0 ) )
		{
			nID		= IDC_DLGDCAMSUBARRAY_EBTOP;
		}
		else
		if( m_nWidth  < m_hunit || ( m_hmax - m_nLeft ) < m_nWidth || ( m_nWidth  != m_hmax && m_hunit != 0 && ( m_nWidth  % m_hunit ) != 0 ) )
		{
			nID		= IDC_DLGDCAMSUBARRAY_EBWIDTH;
		}
		else
		if( m_nHeight < m_vunit || ( m_vmax - m_nTop ) < m_nHeight || ( m_nHeight != m_vmax && m_vunit != 0 && ( m_nHeight % m_vunit ) != 0 ) )
		{
			nID		= IDC_DLGDCAMSUBARRAY_EBHEIGHT;
		}

		if( nID != 0 )
		{
			pDX->PrepareEditCtrl( nID );
			pDX->Fail();
		}
	}
}


BEGIN_MESSAGE_MAP( CDlgDcamSubarray, CDialog )
	//{{AFX_MSG_MAP( CDlgDcamSubarray )
	ON_WM_DESTROY()
	//}}AFX_MSG_MAP
END_MESSAGE_MAP()

/////////////////////////////////////////////////////////////////////////////
// CDlgDcamSubarray message handlers

BOOL CDlgDcamSubarray::OnInitDialog() 
{
	CDialog::OnInitDialog();

	setup_controls();
	update_controls();

	return TRUE;  // return TRUE unless you set the focus to a control
	              // EXCEPTION: OCX Property Pages should return FALSE
}

void CDlgDcamSubarray::OnDestroy() 
{
	CDialog::OnDestroy();
	
	//  TODO: Add your message handler code here
	m_bCreateDialog	= FALSE;
}


void CDlgDcamSubarray::OnOK() 
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
			if( ! dcamex_setsubarrayrect( m_hdcam, m_nLeft, m_nTop, m_nWidth, m_nHeight ) )
				bFinish = FALSE;

			app->resume_capturing( param );
			app->update_availables();
		}
	}

	if( bFinish )
		DestroyWindow();
}

void CDlgDcamSubarray::OnCancel() 
{
	// TODO: Add extra cleanup here
	
	if( m_bCreateDialog )
		DestroyWindow();
	else
		CDialog::OnCancel();
}

