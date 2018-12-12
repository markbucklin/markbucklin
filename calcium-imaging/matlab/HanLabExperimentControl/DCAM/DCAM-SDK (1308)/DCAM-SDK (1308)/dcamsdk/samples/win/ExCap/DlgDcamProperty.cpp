// DlgDcamProperty.cpp : implementation file
//

#include "stdafx.h"
#include "resource.h"
#include <math.h>	// ceil() & fmod()

#include "DlgDcamProperty.h"
#include "dcamex.h"

#ifdef _DEBUG
#define new DEBUG_NEW
#undef THIS_FILE
static char THIS_FILE[] = __FILE__;
#endif

/////////////////////////////////////////////////////////////////////////////

inline BOOL value_to_text( HDCAM hdcam, int32 iProp, double value, char* text, int32 textsize )
{
	DCAM_PROPERTYVALUETEXT	pvt;
	memset( &pvt, 0, sizeof( pvt ) );
	pvt.cbSize	= sizeof( pvt );
	pvt.iProp	= iProp;
	pvt.value	= value;
	pvt.text	= text;
	pvt.textbytes = textsize;

	if( dcam_getpropertyvaluetext( hdcam, &pvt ) )
		return TRUE;

	DCAM_PROPERTYATTR	pa;
	memset( &pa, 0, sizeof( pa ) );
	pa.cbSize	= sizeof( pa );
	pa.iProp	= iProp;

	VERIFY( dcam_getpropertyattr( hdcam, &pa ) );
	if( ( pa.attribute & DCAMPROP_TYPE_MASK ) == DCAMPROP_TYPE_REAL )
	{
		sprintf_s( text, textsize, "%g", value );
	}
	else
	if( ( pa.attribute & DCAMPROP_TYPE_MASK ) == DCAMPROP_TYPE_LONG )
	{
		sprintf_s( text, textsize, "%d", (long)value );
	}
	else
	{
		ASSERT( ( pa.attribute & DCAMPROP_TYPE_MASK ) == DCAMPROP_TYPE_MODE );
		sprintf_s( text, textsize, "(invalid value; %g)", value );
	}

	return TRUE;
}


/////////////////////////////////////////////////////////////////////////////
// CDlgDcamProperty dialog

enum {
	INDEX_PROPERTY_NAME,
	INDEX_PROPERTY_UPDATE,
	INDEX_PROPERTY_VALUE
};

CDlgDcamProperty::CDlgDcamProperty( CWnd* pParent /*=NULL*/)
	: CDialog(CDlgDcamProperty::IDD, pParent)
{
	//{{AFX_DATA_INIT(CDlgDcamProperty)
	m_bShowAllProperties = FALSE;
	m_bUseListboxAlways = FALSE;
	m_bUpdatePeriodically = FALSE;
	//}}AFX_DATA_INIT

	m_bCreateDialog		= FALSE;
	m_hdcam				= NULL;
	m_bChangingEditbox	= FALSE;

	memset( &m_editprop, 0, sizeof( m_editprop ) );
	m_editprop.indexOnListview	= -1;

	m_fRatioSlider		= 1;
	m_fStepSlider		= 0;
	m_dcamstatus		= DCAM_STATUS_ERROR;
	m_bAutomaticUpdatePropertyValues	= TRUE;

	m_viewchannelmode	= 0;
	m_iViewCh			= 0;
	m_idpropoffset		= 0;
	m_idproparraybase	= 0;
	
	m_rcClient.SetRectEmpty();
}

// ----

HDCAM CDlgDcamProperty::set_hdcam( HDCAM hdcam )
{
	HDCAM	old = m_hdcam;

	m_hdcam = hdcam;

	if( IsWindow( GetSafeHwnd() ) )
	{
		update_viewchannel_control();
		update_listview_title( 0 );
		update_listview_value();
		reset_listview_updated_value();
	}

	return old;
}

BOOL CDlgDcamProperty::toggle_visible()
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
		update_listview_updated_value();
		SetWindowPos( &CWnd::wndTop, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_SHOWWINDOW );
	}

	return TRUE;
}

BOOL CDlgDcamProperty::Create( CWnd* pParentWnd, CCreateContext* pContext ) 
{
	// TODO: Add your specialized code here and/or call the base class
	
	if( ! CDialog::Create(IDD, pParentWnd) )
		return FALSE;

	m_bCreateDialog = TRUE;
	return TRUE;
}

// ----------------

void CDlgDcamProperty::update_viewchannel_control()
{
	long	i, j, k;
	long	nView, nChannel;

	double	v;
	
	if( ! dcam_getpropertyvalue( m_hdcam, DCAM_IDPROP_NUMBEROF_VIEW, &v ) || v <= 1 )
		nView = 1;
	else
		nView = (long)v;

	if( ! dcam_getpropertyvalue( m_hdcam, DCAM_IDPROP_NUMBEROF_CHANNEL, &v ) || v <= 1 )
		nChannel = 1;
	else
		nChannel = (long)v;

	if( nView * nChannel == 1 )
	{
		// single view and channel

		m_cbViewCh.ShowWindow( SW_HIDE );
		for( i = 0; i <= 3; i++ )
		{
			m_btnViewCh[ i ].ShowWindow( SW_HIDE );
		}

		m_viewchannelmode = 0;
	}
	else
	if( nView * nChannel <= 3 )
	{
		// not allow the combination of 2 views and 2 channels
		ASSERT( nView == 1 || nChannel == 1 );

		LPCTSTR	type;
		if( nView == 1 )
		{
			type = _T( "CH" );
		}
		else
		{
			type = _T( "View" );
		}

		m_cbViewCh.ShowWindow( SW_HIDE );
		for( i = 0; i <= 3; i++ )
		{
			m_btnViewCh[ i ].ShowWindow( ( i <= v ) ? SW_SHOW : SW_HIDE );

			CString	str;
			str.Format( i == 0 ? _T( "All %s" ) : _T( "%s %d" ), type, i );
			m_btnViewCh[ i ].SetWindowText( str );
		}

		m_viewchannelmode = nView * nChannel;
	}
	else
	{
		// over 3 views and channels

		for( i = 0; i <= 3; i++ )
		{
			m_btnViewCh[ i ].ShowWindow( SW_HIDE );
		}

		m_cbViewCh.ResetContent();

		ASSERT( nView >= 1 || nChannel >= 1 );
		CString	str;

		if( nView == 1 )
		{
			m_cbViewCh.AddString( _T( "CH All" ) );
			m_cbViewCh.SetItemData( 0, 0 );	// idpropoffset is 0.

			for( j = 1; j <= nChannel; j++ )
			{
				str.Format( _T( "CH %d" ), j );
				i = m_cbViewCh.AddString( str );

				long	idpropoffset = j * DCAM_IDPROP__CHANNEL;
				m_cbViewCh.SetItemData( i, idpropoffset );
			}
		}
		else
		if( nChannel == 1 )
		{
			m_cbViewCh.AddString( _T( "View All" ) );
			m_cbViewCh.SetItemData( 0, 0 );	// idpropoffset is 0.

			for( k = 1; k < nView; k++ )
			{
				str.Format( _T( "View %d" ), k );
				i = m_cbViewCh.AddString( str );

				long	idpropoffset = k * DCAM_IDPROP__VIEW;
				m_cbViewCh.SetItemData( i, idpropoffset );
			}
		}
		else
		{
			for( k = 0; k < nView; k++ )
			{
				CString	strView;
				strView.Format( k == 0 ? _T( "View All" ) : _T( "View %d" ), k );

				int	j;
				for( j = 0; j < nChannel; j++ )
				{
					CString	strCH;
					strCH.Format( j == 0 ? _T( "CH All" ) : _T( "CH %d" ), j );

					str = strView + _T( "; " ) + strCH;
					i = m_cbViewCh.AddString( str );

					long	idpropoffset = k * DCAM_IDPROP__VIEW + j * DCAM_IDPROP__CHANNEL;
					m_cbViewCh.SetItemData( i, idpropoffset );
				}
			}
		}

		m_cbViewCh.SetCurSel( 0 );
		m_cbViewCh.ShowWindow( SW_SHOW );

		m_viewchannelmode = 1;
	}
}

