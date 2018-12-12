// DlgExcapStatus.cpp : implementation file
//

#include "stdafx.h"
#include "resource.h"
#include "DlgExcapStatus.h"
#include "ExCapDoc.h"

#ifdef _DEBUG
#define new DEBUG_NEW
#undef THIS_FILE
static char THIS_FILE[] = __FILE__;
#endif

/////////////////////////////////////////////////////////////////////////////
// convert from DCAM value to CString

static void getlasterror( HDCAM hdcam, CString& str )
{
	long	err = dcam_getlasterror( hdcam );
	str.Format( _T( "error code 0x%08X" ), err );
}

// ----

static void update_string_status( HDCAM hdcam, CString& str )
{
	_DWORD	dw;
	if( ! dcam_getstatus( hdcam, &dw ) )
		getlasterror( hdcam, str );
	else
	{
		switch( dw )
		{
		case DCAM_STATUS_ERROR:		str = _T( "ERROR" );	break;
		case DCAM_STATUS_BUSY:		str = _T( "BUSY" );		break;
		case DCAM_STATUS_READY:		str = _T( "READY" );	break;
		case DCAM_STATUS_STABLE:	str = _T( "STABLE" );	break;
		case DCAM_STATUS_UNSTABLE:	str = _T( "UNSTABLE" );	break;
		default:					str.Format( _T( "Unknown( %d )" ), dw );	break;
		}
	}
}

static void update_string_binning( HDCAM hdcam, CString& str )
{
	int32	nBinning;
	if( ! dcam_getbinning( hdcam, &nBinning ) )
		getlasterror( hdcam, str );
	else
	if( nBinning < 100 )
		str.Format( _T( "%dx%d" ), nBinning, nBinning );
	else
		str.Format( _T( "%dx%d" ), nBinning / 100, nBinning % 100 );
}

static void update_string_datasize( HDCAM hdcam, CString& str )
{
	SIZE	sz;
	if( ! dcam_getdatasize( hdcam, &sz ) )
		getlasterror( hdcam, str );
	else
		str.Format( _T( "%dx%d" ), sz.cx, sz.cy );
}

static void update_string_datatype( HDCAM hdcam, CString& str )
{
	DCAM_DATATYPE	type;
	if( ! dcam_getdatatype( hdcam, &type ) )
		getlasterror( hdcam, str );
	else
	{
		switch( type )
		{
		case DCAM_DATATYPE_UINT8:	str = _T( "B/W 8bit" );		break;
		case DCAM_DATATYPE_UINT16:	str = _T( "B/W 16bit" );	break;
		case DCAM_DATATYPE_RGB24:	str = _T( "RGB 24bit" );	break;
		case DCAM_DATATYPE_RGB48:	str = _T( "RGB 48bit" );	break;
		case DCAM_DATATYPE_BGR24:	str = _T( "BGR 24bit" );	break;
		case DCAM_DATATYPE_BGR48:	str = _T( "BGR 48bit" );	break;
		default:					str.Format( _T( "Unknown( 0x%08X )" ), type );	break;
		}
	}
}

static void update_string_bitstype( HDCAM hdcam, CString& str )
{
	DCAM_BITSTYPE	type;
	if( ! dcam_getbitstype( hdcam, &type ) )
		getlasterror( hdcam, str );
	else
	{
		switch( type )
		{
		case DCAM_BITSTYPE_INDEX8:	str = _T( "INDEX 8bit" );	break;
		case DCAM_BITSTYPE_RGB24:	str = _T( "RGB 24bit" );	break;
		default:					str.Format( _T( "Unknown( 0x%08X )" ), type );	break;
		}
	}
}

static void update_string_exposure( HDCAM hdcam, CString& str )
{
	double	tSec;
	if( ! dcam_getexposuretime( hdcam, &tSec ) )
		getlasterror( hdcam, str );
	else
	if( tSec >= 1000 )
		str.Format( _T( "%.0f sec" ), tSec );
	else
	if( tSec >= 100 )
		str.Format( _T( "%.1f sec" ), tSec );
	else
	if( tSec >= 10 )
		str.Format( _T( "%.2f sec" ), tSec );
	else
	if( tSec >= 1 )
		str.Format( _T( "%.3f sec" ), tSec );
	else
	if( tSec >= 0.1 )
		str.Format( _T( "%.1f msec" ), tSec * 1000 );
	else
	if( tSec >= 0.01 )
		str.Format( _T( "%.2f msec" ), tSec * 1000 );
	else
	if( tSec >= 0.001 )
		str.Format( _T( "%.3f msec" ), tSec * 1000 );
	else
	if( tSec >= 0.0001 )
		str.Format( _T( "%.1f usec" ), tSec * 1000 * 1000 );
	else
	if( tSec >= 0.00001 )
		str.Format( _T( "%.2f usec" ), tSec * 1000 * 1000 );
	else
		str.Format( _T( "%.3f usec" ), tSec * 1000 * 1000 );
}

