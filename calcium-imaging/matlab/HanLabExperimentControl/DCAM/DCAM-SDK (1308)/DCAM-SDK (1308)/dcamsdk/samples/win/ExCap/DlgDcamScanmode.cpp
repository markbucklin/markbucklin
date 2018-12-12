// DlgDcamScanmode.cpp : implementation file
//

#include "stdafx.h"
#include "resource.h"
#include "DlgDcamScanmode.h"

#include "dcamex.h"

#include "ExCapApp.h"

#ifdef _DEBUG
#define new DEBUG_NEW
#undef THIS_FILE
static char THIS_FILE[] = __FILE__;
#endif

/////////////////////////////////////////////////////////////////////////////
// CDlgDcamScanmode dialog


CDlgDcamScanmode::CDlgDcamScanmode(CWnd* pParent /*=NULL*/)
	: CDialog(CDlgDcamScanmode::IDD, pParent)
{
	//{{AFX_DATA_INIT(CDlgDcamScanmode)
	//}}AFX_DATA_INIT

	m_bCreateDialog		= FALSE;
	m_hdcam				= NULL;

	m_bChangingEditbox	= FALSE;

	memset( &m_speed, 0, sizeof( m_speed ) );
}

// ----------------

HDCAM CDlgDcamScanmode::set_hdcam( HDCAM hdcam )
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

BOOL CDlgDcamScanmode::toggle_visible()
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

void CDlgDcamScanmode::update_values()
{
	if( m_hdcam == NULL)
		return;

	long	maxspeed;
	VERIFY( dcamex_getreadoutspeedinq( m_hdcam, maxspeed ) );

	m_speed.min = 1;
	m_speed.max = maxspeed;

	long	speed;
	VERIFY( dcamex_getreadoutspeed( m_hdcam, speed ) );

	m_speed.value = speed;
}

void CDlgDcamScanmode::setup_controls()
{
	m_slider.SetRange( m_speed.min, m_speed.max );
}

void CDlgDcamScanmode::update_controls()
{
	m_slider.SetPos( m_speed.value );	

	UpdateData( FALSE );
}

/////////////////////////////////////////////////////////////////////////////

BOOL CDlgDcamScanmode::Create( CWnd* pParentWnd ) 
{
	// TODO: Add your specialized code here and/or call the base class
	
	m_bCreateDialog = CDialog::Create(IDD, pParentWnd);
	return m_bCreateDialog;
}

// ----------------

void CDlgDcamScanmode::DoDataExchange(CDataExchange* pDX)
{
	CDialog::DoDataExchange(pDX);
	//{{AFX_DATA_MAP(CDlgDcamScanmode)
	DDX_Control(pDX, IDC_DLGDCAMSCANMODE_SLIDERSPEED, m_slider);
	//}}AFX_DATA_MAP

	DDX_Text(pDX, IDC_DLGDCAMSCANMODE_EBSPEED, m_speed.value);
	DDV_MinMaxInt(pDX, m_speed.value, m_speed.min, m_speed.max);

	DDX_Text(pDX, IDC_DLGDCAMSCANMODE_TXTMAXSPEED, m_speed.max);
	DDX_Text(pDX, IDC_DLGDCAMSCANMODE_TXTMINSPEED, m_speed.min);
}


BEGIN_MESSAGE_MAP(CDlgDcamScanmode, CDialog)
	//{{AFX_MSG_MAP(CDlgDcamScanmode)
	ON_WM_HSCROLL()
	ON_EN_CHANGE(IDC_DLGDCAMSCANMODE_EBSPEED, OnChangeEbspeed)
	ON_WM_DESTROY()
	//}}AFX_MSG_MAP
END_MESSAGE_MAP()

/////////////////////////////////////////////////////////////////////////////
// CDlgDcamScanmode message handlers

BOOL CDlgDcamScanmode::OnInitDialog() 
{
	CDialog::OnInitDialog();

	update_values();

	setup_controls();
	update_controls();

	return TRUE;  // return TRUE unless you set the focus to a control
	              // EXCEPTION: OCX Property Pages should return FALSE
}

void CDlgDcamScanmode::OnDestroy() 
{
	CDialog::OnDestroy();
	
	//  TODO: Add your message handler code here
	m_bCreateDialog = FALSE;
}

void CDlgDcamScanmode::OnOK() 
{
	// TODO: Add extra validation here
	
	if( ! m_bCreateDialog )
	{
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
			if( ! dcamex_setreadoutspeed( m_hdcam, m_speed.value ) )
				bFinish = FALSE;

			app->resume_capturing( param );
			app->update_availables();
		}
	}

	if( bFinish )
		DestroyWindow();
}

void CDlgDcamScanmode::OnCancel() 
{
	// TODO: Add extra cleanup here
	
	if( m_bCreateDialog )
		DestroyWindow();
	else
		CDialog::OnCancel();
}

void CDlgDcamScanmode::OnHScroll(UINT nSBCode, UINT nPos, CScrollBar* pScrollBar) 
{
	CDialog::OnHScroll(nSBCode, nPos, pScrollBar);

	if( ! m_bChangingEditbox )
	{
		if( pScrollBar == (CScrollBar*)&m_slider )
		{
			int	nowPos = m_slider.GetPos();

			m_bChangingEditbox = TRUE;

			SetDlgItemInt( IDC_DLGDCAMSCANMODE_EBSPEED, nowPos );

			m_bChangingEditbox = FALSE;
		}
	}
}

void CDlgDcamScanmode::OnChangeEbspeed() 
{
	if( ! m_bChangingEditbox )
	{
		int	nMin, nMax;
		m_slider.GetRange( nMin, nMax );

		int	nPos, newPos;
		newPos = GetDlgItemInt( IDC_DLGDCAMSCANMODE_EBSPEED );

		if( newPos < nMin)
			nPos = nMin;
		else
		if( nMax < newPos)
			nPos = nMax;
		else
			nPos = newPos;

		m_bChangingEditbox = TRUE;

		if( nPos != newPos)
			SetDlgItemInt( IDC_DLGDCAMSCANMODE_EBSPEED, nPos );

		m_slider.SetPos( nPos);

		m_bChangingEditbox = FALSE;
	}	
}