void CDlgDcamProperty::update_listview_title( long iPropArrayBase )
{
	m_listview.DeleteAllItems();

	if( m_hdcam != NULL )
	{
		m_listview.SetRedraw( FALSE );
		m_arrayIDPROP.RemoveAll();
		m_arrayAttr.RemoveAll();

		int32	iProp = iPropArrayBase;
		int32	option = ( iProp == 0 ? 0 : DCAMPROP_OPTION_ARRAYELEMENT );

		if( iProp != 0
		 || dcam_getnextpropertyid( m_hdcam, &iProp ) )
		{
			long	iItem = 0;
			do
			{
				char	text[ 64 ];
				VERIFY( dcam_getpropertyname( m_hdcam, iProp, text, sizeof( text ) ) );

				CString	str;
				str = text;
				m_listview.InsertItem( iItem, str );
				m_listview.SetItemData( iItem, iItem );
				m_arrayIDPROP.Add( iProp );

				{
					DCAM_PROPERTYATTR	attr;
					memset( &attr, 0, sizeof( attr ) );
					attr.cbSize	= sizeof( attr );
					attr.iProp	= iProp;
				
					VERIFY( dcam_getpropertyattr( m_hdcam, &attr ) );
					m_arrayAttr.Add( attr.attribute );
				}

				iItem++;
			} while( dcam_getnextpropertyid( m_hdcam, &iProp, option ) );
		}

		m_listview.SetRedraw( TRUE );
		m_listview.Invalidate();
	}

	m_idproparraybase = iPropArrayBase;
}

void CDlgDcamProperty::update_listview_value()
{
	ASSERT( m_arrayIDPROP.GetSize() == m_arrayAttr.GetSize() );

	DWORD	bRedraw = FALSE;

	{
		DWORD	dwNew;
		if( ! dcam_getstatus( m_hdcam, &dwNew) )
			dwNew = DCAM_STATUS_ERROR;

		if( m_dcamstatus != dwNew )
		{
			m_dcamstatus = dwNew;
			bRedraw = TRUE;
		}
	}

	{
		m_listview.SetRedraw( FALSE );

		long	iItem;
		for( iItem = 0; iItem < m_listview.GetItemCount(); iItem++ )
		{
			long	i = (long)m_listview.GetItemData( iItem );
			ASSERT( 0 <= i && i < m_arrayIDPROP.GetSize() );

			long	iProp = (long)m_arrayIDPROP.GetAt( i );
			iProp += m_idpropoffset;

			char	text[ 64 ];
			double	value;

			if( ! dcam_getpropertyvalue( m_hdcam, iProp, &value ) )
			{
				strcpy_s( text, sizeof( text ), "(invalid)" );
			}
			else
			{
				value_to_text( m_hdcam, iProp, value, text, sizeof( text ) );
			}

			CString	str = m_listview.GetItemText( iItem, INDEX_PROPERTY_VALUE );
			if( str != text )
			{
				str = text;
				m_listview.SetItemText( iItem, INDEX_PROPERTY_VALUE, str );
				bRedraw = TRUE;
			}
		}

		m_listview.SetRedraw( TRUE );
		if( bRedraw )
			m_listview.Invalidate();
	}
}

// Enumerate DCAM_IDPROP which is updated value or attribute and Make count up to visualize.

void CDlgDcamProperty::update_listview_updated_value()
{
	if( m_hdcam != NULL )
	{
		m_listview.SetRedraw( FALSE );

		int32	iProp = 0;
		while( dcam_getnextpropertyid( m_hdcam, &iProp, DCAMPROP_OPTION_UPDATED ) )
		{
			// find index on the listview.
			long	iItem;
			for( iItem = 0; iItem < m_listview.GetItemCount(); iItem++ )
			{
				long	i = (long)m_listview.GetItemData( iItem );
				if( (long)m_arrayIDPROP[ i ] == iProp )
				{
					CString	str = m_listview.GetItemText( iItem, INDEX_PROPERTY_UPDATE );
					str.Format( _T( "%d" ), atoi( str ) + 1 );
					m_listview.SetItemText( iItem, INDEX_PROPERTY_UPDATE, str );

					char	text[ 64 ];
					double	value;

					if( ! dcam_getpropertyvalue( m_hdcam, iProp, &value ) )
					{
						strcpy_s( text, sizeof( text ), "(invalid)" );
					}
					else
					{
						value_to_text( m_hdcam, iProp, value, text, sizeof( text ) );
					}

					str = m_listview.GetItemText( iItem, INDEX_PROPERTY_VALUE );
					if( str == text )
					{
						// text sometimes not changed because DCAMPROP_OPTION_UPDATED capture even if the only support range is changed.
					}
					else
					{
						str = text;
						m_listview.SetItemText( iItem, INDEX_PROPERTY_VALUE, str );
					}

					{
						DCAM_PROPERTYATTR	attr;
						memset( &attr, 0, sizeof( attr ) );
						attr.cbSize	= sizeof( attr );
						attr.iProp	= iProp;
					
						VERIFY( dcam_getpropertyattr( m_hdcam, &attr ) );
						m_arrayAttr.SetAt( iItem, attr.attribute );
					}
				}
			}
		}

		m_listview.SetRedraw( TRUE );
		m_listview.Invalidate();
	}
}

