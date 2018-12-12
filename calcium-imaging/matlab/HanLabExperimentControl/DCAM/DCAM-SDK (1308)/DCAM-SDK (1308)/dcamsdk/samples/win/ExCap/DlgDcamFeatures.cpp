// DlgDcamFeatures.cpp : implementation file
//

#include "stdafx.h"
#include "resource.h"

#include "DlgDcamFeatures.h"

#include "dcamex.h"

#ifdef _DEBUG
#define new DEBUG_NEW
#undef THIS_FILE
static char THIS_FILE[] = __FILE__;
#endif

/////////////////////////////////////////////////////////////////////////////
// private structure and functions

const long STEP_OF_IDC_DLGDCAMFEATURE_MODE = 4;

struct feature
{
	BOOL	bAvailable;
	long	capflags;
	double	min;
	double	max;
	double	step;
	double	defaultvalue;

	long	flags;
	double	value;

public:
	void	getSliderRange( long& pmin, long& pmax ) const;
	long	value_to_sliderpos( double value ) const;
	double	sliderpos_to_value( long pos ) const;
};

// ----

void feature::getSliderRange( long& pmin, long& pmax ) const
{
	ASSERT( bAvailable );

	if( step >= 1 )
	{
		pmin	= 0;
		pmax	= long( ( max - min ) / step );
	}
	else if( step > 0 )
	{
		double	nCount	= ( max - min ) / step;
		if( nCount <= 1000 )
		{
			pmin	= 0;
			pmax	= (long)nCount;
			if( pmax < nCount )
				pmax++;
		}
		else
		{
			pmin	= 0;
			pmax	= 1000;
		}
	}
	else
	{
		pmin	= 0;
		pmax	= 1;
	}
}

long feature::value_to_sliderpos( double value ) const
{
	ASSERT( bAvailable );

	long	pmin, pmax;
	getSliderRange( pmin, pmax );

	if( max == min )	return	0;

	long	pnow	= (long)( ( value - min ) * ( pmax - pmin ) / ( max - min ) + ( pmin ) );
		 if( pnow < pmin )	pnow	= pmin;
	else if( pnow > pmax )	pnow	= pmax;

	return	pnow;
}

double feature::sliderpos_to_value( long pos ) const
{
	ASSERT( bAvailable );

	long	pmin, pmax;
	getSliderRange( pmin, pmax );

	if( pmax == pmin )	return min;

	double	value	= ( pos - pmin ) * ( max - min ) / ( pmax - pmin ) + ( min );
		 if( value < min )	value	= min;
	else if( value > max )	value	= max;

	return	value;
}

/////////////////////////////////////////////////////////////////////////////
// CDlgDcamFeatures dialog

	static long	idfeatures[] = {
		DCAM_IDFEATURE_OFFSET,
		DCAM_IDFEATURE_GAIN,
		DCAM_IDFEATURE_EXPOSURETIME,
		DCAM_IDFEATURE_TEMPERATURE,
		DCAM_IDFEATURE_LIGHTMODE,
		DCAM_IDFEATURE_WHITEBALANCE,
		DCAM_IDFEATURE_SENSITIVITY,
		DCAM_IDFEATURE_OPTICALFILTER,
		DCAM_IDFEATURE_TEMPERATURETARGET,
		DCAM_IDFEATURE_TRIGGERTIMES
	};

CDlgDcamFeatures::~CDlgDcamFeatures()
{
	delete[] m_feature;
}

CDlgDcamFeatures::CDlgDcamFeatures( CWnd* pParent /*=NULL*/ )
	: CDialog( CDlgDcamFeatures::IDD, pParent )
{
	//{{AFX_DATA_INIT( CDlgDcamFeatures )
		// NOTE: the ClassWizard will add member initialization here
	//}}AFX_DATA_INIT

	m_nFeaturecount = sizeof( idfeatures ) / sizeof( idfeatures[ 0 ] );
	m_feature = new feature[ m_nFeaturecount ];
	memset( m_feature, 0, sizeof( *m_feature ) * m_nFeaturecount );

	m_hdcam = NULL;

	memset( &m_changing, 0, sizeof( m_changing ) );

	m_bCreateDialog = FALSE;
	m_hdcam			= NULL;
}

