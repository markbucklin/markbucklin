// DlgDcamRGBRatio.cpp : implementation file
//

#include "stdafx.h"
#include "resource.h"

#include "DlgDcamRGBRatio.h"

#ifdef _DEBUG
#define new DEBUG_NEW
#undef THIS_FILE
static char THIS_FILE[] = __FILE__;
#endif

const long IDT_CHANGEVALUE = 1;

/////////////////////////////////////////////////////////////////////////////
// CDlgDcamRGBRatio dialog

CDlgDcamRGBRatio::~CDlgDcamRGBRatio()
{
	delete m_rgbratio;
}

CDlgDcamRGBRatio::CDlgDcamRGBRatio(CWnd* pParent /*=NULL*/)
	: CDialog(CDlgDcamRGBRatio::IDD, pParent)
{
	//{{AFX_DATA_INIT(CDlgDcamRGBRatio)
	//}}AFX_DATA_INIT

	m_rgbratio = new DCAM_PARAM_RGBRATIO;
	memset( m_rgbratio, 0, sizeof( DCAM_PARAM_RGBRATIO ));

	m_rgbratio->exposure.red   = 1.0;
	m_rgbratio->exposure.green = 1.0;
	m_rgbratio->exposure.blue  = 1.0;
	m_rgbratio->gain.red   = 1.0;
	m_rgbratio->gain.green = 1.0;
	m_rgbratio->gain.blue  = 1.0;

	m_bCreateDialog = FALSE;
	m_hdcam			= NULL;
	m_bBlocked		= FALSE;
}

// ----------------

HDCAM CDlgDcamRGBRatio::set_hdcam( HDCAM hdcam )
{
	HDCAM	old = m_hdcam;
	m_hdcam = hdcam;

//	update_values();

	return old;
}

BOOL CDlgDcamRGBRatio::toggle_visible()
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

BOOL CDlgDcamRGBRatio::Create( CWnd* pParentWnd ) 
{
	// TODO: Add your specialized code here and/or call the base class
	
	m_bCreateDialog = CDialog::Create(IDD, pParentWnd);
	return m_bCreateDialog;
}

// ----------------

void CDlgDcamRGBRatio::DoDataExchange(CDataExchange* pDX)
{
	CDialog::DoDataExchange(pDX);
	//{{AFX_DATA_MAP(CDlgDcamRGBRatio)
	//}}AFX_DATA_MAP
	DDX_Text(pDX, IDC_DLGDCAMRGBRATIO_EXPO_EBRED,  m_rgbratio->exposure.red);
	DDX_Text(pDX, IDC_DLGDCAMRGBRATIO_EXPO_EBGREEN,m_rgbratio->exposure.green);
	DDX_Text(pDX, IDC_DLGDCAMRGBRATIO_EXPO_EBBLUE, m_rgbratio->exposure.blue);
	DDX_Text(pDX, IDC_DLGDCAMRGBRATIO_GAIN_EBRED,  m_rgbratio->gain.red);
	DDX_Text(pDX, IDC_DLGDCAMRGBRATIO_GAIN_EBGREEN,m_rgbratio->gain.green);
	DDX_Text(pDX, IDC_DLGDCAMRGBRATIO_GAIN_EBBLUE, m_rgbratio->gain.blue);
}