void CDlgDcamProperty::reset_listview_updated_value()
{
	if( m_hdcam != NULL )
	{
		m_listview.SetRedraw( FALSE );

		// reset INDEX_PROPERTY_UPDATE column of listview

		long	iItem;
		for( iItem = 0; iItem < m_listview.GetItemCount(); iItem++ )
		{
			m_listview.SetItemText( iItem, INDEX_PROPERTY_UPDATE, _T( "" ) );
		}

		// All UPDATED flag should be reset because update_listview_updated_value() is called before this routine.

		int32	iProp = 0;
		ASSERT( ! dcam_getnextpropertyid( m_hdcam, &iProp, DCAMPROP_OPTION_UPDATED ) );

		m_listview.SetRedraw( TRUE );
		m_listview.Invalidate();
	}
}

// ----------------

void CDlgDcamProperty::DoDataExchange(CDataExchange* pDX)
{
	CDialog::DoDataExchange(pDX);
	//{{AFX_DATA_MAP(CDlgDcamProperty)
	DDX_Control(pDX, IDC_DLGDCAMPROPERTY_LISTVIEW, m_listview);
	DDX_Control(pDX, IDC_DLGDCAMPROPERTY_CBSELECTVIEW, m_cbViewCh);
	DDX_Control(pDX, IDC_DLGDCAMPROPERTY_LBVALUES, m_lbValues);
	DDX_Control(pDX, IDC_DLGDCAMPROPERTY_LBATTR, m_lbAttr);
	DDX_Control(pDX, IDC_DLGDCAMPROPERTY_TXTMAX, m_txtMax);
	DDX_Control(pDX, IDC_DLGDCAMPROPERTY_TXTMIN, m_txtMin);
	DDX_Control(pDX, IDC_DLGDCAMPROPERTY_WNDMIN, m_wndMin);
	DDX_Control(pDX, IDC_DLGDCAMPROPERTY_WNDMAX, m_wndMax);
	DDX_Control(pDX, IDC_DLGDCAMPROPERTY_EBVALUE, m_ebValue);
	DDX_Control(pDX, IDC_DLGDCAMPROPERTY_SLIDERVALUE, m_sliderValue);
	DDX_Control(pDX, IDC_DLGDCAMPROPERTY_SPINVALUE, m_spinValue);
	DDX_Check(pDX, IDC_DLGDCAMPROPERTY_BTNUSELISTBOX, m_bUseListboxAlways);
	DDX_Check(pDX, IDC_DLGDCAMPROPERTY_BTNUPDATEPERIODICALLY, m_bUpdatePeriodically);
	//}}AFX_DATA_MAP
	DDX_Control(pDX, IDC_DLGDCAMPROPERTY_BTNALL, m_btnViewCh[0]);
	DDX_Control(pDX, IDC_DLGDCAMPROPERTY_BTN1, m_btnViewCh[1]);
	DDX_Control(pDX, IDC_DLGDCAMPROPERTY_BTN2, m_btnViewCh[2]);
	DDX_Control(pDX, IDC_DLGDCAMPROPERTY_BTN3, m_btnViewCh[3]);
}


BEGIN_MESSAGE_MAP(CDlgDcamProperty, CDialog)
	//{{AFX_MSG_MAP(CDlgDcamProperty)
	ON_WM_SIZE()
	ON_WM_DESTROY()
	ON_NOTIFY(LVN_ITEMCHANGED, IDC_DLGDCAMPROPERTY_LISTVIEW, OnItemchangedDlgdcampropertyListview)
	ON_NOTIFY(NM_CLICK, IDC_DLGDCAMPROPERTY_LISTVIEW, OnClickDlgdcampropertyListview)
	ON_NOTIFY(NM_DBLCLK, IDC_DLGDCAMPROPERTY_LISTVIEW, OnDblclkDlgdcampropertyListview)
	ON_NOTIFY(NM_CUSTOMDRAW, IDC_DLGDCAMPROPERTY_LISTVIEW, OnCustomdrawDlgdcampropertyListview)
	ON_WM_NCHITTEST()
	ON_WM_VSCROLL()
	ON_CBN_SELCHANGE(IDC_DLGDCAMPROPERTY_CBSELECTVIEW, OnSelchangeDlgdcampropertyCbselectview)
	ON_LBN_SELCHANGE(IDC_DLGDCAMPROPERTY_LBVALUES, OnSelchangeDlgdcampropertyLbvalues)
	ON_EN_CHANGE(IDC_DLGDCAMPROPERTY_EBVALUE, OnChangeDlgdcampropertyEbvalue)
	ON_WM_TIMER()
	ON_COMMAND_RANGE(IDC_DLGDCAMPROPERTY_BTNALL, IDC_DLGDCAMPROPERTY_BTN3, OnDlgdcampropertyBtn)
	ON_BN_CLICKED(IDC_DLGDCAMPROPERTY_BTNUSELISTBOX, OnDlgdcampropertyBtnuselistbox)
	ON_BN_CLICKED(IDC_DLGDCAMPROPERTY_BTNUPDATEPERIODICALLY, OnDlgdcampropertyBtnupdateperiodically)
	ON_BN_CLICKED(IDC_DLGDCAMPROPERTY_BTNUPDATEVALUES, OnDlgdcampropertyBtnupdatevalues)
	ON_BN_CLICKED(IDC_DLGDCAMPROPERTY_BTNWHOLEIDPROP, OnDlgdcampropertyBtnwholeidprop)
	ON_BN_CLICKED(IDC_DLGDCAMPROPERTY_BTNARRAYELEMENT, OnDlgdcampropertyBtnarrayelement)
	//}}AFX_MSG_MAP