// ----------------

HDCAM CDlgDcamFeatures::set_hdcam( HDCAM hdcam )
{
	HDCAM	old = m_hdcam;
	m_hdcam = hdcam;

	update_values();

	if( IsWindow( GetSafeHwnd() ) && IsWindowVisible() )
	{
		long	i;
		for( i = 0; i < m_nFeaturecount; i++ )
			update_control( i, TRUE );
	}

	return old;
}

BOOL CDlgDcamFeatures::toggle_visible()
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


BOOL CDlgDcamFeatures::Create( CWnd* pParentWnd ) 
{
	// TODO: Add your specialized code here and/or call the base class
	
	m_bCreateDialog = CDialog::Create( IDD, pParentWnd );
	return m_bCreateDialog;
}

// ----------------

#define	IDC_DLGDCAMFEATURE_MODE_OFF_TOP		IDC_DLGDCAMFEATURE_OFFSET_MODE_OFF
#define	IDC_DLGDCAMFEATURE_MODE_MANUAL_TOP	IDC_DLGDCAMFEATURE_OFFSET_MODE_MANUAL
#define	IDC_DLGDCAMFEATURE_MODE_AUTO_TOP	IDC_DLGDCAMFEATURE_OFFSET_MODE_AUTO
#define	IDC_DLGDCAMFEATURE_MODE_ONEPUSH_TOP	IDC_DLGDCAMFEATURE_OFFSET_MODE_ONEPUSH

#define	IDC_DLGDCAMFEATURE_GROUP_TOP		IDC_DLGDCAMFEATURE_OFFSET_GROUP
#define	IDC_DLGDCAMFEATURE_EBMIN_TOP		IDC_DLGDCAMFEATURE_OFFSET_EBMIN
#define	IDC_DLGDCAMFEATURE_SLIDER_TOP		IDC_DLGDCAMFEATURE_OFFSET_SLIDER
#define	IDC_DLGDCAMFEATURE_EBMAX_TOP		IDC_DLGDCAMFEATURE_OFFSET_EBMAX
#define	IDC_DLGDCAMFEATURE_EBVALUE_TOP		IDC_DLGDCAMFEATURE_OFFSET_EBVALUE
#define	IDC_DLGDCAMFEATURE_EBVALUEREAD_TOP	IDC_DLGDCAMFEATURE_OFFSET_EBVALUEREAD
#define	IDC_DLGDCAMFEATURE_LABELSTEP_TOP	IDC_DLGDCAMFEATURE_OFFSET_LABELSTEP
#define	IDC_DLGDCAMFEATURE_EBSTEP_TOP		IDC_DLGDCAMFEATURE_OFFSET_EBSTEP
#define	IDC_DLGDCAMFEATURE_LABELDEFAULT_TOP	IDC_DLGDCAMFEATURE_OFFSET_LABELDEFAULT
#define	IDC_DLGDCAMFEATURE_EBDEFAULT_TOP	IDC_DLGDCAMFEATURE_OFFSET_EBDEFAULT

#define	IDC_DLGDCAMFEATURE_EBVALUE_LAST		IDC_DLGDCAMFEATURE_TRIGGERTIMES_EBVALUE
#define	IDC_DLGDCAMFEATURE_MODE_TOP			IDC_DLGDCAMFEATURE_OFFSET_MODE_OFF
#define	IDC_DLGDCAMFEATURE_MODE_LAST		IDC_DLGDCAMFEATURE_TRIGGERTIMES_MODE_ONEPUSH


