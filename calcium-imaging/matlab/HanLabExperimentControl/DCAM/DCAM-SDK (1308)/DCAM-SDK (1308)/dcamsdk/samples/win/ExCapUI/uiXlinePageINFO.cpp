// uiXlinePageINFO.cpp : implementation file
//

#include "stdafx.h"
#include "ExCapUI.h"
#include "uiXlinePageINFO.h"
#include "dcamex.h"

#ifdef _DEBUG
#define new DEBUG_NEW
#undef THIS_FILE
static char THIS_FILE[] = __FILE__;
#endif

/////////////////////////////////////////////////////////////////////////////
// CuiXlinePageINFO property page

IMPLEMENT_DYNCREATE(CuiXlinePageINFO, CPropertyPage)

CuiXlinePageINFO::CuiXlinePageINFO() : CExCapUIPropertyPage(CuiXlinePageINFO::IDD)
{
	//{{AFX_DATA_INIT(CuiXlinePageINFO)
		// NOTE: the ClassWizard will add member initialization here
	//}}AFX_DATA_INIT

}

CuiXlinePageINFO::~CuiXlinePageINFO()
{
}

void CuiXlinePageINFO::DoDataExchange(CDataExchange* pDX)
{
	CPropertyPage::DoDataExchange(pDX);
	//{{AFX_DATA_MAP(CuiXlinePageINFO)
		// NOTE: the ClassWizard will add DDX and DDV calls here
	//}}AFX_DATA_MAP

}