static void update_string_trigger( HDCAM hdcam, CString& str )
{
	int32	mode;
	if( ! dcam_gettriggermode( hdcam, &mode ) )
		getlasterror( hdcam, str );
	else
	{
		switch( mode )
		{
		case DCAM_TRIGMODE_INTERNAL:			str = _T( "INTERNAL" );					break;
		case DCAM_TRIGMODE_EDGE:				str = _T( "EDGE" );						break;
		case DCAM_TRIGMODE_LEVEL:				str = _T( "LEVEL" );					break;
		case DCAM_TRIGMODE_MULTISHOT_SENSITIVE:	str = _T( "MULTISHOT_SENSITIVE" );		break;
		case DCAM_TRIGMODE_CYCLE_DELAY:			str = _T( "CYCLE_DELAY" );				break;
		case DCAM_TRIGMODE_SOFTWARE:			str = _T( "SOFTWARE" );					break;
		case DCAM_TRIGMODE_FASTREPETITION:		str = _T( "FASTREPETITION" );			break;
		case DCAM_TRIGMODE_TDI:					str = _T( "TDI" );						break;
		case DCAM_TRIGMODE_TDIINTERNAL:			str = _T( "TDIINTERNAL" );				break;
		case DCAM_TRIGMODE_START:				str = _T( "START" );					break;
		case DCAM_TRIGMODE_SYNCREADOUT:			str = _T( "SYNCREADOUT" );				break;
		default:						str.Format( _T( "Unknown( 0x%08X )" ), mode );	break;
		}
	}
}
static void update_string_datarange( HDCAM hdcam, CString& str )
{
	int32	nMax, nMin;
	if( ! dcam_getdatarange( hdcam, &nMax, &nMin ) )
		getlasterror( hdcam, str );
	else
		str.Format( _T( "%d - %d" ), nMin, nMax );
}

static void update_string_dataframebytes( HDCAM hdcam, CString& str )
{
	_DWORD	dw;
	if( ! dcam_getdataframebytes( hdcam, &dw ) )
		getlasterror( hdcam, str );
	else
		str.Format( _T( "%d bytes" ), dw );
}


/////////////////////////////////////////////////////////////////////////////
// CDlgExcapStatus dialog


CDlgExcapStatus::CDlgExcapStatus(CWnd* pParent /*=NULL*/)
	: CDialog(CDlgExcapStatus::IDD, pParent)
{
	//{{AFX_DATA_INIT(CDlgExcapStatus)
	m_strStatus = _T("");
	m_strArea = _T("");
	m_strBitstype = _T("");
	m_strDataframebytes = _T("");
	m_strDatarange = _T("");
	m_strDatatype = _T("");
	m_strExposure = _T("");
	m_strResolution = _T("");
	m_strTrigger = _T("");
	//}}AFX_DATA_INIT

	m_bCreateDialog			= FALSE;
	m_hdcam					= NULL;
}

// ----------------

void CDlgExcapStatus::set_hdcamdoc( HDCAM hdcam, CExCapDoc* doc )
{
	m_hdcam = hdcam;
	m_doc = doc;

	update_values( FALSE );

	if( IsWindow( GetSafeHwnd() ) && IsWindowVisible() )
	{
	//	setup_controls();
		update_controls();
	}
}

BOOL CDlgExcapStatus::toggle_visible()
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

/////////////////////////////////////////////////////////////////////////////

BOOL CDlgExcapStatus::Create(CWnd* pParentWnd) 
{
	// TODO: Add your specialized code here and/or call the base class
	
	m_bCreateDialog = CDialog::Create(IDD, pParentWnd );
	return m_bCreateDialog;
}