void CDlgDcamFeatures::update_value( int iFeature )
{
	ASSERT( 0 <= iFeature && iFeature < m_nFeaturecount );
	ASSERT( m_hdcam != NULL );

	struct feature&	info = m_feature[ iFeature ];
	memset( &info, 0, sizeof( info ) );

	if( dcamex_getfeatureinq( m_hdcam, idfeatures[ iFeature ]
			, info.capflags
			, info.min
			, info.max
			, info.step
			, info.defaultvalue ) )
	{
		info.bAvailable	= TRUE;

		// get feature values.
		VERIFY( dcamex_getfeature( m_hdcam, idfeatures[ iFeature ], info.value, info.flags )
			|| ! ( info.flags & DCAM_FEATURE_FLAGS_MANUAL ) );
	}
}

void CDlgDcamFeatures::update_values()
{
	long	i;

	// get feature information.

	memset( m_feature, 0, sizeof( *m_feature ) * m_nFeaturecount );
	if( m_hdcam != NULL )
	{
		// DIRECT EM GAIN
		if( IsWindow( m_btnDirectEMGain.GetSafeHwnd() ) )
		{
			double	value;
			if( ! dcam_getpropertyvalue( m_hdcam, DCAM_IDPROP_DIRECTEMGAIN_MODE, &value ) )
			{
				m_btnDirectEMGain.EnableWindow( FALSE );
			}
			else
			{
				m_btnDirectEMGain.EnableWindow( TRUE );
				m_btnDirectEMGain.SetCheck( value == DCAMPROP_MODE__ON ? 1 : 0 );
			}
		}

		for( i = 0; i < m_nFeaturecount; i++ )
		{
			update_value( i );
		}
	}
}

// ----