END_MESSAGE_MAP()

/////////////////////////////////////////////////////////////////////////////
// CDlgDcamProperty 

/////////////////////////////////////////////////////////////////////////////
// helper functions

inline CString get_string_as_long( double v )
{
	CString	str;
	str.Format( _T( "%d" ), (long)v );

	return str;
}

inline CString get_string_as_real( double v )
{
	CString	str;
	str.Format( _T( "%g" ), v );

	return str;
}

void fill_propertyvaluetext_into_listbox( CListBox& lb, HDCAM hdcam, long iProp, double selectedValue = 0 )
{
	DCAM_PROPERTYATTR	pa;
	memset( &pa, 0, sizeof( pa ) );
	pa.cbSize	= sizeof( pa );
	pa.iProp	= iProp;

	VERIFY( dcam_getpropertyattr( hdcam, &pa ) );
//	if( ( pa.attribute & DCAMPROP_ATTR_WRITABLE ) == 0 )
//		return;

	lb.SetRedraw( FALSE );
	lb.ResetContent();

	long	iSel = -1;
	double	v = pa.valuemin;
	for( ;; )
	{
		char	buf[ 256 ];

		VERIFY( value_to_text( hdcam, iProp, v, buf, sizeof( buf ) ) );

		CString	str;
		str = buf;
		long	index = lb.AddString( str );

		lb.SetItemData( index, (long)v );
		if( selectedValue == v )
			iSel = index;

		if( ! dcam_querypropertyvalue( hdcam, iProp, &v, DCAMPROP_OPTION_NEXT ) )
			break;
	}

	lb.SetCurSel( iSel );
	lb.SetRedraw( TRUE );
	lb.Invalidate();
}


void CDlgDcamProperty::edit_property_of( long index )
{
	m_bChangingEditbox = TRUE;

	m_editprop.indexOnListview	= index;
	m_editprop.attribute	= 0;
	m_editprop.attribute2	= 0;

	long	iPropBase = 0;
	if( m_hdcam != NULL && index >= 0 )
	{
		ASSERT( index < m_listview.GetItemCount() );

		long	i = (long)m_listview.GetItemData( m_editprop.indexOnListview );
		ASSERT( 0 <= i && i < m_arrayIDPROP.GetSize() );

		iPropBase = m_arrayIDPROP.GetAt( i );
		long	iProp = iPropBase + m_idpropoffset;

		DCAM_PROPERTYATTR	pa;
		memset( &pa, 0, sizeof( pa ) );
		pa.cbSize	= sizeof( pa );
		pa.iProp	= iProp;

		CString	strValue;

		if( ! dcam_getpropertyattr( m_hdcam, &pa ) )
		{
			ASSERT( m_idpropoffset != 0 );
			m_editprop.attribute	= 0;
			m_editprop.attribute2	= 0;
		}
		else
		{
			m_editprop.attribute	= pa.attribute;
			m_editprop.attribute2	= pa.attribute2;
			m_editprop.nMaxView		= pa.nMaxView;
			m_editprop.nMaxChannel	= pa.nMaxChannel;

			if( m_editprop.nMaxView <= 1 && m_editprop.nMaxChannel <= 1 )
			{
				m_idpropoffset = 0;	// all
				m_iViewCh = 0;
			}

			double	value;
			VERIFY( dcam_getpropertyvalue( m_hdcam, iProp, &value ) );

			if( m_bUseListboxAlways )
			{
				fill_propertyvaluetext_into_listbox( m_lbValues, m_hdcam, iProp, value );
			}
			else
			{
				switch( m_editprop.attribute & DCAMPROP_TYPE_MASK )
				{
				case DCAMPROP_TYPE_NONE:	break;
				case DCAMPROP_TYPE_MODE:
					fill_propertyvaluetext_into_listbox( m_lbValues, m_hdcam, iProp, value );
					break;

				case DCAMPROP_TYPE_LONG:
					m_txtMin.SetWindowText( get_string_as_long( pa.valuemin ) );
					m_txtMax.SetWindowText( get_string_as_long( pa.valuemax ) );

					m_fRatioSlider = 1;
					m_fStepSlider = pa.valuestep;
					m_sliderValue.SetRange( -(long)pa.valuemax, -(long)pa.valuemin );
					m_sliderValue.SetPos( -(long)value );

					strValue = get_string_as_long( value );
				//	m_spinValue.
					break;
				case DCAMPROP_TYPE_REAL:
					m_txtMin.SetWindowText( get_string_as_real( pa.valuemin ) );
					m_txtMax.SetWindowText( get_string_as_real( pa.valuemax ) );

					if( pa.valuestep > 0 )
					{
						if( ( pa.valuemax - pa.valuemin ) / pa.valuestep >= 65536 )
							m_fRatioSlider = ceil( ( pa.valuemax - pa.valuemin ) / pa.valuestep / 65536 ) * pa.valuestep;
						else
							m_fRatioSlider = pa.valuestep;
					}
					else
					{
						if( ( pa.valuemax - pa.valuemin ) >= 65536 )
							m_fRatioSlider = ceil( ( pa.valuemax - pa.valuemin ) / 65536 );
						else
							m_fRatioSlider = 1;
					}

					m_sliderValue.SetRange( -(long)( pa.valuemax / m_fRatioSlider ), -(long)( pa.valuemin / m_fRatioSlider ) );
					m_sliderValue.SetPos( -(long)( value / m_fRatioSlider ) );

					strValue = get_string_as_real( value );
					break;
				}
			}
		}

		if( ! strValue.IsEmpty() && GetFocus() != &m_ebValue )
		{
			m_ebValue.SetWindowText( strValue );
			m_listview.SetItemText( m_editprop.indexOnListview, INDEX_PROPERTY_VALUE, strValue );
		}
	}

	if( m_editprop.idprop != iPropBase )
	{
		m_editprop.idprop = iPropBase;

		update_controls();
	}

	m_bChangingEditbox = FALSE;
}

static void addstring( CListBox& lb, BOOL bAdd, LPCTSTR str )
{
	lb.AddString( bAdd ? str : _T( "" ) );
}

