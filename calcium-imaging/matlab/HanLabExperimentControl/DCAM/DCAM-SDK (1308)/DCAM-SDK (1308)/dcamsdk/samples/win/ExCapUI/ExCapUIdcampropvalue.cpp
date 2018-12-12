// ExCapUIdcampropvalue.cpp : implementation file
//

#include "stdafx.h"
#include "excapui.h"
#include "ExCapUIdcampropvalue.h"

#ifdef _DEBUG
#define new DEBUG_NEW
#undef THIS_FILE
static char THIS_FILE[] = __FILE__;
#endif

/////////////////////////////////////////////////////////////////////////////
// CExCapUIdcampropvalue dialog


CExCapUIdcampropvalue::CExCapUIdcampropvalue(CWnd* pParent, UINT idEdit )
	: CDialog(CExCapUIdcampropvalue::IDD, pParent)
{
	//{{AFX_DATA_INIT(CExCapUIdcampropvalue)
	m_strValue = _T("");
	m_strMax = _T("");
	m_strMin = _T("");
	//}}AFX_DATA_INIT

	m_value		= 0;
	m_valuemax	= 0;
	m_valuemin	= 0;
	m_valuestep	= 0;

	m_idEdit = idEdit;
	m_fRatioSlider = 0;
	m_fOffsetSlider = 0;
}


void CExCapUIdcampropvalue::DoDataExchange(CDataExchange* pDX)
{
	CDialog::DoDataExchange(pDX);
	//{{AFX_DATA_MAP(CExCapUIdcampropvalue)
	DDX_Control(pDX, IDC_PROPERTYVALUE_SPINVALUE, m_spinValue);
	DDX_Control(pDX, IDC_PROPERTYVALUE_SLIDERVALUE, m_sliderValue);
	DDX_Text(pDX, IDC_PROPERTYVALUE_EBVALUE, m_strValue);
	DDX_Text(pDX, IDC_PROPERTYVALUE_TXTMAX, m_strMax);
	DDX_Text(pDX, IDC_PROPERTYVALUE_TXTMIN, m_strMin);
	//}}AFX_DATA_MAP
}


BEGIN_MESSAGE_MAP(CExCapUIdcampropvalue, CDialog)
	//{{AFX_MSG_MAP(CExCapUIdcampropvalue)
	ON_WM_VSCROLL()
	//}}AFX_MSG_MAP
END_MESSAGE_MAP()

void CExCapUIdcampropvalue::setvalue( double value, double valuemax, double valuemin, double valuestep )
{
	m_value		= value;
	m_valuemax	= valuemax;
	m_valuemin	= valuemin;
	m_valuestep	= valuestep;

	m_strValue.Format( _T( "%g" ), m_value );
	m_strMax.Format(   _T( "%g" ), m_valuemax );
	m_strMin.Format(   _T( "%g" ), m_valuemin );

	ASSERT( m_valuestep >= 0 );
	if( m_valuestep == 0 )
		m_valuestep = 1;

	if( ( m_valuemax - m_valuemin ) / m_valuestep > 32767 )
	{
		m_fRatioSlider = ceil( ( m_valuemax - m_valuemin ) / m_valuestep / 32767 ) * m_valuestep;
	}
	else
	{
		m_fRatioSlider = m_valuestep;
	}

	m_fOffsetSlider = m_valuemin;
}

double CExCapUIdcampropvalue::getvalue() const
{
	LPTSTR	endptr;
#ifdef _UNICODE
	return wcstod( m_strValue, &endptr );
#else
	return strtod( m_strValue, &endptr );
#endif
}

/////////////////////////////////////////////////////////////////////////////
// CExCapUIdcampropvalue message handlers


BOOL CExCapUIdcampropvalue::OnInitDialog() 
{
	CDialog::OnInitDialog();
	
	// TODO: Add extra initialization here

	long	iMin = 0;
	long	iMax = int( ( m_valuemax - m_valuemin) / m_fRatioSlider );
	m_sliderValue.SetRange( -iMax, -iMin );

	long	iPos = -int( ( m_value - m_valuemin ) / m_fRatioSlider );
	m_sliderValue.SetPos( iPos );
	
	return TRUE;  // return TRUE unless you set the focus to a control
	              // EXCEPTION: OCX Property Pages should return FALSE
}

inline BOOL interpret_scrollmessage( CSliderCtrl& slider, long& v, UINT nSBCode, double ratio = 0 )
{
	int		nMin, nMax;
	slider.GetRange( nMin, nMax );

	// flip vertical direction
	{
		long	_nmin = -nMax;
		long	_nmax = -nMin;

		nMin = _nmin;
		nMax = _nmax;
	}

	v = -slider.GetPos();
	long	page;
	if( ratio <= 0 )
		page = (nMax - nMin ) / 8;
	else
	if( ratio < 1 )
		page = (long)( (nMax - nMin ) * ratio );
	else
		page = (long)ratio;

	switch( nSBCode )
	{
	case SB_BOTTOM:		v = nMin;	break;	// Scroll to far left.
	case SB_TOP:		v = nMax;	break;	// Scroll to far right.
	case SB_LINEDOWN:	v--;		break;	// Scroll left.
	case SB_LINEUP:		v++;		break;	// Scroll right.
	case SB_PAGEDOWN:	v -= page;	break;	// Scroll one page left.
	case SB_PAGEUP:		v += page;	break;	// Scroll one page right.
	case SB_THUMBPOSITION:	// Scroll to absolute position. The current position is specified by the nPos parameter.
	case SB_THUMBTRACK:	// Drag scroll box to specified position. The current position is specified by the nPos parameter. 
		break;
	case SB_ENDSCROLL:	// End scroll.
		return FALSE;
	}

	if( v < nMin )
		v = nMin;
	else
	if( v > nMax )
		v = nMax;

	return TRUE;
}

void CExCapUIdcampropvalue::OnVScroll(UINT nSBCode, UINT nPos, CScrollBar* pScrollBar) 
{
	// TODO: Add your message handler code here and/or call default
	
	if( pScrollBar == (CScrollBar*)&m_sliderValue )
	{
		long	pos;
		if( interpret_scrollmessage( m_sliderValue, pos, nSBCode ) )
		{
			double	newValue = pos * m_fRatioSlider + m_fOffsetSlider;

			if( m_value != newValue )
			{
				m_value = newValue;
				m_strValue.Format( _T( "%g" ), m_value );

				SetDlgItemText( IDC_PROPERTYVALUE_EBVALUE, m_strValue );
			}
		}
	}

	CDialog::OnVScroll(nSBCode, nPos, pScrollBar);
}