void CDlgDcamFeatures::update_control( int iFeature, BOOL bInitialize )
{
	ASSERT( 0 <= iFeature && iFeature < m_nFeaturecount );

	struct feature&	info = m_feature[ iFeature ];

	BOOL	bReadable = info.bAvailable;
	BOOL	bWritable = ( info.flags & DCAM_FEATURE_FLAGS_MANUAL );

	// Update label and sliders

	GetDlgItem( IDC_DLGDCAMFEATURE_GROUP_TOP		+ iFeature )->EnableWindow( info.bAvailable );
	GetDlgItem( IDC_DLGDCAMFEATURE_EBMIN_TOP		+ iFeature )->EnableWindow( info.bAvailable );
	GetDlgItem( IDC_DLGDCAMFEATURE_SLIDER_TOP		+ iFeature )->EnableWindow( bWritable      );
	GetDlgItem( IDC_DLGDCAMFEATURE_EBMAX_TOP		+ iFeature )->EnableWindow( info.bAvailable );
	GetDlgItem( IDC_DLGDCAMFEATURE_EBVALUE_TOP		+ iFeature )->EnableWindow( bWritable      );
	GetDlgItem( IDC_DLGDCAMFEATURE_EBVALUEREAD_TOP	+ iFeature )->EnableWindow( info.bAvailable );
	GetDlgItem( IDC_DLGDCAMFEATURE_LABELSTEP_TOP	+ iFeature )->EnableWindow( info.bAvailable );
	GetDlgItem( IDC_DLGDCAMFEATURE_EBSTEP_TOP		+ iFeature )->EnableWindow( info.bAvailable );
	GetDlgItem( IDC_DLGDCAMFEATURE_LABELDEFAULT_TOP	+ iFeature )->EnableWindow( info.bAvailable );
	GetDlgItem( IDC_DLGDCAMFEATURE_EBDEFAULT_TOP	+ iFeature )->EnableWindow( info.bAvailable );

	if( info.bAvailable )
	{
		long	nMin, nMax;
		info.getSliderRange( nMin, nMax );

		long	id = IDC_DLGDCAMFEATURE_SLIDER_TOP + iFeature;
		( (CSliderCtrl*)GetDlgItem( id ) )->SetRange( nMin, nMax );

		SetDlgItemDbl( IDC_DLGDCAMFEATURE_EBMIN_TOP     + iFeature, info.min );
		SetDlgItemDbl( IDC_DLGDCAMFEATURE_EBMAX_TOP     + iFeature, info.max );
		SetDlgItemDbl( IDC_DLGDCAMFEATURE_EBSTEP_TOP    + iFeature, info.step );
		SetDlgItemDbl( IDC_DLGDCAMFEATURE_EBDEFAULT_TOP + iFeature, info.defaultvalue );

		GetDlgItem( IDC_DLGDCAMFEATURE_EBMIN_TOP		+ iFeature )->ShowWindow( SW_SHOW );
		GetDlgItem( IDC_DLGDCAMFEATURE_EBMAX_TOP		+ iFeature )->ShowWindow( SW_SHOW );
		GetDlgItem( IDC_DLGDCAMFEATURE_LABELSTEP_TOP	+ iFeature )->ShowWindow( SW_SHOW );
		GetDlgItem( IDC_DLGDCAMFEATURE_EBSTEP_TOP		+ iFeature )->ShowWindow( SW_SHOW );
		GetDlgItem( IDC_DLGDCAMFEATURE_LABELDEFAULT_TOP	+ iFeature )->ShowWindow( SW_SHOW );
		GetDlgItem( IDC_DLGDCAMFEATURE_EBDEFAULT_TOP	+ iFeature )->ShowWindow( SW_SHOW );

		// mode
		// off
		id = IDC_DLGDCAMFEATURE_MODE_OFF_TOP + iFeature * STEP_OF_IDC_DLGDCAMFEATURE_MODE;
		( (CButton*)GetDlgItem( id ) )->EnableWindow( info.capflags & DCAM_FEATURE_FLAGS_ONOFF );

		// manual
		id = IDC_DLGDCAMFEATURE_MODE_MANUAL_TOP + iFeature * STEP_OF_IDC_DLGDCAMFEATURE_MODE;
		( (CButton*)GetDlgItem( id ) )->EnableWindow( info.capflags & DCAM_FEATURE_FLAGS_MANUAL );

		// auto
		id = IDC_DLGDCAMFEATURE_MODE_AUTO_TOP + iFeature * STEP_OF_IDC_DLGDCAMFEATURE_MODE;
		( (CButton*)GetDlgItem( id ) )->EnableWindow( info.capflags & DCAM_FEATURE_FLAGS_AUTO );

		// onepush
		id = IDC_DLGDCAMFEATURE_MODE_ONEPUSH_TOP + iFeature * STEP_OF_IDC_DLGDCAMFEATURE_MODE;
		( (CButton*)GetDlgItem( id ) )->EnableWindow( info.capflags & DCAM_FEATURE_FLAGS_ONE_PUSH );
	}
	else
	{
		GetDlgItem( IDC_DLGDCAMFEATURE_EBMIN_TOP		+ iFeature )->ShowWindow( SW_HIDE );
		GetDlgItem( IDC_DLGDCAMFEATURE_EBMAX_TOP		+ iFeature )->ShowWindow( SW_HIDE );
		GetDlgItem( IDC_DLGDCAMFEATURE_LABELSTEP_TOP	+ iFeature )->ShowWindow( SW_HIDE );
		GetDlgItem( IDC_DLGDCAMFEATURE_EBSTEP_TOP		+ iFeature )->ShowWindow( SW_HIDE );
		GetDlgItem( IDC_DLGDCAMFEATURE_LABELDEFAULT_TOP	+ iFeature )->ShowWindow( SW_HIDE );
		GetDlgItem( IDC_DLGDCAMFEATURE_EBDEFAULT_TOP	+ iFeature )->ShowWindow( SW_HIDE );

		m_changing.value++;

		SetDlgItemText( IDC_DLGDCAMFEATURE_EBVALUEREAD_TOP + iFeature, _T( "" ) );
		SetDlgItemText( IDC_DLGDCAMFEATURE_EBVALUE_TOP + iFeature, _T( "" ) );

		m_changing.value--;

		// mode
		long	i, id;
		for( i = 0; i < STEP_OF_IDC_DLGDCAMFEATURE_MODE; i++ )
		{
			id = IDC_DLGDCAMFEATURE_MODE_OFF_TOP + iFeature * STEP_OF_IDC_DLGDCAMFEATURE_MODE + i;
			CButton*	btn = (CButton*)GetDlgItem( id );
			
			btn->SetCheck( FALSE );
			btn->EnableWindow( FALSE );
		}

		return;
	}

	// update value

	SetDlgItemDbl( IDC_DLGDCAMFEATURE_EBVALUEREAD_TOP + iFeature, info.value );

	if( m_changing.value == 0 )
	{
		m_changing.value++;

		if( bInitialize )
		{
			SetDlgItemDbl( IDC_DLGDCAMFEATURE_EBVALUE_TOP + iFeature, info.value );
		}

		m_changing.value--;
	}

	// update radio buttons

	{
		BOOL	bDefault= FALSE;
		BOOL	bManual	= FALSE;
		BOOL	bAuto	= FALSE;
		BOOL	bOnePush= FALSE;

		if( info.flags & DCAM_FEATURE_FLAGS_OFF )
			bDefault = TRUE;
		else
		if( info.flags & DCAM_FEATURE_FLAGS_MANUAL )
			bManual = TRUE;
		else
		if( info.flags & DCAM_FEATURE_FLAGS_AUTO )
			bAuto = TRUE;
		else
		if( info.flags & DCAM_FEATURE_FLAGS_ONE_PUSH )
			bOnePush = TRUE;

		long	id;
		// off
		id = IDC_DLGDCAMFEATURE_MODE_OFF_TOP + iFeature * STEP_OF_IDC_DLGDCAMFEATURE_MODE;
		( (CButton*)GetDlgItem( id ) )->SetCheck( bDefault );

		// manual
		id = IDC_DLGDCAMFEATURE_MODE_MANUAL_TOP + iFeature * STEP_OF_IDC_DLGDCAMFEATURE_MODE;
		( (CButton*)GetDlgItem( id ) )->SetCheck( bManual );

		// auto
		id = IDC_DLGDCAMFEATURE_MODE_AUTO_TOP + iFeature * STEP_OF_IDC_DLGDCAMFEATURE_MODE;
		( (CButton*)GetDlgItem( id ) )->SetCheck( bAuto );

		// onepush
		id = IDC_DLGDCAMFEATURE_MODE_ONEPUSH_TOP + iFeature * STEP_OF_IDC_DLGDCAMFEATURE_MODE;
		( (CButton*)GetDlgItem( id ) )->SetCheck( bOnePush );
	}

	//	update slider pos

	if( m_changing.slider == 0 )
	{
		m_changing.slider++;

		long	nPos = info.value_to_sliderpos( info.value );
		( (CSliderCtrl*)GetDlgItem( IDC_DLGDCAMFEATURE_SLIDER_TOP + iFeature ) )->SetPos( nPos );

		m_changing.slider--;
	}
}

