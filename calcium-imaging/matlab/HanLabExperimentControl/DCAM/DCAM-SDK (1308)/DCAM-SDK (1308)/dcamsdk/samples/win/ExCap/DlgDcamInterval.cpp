// DlgDcamInterval.cpp : implementation file
//

#include "stdafx.h"
#include "resource.h"
#include "DlgDcamInterval.h"
#include "dcamex.h"

#ifdef _DEBUG
#define new DEBUG_NEW
#undef THIS_FILE
static char THIS_FILE[] = __FILE__;
#endif

inline long map2long( long lMin, long lMax, double fMin, double fMax, double fValue )
{
	if( fMin == fMax )
	{
		if( fValue < fMin )
			return lMin;
		else
			return lMax;
	}
	else
	{
		return long( ( fValue - fMin ) * ( lMax - lMin ) / ( fMax - fMin ) ) + lMin;
	}
}

inline double map2double( double fMin, double fMax, long lMin, long lMax, long lValue )
{
	if( lMin == lMax )
	{
		if( lValue < lMin )
			return fMin;
		else
			return fMax;
	}
	else
	{
		return ( lValue - lMin ) * ( fMax - fMin ) / ( lMax - lMin ) + fMin;
	}
}

/////////////////////////////////////////////////////////////////////////////
// CDlgDcamInterval dialog


CDlgDcamInterval::CDlgDcamInterval(CWnd* pParent /*=NULL*/)
	: CDialog(CDlgDcamInterval::IDD, pParent)
{
	//{{AFX_DATA_INIT(CDlgDcamInterval)
		// NOTE: the ClassWizard will add member initialization here
	//}}AFX_DATA_INIT

	m_bCreateDialog			= FALSE;
	m_hdcam					= NULL;

	memset( &m_linerate, 0, sizeof( m_linerate ) );
	memset( &m_exposure, 0, sizeof( m_exposure ) );
}

// ----------------

HDCAM CDlgDcamInterval::set_hdcam( HDCAM hdcam )
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

BOOL CDlgDcamInterval::toggle_visible()
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

void CDlgDcamInterval::update_values()
{
	if( m_hdcam == NULL )
		return;

	if( ! dcam_getexposuretime( m_hdcam, &m_exposure.value ) )
	{
		m_exposure.bAvailable = FALSE;
	}
	else
	{
		m_exposure.bAvailable = TRUE;
	}

	if( m_exposure.bAvailable )
	{
		VERIFY( dcamex_getexposuretimerange( m_hdcam, m_exposure.max, m_exposure.min ) );

		m_exposure.barmax = 32767;
		m_exposure.barmin = 0;
	}

	if( dcamex_getinternallineraterange( m_hdcam, m_linerate.max, m_linerate.min )
	 && dcamex_getinternallinerate( m_hdcam, m_linerate.value ) )
	{
		m_linerate.bAvailable = TRUE;
	}
	else
	{
		m_linerate.bAvailable = FALSE;
	}
	m_linerate.barmax = 32767;
	m_linerate.barmin = 0;
}

/////////////////////////////////////////////////////////////////////////////

BOOL CDlgDcamInterval::Create( CWnd* pParentWnd ) 
{
	// TODO: Add your specialized code here and/or call the base class
	
	m_bCreateDialog = CDialog::Create(IDD, pParentWnd );
	return m_bCreateDialog;
}

void CDlgDcamInterval::setup_controls()
{
	m_ebExposure.EnableWindow( m_exposure.bAvailable );
	m_sliderExposure.EnableWindow( m_exposure.bAvailable );
	if( m_exposure.bAvailable )
		m_sliderExposure.SetRange( m_exposure.barmin, m_exposure.barmax );
	
	m_ebLinerate.EnableWindow( m_linerate.bAvailable );
	m_sliderLinerate.EnableWindow( m_linerate.bAvailable );

	if( m_linerate.bAvailable )
		m_sliderLinerate.SetRange( m_linerate.barmin, m_linerate.barmax );
}

void CDlgDcamInterval::update_controls()
{
	CString	str;
	long	pos;

	str.Format( _T( "%g" ), m_exposure.value );
	m_ebExposure.SetWindowText( str );
	pos = map2long( m_exposure.barmin, m_exposure.barmax, m_exposure.min, m_exposure.max, m_exposure.value );
	m_sliderExposure.SetPos( pos );

	if( m_linerate.bAvailable )
	{
		pos = map2long( m_linerate.barmin, m_linerate.barmax, m_linerate.min, m_linerate.max, m_linerate.value );
		m_sliderLinerate.SetPos( pos );
		str.Format( _T( "%g" ), m_linerate.value );
	}
	else
	{
		str.Empty();
	}
	m_ebLinerate.SetWindowText( str );
}

/////////////////////////////////////////////////////////////////////////////
// helper functions