void CuiXlinePageINFO::getvaluefromDCAM()
{
	CString	str;
	char buf[128];
	int	pos;
	double dValue;
	BOOL	bRet;

	/////////////////////////////////////////////////////////////////////////////////////////////////
	//Sensor Camera & Pixel Size & Option & Pixel Clock
	dcam_getstring( m_hdcam, DCAM_IDSTR_MODEL, buf, sizeof( buf ) );
	str = buf;
	pos	= str.Find (' ');
	if (pos >= 0)	str	= str.Left (pos);
	s_CameraModel = str;
	SetDlgItemText( IDC_XLINE_INFO_CAMERAMODEL_EDIT, s_CameraModel );	// Camera

	//Pixel Size
	d_PixelSize = 0.0;
	if(str.Find("C9750") >= 0 || str.Find("C10400") >= 0 || str.Find("C10800") >= 0)
	{
		pos	= str.Find ('-');
		if (pos >= 0){
			if(buf[pos+3] == 'T')		d_PixelSize = 0.2;
			else if(buf[pos+3] == 'F')	d_PixelSize = 0.4;
			else if(buf[pos+3] == 'E')	d_PixelSize = 0.8;
			else if(buf[pos+3] == 'S')	d_PixelSize = 1.6;
			else						d_PixelSize = 0.0;
		}

		if(d_PixelSize != 0.0)	str.Format("%.1f",d_PixelSize);
		else					str.Format("unknown");
	}
	else if(str.Find("C10650") >= 0)
	{
		d_PixelSize = 0.048;
		str.Format("%.3f",d_PixelSize);
	}
	else
	{
		str.Format("unknown");
	}
	SetDlgItemText( IDC_XLINE_INFO_CAMERAPIXELSIZE_EDIT, str );	// PixelSize


	CString	strOption;
	d_PixelClock = 5.33;
	str = buf;
	if(str.Find("M8815-01") >= 0)
	{
		strOption.LoadString(IDS_INFO_M8815_01_TITLE);
		s_CameraOption += "M8815-01 : " + strOption + "\r\n";	
	}
	if(str.Find("M8815-02") >= 0)
	{
		strOption.LoadString(IDS_INFO_M8815_02_TITLE);
		s_CameraOption += "M8815-02 : " + strOption + "\r\n";
	}
	if(str.Find("M8815-03") >= 0){
		strOption.LoadString(IDS_INFO_M8815_03_TITLE);
		s_CameraOption += "M8815-03 : " + strOption + "\r\n";
	}
	if(str.Find("M8815-04") >= 0)
	{
		strOption.LoadString(IDS_INFO_M8815_04_TITLE);
		s_CameraOption += "M8815-04 : " + strOption + "\r\n";
	}
	if(str.Find("M8815-11") >= 0)
	{
		strOption.LoadString(IDS_INFO_M8815_11_TITLE);
		s_CameraOption += "M8815-11 : " + strOption + "\r\n";
	}
	if(str.Find("M8815-12") >= 0)
	{
		strOption.LoadString(IDS_INFO_M8815_12_TITLE);
		s_CameraOption += "M8815-12 : " + strOption + "\r\n";
	}
	if(str.Find("M8815-13") >= 0)
	{
		strOption.LoadString(IDS_INFO_M8815_13_TITLE);
		s_CameraOption += "M8815-13 : " + strOption + "\r\n";
	}
	if(str.Find("M9468-01") >= 0)
	{
		strOption.LoadString(IDS_INFO_M9468_01_TITLE);
		s_CameraOption += "M9468-01 : " + strOption + "\r\n";
		d_PixelClock = 6.67;	
	}
	if(str.Find("M9468-02") >= 0)
	{
		strOption.LoadString(IDS_INFO_M9468_02_TITLE);
		s_CameraOption += "M9468-02 : " + strOption + "\r\n";
		d_PixelClock = 8.00;	
	}
	if(str.Find("M9468-03") >= 0)
	{
		strOption.LoadString(IDS_INFO_M9468_03_TITLE);
		s_CameraOption += "M9468-03 : " + strOption + "\r\n";
		d_PixelClock = 10.00;	
	}
	if(str.Find("M9468-04") >= 0)
	{
		strOption.LoadString(IDS_INFO_M9468_04_TITLE);
		s_CameraOption += "M9468-04 : " + strOption + "\r\n";
		d_PixelClock = 20.00;	
	}
	if(str.Find("M9468-05") >= 0)
	{
		strOption.LoadString(IDS_INFO_M9468_05_TITLE);
		s_CameraOption += "M9468-05 : " + strOption + "\r\n";
		d_PixelClock = 16.00;	
	}
	if(str.Find("M9468-11") >= 0)
	{
		strOption.LoadString(IDS_INFO_M9468_11_TITLE);
		s_CameraOption += "M9468-11 : " + strOption + "\r\n";
	}
	if(str.Find("M9468-12") >= 0)
	{
		strOption.LoadString(IDS_INFO_M9468_12_TITLE);
		s_CameraOption += "M9468-12 : " + strOption + "\r\n";
	}
	if(str.Find("M9468-13") >= 0)
	{
		strOption.LoadString(IDS_INFO_M9468_13_TITLE);
		s_CameraOption += "M9468-13 : " + strOption + "\r\n";
	}
	if(str.Find("M10174-01") >= 0)
	{
		strOption.LoadString(IDS_INFO_M10174_01_TITLE);
		s_CameraOption += "M10174-01 : " + strOption + "\r\n";
	}
	if(str.Find("M10313-01") >= 0)
	{
		strOption.LoadString(IDS_INFO_M10313_01_TITLE);
		s_CameraOption += "M10313-01 : " + strOption + "\r\n";
	}
	if(str.Find("M10351-01") >= 0)
	{
		strOption.LoadString(IDS_INFO_M10351_01_TITLE);
		s_CameraOption += "M10351-01 : " + strOption + "\r\n";
	}
	if(str.Find("M10389-01") >= 0)
	{
		strOption.LoadString(IDS_INFO_M10389_01_TITLE);
		s_CameraOption += "M10389-01 : " + strOption + "\r\n";
	}
	if(str.Find("M10389-02") >= 0)
	{
		strOption.LoadString(IDS_INFO_M10389_02_TITLE);
		s_CameraOption += "M10389-02 : " + strOption + "\r\n";
	}
	if(str.Find("M10389-03") >= 0)
	{
		strOption.LoadString(IDS_INFO_M10389_03_TITLE);
		s_CameraOption += "M10389-03 : " + strOption + "\r\n";
	}
	if(str.Find("M10389-11") >= 0)
	{
		strOption.LoadString(IDS_INFO_M10389_11_TITLE);
		s_CameraOption += "M10389-11 : " + strOption + "\r\n";
	}
	SetDlgItemText( IDC_XLINE_INFO_CAMERAMODEL_OPTION_EDIT, s_CameraOption );	// Option

	str.Format("%0.2f",d_PixelClock);
	SetDlgItemText( IDC_XLINE_INFO_CAMERAPIXELCLOCK_EDIT, str );	// Pixel Clock

	//Serial Number
	dcam_getstring( m_hdcam, DCAM_IDSTR_CAMERAID, buf, sizeof( buf ) );
	s_SerialNumber = buf;
	SetDlgItemText( IDC_XLINE_INFO_CAMERAID_EDIT, s_SerialNumber );
		
	//Soft Version(Firm Version)
	dcam_getstring( m_hdcam, DCAM_IDSTR_CAMERAVERSION, buf, sizeof( buf ) );
	s_CameraVersion = buf;
	SetDlgItemText( IDC_XLINE_INFO_CAMERAVERSION_EDIT, s_CameraVersion );

	// Bits per Channel
	bRet = dcam_getpropertyvalue( m_hdcam, DCAM_IDPROP_BITSPERCHANNEL, &dValue );
	m_BitsPerChannel = (long)dValue;
	str.Format("%d",m_BitsPerChannel);
	SetDlgItemText( IDC_XLINE_INFO_CAMERABITSPERCHANNEL_EDIT, str );

	// Number of Pixel (ValueMax of Subarray HSize)
	DCAM_PROPERTYATTR attr;
	memset( &attr , 0 , sizeof(attr) );
	attr.cbSize = sizeof(attr);
	attr.iProp = DCAM_IDPROP_SUBARRAYHSIZE;
	dcam_getpropertyattr( m_hdcam , &attr );
	m_NumberOfPixel = (long)attr.valuemax;
	str.Format("%d",m_NumberOfPixel);
	SetDlgItemText( IDC_XLINE_INFO_CAMERANUMBEROFPIXEL_EDIT, str );

}

