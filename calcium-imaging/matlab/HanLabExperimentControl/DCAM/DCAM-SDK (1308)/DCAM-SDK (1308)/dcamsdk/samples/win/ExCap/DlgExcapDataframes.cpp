// DlgExcapDataframes.cpp : implementation file
//

#include "stdafx.h"
#include "resource.h"
#include "DlgExcapDataframes.h"

#ifdef _DEBUG
#define new DEBUG_NEW
#undef THIS_FILE
static char THIS_FILE[] = __FILE__;
#endif

/////////////////////////////////////////////////////////////////////////////
// CDlgExcapDataframes dialog


CDlgExcapDataframes::CDlgExcapDataframes(CWnd* pParent /*=NULL*/)
	: CDialog(CDlgExcapDataframes::IDD, pParent)
{
	//{{AFX_DATA_INIT(CDlgExcapDataframes)
	m_bUserAttachBuffer = FALSE;
	m_nFrames = 0;
	//}}AFX_DATA_INIT

	m_hdcam = NULL;
	m_nDatatype = DCAM_DATATYPE_NONE;
	m_szData.cx = m_szData.cy = 0;
}


void CDlgExcapDataframes::DoDataExchange(CDataExchange* pDX)
{
	CDialog::DoDataExchange(pDX);
	//{{AFX_DATA_MAP(CDlgExcapDataframes)
	DDX_Control(pDX, IDC_EXCAPDATAFRAMES_CBDATATYPE, m_cbDatatype);
	DDX_Check(pDX, IDC_EXCAPDATAFRAMES_BUSEATTACHBUFFER, m_bUserAttachBuffer);
	DDX_Text(pDX, IDC_EXCAPDATAFRAMES_EBFRAMEPERCYCLE, m_nFrames);
	//}}AFX_DATA_MAP

	DDX_Text(pDX, IDC_EXCAPDATAFRAMES_TXTWIDTH, m_szData.cx );
	DDX_Text(pDX, IDC_EXCAPDATAFRAMES_TXTHEIGHT, m_szData.cy );
}


BEGIN_MESSAGE_MAP(CDlgExcapDataframes, CDialog)
	//{{AFX_MSG_MAP(CDlgExcapDataframes)
	//}}AFX_MSG_MAP
END_MESSAGE_MAP()

/////////////////////////////////////////////////////////////////////////////
// CDlgExcapDataframes message handlers

inline void addstring_datatype( CComboBox& cb, DWORD dwSupports, DWORD dwItem, LPCTSTR strItem )
{
	if( dwSupports & dwItem )
	{
		long	i = cb.AddString( strItem );
		cb.SetItemData( i, dwItem );
	}
}

inline long finditemdata( CComboBox& cb, DWORD dwItemdata )
{
	long	n = cb.GetCount();
	long	i;
	for( i = 0; i < n; i++ )
	{
		if( cb.GetItemData( i ) == dwItemdata )
			return i;
	}

	return LB_ERR;
}

BOOL CDlgExcapDataframes::OnInitDialog() 
{
	CDialog::OnInitDialog();
	
	// TODO: Add extra initialization here

	// update combobox for DCAM_DATATYPE
	{
		DWORD	dw;

		VERIFY( dcam_getcapability( m_hdcam, &dw, DCAM_QUERYCAPABILITY_DATATYPE ) );
		ASSERT( dw != 0 );

		addstring_datatype( m_cbDatatype, dw, DCAM_DATATYPE_UINT8,	_T( "DCAM_DATATYPE_UINT8" ) );
		addstring_datatype( m_cbDatatype, dw, DCAM_DATATYPE_UINT16,	_T( "DCAM_DATATYPE_UINT16") );
		addstring_datatype( m_cbDatatype, dw, DCAM_DATATYPE_RGB24,	_T( "DCAM_DATATYPE_RGB24" ) );
		addstring_datatype( m_cbDatatype, dw, DCAM_DATATYPE_RGB48,	_T( "DCAM_DATATYPE_RGB48" ) );
		addstring_datatype( m_cbDatatype, dw, DCAM_DATATYPE_BGR24,	_T( "DCAM_DATATYPE_BGR24" ) );
		addstring_datatype( m_cbDatatype, dw, DCAM_DATATYPE_BGR48,	_T( "DCAM_DATATYPE_BGR48" ) );

		long	i = finditemdata( m_cbDatatype, m_nDatatype );
		m_cbDatatype.SetCurSel( i );

		m_cbDatatype.EnableWindow( m_cbDatatype.GetCount() > 1 );
	}
	
	return TRUE;  // return TRUE unless you set the focus to a control
	              // EXCEPTION: OCX Property Pages should return FALSE
}

void CDlgExcapDataframes::OnOK() 
{
	// TODO: Add extra validation here

	long	i = m_cbDatatype.GetCurSel();
	m_nDatatype = (DCAM_DATATYPE)m_cbDatatype.GetItemData( i );
	
	CDialog::OnOK();
}
