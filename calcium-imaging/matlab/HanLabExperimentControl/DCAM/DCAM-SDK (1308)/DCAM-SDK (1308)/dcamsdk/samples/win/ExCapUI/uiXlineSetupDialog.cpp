// uiXlineSetupDialog.cpp : implementation file
//

#include "stdafx.h"
#include "ExCapUI.h"
#include "uiXlineSetupDialog.h"

#ifdef _DEBUG
#define new DEBUG_NEW
#undef THIS_FILE
static char THIS_FILE[] = __FILE__;
#endif

/////////////////////////////////////////////////////////////////////////////
// CuiXlineSetupDialog

IMPLEMENT_DYNAMIC(CuiXlineSetupDialog, CPropertySheet)

CuiXlineSetupDialog::CuiXlineSetupDialog(CWnd* pParentWnd, UINT iSelectPage)
	:CPropertySheet( IDS_XLINE_DIALOGSETUP_TITLE, pParentWnd, iSelectPage)
{
	p_COND		= NULL;
	p_CONDTDI	= NULL;

	p_DCAL		= NULL;
	p_DCALDUAL	= NULL;

	p_ACAL		= NULL;
	p_ACALDUAL	= NULL;

}

CuiXlineSetupDialog::CuiXlineSetupDialog(UINT nIDCaption, CWnd* pParentWnd, UINT iSelectPage)
	:CPropertySheet(nIDCaption, pParentWnd, iSelectPage)
{
	p_COND		= NULL;
	p_CONDTDI	= NULL;

	p_DCAL		= NULL;
	p_DCALDUAL	= NULL;

	p_ACAL		= NULL;
	p_ACALDUAL	= NULL;

}

CuiXlineSetupDialog::CuiXlineSetupDialog(LPCTSTR pszCaption, CWnd* pParentWnd, UINT iSelectPage)
	:CPropertySheet(pszCaption, pParentWnd, iSelectPage)
{
	p_COND		= NULL;
	p_CONDTDI	= NULL;

	p_DCAL		= NULL;
	p_DCALDUAL	= NULL;

	p_ACAL		= NULL;
	p_ACALDUAL	= NULL;

}

CuiXlineSetupDialog::~CuiXlineSetupDialog()
{

	// remove pages
//	RemovePage(&m_INFO);
//	RemovePage(&m_CONF);
//	RemovePage(&m_MASK);

	// condition tab
	if(p_COND != NULL)
	{
		RemovePage(p_COND);
		delete	p_COND;
		p_COND = NULL;
	}
	if(p_CONDTDI != NULL)
	{
		RemovePage(p_CONDTDI);
		delete	p_CONDTDI;
		p_CONDTDI = NULL;
	}

	// DigitalCalibration tab
	if(p_DCAL != NULL)
	{
		RemovePage(p_DCAL);
		delete	p_DCAL;
		p_DCAL = NULL;
	}
	if(p_DCALDUAL != NULL)
	{
		RemovePage(p_DCALDUAL);
		delete	p_DCALDUAL;
		p_DCALDUAL = NULL;
	}

	// Analog gain calibration tab
	if(p_ACAL != NULL)
	{
		RemovePage(p_ACAL);
		delete	p_ACAL;
		p_ACAL = NULL;
	}
	if(p_ACALDUAL != NULL)
	{
		RemovePage(p_ACALDUAL);
		delete	p_ACALDUAL;
		p_ACALDUAL = NULL;
	}

}