BEGIN_MESSAGE_MAP(CDlgDcamRGBRatio, CDialog)
	//{{AFX_MSG_MAP(CDlgDcamRGBRatio)
	ON_BN_CLICKED(IDC_DLGDCAMRGBRATIO_EXPO_BTNSET1BLUE,  OnRgbratioExpoBtnset1blue)
	ON_BN_CLICKED(IDC_DLGDCAMRGBRATIO_EXPO_BTNSET1GREEN, OnRgbratioExpoBtnset1green)
	ON_BN_CLICKED(IDC_DLGDCAMRGBRATIO_EXPO_BTNSET1RED,   OnRgbratioExpoBtnset1red)
	ON_BN_CLICKED(IDC_DLGDCAMRGBRATIO_GAIN_BTNSET1BLUE,  OnRgbratioGainBtnset1blue)
	ON_BN_CLICKED(IDC_DLGDCAMRGBRATIO_GAIN_BTNSET1GREEN, OnRgbratioGainBtnset1green)
	ON_BN_CLICKED(IDC_DLGDCAMRGBRATIO_GAIN_BTNSET1RED,   OnRgbratioGainBtnset1red)
	ON_BN_CLICKED(IDC_DLGDCAMRGBRATIO_EXPO_BTNHALFBLUE,  OnRgbratioExpoBtnhalfblue)
	ON_BN_CLICKED(IDC_DLGDCAMRGBRATIO_EXPO_BTNHALFGREEN, OnRgbratioExpoBtnhalfgreen)
	ON_BN_CLICKED(IDC_DLGDCAMRGBRATIO_EXPO_BTNHALFRED,   OnRgbratioExpoBtnhalfred)
	ON_BN_CLICKED(IDC_DLGDCAMRGBRATIO_GAIN_BTNHALFBLUE,  OnRgbratioGainBtnhalfblue)
	ON_BN_CLICKED(IDC_DLGDCAMRGBRATIO_GAIN_BTNHALFGREEN, OnRgbratioGainBtnhalfgreen)
	ON_BN_CLICKED(IDC_DLGDCAMRGBRATIO_GAIN_BTNHALFRED,   OnRgbratioGainBtnhalfred)
	ON_BN_CLICKED(IDC_DLGDCAMRGBRATIO_EXPO_BTNTWICEBLUE, OnRgbratioExpoBtntwiceblue)
	ON_BN_CLICKED(IDC_DLGDCAMRGBRATIO_EXPO_BTNTWICEGREEN,OnRgbratioExpoBtntwicegreen)
	ON_BN_CLICKED(IDC_DLGDCAMRGBRATIO_EXPO_BTNTWICERED,  OnRgbratioExpoBtntwicered)
	ON_BN_CLICKED(IDC_DLGDCAMRGBRATIO_GAIN_BTNTWICEBLUE, OnRgbratioGainBtntwiceblue)
	ON_BN_CLICKED(IDC_DLGDCAMRGBRATIO_GAIN_BTNTWICEGREEN,OnRgbratioGainBtntwicegreen)
	ON_BN_CLICKED(IDC_DLGDCAMRGBRATIO_GAIN_BTNTWICERED,  OnRgbratioGainBtntwicered)
	ON_BN_CLICKED(IDC_DLGDCAMRGBRATIO_EXPO_WHITEBALANCE, OnRgbratioExpoWhitebalance)
	ON_EN_CHANGE(IDC_DLGDCAMRGBRATIO_EXPO_EBBLUE, OnChangeRgbvalue)
	ON_WM_TIMER()
	ON_EN_CHANGE(IDC_DLGDCAMRGBRATIO_EXPO_EBGREEN, OnChangeRgbvalue)
	ON_EN_CHANGE(IDC_DLGDCAMRGBRATIO_EXPO_EBRED, OnChangeRgbvalue)
	ON_EN_CHANGE(IDC_DLGDCAMRGBRATIO_GAIN_EBBLUE, OnChangeRgbvalue)
	ON_EN_CHANGE(IDC_DLGDCAMRGBRATIO_GAIN_EBGREEN, OnChangeRgbvalue)
	ON_EN_CHANGE(IDC_DLGDCAMRGBRATIO_GAIN_EBRED, OnChangeRgbvalue)
	ON_WM_DESTROY()
	//}}AFX_MSG_MAP
END_MESSAGE_MAP()

/////////////////////////////////////////////////////////////////////////////

void CDlgDcamRGBRatio::update_ratiovalue( UINT id, double& value )
{
	if( ! m_bBlocked )
	{
		CString	str;
		GetDlgItemText( id, str );
		value = atof( str );

		update_values();
	}
}