void CDlgDcamProperty::recalc_layout()
{
	GetClientRect( &m_rcClient );

	CRect	rc;
	m_listview.GetWindowRect( &rc );
	ScreenToClient( &rc );

	rc.bottom = m_rcClient.bottom - m_szSpaceListview.cy;
	m_listview.SetWindowPos( NULL, rc.left, rc.top, rc.Width(), rc.Height(), SWP_NOZORDER );

	m_lbValues.GetWindowRect( &rc );
	ScreenToClient( &rc );

	rc.bottom = m_rcClient.bottom - m_szSpaceListview.cy;
	m_lbValues.SetWindowPos( NULL, rc.left, rc.top, rc.Width(), rc.Height(), SWP_NOZORDER );
}

void CDlgDcamProperty::update_controls()
{
	BOOL	bShowValues		= FALSE;
	BOOL	bShowModes		= FALSE;
	BOOL	bEnableArrayElement = FALSE;
	BOOL	bEnableValues	= FALSE;
	BOOL	bEnableModes	= FALSE;

	m_lbAttr.SetRedraw( FALSE );
	m_lbAttr.ResetContent();

	if( m_editprop.attribute != 0 )
	{
		// update attribute listbox
		CString	str;
		switch( m_editprop.attribute & DCAMPROP_TYPE_MASK )
		{
		default:					ASSERT( 0 );
		case DCAMPROP_TYPE_NONE:	str = "(type_none)";		break;
		case DCAMPROP_TYPE_MODE:	str = "TYPE_MODE";		break;
		case DCAMPROP_TYPE_LONG:	str = "TYPE_LONG";		break;
		case DCAMPROP_TYPE_REAL:	str = "TYPE_REAL";		break;
		}

		m_lbAttr.AddString( str );

		addstring( m_lbAttr, m_editprop.attribute & DCAMPROP_ATTR_WRITABLE,		_T( "WRITABLE" ) );
		addstring( m_lbAttr, m_editprop.attribute & DCAMPROP_ATTR_READABLE,		_T( "READABLE" ) );
		addstring( m_lbAttr, m_editprop.attribute & DCAMPROP_ATTR_EFFECTIVE,	_T( "EFFECTIVE" ) );
		addstring( m_lbAttr, m_editprop.attribute & DCAMPROP_ATTR_DATASTREAM,	_T( "DATASTREAM" ) );
		addstring( m_lbAttr, m_editprop.attribute & DCAMPROP_ATTR_ACCESSREADY,	_T( "ACCESSREADY" ) );
		addstring( m_lbAttr, m_editprop.attribute & DCAMPROP_ATTR_ACCESSBUSY,	_T( "ACCESSBUSY" ) );
		addstring( m_lbAttr, m_editprop.attribute & DCAMPROP_ATTR_HASVIEW,		_T( "HASVIEW" ) );
		addstring( m_lbAttr, m_editprop.attribute & DCAMPROP_ATTR_HASCHANNEL,	_T( "HASCHANNEL" ) );
		addstring( m_lbAttr, m_editprop.attribute & DCAMPROP_ATTR_VOLATILE,		_T( "VOLATILE" ) );
		addstring( m_lbAttr, m_editprop.attribute & DCAMPROP_ATTR_ACTION,		_T( "ACTION" ) );

		addstring( m_lbAttr, m_editprop.attribute2 & DCAMPROP_ATTR2_ARRAYBASE,	_T( "ARRAYBASE" ) );

		if( m_viewchannelmode == 1 )
		{
		}
		else
		if( m_viewchannelmode > 1 )
		{
			long	iMaxViewChMode;
			long	iFactorIdprop;

			if( m_editprop.nMaxView <= 1 && m_editprop.nMaxChannel <= 1 )
			{
				iMaxViewChMode	= 0;
				iFactorIdprop	= 0;
			}
			else
			if( m_editprop.nMaxView <= 1 )
			{
				ASSERT( m_editprop.nMaxChannel > 1 );
				ASSERT( m_editprop.attribute & DCAMPROP_ATTR_HASCHANNEL );

				iMaxViewChMode	= m_editprop.nMaxChannel;
				iFactorIdprop	= DCAM_IDPROP__CHANNEL;
			}
			else
			{
				ASSERT( m_editprop.nMaxView > 1 );
				ASSERT( m_editprop.nMaxChannel <= 1 );
				ASSERT( m_editprop.attribute & DCAMPROP_ATTR_HASVIEW );

				iMaxViewChMode	= m_editprop.nMaxView;
				iFactorIdprop	= DCAM_IDPROP__VIEW;
			}

			// reset index for channel or view if it is out of range.
			if( m_iViewCh > m_viewchannelmode )
				m_iViewCh = 0;

			// update buttons
			long	i;
			for( i = 0; i <= m_viewchannelmode; i++ )
			{
				m_btnViewCh[ i ].EnableWindow( i <= iMaxViewChMode );
			}

			m_idpropoffset = m_iViewCh * iFactorIdprop;
			CheckRadioButton( IDC_DLGDCAMPROPERTY_BTNALL, IDC_DLGDCAMPROPERTY_BTN3, IDC_DLGDCAMPROPERTY_BTNALL + m_iViewCh );
		}
		else
		{
			ASSERT( m_viewchannelmode == 0 );

			m_idpropoffset = 0;	// offset for DCAM_IDPROP_*, means basic access
			m_iViewCh = 0;
		}

		// update related control to TYPE
		if( m_bUseListboxAlways )
		{
			bShowModes = TRUE;
			if( m_editprop.attribute & DCAMPROP_ATTR_WRITABLE )
			{
				if( m_dcamstatus == DCAM_STATUS_UNSTABLE
				 ||	m_dcamstatus == DCAM_STATUS_STABLE 
				 || m_dcamstatus == DCAM_STATUS_READY && ( m_editprop.attribute & DCAMPROP_ATTR_ACCESSREADY )
				 || m_dcamstatus == DCAM_STATUS_BUSY  && ( m_editprop.attribute & DCAMPROP_ATTR_ACCESSBUSY ) )
				{
					bEnableModes = TRUE;
				}
			}
		}
		else
		{
			switch( m_editprop.attribute & DCAMPROP_TYPE_MASK )
			{
			case DCAMPROP_TYPE_NONE:	break;
			case DCAMPROP_TYPE_MODE:	bShowModes = TRUE;
										if( m_editprop.attribute & DCAMPROP_ATTR_WRITABLE )
										{
											if( m_dcamstatus == DCAM_STATUS_UNSTABLE
											 ||	m_dcamstatus == DCAM_STATUS_STABLE 
											 || m_dcamstatus == DCAM_STATUS_READY && ( m_editprop.attribute & DCAMPROP_ATTR_ACCESSREADY )
											 || m_dcamstatus == DCAM_STATUS_BUSY  && ( m_editprop.attribute & DCAMPROP_ATTR_ACCESSBUSY ) )
											{
												bEnableModes = TRUE;
											}
										}
										break;

			case DCAMPROP_TYPE_LONG:
			case DCAMPROP_TYPE_REAL:	bShowValues = TRUE;
										if( m_editprop.attribute & DCAMPROP_ATTR_WRITABLE )
										{
											if( m_dcamstatus == DCAM_STATUS_UNSTABLE
											 ||	m_dcamstatus == DCAM_STATUS_STABLE 
											 || m_dcamstatus == DCAM_STATUS_READY && ( m_editprop.attribute & DCAMPROP_ATTR_ACCESSREADY )
											 || m_dcamstatus == DCAM_STATUS_BUSY  && ( m_editprop.attribute & DCAMPROP_ATTR_ACCESSBUSY ) )
											{
												bEnableValues = TRUE;
											}
										}
										break;
			}

			if( m_idproparraybase != 0 )
			{
			}
			else
			if( m_editprop.attribute2 & DCAMPROP_ATTR2_ARRAYBASE )
			{
				bEnableArrayElement = TRUE;
			}
		}
	}
	m_lbAttr.SetRedraw( TRUE );
	m_lbAttr.Invalidate( FALSE );

	m_txtMin.ShowWindow( bShowValues );			m_txtMin.EnableWindow( bEnableValues );
	m_txtMax.ShowWindow( bShowValues );			m_txtMax.EnableWindow( bEnableValues );
	m_wndMin.ShowWindow( bShowValues );			m_wndMin.EnableWindow( bEnableValues );
	m_wndMax.ShowWindow( bShowValues );			m_wndMax.EnableWindow( bEnableValues );

	m_sliderValue.ShowWindow( bShowValues );	m_sliderValue.EnableWindow( bEnableValues );
	m_ebValue.ShowWindow( bShowValues );		m_ebValue.EnableWindow( bEnableValues );
	m_spinValue.ShowWindow( bShowValues );		m_spinValue.EnableWindow( bEnableValues );

	m_lbValues.ShowWindow( bShowModes );		m_lbValues.EnableWindow( bEnableModes );

	GetDlgItem( IDC_DLGDCAMPROPERTY_BTNARRAYELEMENT )->EnableWindow( bEnableArrayElement );

	CheckRadioButton( IDC_DLGDCAMPROPERTY_BTNWHOLEIDPROP, IDC_DLGDCAMPROPERTY_BTNARRAYELEMENT
		, m_idproparraybase == 0 ? IDC_DLGDCAMPROPERTY_BTNWHOLEIDPROP : IDC_DLGDCAMPROPERTY_BTNARRAYELEMENT );
}