/////////////////////////////////////////////////////////////////////////////
// helper functions

BOOL CDlgDcamFeatures::GetDlgItemDbl( int nID, double& fValue )
{
	TCHAR	buf[ 256 ];
	GetDlgItemText( nID, buf, sizeof( buf ) );

	fValue = atof( buf );
	return buf[ 0 ] != _T( '\0' );
}

void CDlgDcamFeatures::SetDlgItemDbl( int nID, double fValue )
{
	CString	str;
	str.Format( _T( "%lg" ), fValue );

	SetDlgItemText( nID, str );
}

/////////////////////////////////////////////////////////////////////////////

void CDlgDcamFeatures::DoDataExchange( CDataExchange* pDX )
{
	CDialog::DoDataExchange( pDX );
	//{{AFX_DATA_MAP( CDlgDcamFeatures )
	DDX_Control(pDX, IDC_DLGDCAMFEATURE_BTNDIRECTEMGAIN, m_btnDirectEMGain);
	//}}AFX_DATA_MAP
}


BEGIN_MESSAGE_MAP( CDlgDcamFeatures, CDialog )
	//{{AFX_MSG_MAP( CDlgDcamFeatures )
	ON_WM_DESTROY()
	ON_WM_HSCROLL()
	ON_BN_CLICKED(IDC_DLGDCAMFEATURE_BTNDIRECTEMGAIN, OnDlgdcamfeatureBtndirectemgain)
	//}}AFX_MSG_MAP
	ON_CONTROL_RANGE( EN_CHANGE, IDC_DLGDCAMFEATURE_EBVALUE_TOP, IDC_DLGDCAMFEATURE_EBVALUE_LAST, OnChangeValue )
	ON_COMMAND_RANGE( IDC_DLGDCAMFEATURE_MODE_TOP, IDC_DLGDCAMFEATURE_MODE_LAST, OnChangeMode )