void CDlgExcapStatus::update_values( BOOL bForce )
{
	if( m_hdcam == NULL )
	{
		m_strStatus			= _T("--");
	}
	else
	{
		update_string_status( m_hdcam, m_strStatus );

		_DWORD	dwUpdated;
		VERIFY( dcam_queryupdate( m_hdcam, &dwUpdated ) );

		if( bForce || ( dwUpdated & DCAM_UPDATE_RESOLUTION ) )
			update_string_binning( m_hdcam, m_strResolution );

		if( bForce || ( dwUpdated & DCAM_UPDATE_AREA ) )
			update_string_datasize( m_hdcam, m_strArea);

		if( bForce || ( dwUpdated & DCAM_UPDATE_DATATYPE ) )
		{
			update_string_datatype( m_hdcam, m_strDatatype );
			if( m_doc != NULL )
				m_doc->update_datatype();
		}

		if( bForce || ( dwUpdated & DCAM_UPDATE_BITSTYPE ) )
			update_string_bitstype( m_hdcam, m_strBitstype);

		if( bForce || ( dwUpdated & DCAM_UPDATE_EXPOSURE ) )
			update_string_exposure( m_hdcam, m_strExposure);

		if( bForce || ( dwUpdated & DCAM_UPDATE_TRIGGER ) )
			update_string_trigger( m_hdcam, m_strTrigger );

		if( bForce || ( dwUpdated & DCAM_UPDATE_DATARANGE ) )
			update_string_datarange( m_hdcam, m_strDatarange);

		if( bForce || ( dwUpdated & DCAM_UPDATE_DATAFRAMEBYTES ) )
			update_string_dataframebytes( m_hdcam, m_strDataframebytes);
	}
}

// ----

void CDlgExcapStatus::update_controls()
{
	UpdateData( FALSE );
}

// ----------------

void CDlgExcapStatus::DoDataExchange(CDataExchange* pDX)
{
	CDialog::DoDataExchange(pDX);
	//{{AFX_DATA_MAP(CDlgExcapStatus)
	DDX_Text(pDX, IDC_EXCAPSTATUS_TXTSTATUS, m_strStatus);
	DDX_Text(pDX, IDC_EXCAPSTATUS_TXTAREA, m_strArea);
	DDX_Text(pDX, IDC_EXCAPSTATUS_TXTBITSTYPE, m_strBitstype);
	DDX_Text(pDX, IDC_EXCAPSTATUS_TXTDATAFRAMEBYTES, m_strDataframebytes);
	DDX_Text(pDX, IDC_EXCAPSTATUS_TXTDATARANGE, m_strDatarange);
	DDX_Text(pDX, IDC_EXCAPSTATUS_TXTDATATYPE, m_strDatatype);
	DDX_Text(pDX, IDC_EXCAPSTATUS_TXTEXPOSURE, m_strExposure);
	DDX_Text(pDX, IDC_EXCAPSTATUS_TXTRESOLUTION, m_strResolution);
	DDX_Text(pDX, IDC_EXCAPSTATUS_TXTTRIGGER, m_strTrigger);
	//}}AFX_DATA_MAP
}


BEGIN_MESSAGE_MAP(CDlgExcapStatus, CDialog)
	//{{AFX_MSG_MAP(CDlgExcapStatus)
	ON_WM_DESTROY()
	ON_WM_TIMER()
	//}}AFX_MSG_MAP
END_MESSAGE_MAP()

/////////////////////////////////////////////////////////////////////////////
// CDlgExcapStatus message handlers

#define	IDT_UPDATESTATUS	1

BOOL CDlgExcapStatus::OnInitDialog() 
{
	update_values( TRUE );

	CDialog::OnInitDialog();
	
	// TODO: Add extra initialization here

	SetTimer( IDT_UPDATESTATUS, 500, NULL );

	return TRUE;  // return TRUE unless you set the focus to a control
	              // EXCEPTION: OCX Property Pages should return FALSE
}

void CDlgExcapStatus::OnDestroy() 
{
	CDialog::OnDestroy();
	
	// TODO: Add your message handler code here

	m_bCreateDialog	= FALSE;
}

void CDlgExcapStatus::OnOK() 
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
}

void CDlgExcapStatus::OnCancel() 
{
	// TODO: Add extra cleanup here	
	if( m_bCreateDialog )
		DestroyWindow();
	else
		CDialog::OnCancel();
}

void CDlgExcapStatus::OnTimer(UINT_PTR nIDEvent) 
{
	// TODO: Add your message handler code here and/or call default

	update_values( FALSE );
	update_controls();

	CDialog::OnTimer(nIDEvent);
}