BOOL CDlgDcamRGBRatio::update_values( BOOL bSet )
{
	KillTimer( IDT_CHANGEVALUE );

	if( m_hdcam == NULL)
		return FALSE;

	m_rgbratio->hdr.cbSize	= sizeof( *m_rgbratio );
	m_rgbratio->hdr.id		= DCAM_IDPARAM_RGBRATIO;
	m_rgbratio->hdr.iFlag	= dcamparam_rgbratio_exposure
							| dcamparam_rgbratio_gain;

	if( bSet )
	{
		dcam_extended( m_hdcam, DCAM_IDMSG_SETPARAM, m_rgbratio, sizeof( *m_rgbratio ));
	}

	dcam_extended( m_hdcam, DCAM_IDMSG_GETPARAM, m_rgbratio, sizeof( *m_rgbratio ));

	m_bBlocked = TRUE;
	UpdateData( FALSE );
	m_bBlocked = FALSE;

	BOOL	bEnable;
	
	bEnable = ( m_rgbratio->hdr.oFlag & dcamparam_rgbratio_exposure) ? 1 : 0;
	GetDlgItem( IDC_DLGDCAMRGBRATIO_EXPO_GROUP		   )->EnableWindow( bEnable );
	GetDlgItem( IDC_DLGDCAMRGBRATIO_EXPO_TXTRED        )->EnableWindow( bEnable );
	GetDlgItem( IDC_DLGDCAMRGBRATIO_EXPO_EBRED         )->EnableWindow( bEnable );
	GetDlgItem( IDC_DLGDCAMRGBRATIO_EXPO_BTNHALFRED    )->EnableWindow( bEnable );
	GetDlgItem( IDC_DLGDCAMRGBRATIO_EXPO_BTNSET1RED    )->EnableWindow( bEnable );
	GetDlgItem( IDC_DLGDCAMRGBRATIO_EXPO_BTNTWICERED   )->EnableWindow( bEnable );
	GetDlgItem( IDC_DLGDCAMRGBRATIO_EXPO_TXTGREEN      )->EnableWindow( bEnable );
	GetDlgItem( IDC_DLGDCAMRGBRATIO_EXPO_EBGREEN       )->EnableWindow( bEnable );
	GetDlgItem( IDC_DLGDCAMRGBRATIO_EXPO_BTNHALFGREEN  )->EnableWindow( bEnable );
	GetDlgItem( IDC_DLGDCAMRGBRATIO_EXPO_BTNSET1GREEN  )->EnableWindow( bEnable );
	GetDlgItem( IDC_DLGDCAMRGBRATIO_EXPO_BTNTWICEGREEN )->EnableWindow( bEnable );
	GetDlgItem( IDC_DLGDCAMRGBRATIO_EXPO_TXTBLUE       )->EnableWindow( bEnable );
	GetDlgItem( IDC_DLGDCAMRGBRATIO_EXPO_EBBLUE        )->EnableWindow( bEnable );
	GetDlgItem( IDC_DLGDCAMRGBRATIO_EXPO_BTNHALFBLUE   )->EnableWindow( bEnable );
	GetDlgItem( IDC_DLGDCAMRGBRATIO_EXPO_BTNSET1BLUE   )->EnableWindow( bEnable );
	GetDlgItem( IDC_DLGDCAMRGBRATIO_EXPO_BTNTWICEBLUE  )->EnableWindow( bEnable );

	bEnable = ( m_rgbratio->hdr.oFlag & dcamparam_rgbratio_gain) ? 1 : 0;
	GetDlgItem( IDC_DLGDCAMRGBRATIO_GAIN_GROUP         )->EnableWindow( bEnable );
	GetDlgItem( IDC_DLGDCAMRGBRATIO_GAIN_EBRED         )->EnableWindow( bEnable );
	GetDlgItem( IDC_DLGDCAMRGBRATIO_GAIN_TXTRED        )->EnableWindow( bEnable );
	GetDlgItem( IDC_DLGDCAMRGBRATIO_GAIN_BTNHALFRED    )->EnableWindow( bEnable );
	GetDlgItem( IDC_DLGDCAMRGBRATIO_GAIN_BTNSET1RED    )->EnableWindow( bEnable );
	GetDlgItem( IDC_DLGDCAMRGBRATIO_GAIN_BTNTWICERED   )->EnableWindow( bEnable );
	GetDlgItem( IDC_DLGDCAMRGBRATIO_GAIN_TXTGREEN      )->EnableWindow( bEnable );
	GetDlgItem( IDC_DLGDCAMRGBRATIO_GAIN_EBGREEN       )->EnableWindow( bEnable );
	GetDlgItem( IDC_DLGDCAMRGBRATIO_GAIN_BTNHALFGREEN  )->EnableWindow( bEnable );
	GetDlgItem( IDC_DLGDCAMRGBRATIO_GAIN_BTNSET1GREEN  )->EnableWindow( bEnable );
	GetDlgItem( IDC_DLGDCAMRGBRATIO_GAIN_BTNTWICEGREEN )->EnableWindow( bEnable );
	GetDlgItem( IDC_DLGDCAMRGBRATIO_GAIN_TXTBLUE       )->EnableWindow( bEnable );
	GetDlgItem( IDC_DLGDCAMRGBRATIO_GAIN_EBBLUE        )->EnableWindow( bEnable );
	GetDlgItem( IDC_DLGDCAMRGBRATIO_GAIN_BTNHALFBLUE   )->EnableWindow( bEnable );
	GetDlgItem( IDC_DLGDCAMRGBRATIO_GAIN_BTNSET1BLUE   )->EnableWindow( bEnable );
	GetDlgItem( IDC_DLGDCAMRGBRATIO_GAIN_BTNTWICEBLUE  )->EnableWindow( bEnable );

	return TRUE;
}
/////////////////////////////////////////////////////////////////////////////
// CDlgDcamRGBRatio message handlers