END_MESSAGE_MAP()

/////////////////////////////////////////////////////////////////////////////
// CDlgDcamFeatures message handlers

BOOL CDlgDcamFeatures::OnInitDialog() 
{
	CDialog::OnInitDialog();
	
	// TODO: Add extra initialization here

	update_values();

	long	i;
	for( i = 0; i < m_nFeaturecount; i++ )
		update_control( i, TRUE );

	return TRUE;  // return TRUE unless you set the focus to a control
	              // EXCEPTION: OCX Property Pages should return FALSE
}

void CDlgDcamFeatures::OnDestroy() 
{
	CDialog::OnDestroy();
	
	// TODO: Add your message handler code here
	
	m_bCreateDialog = FALSE;
}

void CDlgDcamFeatures::OnOK() 
{
	if( ! UpdateData() )
		return;
	
	if( m_bCreateDialog )
		;	// nothing to do
	else
		CDialog::OnOK();
}

void CDlgDcamFeatures::OnCancel() 
{
	// TODO: Add extra cleanup here

	if( m_bCreateDialog )
		DestroyWindow();
	else
		CDialog::OnCancel();
}

void CDlgDcamFeatures::OnChangeValue( UINT id )
{
	if( m_changing.value == 0 )
	{
		m_changing.value++;

		long	iFeature = id - IDC_DLGDCAMFEATURE_EBVALUE_TOP;

		struct feature&	info = m_feature[ iFeature ];
		ASSERT( info.bAvailable );

		// just change the value
		double	fValue	= info.value;
		if( GetDlgItemDbl( IDC_DLGDCAMFEATURE_EBVALUE_TOP + iFeature, fValue ) )
			dcamex_setfeaturevalue( m_hdcam, idfeatures[ iFeature ], ( float )fValue );

		VERIFY( dcamex_getfeature( m_hdcam, idfeatures[ iFeature ], info.value, info.flags ) );

		update_control( iFeature );
		m_changing.value--;
	}
}

void CDlgDcamFeatures::OnChangeMode( UINT id )
{
	{
		long	i = id - IDC_DLGDCAMFEATURE_MODE_TOP;

		long	iFeature = i / STEP_OF_IDC_DLGDCAMFEATURE_MODE;
		long	flags;

		ASSERT( 0 <= iFeature && iFeature < m_nFeaturecount );

		switch( i % STEP_OF_IDC_DLGDCAMFEATURE_MODE )
		{
		case 0:	flags = DCAM_FEATURE_FLAGS_OFF;			break;
		case 1:	flags = DCAM_FEATURE_FLAGS_MANUAL;		break;
		case 2:	flags = DCAM_FEATURE_FLAGS_AUTO;		break;
		case 3:	flags = DCAM_FEATURE_FLAGS_ONE_PUSH;	break;
		default:
			ASSERT( 0 );
		}

		struct feature&	info = m_feature[ iFeature ];
		ASSERT( info.bAvailable );

		if( flags != DCAM_FEATURE_FLAGS_OFF )
		{
			if( ( info.capflags & DCAM_FEATURE_FLAGS_ONOFF ) == DCAM_FEATURE_FLAGS_ONOFF )
				flags |= DCAM_FEATURE_FLAGS_ON;
		}

		// just change the mode
		dcamex_setfeatureflags( m_hdcam, idfeatures[ iFeature ], flags );

		VERIFY( dcamex_getfeature( m_hdcam, idfeatures[ iFeature ], info.value, info.flags ) );

		update_control( iFeature );
	}
}