void CuiXlinePageINFO::CheckSupportDCAMPROP()
{
	if(m_hdcam == NULL)		return;
	
	int32	iProp;		// property ID
	double	dValue;

	iProp = 0;
	if( dcam_getnextpropertyid( m_hdcam , &iProp , DCAMPROP_OPTION_SUPPORT ) )		// get first iProp supported
	{
		do{
			// The iProp value is a property ID that device supports
			
			// Getting property attribute
			DCAM_PROPERTYATTR attr;
			char	name[128];
			
			memset( &attr , 0 , sizeof(attr) );
			attr.cbSize	= sizeof (attr);
			attr.iProp = iProp;
			dcam_getpropertyattr( m_hdcam , &attr );

			// Getting property name
			dcam_getpropertyname( m_hdcam , iProp , name , sizeof(name) ) ;

			// Getting property value
			dcam_getpropertyvalue( m_hdcam , iProp , &dValue );

		} while( dcam_getnextpropertyid( m_hdcam , &iProp , DCAMPROP_OPTION_SUPPORT )
			&& iProp != 0);
	}

}

BEGIN_MESSAGE_MAP(CuiXlinePageINFO, CPropertyPage)
	//{{AFX_MSG_MAP(CuiXlinePageINFO)
		// NOTE: the ClassWizard will add message map macros here
	//}}AFX_MSG_MAP
END_MESSAGE_MAP()

/////////////////////////////////////////////////////////////////////////////
// CuiXlinePageINFO message handlers

BOOL CuiXlinePageINFO::OnInitDialog() 
{
	getvaluefromDCAM();
	
	CheckSupportDCAMPROP();

	CPropertyPage::OnInitDialog();
	
	// TODO: Add extra initialization here
	
	return TRUE;  // return TRUE unless you set the focus to a control
	              // EXCEPTION: OCX Property Pages should return FALSE
}

BOOL CuiXlinePageINFO::PreTranslateMessage(MSG* pMsg) 
{
	if(pMsg->message == WM_KEYDOWN)
	{
		if (pMsg->wParam == VK_RETURN)
		{
			return TRUE;
		}
	}

	if(pMsg->message == WM_KEYUP)
	{
		if (pMsg->wParam == VK_RETURN)
		{
			CWnd* pWnd = (CWnd*)FromHandle(pMsg->hwnd);
			int nDlgCtrlID = pWnd->GetDlgCtrlID();
//			switch(nDlgCtrlID)
//			{
//			default:
//				break;
//			}
			return 0;
		}
	}

	
	return CPropertyPage::PreTranslateMessage(pMsg);
}