/////////////////////////////////////////////////////////////////////////////
// CDlgDcamProperty message handlers

#define IDT_UPDATEPROPERTY	1

BOOL CDlgDcamProperty::OnInitDialog() 
{
	CDialog::OnInitDialog();

	// TODO: Add extra initialization here

	GetClientRect( &m_rcClient );
	{
		CRect	rc;
		m_listview.GetWindowRect( &rc );
		ScreenToClient( &rc );
		m_szSpaceListview = CSize( rc.left - m_rcClient.left, rc.top - m_rcClient.top );
	}

	m_listview.InsertColumn( INDEX_PROPERTY_NAME,   _T( "name" ),	LVCFMT_LEFT, 128 );
	m_listview.InsertColumn( INDEX_PROPERTY_UPDATE, _T( "#" ),		LVCFMT_LEFT,  16 );
	m_listview.InsertColumn( INDEX_PROPERTY_VALUE,  _T( "value" ),	LVCFMT_LEFT, 128 );

	m_listview.SetExtendedStyle( LVS_EX_FULLROWSELECT | LVS_EX_GRIDLINES );

	m_editprop.indexOnListview	= -1;
	m_editprop.idprop		= 0;

	if( m_hdcam != NULL )
	{
		update_viewchannel_control();
		update_listview_title( 0 );
		update_listview_value();
		reset_listview_updated_value();
	}
	update_controls();

	if( m_bUpdatePeriodically )
		SetTimer( IDT_UPDATEPROPERTY, 500, NULL );	// to update property status

	return TRUE;  // return TRUE unless you set the focus to a control
	              // EXCEPTION: OCX Property Pages should return FALSE
}

void CDlgDcamProperty::OnDestroy() 
{
	CDialog::OnDestroy();
	
	// TODO: Add your message handler code here

	m_bCreateDialog = FALSE;
}

void CDlgDcamProperty::OnSize(UINT nType, int cx, int cy) 
{
	CDialog::OnSize(nType, cx, cy);
	
	// TODO: Add your message handler code here

	if( IsWindow( m_listview.GetSafeHwnd() ) )
	{
		recalc_layout();
	}
}

LRESULT CDlgDcamProperty::OnNcHitTest(CPoint point) 
{
	LRESULT	ht = CDialog::OnNcHitTest(point);

	switch( ht )
	{
	case HTTOPLEFT:
	case HTTOPRIGHT:
		ht = HTTOP;
		break;
	case HTBOTTOMLEFT:
	case HTBOTTOMRIGHT:
		ht = HTBOTTOM;
		break;
	case HTLEFT:
	case HTRIGHT:
		ht = HTCAPTION;
		break;
	}

	return ht;
}

// ----

inline long interpret_scrollmessage( CSliderCtrl& slider, UINT nSBCode, double ratio = 0 )
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

	long	v = -slider.GetPos();
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
	case SB_PAGEUP:	v += page;	break;	// Scroll one page right.
	case SB_THUMBPOSITION:	// Scroll to absolute position. The current position is specified by the nPos parameter.
	case SB_THUMBTRACK:	// Drag scroll box to specified position. The current position is specified by the nPos parameter. 
	case SB_ENDSCROLL:	// End scroll.
		break;
	}

	if( v < nMin )
		v = nMin;
	else
	if( v > nMax )
		v = nMax;

	return v;
}