BOOL CDlgDcamRGBRatio::OnInitDialog() 
{
	m_bBlocked = TRUE;

	CDialog::OnInitDialog();

	update_values( FALSE );

	return TRUE;  // return TRUE unless you set the focus to a control
	              // EXCEPTION: OCX Property Pages should return FALSE
}

void CDlgDcamRGBRatio::OnDestroy() 
{
	CDialog::OnDestroy();
	
	//  TODO: Add your message handler code here
	m_bCreateDialog	= FALSE;
}

// ----------------

void CDlgDcamRGBRatio::OnRgbratioExpoBtnset1blue()	{	m_rgbratio->exposure.blue	= 1;	update_values();	}
void CDlgDcamRGBRatio::OnRgbratioExpoBtnset1green()	{	m_rgbratio->exposure.green	= 1;	update_values();	}
void CDlgDcamRGBRatio::OnRgbratioExpoBtnset1red()	{	m_rgbratio->exposure.red	= 1;	update_values();	}
void CDlgDcamRGBRatio::OnRgbratioGainBtnset1blue()	{	m_rgbratio->gain.blue		= 1;	update_values();	}
void CDlgDcamRGBRatio::OnRgbratioGainBtnset1green()	{	m_rgbratio->gain.green		= 1;	update_values();	}
void CDlgDcamRGBRatio::OnRgbratioGainBtnset1red()	{	m_rgbratio->gain.red		= 1;	update_values();	}

void CDlgDcamRGBRatio::OnRgbratioExpoBtnhalfblue()	{	m_rgbratio->exposure.blue	/= 2;	update_values();	}
void CDlgDcamRGBRatio::OnRgbratioExpoBtnhalfgreen()	{	m_rgbratio->exposure.green	/= 2;	update_values();	}
void CDlgDcamRGBRatio::OnRgbratioExpoBtnhalfred()	{	m_rgbratio->exposure.red	/= 2;	update_values();	}
void CDlgDcamRGBRatio::OnRgbratioGainBtnhalfblue()	{	m_rgbratio->gain.blue		/= 2;	update_values();	}
void CDlgDcamRGBRatio::OnRgbratioGainBtnhalfgreen()	{	m_rgbratio->gain.green		/= 2;	update_values();	}
void CDlgDcamRGBRatio::OnRgbratioGainBtnhalfred()	{	m_rgbratio->gain.red		/= 2;	update_values();	}

void CDlgDcamRGBRatio::OnRgbratioExpoBtntwiceblue()	{	m_rgbratio->exposure.blue	*= 2;	update_values();	}
void CDlgDcamRGBRatio::OnRgbratioExpoBtntwicegreen(){	m_rgbratio->exposure.green	*= 2;	update_values();	}
void CDlgDcamRGBRatio::OnRgbratioExpoBtntwicered()	{	m_rgbratio->exposure.red	*= 2;	update_values();	}
void CDlgDcamRGBRatio::OnRgbratioGainBtntwiceblue()	{	m_rgbratio->gain.blue		*= 2;	update_values();	}
void CDlgDcamRGBRatio::OnRgbratioGainBtntwicegreen(){	m_rgbratio->gain.green		*= 2;	update_values();	}
void CDlgDcamRGBRatio::OnRgbratioGainBtntwicered()	{	m_rgbratio->gain.red		*= 2;	update_values();	}

void CDlgDcamRGBRatio::OnChangeRgbvalue() 
{
	KillTimer( IDT_CHANGEVALUE );
	SetTimer( IDT_CHANGEVALUE, 500, NULL );
}

// ----

void CalcSum_RGB24( BYTE* pTop, double &r, double &g, double &b, SIZE datasize, long rowbytes )
{
	r = 0;
	g = 0;
	b = 0;

	long	x, y;
	for( y = 0; y < datasize.cy; y++ )
	{
		BYTE* src = pTop;
		for( x = datasize.cx; x-- > 0; )
		{
			r += (double)*src++;
			g += (double)*src++;
			b += (double)*src++;
		}
		pTop = pTop + rowbytes;
	}
}