void CDlgDcamFeatures::OnHScroll( UINT nSBCode, UINT nPos, CScrollBar* pScrollBar ) 
{
	// TODO: Add your message handler code here and/or call default

	if( m_changing.slider == 0 )
	{
		m_changing.slider++;

		ASSERT( pScrollBar != NULL );

		long	iFeature = pScrollBar->GetDlgCtrlID() - IDC_DLGDCAMFEATURE_SLIDER_TOP;
		ASSERT( 0 <= iFeature && iFeature < m_nFeaturecount );

		CSliderCtrl*	slider = ( CSliderCtrl* )pScrollBar;

		struct feature&	info = m_feature[ iFeature ];
		ASSERT( info.bAvailable );

		long	nowPos, newPos;
		long	nMin, nMax;

		nowPos = slider->GetPos();
		info.getSliderRange( nMin, nMax );

		BOOL	bForce = FALSE;

		switch( nSBCode )
		{
		case SB_LEFT:			newPos	= nMin;			break;
		case SB_ENDSCROLL:		newPos	= nowPos;		break;
		case SB_LINELEFT:		newPos	= nowPos - 1;	break;
		case SB_LINERIGHT:		newPos	= nowPos + 1;	break;
		case SB_PAGELEFT:		newPos	= nowPos - 10;	break;
		case SB_PAGERIGHT:		newPos	= nowPos + 10;	break;
		case SB_RIGHT:			newPos	= nMax;			break;
		case SB_THUMBPOSITION:	newPos	= nPos;			bForce = TRUE;	break;
		case SB_THUMBTRACK:		newPos	= nPos;			bForce = TRUE;	break;
		default:				newPos	= nowPos;		break;
		}

			 if( newPos < nMin )	newPos	= nMin;
		else if( newPos > nMax )	newPos	= nMax;

		double	fNow;
		VERIFY( GetDlgItemDbl( IDC_DLGDCAMFEATURE_EBVALUE_TOP + iFeature, fNow ) );

		double	fNew = info.sliderpos_to_value( newPos );

		if( fNew != fNow || bForce )
		{
			slider->SetPos( newPos );
			SetDlgItemDbl( IDC_DLGDCAMFEATURE_EBVALUE_TOP + iFeature, fNew );
		}

		m_changing.slider--;
	}
	
	CDialog::OnHScroll( nSBCode, nPos, pScrollBar );
}

void CDlgDcamFeatures::OnDlgdcamfeatureBtndirectemgain() 
{
	// TODO: Add your control notification handler code here

	double	value;
	value = ( m_btnDirectEMGain.GetCheck() == 0 ? DCAMPROP_MODE__OFF : DCAMPROP_MODE__ON );

	if( ! dcam_setpropertyvalue( m_hdcam, DCAM_IDPROP_DIRECTEMGAIN_MODE, value ) )
	{
		AfxMessageBox( _T( "INTERNAL ERROR: dcam_setpropertyvalue( DCAM_IDPROP_DIRECTEMGAIN_MODE ) returns error" ) );
	}
	else
	{
		int	i;
		for( i = 0; i < m_nFeaturecount; i++ )
		{
			if( idfeatures[ i ] == DCAM_IDFEATURE_SENSITIVITY )
			{
				update_value( i );
				update_control( i, TRUE );
			}
		}
	}
}