void CDlgDcamProperty::OnVScroll(UINT nSBCode, UINT nPos, CScrollBar* pScrollBar) 
{
	// TODO: Add your message handler code here and/or call default

	if( pScrollBar == (CScrollBar*)&m_sliderValue )
	{
		BOOL	bValid = FALSE;

		long	pos;
		double	oldValue, newValue;
		if( dcam_getpropertyvalue( m_hdcam, m_editprop.idprop, &oldValue ) )
		{
			pos = interpret_scrollmessage( m_sliderValue, nSBCode );
			newValue = pos * m_fRatioSlider;
			if( m_fStepSlider != 0 )
			{
				newValue -= fmod( newValue, m_fStepSlider );
			}

			ASSERT( m_hdcam != NULL );
			if( oldValue == newValue )
			{
				bValid = TRUE;
			}
			else
			{
				if( dcam_querypropertyvalue( m_hdcam, m_editprop.idprop, &newValue ) )
				{
					bValid = TRUE;
				}
				else
				{
					if( oldValue < newValue )
					{
						if( dcam_querypropertyvalue( m_hdcam, m_editprop.idprop, &newValue, DCAMPROP_OPTION_NEXT ) )
							bValid = TRUE;
					}
					else
					{
						ASSERT( newValue < oldValue );
						if( dcam_querypropertyvalue( m_hdcam, m_editprop.idprop, &newValue, DCAMPROP_OPTION_PRIOR ) )
							bValid = TRUE;
					}
				}
			}

			if( bValid )
				bValid = dcam_setgetpropertyvalue( m_hdcam, m_editprop.idprop, &newValue );
		}

		char	text[ 64 ];
		if( ! bValid )
		{
			strcpy_s( text, sizeof( text ), "(invalid)" );
		}
		else
		{
			value_to_text( m_hdcam, m_editprop.idprop, newValue, text, sizeof( text ) );
			m_sliderValue.SetPos( -pos );
		}

		CString	str;
		str = text;
		m_ebValue.SetWindowText( str );
		m_listview.SetItemText( m_editprop.indexOnListview, INDEX_PROPERTY_VALUE, str );
	}

	CDialog::OnVScroll(nSBCode, nPos, pScrollBar);
}

/////////////////////////////////////////////////////////////////////////////
// CDlgDcamProperty custom draw function

void CDlgDcamProperty::OnCustomdrawDlgdcampropertyListview(NMHDR* pNMHDR, LRESULT* pResult)
{
	// TODO: Add your control notification handler code here

	NMLVCUSTOMDRAW* lplvcd = (NMLVCUSTOMDRAW*)pNMHDR;

	/*
		CDDS_PREPAINT is at the beginning of the paint cycle. You 
		implement custom draw by returning the proper value. In this 
		case, we're requesting item-specific notifications.
	*/
	if( lplvcd->nmcd.dwDrawStage == CDDS_PREPAINT )
	{
		// Request prepaint notifications for each item.
		*pResult = CDRF_NOTIFYITEMDRAW;
	}
	else
	if( lplvcd->nmcd.dwDrawStage == CDDS_ITEMPREPAINT)
	{
		/*
			Because we returned CDRF_NOTIFYITEMDRAW in response to
			CDDS_PREPAINT, CDDS_ITEMPREPAINT is sent when the control is
			about to paint an item.
		*/

		/*
			To change the font, select the desired font into the 
			provided HDC. We're changing the font for every third item
			in the control, starting with item zero.
		*/

		/*
			To change the text and background colors in a list view 
			control, set the clrText and clrTextBk members of the 
			NMLVCUSTOMDRAW structure to the desired color.

			This differs from most other controls that support 
			CustomDraw. To change the text and background colors for 
			the others, call SetTextColor and SetBkColor on the provided HDC.
		*/

		BOOL	bGrayed;
		long	attr = m_arrayAttr.GetAt( lplvcd->nmcd.dwItemSpec );

		if( ( attr & DCAMPROP_ATTR_WRITABLE ) == 0 )
		{
			bGrayed = TRUE;
		}
		else
		{
			if( m_dcamstatus == DCAM_STATUS_UNSTABLE
			 ||	m_dcamstatus == DCAM_STATUS_STABLE 
			 || m_dcamstatus == DCAM_STATUS_READY && ( attr & DCAMPROP_ATTR_ACCESSREADY )
			 || m_dcamstatus == DCAM_STATUS_BUSY  && ( attr & DCAMPROP_ATTR_ACCESSBUSY ) )
			{
				bGrayed = FALSE;
			}
			else
			{
				bGrayed = TRUE;
			}
		}

		lplvcd->clrText = GetSysColor( bGrayed ? COLOR_GRAYTEXT : COLOR_WINDOWTEXT );

		/*
			We changed the font, so we're returning CDRF_NEWFONT. This
			tells the control to recalculate the extent of the text.
		*/
		*pResult = CDRF_NEWFONT;
	}
	else
		*pResult = 0;
}

/////////////////////////////////////////////////////////////////////////////
// CDlgDcamProperty command handlers

void CDlgDcamProperty::OnOK() 
{
	// TODO: Add extra validation here
/*
	if( m_bCreateDialog )
		DestroyWindow();
	else
		CDialog::OnOK();
*/
}

void CDlgDcamProperty::OnCancel() 
{
	// TODO: Add extra cleanup here
	
	if( m_bCreateDialog )
		DestroyWindow();
	else
		CDialog::OnCancel();
}


void CDlgDcamProperty::OnItemchangedDlgdcampropertyListview(NMHDR* pNMHDR, LRESULT* pResult) 
{
	NM_LISTVIEW* pNMListView = (NM_LISTVIEW*)pNMHDR;
	// TODO: Add your control notification handler code here
	
	long	i = m_listview.GetNextItem( -1, LVNI_SELECTED );
	if( i >= 0 && m_editprop.indexOnListview != i )
	{
		edit_property_of( i );
	}

	*pResult = 0;
}