void CuiXlineSetupDialog::addpages()
{

	AddPage( &m_INFO );

	// condition tab
	p_COND		= NULL;
	p_CONDTDI	= NULL;
	if(			m_CameraType == cameratype_C9750
			||	m_CameraType == cameratype_C10400
			||	m_CameraType == cameratype_C10800	)
	{
		p_COND = new CuiXlinePageCOND;
		AddPage( p_COND );
	}
	else if(	m_CameraType == cameratype_C10650	)
	{
		p_CONDTDI = new CuiXlinePageCONDTDI;
		AddPage( p_CONDTDI );
	}

	// DigitalCalibration tab
	p_DCAL		= NULL;
	p_DCALDUAL	= NULL;
	if(			m_CameraType == cameratype_C9750
			||	m_CameraType == cameratype_C10400
			||	m_CameraType == cameratype_C10650	)
	{
		p_DCAL = new CuiXlinePageDCAL;
		AddPage( p_DCAL );
	}
	else if(	m_CameraType == cameratype_C10800	)
	{
		p_DCALDUAL = new CuiXlinePageDCALDUAL;
		AddPage( p_DCALDUAL );

	}

	AddPage( &m_CONF );
	AddPage( &m_MASK );
	
	// Analog gain calibration tab
	p_ACAL		= NULL;
	p_ACALDUAL	= NULL;
	if(b_M8815_0X)
	{
		if(		m_CameraType == cameratype_C9750
			||	m_CameraType == cameratype_C10400
			||	m_CameraType == cameratype_C10650	)
		{
			p_ACAL = new CuiXlinePageACAL;
			AddPage( p_ACAL );
		}
		else if(	m_CameraType == cameratype_C10800	)
		{
			p_ACALDUAL = new CuiXlinePageACALDUAL;
			AddPage( p_ACALDUAL );
		}

	}

}

void CuiXlineSetupDialog::set_hdcam( HDCAM hdcam )
{
	getdcamparams(hdcam);

	addpages();

	m_INFO.set_hdcam( hdcam );

	if(p_COND != NULL)		p_COND->set_hdcam( hdcam );
	if(p_CONDTDI != NULL)	p_CONDTDI->set_hdcam( hdcam );

	if(p_DCAL != NULL)		p_DCAL->set_hdcam( hdcam );
	if(p_DCALDUAL != NULL)	p_DCALDUAL->set_hdcam( hdcam );


	m_CONF.set_hdcam( hdcam );
	m_MASK.set_hdcam( hdcam );
	if(b_M8815_0X)
	{
		if(p_ACAL != NULL)		p_ACAL->set_hdcam( hdcam );
		if(p_ACALDUAL != NULL)	p_ACALDUAL->set_hdcam( hdcam );
	}

}

void CuiXlineSetupDialog::getdcamparams( HDCAM hdcam )
{
	CString	str;
	BOOL	bRet;

	DCAM_PROPERTYATTR	attr;
	memset (& attr, 0, sizeof (attr));
	attr.cbSize	= sizeof (attr);
	attr.iProp	= DCAM_IDPROP_TAPCALIBDATAMEMORY;

	bRet = dcam_getpropertyattr( hdcam, & attr );
	if(bRet)	b_M8815_0X = TRUE;
	else		b_M8815_0X = FALSE;

	/////////////////////////////////////////////////////////////////////////////////////////////////
	// Camera Type
	char buf[128];
	dcam_getstring( hdcam, DCAM_IDSTR_MODEL, buf, sizeof( buf ) );
	str = buf;
	if(str.Find("C9750") >= 0)
	{
		m_CameraType = cameratype_C9750;
	}
	else if(str.Find("C10400") >= 0)
	{
		m_CameraType = cameratype_C10400;
	}
	else if(str.Find("C10650") >= 0)
	{
		m_CameraType = cameratype_C10650;
	}
	else if(str.Find("C10800") >= 0)
	{
		m_CameraType = cameratype_C10800;
	}
	else
	{
		m_CameraType = cameratype_NONE;
	}

}

BEGIN_MESSAGE_MAP(CuiXlineSetupDialog, CPropertySheet)
	//{{AFX_MSG_MAP(CuiXlineSetupDialog)
	//}}AFX_MSG_MAP
END_MESSAGE_MAP()

/////////////////////////////////////////////////////////////////////////////
// CuiXlineSetupDialog message handlers


BOOL CuiXlineSetupDialog::OnInitDialog() 
{
	BOOL bResult = CPropertySheet::OnInitDialog();
	
	CWnd*	pWnd;

	// Hide OK Button
	pWnd = (CWnd*)GetDlgItem(IDOK);
	pWnd->ShowWindow(SW_HIDE);

	// change window text on cancel button
	pWnd = (CWnd*)GetDlgItem(IDCANCEL);
	pWnd->SetWindowText("CLOSE");
	
	return bResult;
}