BOOL CDlgDcamInterval::GetDlgItemDbl( int nID, double& fValue )
{
	TCHAR	buf[ 256 ];
	GetDlgItemText( nID, buf, sizeof( buf ) );

	fValue = atof( buf );
	return buf[ 0 ] != '\0';
}

void CDlgDcamInterval::SetDlgItemDbl( int nID, double fValue )
{
	CString	str;
	str.Format( _T( "%lg" ), fValue );

	SetDlgItemText( nID, str );
}

/////////////////////////////////////////////////////////////////////////////

void CDlgDcamInterval::DoDataExchange(CDataExchange* pDX)
{
	CDialog::DoDataExchange(pDX);
	//{{AFX_DATA_MAP(CDlgDcamInterval)
	DDX_Control(pDX, IDC_DLGDCAMINTERVAL_EBEXPOSURE, m_ebExposure);
	DDX_Control(pDX, IDC_DLGDCAMINTERVAL_EBLINERATE, m_ebLinerate);
	DDX_Control(pDX, IDC_DLGDCAMINTERVAL_SLIDERLINERATE, m_sliderLinerate);
	DDX_Control(pDX, IDC_DLGDCAMINTERVAL_SLIDEREXPOSURE, m_sliderExposure);
	//}}AFX_DATA_MAP
}


BEGIN_MESSAGE_MAP(CDlgDcamInterval, CDialog)
	//{{AFX_MSG_MAP(CDlgDcamInterval)
	ON_WM_DESTROY()
	ON_WM_HSCROLL()
	ON_EN_CHANGE(IDC_DLGDCAMINTERVAL_EBEXPOSURE, OnChangeDlgdcamintervalEbexposure)
	ON_EN_CHANGE(IDC_DLGDCAMINTERVAL_EBLINERATE, OnChangeDlgdcamintervalEblinerate)
	//}}AFX_MSG_MAP
END_MESSAGE_MAP()

/////////////////////////////////////////////////////////////////////////////
// CDlgDcamInterval message handlers

BOOL CDlgDcamInterval::OnInitDialog() 
{
	CDialog::OnInitDialog();
	
	update_values();

	setup_controls();
	update_controls();
	
	return TRUE;  // return TRUE unless you set the focus to a control
	              // EXCEPTION: OCX Property Pages should return FALSE
}

void CDlgDcamInterval::OnDestroy() 
{
	CDialog::OnDestroy();
	
	//  TODO: Add your message handler code here

	m_bCreateDialog = FALSE;
}

void CDlgDcamInterval::OnOK() 
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

	DestroyWindow();
}

void CDlgDcamInterval::OnCancel() 
{
	// TODO: Add extra cleanup here	
	if( m_bCreateDialog )
		DestroyWindow();
	else
		CDialog::OnCancel();
}

void CDlgDcamInterval::OnHScroll(UINT nSBCode, UINT nPos, CScrollBar* pScrollBar) 
{
	// TODO: Add your message handler code here and/or call default

	{
		if( pScrollBar == (CScrollBar*)&m_sliderExposure )
		{
			int	nowPos = m_sliderExposure.GetPos();

			m_exposure.value = map2double( m_exposure.min, m_exposure.max, m_exposure.barmin, m_exposure.barmax, nowPos );

			SetDlgItemDbl( IDC_DLGDCAMINTERVAL_EBEXPOSURE, m_exposure.value );
		}
		else
		if( pScrollBar == (CScrollBar*)&m_sliderLinerate )
		{
			int	nowPos = m_sliderLinerate.GetPos();

			m_linerate.value = map2double( m_linerate.min, m_linerate.max, m_linerate.barmin, m_linerate.barmax, nowPos );

			SetDlgItemDbl( IDC_DLGDCAMINTERVAL_EBLINERATE, m_linerate.value );
		}
	}

	CDialog::OnHScroll(nSBCode, nPos, pScrollBar);
}

void CDlgDcamInterval::OnChangeDlgdcamintervalEbexposure() 
{
	// TODO: If this is a RICHEDIT control, the control will not
	// send this notification unless you override the CDialog::OnInitDialog()
	// function and call CRichEditCtrl().SetEventMask()
	// with the ENM_CHANGE flag ORed into the mask.
	
	// TODO: Add your control notification handler code here

	if( GetDlgItemDbl( IDC_DLGDCAMINTERVAL_EBEXPOSURE, m_exposure.value ) )
	{
		dcam_setexposuretime( m_hdcam, m_exposure.value );
	}
}

void CDlgDcamInterval::OnChangeDlgdcamintervalEblinerate() 
{
	// TODO: If this is a RICHEDIT control, the control will not
	// send this notification unless you override the CDialog::OnInitDialog()
	// function and call CRichEditCtrl().SetEventMask()
	// with the ENM_CHANGE flag ORed into the mask.
	
	// TODO: Add your control notification handler code here

	if( GetDlgItemDbl( IDC_DLGDCAMINTERVAL_EBLINERATE, m_linerate.value ) )
	{
		dcamex_setinternallinerate( m_hdcam, m_linerate.value );
	}
}