void CDlgDcamProperty::OnClickDlgdcampropertyListview(NMHDR* pNMHDR, LRESULT* pResult) 
{
	// TODO: Add your control notification handler code here

	LVHITTESTINFO	lvht;
	memset( &lvht, 0, sizeof( lvht ) );

	GetCursorPos( &lvht.pt );
	m_listview.ScreenToClient( &lvht.pt );

	m_listview.SubItemHitTest( &lvht );
//	if( lvht.iItem >= 0 )
	edit_property_of( lvht.iItem );

	*pResult = 0;
}

void CDlgDcamProperty::OnDblclkDlgdcampropertyListview(NMHDR* pNMHDR, LRESULT* pResult) 
{
	// TODO: Add your control notification handler code here
	
	*pResult = 0;
}

/*
void CDlgDcamProperty::OnDlgdcampropertyBtnshowallproperties() 
{
	// TODO: Add your control notification handler code here

	DWORD	dwExStyle = m_listview.GetExtendedStyle();
	if( m_bShowAllProperties )
	{
		dwExStyle |= LVS_EX_CHECKBOXES;
	}
	else
	{
		dwExStyle &=~LVS_EX_CHECKBOXES;
	}
	m_listview.SetExtendedStyle( dwExStyle );
}
*/

void CDlgDcamProperty::OnDlgdcampropertyBtn( UINT nID )
{
	// TODO: Add your control notification handler code here

	m_iViewCh = nID - IDC_DLGDCAMPROPERTY_BTNALL;

	update_controls();

	update_all();
}

void CDlgDcamProperty::OnSelchangeDlgdcampropertyCbselectview() 
{
	// TODO: Add your control notification handler code here

	m_iViewCh = m_cbViewCh.GetCurSel();
	m_idpropoffset = (long)m_cbViewCh.GetItemData( m_iViewCh );

	update_listview_value();
	if( m_editprop.indexOnListview >= 0 )
		edit_property_of( m_editprop.indexOnListview );
}

void CDlgDcamProperty::OnSelchangeDlgdcampropertyLbvalues() 
{
	// TODO: Add your control notification handler code here

	long	i = m_lbValues.GetCurSel();
	ASSERT( i != LB_ERR );
	long	v = (long)m_lbValues.GetItemData( i );

	dcam_setpropertyvalue( m_hdcam, m_editprop.idprop + m_idpropoffset, v );

	edit_property_of( m_editprop.indexOnListview );

	char	buf[ 256 ];
	value_to_text( m_hdcam, m_editprop.idprop, v, buf, sizeof( buf) );
	CString	str;
	str = buf;
	m_listview.SetItemText( m_editprop.indexOnListview, INDEX_PROPERTY_VALUE, str );

	update_listview_updated_value();
}

void CDlgDcamProperty::OnChangeDlgdcampropertyEbvalue() 
{
	if( ! m_bChangingEditbox )
	{
		CString	str;
		m_ebValue.GetWindowText( str );

		double	v = atof( str );
		if( dcam_querypropertyvalue( m_hdcam, m_editprop.idprop + m_idpropoffset, &v ) )
		{
			if( dcam_setgetpropertyvalue( m_hdcam, m_editprop.idprop + m_idpropoffset, &v ) )
			{
				char	buf[ 256 ];
				value_to_text( m_hdcam, m_editprop.idprop, v, buf, sizeof( buf) );
				CString	str;
				str = buf;
				m_listview.SetItemText( m_editprop.indexOnListview, INDEX_PROPERTY_VALUE, str );
			}

			edit_property_of( m_editprop.indexOnListview );

			update_listview_updated_value();
		}
	}
}

void CDlgDcamProperty::OnDlgdcampropertyBtnuselistbox() 
{
	// TODO: Add your control notification handler code here

	m_bUseListboxAlways = ! m_bUseListboxAlways;

	update_controls();
	edit_property_of( m_editprop.indexOnListview );
}

void CDlgDcamProperty::OnDlgdcampropertyBtnupdateperiodically() 
{
	m_bUpdatePeriodically = ! m_bUpdatePeriodically;

	if( m_bUpdatePeriodically )
		SetTimer( IDT_UPDATEPROPERTY, 500, NULL );
	else
		KillTimer( IDT_UPDATEPROPERTY );
}

void CDlgDcamProperty::OnDlgdcampropertyBtnupdatevalues() 
{
	// TODO: Add your control notification handler code here	
	update_all();
}


void CDlgDcamProperty::OnDlgdcampropertyBtnwholeidprop() 
{
	// TODO: Add your control notification handler code here
	
	if( m_idproparraybase != 0 )
	{
		// find index on the listview.
		long	idprop = m_idproparraybase;

		update_listview_title( 0 );
		update_listview_value();
		reset_listview_updated_value();

		long	iItem;
		for( iItem = m_listview.GetItemCount(); iItem-- >= 0; )
		{
			long	i = (long)m_listview.GetItemData( iItem );
			if( (long)m_arrayIDPROP[ i ] == idprop )
				break;
		}

		edit_property_of( iItem );
		m_listview.SetItemState( iItem, LVIS_SELECTED | LVIS_FOCUSED, LVIS_SELECTED | LVIS_FOCUSED );
	}
}

void CDlgDcamProperty::OnDlgdcampropertyBtnarrayelement() 
{
	// TODO: Add your control notification handler code here

	ASSERT( m_idproparraybase == 0 );

	update_listview_title( m_editprop.idprop );
	update_listview_value();
	reset_listview_updated_value();

	long	iItem = 0;
	edit_property_of( iItem );
	m_listview.SetItemState( iItem, LVIS_SELECTED | LVIS_FOCUSED, LVIS_SELECTED | LVIS_FOCUSED );
}

void CDlgDcamProperty::OnTimer(UINT_PTR nIDEvent) 
{
	// TODO: Add your message handler code here and/or call default

	if( m_bAutomaticUpdatePropertyValues && m_arrayIDPROP.GetSize() > 0 )
	{
		update_listview_value();
	}

	CDialog::OnTimer(nIDEvent);
}

void CDlgDcamProperty::update_all()
{
	if( m_bAutomaticUpdatePropertyValues && m_arrayIDPROP.GetSize() > 0 )
	{
		if( m_bUpdatePeriodically )
			KillTimer( IDT_UPDATEPROPERTY );

		update_listview_updated_value();
		update_listview_value();
		update_controls();

		if( m_bUpdatePeriodically )
			SetTimer( IDT_UPDATEPROPERTY, 500, NULL );
	}
}