void CalcSum_BGR24( BYTE* pTop, double &r, double &g, double &b, SIZE datasize, long rowbytes )
{
	r = 0;
	g = 0;
	b = 0;

	long	x, y;
	for( y = 0; y < datasize.cy; y++ )
	{
		BYTE* src = pTop;
		for( x = datasize.cx; x-- > 0; )
		{
			b += (double)*src++;
			g += (double)*src++;
			r += (double)*src++;
		}
		pTop = pTop + rowbytes;
	}
}

void CalcSum_RGB48( WORD* pTop, double &r, double &g, double &b, SIZE datasize, long rowbytes )
{
	r = 0;
	g = 0;
	b = 0;

	long	x, y;
	for( y = 0; y < datasize.cy; y++ )
	{
		WORD* src = pTop;
		for( x = datasize.cx; x-- > 0; )
		{
			r += (double)*src++;
			g += (double)*src++;
			b += (double)*src++;
		}
		pTop = (WORD*)( (char*)pTop + rowbytes );
	}
}

void CalcSum_BGR48( WORD* pTop, double &r, double &g, double &b, SIZE datasize, long rowbytes )
{
	r = 0;
	g = 0;
	b = 0;

	long	x, y;
	for( y = 0; y < datasize.cy; y++ )
	{
		WORD* src = pTop;
		for( x = datasize.cx; x-- > 0; )
		{
			b += (double)*src++;
			g += (double)*src++;
			r += (double)*src++;
		}
		pTop = (WORD*)( (char*)pTop + rowbytes );
	}
}

void CDlgDcamRGBRatio::OnRgbratioExpoWhitebalance() 
{
	DCAM_DATATYPE datatype;
	VERIFY( dcam_getdatatype( m_hdcam, &datatype ) );

	if( datatype != DCAM_DATATYPE_RGB24
	 && datatype != DCAM_DATATYPE_RGB48
	 && datatype != DCAM_DATATYPE_BGR24
	 && datatype != DCAM_DATATYPE_BGR48)
	{
		// data is not color.

		return;
	}

	SIZE datasize;
	VERIFY( dcam_getdatasize( m_hdcam, &datasize ) );

	void*	pTop;
	int32	rowbytes;

	if( ! dcam_lockdata( m_hdcam, &pTop, &rowbytes, -1) )
	{
		// There is no frame

		return;
	}

	double	r = 0, g = 0, b = 0;

	switch(datatype)
	{
	case DCAM_DATATYPE_RGB24:	CalcSum_RGB24( (BYTE*)pTop, r, g, b, datasize, rowbytes );	break;
	case DCAM_DATATYPE_BGR24:	CalcSum_BGR24( (BYTE*)pTop, r, g, b, datasize, rowbytes );	break;
	case DCAM_DATATYPE_RGB48:	CalcSum_RGB48( (WORD*)pTop, r, g, b, datasize, rowbytes );	break;
	case DCAM_DATATYPE_BGR48:	CalcSum_BGR48( (WORD*)pTop, r, g, b, datasize, rowbytes );	break;
	default:					ASSERT( 0 );
	}

	dcam_unlockdata(m_hdcam);

	// get newest ratio
	double anchor;
	anchor = r;
	if( anchor < g )	anchor = g;
	if( anchor < b )	anchor = b;

	if( anchor == 0 )
	{
		// whole pixels has no intensity.

		return;
	}

	r	= m_rgbratio->exposure.red   * (anchor / r);
	g	= m_rgbratio->exposure.green * (anchor / g);
	b	= m_rgbratio->exposure.blue  * (anchor / b);

	// fix ratio so 1 is greatest value
	anchor = r;
	if( anchor < g )	anchor = g;
	if( anchor < b )	anchor = b;

	ASSERT( anchor > 0 );
	m_rgbratio->exposure.red	= r / anchor;
	m_rgbratio->exposure.green	= g / anchor;
	m_rgbratio->exposure.blue	= b / anchor;

	// send new values to camera and update dialog box
	update_values();
}

void CDlgDcamRGBRatio::OnTimer(UINT_PTR nIDEvent) 
{
	UpdateData();
	update_values();

	CDialog::OnTimer(nIDEvent);
}

void CDlgDcamRGBRatio::OnOK() 
{
	// TODO: Add extra validation here
	
	if( m_bCreateDialog )
		DestroyWindow();
	else
		CDialog::OnOK();
}

void CDlgDcamRGBRatio::OnCancel() 
{
	// TODO: Add extra cleanup here
	
	if( m_bCreateDialog )
		DestroyWindow();
	else
		CDialog::OnCancel();
}


