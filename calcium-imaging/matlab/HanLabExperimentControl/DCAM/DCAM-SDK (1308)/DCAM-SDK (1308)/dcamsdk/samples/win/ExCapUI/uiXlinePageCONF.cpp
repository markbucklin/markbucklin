// uiXlinePageCONF.cpp : implementation file
//

#include "stdafx.h"
#include "ExCapUI.h"
#include "uiXlinePageCONF.h"
#include "dcamex.h"

#ifdef _DEBUG
#define new DEBUG_NEW
#undef THIS_FILE
static char THIS_FILE[] = __FILE__;
#endif

/////////////////////////////////////////////////////////////////////////////
// CuiXlinePageCONF property page

IMPLEMENT_DYNCREATE(CuiXlinePageCONF, CPropertyPage)

CuiXlinePageCONF::CuiXlinePageCONF() : CExCapUIPropertyPage(CuiXlinePageCONF::IDD)
{
	//{{AFX_DATA_INIT(CuiXlinePageCONF)
	m_radio = -1;
	//}}AFX_DATA_INIT

}

void CuiXlinePageCONF::AddProperties()
{
	// NumberOfCalibRegion
	AddPropertyID(DCAM_IDPROP_NUMBEROF_CALIBREGION);
	uipParam[NumberOfCalibRegion].iEditBox	= IDC_XLINE_CONF_NUMBEROFCALIBREGION_EDIT;
	uipParam[NumberOfCalibRegion].iSpin		= IDC_XLINE_CONF_NUMBEROFCALIBREGION_SPIN;

	// CalibRegionHPos0
	AddPropertyID(DCAM_IDPROP_CALIBREGION_HPOS);
	uipParam[CalibRegionHPos0].iEditBox		= IDC_XLINE_CONF_CALIBREGIONHPOS0_EDIT;
	uipParam[CalibRegionHPos0].iSpin		= IDC_XLINE_CONF_CALIBREGIONHPOS0_SPIN;

	// CalibRegionHPos1
	AddPropertyID(MakeIDPROP_array(DCAM_IDPROP_CALIBREGION_HPOS,1));
	uipParam[CalibRegionHPos1].iEditBox		= IDC_XLINE_CONF_CALIBREGIONHPOS1_EDIT;
	uipParam[CalibRegionHPos1].iSpin		= IDC_XLINE_CONF_CALIBREGIONHPOS1_SPIN;

	// CalibRegionHPos2
	AddPropertyID(MakeIDPROP_array(DCAM_IDPROP_CALIBREGION_HPOS,2));
	uipParam[CalibRegionHPos2].iEditBox		= IDC_XLINE_CONF_CALIBREGIONHPOS2_EDIT;
	uipParam[CalibRegionHPos2].iSpin		= IDC_XLINE_CONF_CALIBREGIONHPOS2_SPIN;

	// CalibRegionHPos3
	AddPropertyID(MakeIDPROP_array(DCAM_IDPROP_CALIBREGION_HPOS,3));
	uipParam[CalibRegionHPos3].iEditBox		= IDC_XLINE_CONF_CALIBREGIONHPOS3_EDIT;
	uipParam[CalibRegionHPos3].iSpin		= IDC_XLINE_CONF_CALIBREGIONHPOS3_SPIN;

	// CalibRegionHSize0
	AddPropertyID(DCAM_IDPROP_CALIBREGION_HSIZE);
	uipParam[CalibRegionHSize0].iEditBox	= IDC_XLINE_CONF_CALIBREGIONHSIZE0_EDIT;
	uipParam[CalibRegionHSize0].iSpin		= IDC_XLINE_CONF_CALIBREGIONHSIZE0_SPIN;

	// CalibRegionHSize1
	AddPropertyID(MakeIDPROP_array(DCAM_IDPROP_CALIBREGION_HSIZE,1));
	uipParam[CalibRegionHSize1].iEditBox	= IDC_XLINE_CONF_CALIBREGIONHSIZE1_EDIT;
	uipParam[CalibRegionHSize1].iSpin		= IDC_XLINE_CONF_CALIBREGIONHSIZE1_SPIN;
	
	// CalibRegionHSize2
	AddPropertyID(MakeIDPROP_array(DCAM_IDPROP_CALIBREGION_HSIZE,2));
	uipParam[CalibRegionHSize2].iEditBox	= IDC_XLINE_CONF_CALIBREGIONHSIZE2_EDIT;
	uipParam[CalibRegionHSize2].iSpin		= IDC_XLINE_CONF_CALIBREGIONHSIZE2_SPIN;
	
	// CalibRegionHSize3
	AddPropertyID(MakeIDPROP_array(DCAM_IDPROP_CALIBREGION_HSIZE,3));
	uipParam[CalibRegionHSize3].iEditBox	= IDC_XLINE_CONF_CALIBREGIONHSIZE3_EDIT;
	uipParam[CalibRegionHSize3].iSpin		= IDC_XLINE_CONF_CALIBREGIONHSIZE3_SPIN;

	// CalibRegionMode
	AddPropertyID(DCAM_IDPROP_CALIBREGION_MODE);
	uipParam[CalibRegionMode].iRadio		= IDC_XLINE_CONF_CALIBREGIONMODE_ALL_RADIO;

}

CuiXlinePageCONF::~CuiXlinePageCONF()
{
}

void CuiXlinePageCONF::DoDataExchange(CDataExchange* pDX)
{
	CPropertyPage::DoDataExchange(pDX);
	//{{AFX_DATA_MAP(CuiXlinePageCONF)
	DDX_Radio(pDX, IDC_XLINE_CONF_CALIBREGIONMODE_ALL_RADIO, m_radio);
	//}}AFX_DATA_MAP

}

void CuiXlinePageCONF::setallenable()
{
	BOOL bStatus = dcam_getstatus(m_hdcam, &dwStatusDCAM);
	if(!bStatus){
		return;
	}

}

BEGIN_MESSAGE_MAP(CuiXlinePageCONF, CPropertyPage)
	//{{AFX_MSG_MAP(CuiXlinePageCONF)
	ON_BN_CLICKED(IDC_XLINE_CONF_CALIBREGIONMODE_ALL_RADIO, OnXlscConfCalibregionmodeAllRadio)
	ON_BN_CLICKED(IDC_XLINE_CONF_CALIBREGIONMODE_ON_RADIO, OnXlscConfCalibregionmodeOnRadio)
	ON_EN_KILLFOCUS(IDC_XLINE_CONF_NUMBEROFCALIBREGION_EDIT, OnKillfocusXlscConfNumberofcalibregionEdit)
	ON_NOTIFY(UDN_DELTAPOS, IDC_XLINE_CONF_NUMBEROFCALIBREGION_SPIN, OnDeltaposXlscConfNumberofcalibregionSpin)
	ON_EN_KILLFOCUS(IDC_XLINE_CONF_CALIBREGIONHPOS0_EDIT, OnKillfocusXlscConfCalibregionhpos0Edit)
	ON_NOTIFY(UDN_DELTAPOS, IDC_XLINE_CONF_CALIBREGIONHPOS0_SPIN, OnDeltaposXlscConfCalibregionhpos0Spin)
	ON_EN_KILLFOCUS(IDC_XLINE_CONF_CALIBREGIONHSIZE0_EDIT, OnKillfocusXlscConfCalibregionhsize0Edit)
	ON_NOTIFY(UDN_DELTAPOS, IDC_XLINE_CONF_CALIBREGIONHSIZE0_SPIN, OnDeltaposXlscConfCalibregionhsize0Spin)
	ON_EN_KILLFOCUS(IDC_XLINE_CONF_CALIBREGIONHPOS1_EDIT, OnKillfocusXlscConfCalibregionhpos1Edit)
	ON_NOTIFY(UDN_DELTAPOS, IDC_XLINE_CONF_CALIBREGIONHPOS1_SPIN, OnDeltaposXlscConfCalibregionhpos1Spin)
	ON_EN_KILLFOCUS(IDC_XLINE_CONF_CALIBREGIONHSIZE1_EDIT, OnKillfocusXlscConfCalibregionhsize1Edit)
	ON_NOTIFY(UDN_DELTAPOS, IDC_XLINE_CONF_CALIBREGIONHSIZE1_SPIN, OnDeltaposXlscConfCalibregionhsize1Spin)
	ON_EN_KILLFOCUS(IDC_XLINE_CONF_CALIBREGIONHPOS2_EDIT, OnKillfocusXlscConfCalibregionhpos2Edit)
	ON_NOTIFY(UDN_DELTAPOS, IDC_XLINE_CONF_CALIBREGIONHPOS2_SPIN, OnDeltaposXlscConfCalibregionhpos2Spin)
	ON_EN_KILLFOCUS(IDC_XLINE_CONF_CALIBREGIONHSIZE2_EDIT, OnKillfocusXlscConfCalibregionhsize2Edit)
	ON_NOTIFY(UDN_DELTAPOS, IDC_XLINE_CONF_CALIBREGIONHSIZE2_SPIN, OnDeltaposXlscConfCalibregionhsize2Spin)
	ON_EN_KILLFOCUS(IDC_XLINE_CONF_CALIBREGIONHPOS3_EDIT, OnKillfocusXlscConfCalibregionhpos3Edit)
	ON_NOTIFY(UDN_DELTAPOS, IDC_XLINE_CONF_CALIBREGIONHPOS3_SPIN, OnDeltaposXlscConfCalibregionhpos3Spin)
	ON_EN_KILLFOCUS(IDC_XLINE_CONF_CALIBREGIONHSIZE3_EDIT, OnKillfocusXlscConfCalibregionhsize3Edit)
	ON_NOTIFY(UDN_DELTAPOS, IDC_XLINE_CONF_CALIBREGIONHSIZE3_SPIN, OnDeltaposXlscConfCalibregionhsize3Spin)
	ON_EN_SETFOCUS(IDC_XLINE_CONF_NUMBEROFCALIBREGION_EDIT, OnSetfocusXlscConfNumberofcalibregionEdit)
	ON_EN_SETFOCUS(IDC_XLINE_CONF_CALIBREGIONHPOS0_EDIT, OnSetfocusXlscConfCalibregionhpos0Edit)
	ON_EN_SETFOCUS(IDC_XLINE_CONF_CALIBREGIONHSIZE0_EDIT, OnSetfocusXlscConfCalibregionhsize0Edit)
	ON_EN_SETFOCUS(IDC_XLINE_CONF_CALIBREGIONHPOS1_EDIT, OnSetfocusXlscConfCalibregionhpos1Edit)
	ON_EN_SETFOCUS(IDC_XLINE_CONF_CALIBREGIONHSIZE1_EDIT, OnSetfocusXlscConfCalibregionhsize1Edit)
	ON_EN_SETFOCUS(IDC_XLINE_CONF_CALIBREGIONHPOS2_EDIT, OnSetfocusXlscConfCalibregionhpos2Edit)
	ON_EN_SETFOCUS(IDC_XLINE_CONF_CALIBREGIONHSIZE2_EDIT, OnSetfocusXlscConfCalibregionhsize2Edit)
	ON_EN_SETFOCUS(IDC_XLINE_CONF_CALIBREGIONHPOS3_EDIT, OnSetfocusXlscConfCalibregionhpos3Edit)
	ON_EN_SETFOCUS(IDC_XLINE_CONF_CALIBREGIONHSIZE3_EDIT, OnSetfocusXlscConfCalibregionhsize3Edit)
	//}}AFX_MSG_MAP
END_MESSAGE_MAP()

/////////////////////////////////////////////////////////////////////////////
// CuiXlinePageCONF message handlers

BOOL CuiXlinePageCONF::OnInitDialog() 
{
	AddProperties();

	CheckSupportDCAMPROP();

	// set check radio button
	for(int i = 0; i < uipParam[CalibRegionMode].numberofidvalue; i++)
	{
		if(uipParam[CalibRegionMode].value == uipParam[CalibRegionMode].idvalue[i])
		{
			m_radio = i;
		}
	}

	dHSizeMax = uipParam[CalibRegionHSize0].attr.valuemax;
	CEdit* pEdit = (CEdit*)GetDlgItem(IDC_XLINE_CONF_CALIBREGIONHSIZE0_EDIT2);
	CString	str;
	str.Format("%.0f",dHSizeMax);
	pEdit->SetWindowText(str);


	CPropertyPage::OnInitDialog();
	
	// TODO: Add extra initialization here

	return TRUE;  // return TRUE unless you set the focus to a control
	              // EXCEPTION: OCX Property Pages should return FALSE
}

void CuiXlinePageCONF::OnOK() 
{
	CPropertyPage::OnOK();
}

void CuiXlinePageCONF::OnCancel() 
{
	CPropertyPage::OnCancel();
}

BOOL CuiXlinePageCONF::OnApply() 
{
	return CPropertyPage::OnApply();
}

void CuiXlinePageCONF::OnXlscConfCalibregionmodeAllRadio() 
{
	BOOL	bRet = FALSE;
	UpdateData();

	if(m_radio == 0)
		bRet = setvaluetoDCAM(uipParam[CalibRegionMode].attr.iProp, DCAMPROP_MODE__OFF);
	else if(m_radio == 1)
		bRet = setvaluetoDCAM(uipParam[CalibRegionMode].attr.iProp, DCAMPROP_MODE__ON);

	CheckUpdateDCAMPROP();

}

void CuiXlinePageCONF::OnXlscConfCalibregionmodeOnRadio() 
{
	BOOL	bRet = FALSE;
	UpdateData();

	if(m_radio == 0)
		bRet = setvaluetoDCAM(uipParam[CalibRegionMode].attr.iProp, DCAMPROP_MODE__OFF);
	else if(m_radio == 1)
		bRet = setvaluetoDCAM(uipParam[CalibRegionMode].attr.iProp, DCAMPROP_MODE__ON);

	CheckUpdateDCAMPROP();

}

void CuiXlinePageCONF::OnSetfocusXlscConfNumberofcalibregionEdit() 
{
	int		nID = NumberOfCalibRegion;
	input_on_setfocus(nID);	
}

void CuiXlinePageCONF::OnKillfocusXlscConfNumberofcalibregionEdit() 
{
	int		nID = NumberOfCalibRegion;
	input_on_killfocus(nID);
}

void CuiXlinePageCONF::OnDeltaposXlscConfNumberofcalibregionSpin(NMHDR* pNMHDR, LRESULT* pResult) 
{
	NM_UPDOWN* pNMUpDown = (NM_UPDOWN*)pNMHDR;
	
	int		nID = NumberOfCalibRegion;
	CString	str;
	double	dNewValue;
	double	min = uipParam[nID].attr.valuemin;
	double	max = uipParam[nID].attr.valuemax;
	double	step = uipParam[nID].attr.valuestep;

	CEdit*	pEdit = (CEdit*)GetDlgItem(uipParam[nID].iEditBox);
	pEdit->GetWindowText(str);
	dNewValue = atof(str);

	dNewValue	= (pNMUpDown->iDelta > 0) ? (dNewValue + step) : (dNewValue - step);
	if(dNewValue < min)		dNewValue = min;
	if(dNewValue > max)		dNewValue = max;


	setvaluetoDCAM(uipParam[nID].attr.iProp, dNewValue);
	updatevalue(uipParam[nID].attr.iProp);

	CheckUpdateDCAMPROP();

	*pResult = 0;
}

void CuiXlinePageCONF::OnSetfocusXlscConfCalibregionhpos0Edit() 
{
	int		nID = CalibRegionHPos0;
	input_on_setfocus(nID);	
}

void CuiXlinePageCONF::OnKillfocusXlscConfCalibregionhpos0Edit() 
{
	int		nID = CalibRegionHPos0;
	input_on_killfocus(nID);
}

void CuiXlinePageCONF::OnDeltaposXlscConfCalibregionhpos0Spin(NMHDR* pNMHDR, LRESULT* pResult) 
{
	NM_UPDOWN* pNMUpDown = (NM_UPDOWN*)pNMHDR;

	int		nID = CalibRegionHPos0;

	CString	str;
	double	dNewValue;
	double	min = uipParam[nID].attr.valuemin;
	double	max = uipParam[nID].attr.valuemax;
	double	step = uipParam[nID].attr.valuestep;

	CEdit*	pEdit = (CEdit*)GetDlgItem(uipParam[nID].iEditBox);
	pEdit->GetWindowText(str);
	dNewValue = atof(str);

	dNewValue	= (pNMUpDown->iDelta > 0) ? (dNewValue + step) : (dNewValue - step);
	if(dNewValue < min)		dNewValue = min;
	if(dNewValue > max)		dNewValue = max;

	// query
	BOOL	bQuery = dcam_querypropertyvalue(m_hdcam,uipParam[nID].attr.iProp,&dNewValue,DCAMPROP_OPTION_NONE);
	if(!bQuery)
	{
		updatevalue(uipParam[nID].attr.iProp);
		*pResult = 0;
		return;
	}

	// set value
	if(! setvaluetoDCAM(uipParam[nID].attr.iProp, dNewValue))
	{
		showerrorcode();
	}
	updatevalue(uipParam[nID].attr.iProp);

	CheckUpdateDCAMPROP();

	*pResult = 0;
}

void CuiXlinePageCONF::OnSetfocusXlscConfCalibregionhsize0Edit() 
{
	int		nID = CalibRegionHSize0;
	input_on_setfocus(nID);	
}

void CuiXlinePageCONF::OnKillfocusXlscConfCalibregionhsize0Edit() 
{
	int		nID = CalibRegionHSize0;
	input_on_killfocus(nID);
}

void CuiXlinePageCONF::OnDeltaposXlscConfCalibregionhsize0Spin(NMHDR* pNMHDR, LRESULT* pResult) 
{
	NM_UPDOWN* pNMUpDown = (NM_UPDOWN*)pNMHDR;

	int		nID = CalibRegionHSize0;
	CString	str;
	double	dNewValue;
	double	min = uipParam[nID].attr.valuemin;
	double	max = uipParam[nID].attr.valuemax;
	double	step = uipParam[nID].attr.valuestep;

	CEdit*	pEdit = (CEdit*)GetDlgItem(uipParam[nID].iEditBox);
	pEdit->GetWindowText(str);
	dNewValue = atof(str);

	dNewValue	= (pNMUpDown->iDelta > 0) ? (dNewValue + step) : (dNewValue - step);
	if(dNewValue < min)		dNewValue = min;
	if(dNewValue > max)		dNewValue = max;

	// query
	BOOL	bQuery = dcam_querypropertyvalue(m_hdcam,uipParam[nID].attr.iProp,&dNewValue,DCAMPROP_OPTION_NONE);
	if(!bQuery)
	{
		updatevalue(uipParam[nID].attr.iProp);
		*pResult = 0;
		return;
	}

	// set value
	if(! setvaluetoDCAM(uipParam[nID].attr.iProp, dNewValue))
	{
		showerrorcode();
	}
	updatevalue(uipParam[nID].attr.iProp);

	CheckUpdateDCAMPROP();
	
	*pResult = 0;
}

void CuiXlinePageCONF::OnSetfocusXlscConfCalibregionhpos1Edit() 
{
	int		nID = CalibRegionHPos1;
	input_on_setfocus(nID);
}

void CuiXlinePageCONF::OnKillfocusXlscConfCalibregionhpos1Edit() 
{
	int		nID = CalibRegionHPos1;
	input_on_killfocus(nID);
}

void CuiXlinePageCONF::OnDeltaposXlscConfCalibregionhpos1Spin(NMHDR* pNMHDR, LRESULT* pResult) 
{
	NM_UPDOWN* pNMUpDown = (NM_UPDOWN*)pNMHDR;
	
	int		nID = CalibRegionHPos1;
	CString	str;
	double	dNewValue;
	double	min = uipParam[nID].attr.valuemin;
	double	max = uipParam[nID].attr.valuemax;
	double	step = uipParam[nID].attr.valuestep;

	CEdit*	pEdit = (CEdit*)GetDlgItem(uipParam[nID].iEditBox);
	pEdit->GetWindowText(str);
	dNewValue = atof(str);

	dNewValue	= (pNMUpDown->iDelta > 0) ? (dNewValue + step) : (dNewValue - step);
	if(dNewValue < min)		dNewValue = min;
	if(dNewValue > max)		dNewValue = max;

	// query
	BOOL	bQuery = dcam_querypropertyvalue(m_hdcam,uipParam[nID].attr.iProp,&dNewValue,DCAMPROP_OPTION_NONE);
	if(!bQuery)
	{
		updatevalue(uipParam[nID].attr.iProp);
		*pResult = 0;
		return;
	}

	// set value
	if(! setvaluetoDCAM(uipParam[nID].attr.iProp, dNewValue))
	{
		showerrorcode();
	}
	updatevalue(uipParam[nID].attr.iProp);

	CheckUpdateDCAMPROP();

	*pResult = 0;
}

void CuiXlinePageCONF::OnSetfocusXlscConfCalibregionhsize1Edit() 
{
	int		nID = CalibRegionHSize1;
	input_on_setfocus(nID);
}

void CuiXlinePageCONF::OnKillfocusXlscConfCalibregionhsize1Edit() 
{
	int		nID = CalibRegionHSize1;
	input_on_killfocus(nID);
}

void CuiXlinePageCONF::OnDeltaposXlscConfCalibregionhsize1Spin(NMHDR* pNMHDR, LRESULT* pResult) 
{
	NM_UPDOWN* pNMUpDown = (NM_UPDOWN*)pNMHDR;

	int		nID = CalibRegionHSize1;
	CString	str;
	double	dNewValue;
	double	min = uipParam[nID].attr.valuemin;
	double	max = uipParam[nID].attr.valuemax;
	double	step = uipParam[nID].attr.valuestep;

	CEdit*	pEdit = (CEdit*)GetDlgItem(uipParam[nID].iEditBox);
	pEdit->GetWindowText(str);
	dNewValue = atof(str);

	dNewValue	= (pNMUpDown->iDelta > 0) ? (dNewValue + step) : (dNewValue - step);
	if(dNewValue < min)		dNewValue = min;
	if(dNewValue > max)		dNewValue = max;

	// query
	BOOL	bQuery = dcam_querypropertyvalue(m_hdcam,uipParam[nID].attr.iProp,&dNewValue,DCAMPROP_OPTION_NONE);
	if(!bQuery)
	{
		updatevalue(uipParam[nID].attr.iProp);
		*pResult = 0;
		return;
	}

	// set value
	if(! setvaluetoDCAM(uipParam[nID].attr.iProp, dNewValue))
	{
		showerrorcode();
	}
	updatevalue(uipParam[nID].attr.iProp);

	CheckUpdateDCAMPROP();

	*pResult = 0;
}

void CuiXlinePageCONF::OnSetfocusXlscConfCalibregionhpos2Edit() 
{
	int		nID = CalibRegionHPos2;
	input_on_setfocus(nID);	
}

void CuiXlinePageCONF::OnKillfocusXlscConfCalibregionhpos2Edit() 
{
	int		nID = CalibRegionHPos2;
	input_on_killfocus(nID);
}

void CuiXlinePageCONF::OnDeltaposXlscConfCalibregionhpos2Spin(NMHDR* pNMHDR, LRESULT* pResult) 
{
	NM_UPDOWN* pNMUpDown = (NM_UPDOWN*)pNMHDR;
	
	int		nID = CalibRegionHPos2;
	CString	str;
	double	dNewValue;
	double	min = uipParam[nID].attr.valuemin;
	double	max = uipParam[nID].attr.valuemax;
	double	step = uipParam[nID].attr.valuestep;

	CEdit*	pEdit = (CEdit*)GetDlgItem(uipParam[nID].iEditBox);
	pEdit->GetWindowText(str);
	dNewValue = atof(str);

	dNewValue	= (pNMUpDown->iDelta > 0) ? (dNewValue + step) : (dNewValue - step);
	if(dNewValue < min)		dNewValue = min;
	if(dNewValue > max)		dNewValue = max;

	// query
	BOOL	bQuery = dcam_querypropertyvalue(m_hdcam,uipParam[nID].attr.iProp,&dNewValue,DCAMPROP_OPTION_NONE);
	if(!bQuery)
	{
		updatevalue(uipParam[nID].attr.iProp);
		*pResult = 0;
		return;
	}

	// set value
	if(! setvaluetoDCAM(uipParam[nID].attr.iProp, dNewValue))
	{
		showerrorcode();
	}
	updatevalue(uipParam[nID].attr.iProp);

	CheckUpdateDCAMPROP();

	*pResult = 0;
}

void CuiXlinePageCONF::OnSetfocusXlscConfCalibregionhsize2Edit() 
{
	int		nID = CalibRegionHSize2;
	input_on_setfocus(nID);		
}

void CuiXlinePageCONF::OnKillfocusXlscConfCalibregionhsize2Edit() 
{
	int		nID = CalibRegionHSize2;
	input_on_killfocus(nID);
}

void CuiXlinePageCONF::OnDeltaposXlscConfCalibregionhsize2Spin(NMHDR* pNMHDR, LRESULT* pResult) 
{
	NM_UPDOWN* pNMUpDown = (NM_UPDOWN*)pNMHDR;
	
	int		nID = CalibRegionHSize2;
	CString	str;
	double	dNewValue;
	double	min = uipParam[nID].attr.valuemin;
	double	max = uipParam[nID].attr.valuemax;
	double	step = uipParam[nID].attr.valuestep;

	CEdit*	pEdit = (CEdit*)GetDlgItem(uipParam[nID].iEditBox);
	pEdit->GetWindowText(str);
	dNewValue = atof(str);

	dNewValue	= (pNMUpDown->iDelta > 0) ? (dNewValue + step) : (dNewValue - step);
	if(dNewValue < min)		dNewValue = min;
	if(dNewValue > max)		dNewValue = max;

	// query
	BOOL	bQuery = dcam_querypropertyvalue(m_hdcam,uipParam[nID].attr.iProp,&dNewValue,DCAMPROP_OPTION_NONE);
	if(!bQuery)
	{
		updatevalue(uipParam[nID].attr.iProp);
		*pResult = 0;
		return;
	}

	// set value
	if(! setvaluetoDCAM(uipParam[nID].attr.iProp, dNewValue))
	{
		showerrorcode();
	}
	updatevalue(uipParam[nID].attr.iProp);

	CheckUpdateDCAMPROP();

	*pResult = 0;
}

void CuiXlinePageCONF::OnSetfocusXlscConfCalibregionhpos3Edit() 
{
	int		nID = CalibRegionHPos3;
	input_on_setfocus(nID);	
}

void CuiXlinePageCONF::OnKillfocusXlscConfCalibregionhpos3Edit() 
{
	int		nID = CalibRegionHPos3;
	input_on_killfocus(nID);
}

void CuiXlinePageCONF::OnDeltaposXlscConfCalibregionhpos3Spin(NMHDR* pNMHDR, LRESULT* pResult) 
{
	NM_UPDOWN* pNMUpDown = (NM_UPDOWN*)pNMHDR;

	int		nID = CalibRegionHPos3;
	CString	str;
	double	dNewValue;
	double	min = uipParam[nID].attr.valuemin;
	double	max = uipParam[nID].attr.valuemax;
	double	step = uipParam[nID].attr.valuestep;

	CEdit*	pEdit = (CEdit*)GetDlgItem(uipParam[nID].iEditBox);
	pEdit->GetWindowText(str);
	dNewValue = atof(str);

	dNewValue	= (pNMUpDown->iDelta > 0) ? (dNewValue + step) : (dNewValue - step);
	if(dNewValue < min)		dNewValue = min;
	if(dNewValue > max)		dNewValue = max;
	// query
	BOOL	bQuery = dcam_querypropertyvalue(m_hdcam,uipParam[nID].attr.iProp,&dNewValue,DCAMPROP_OPTION_NONE);
	if(!bQuery)
	{
		updatevalue(uipParam[nID].attr.iProp);
		*pResult = 0;
		return;
	}

	// set value
	if(! setvaluetoDCAM(uipParam[nID].attr.iProp, dNewValue))
	{
		showerrorcode();
	}
	updatevalue(uipParam[nID].attr.iProp);

	CheckUpdateDCAMPROP();

	*pResult = 0;
}

void CuiXlinePageCONF::OnSetfocusXlscConfCalibregionhsize3Edit() 
{
	int		nID = CalibRegionHSize3;
	input_on_setfocus(nID);	
}

void CuiXlinePageCONF::OnKillfocusXlscConfCalibregionhsize3Edit() 
{
	int		nID = CalibRegionHSize3;
	input_on_killfocus(nID);
}

void CuiXlinePageCONF::OnDeltaposXlscConfCalibregionhsize3Spin(NMHDR* pNMHDR, LRESULT* pResult) 
{
	NM_UPDOWN* pNMUpDown = (NM_UPDOWN*)pNMHDR;

	int		nID = CalibRegionHSize3;
	CString	str;
	double	dNewValue;
	double	min = uipParam[nID].attr.valuemin;
	double	max = uipParam[nID].attr.valuemax;
	double	step = uipParam[nID].attr.valuestep;

	CEdit*	pEdit = (CEdit*)GetDlgItem(uipParam[nID].iEditBox);
	pEdit->GetWindowText(str);
	dNewValue = atof(str);

	dNewValue	= (pNMUpDown->iDelta > 0) ? (dNewValue + step) : (dNewValue - step);
	if(dNewValue < min)		dNewValue = min;
	if(dNewValue > max)		dNewValue = max;

	// query
	BOOL	bQuery = dcam_querypropertyvalue(m_hdcam,uipParam[nID].attr.iProp,&dNewValue,DCAMPROP_OPTION_NONE);
	if(!bQuery)
	{
		updatevalue(uipParam[nID].attr.iProp);
		*pResult = 0;
		return;
	}

	// set value
	if(! setvaluetoDCAM(uipParam[nID].attr.iProp, dNewValue))
	{
		showerrorcode();
	}
	updatevalue(uipParam[nID].attr.iProp);

	CheckUpdateDCAMPROP();
	
	*pResult = 0;
}

BOOL CuiXlinePageCONF::PreTranslateMessage(MSG* pMsg) 
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
			switch(nDlgCtrlID)
			{
				case IDC_XLINE_CONF_CALIBREGIONMODE_ALL_RADIO:
					OnXlscConfCalibregionmodeAllRadio();
					break;
				case IDC_XLINE_CONF_CALIBREGIONMODE_ON_RADIO:
					OnXlscConfCalibregionmodeOnRadio();
					break;
				case IDC_XLINE_CONF_NUMBEROFCALIBREGION_EDIT:
					OnKillfocusXlscConfNumberofcalibregionEdit();
					break;
				case IDC_XLINE_CONF_CALIBREGIONHPOS0_EDIT:
					OnKillfocusXlscConfCalibregionhpos0Edit();
					break;
				case IDC_XLINE_CONF_CALIBREGIONHSIZE0_EDIT:
					OnKillfocusXlscConfCalibregionhsize0Edit();
					break;
				case IDC_XLINE_CONF_CALIBREGIONHPOS1_EDIT:
					OnKillfocusXlscConfCalibregionhpos1Edit();
					break;
				case IDC_XLINE_CONF_CALIBREGIONHSIZE1_EDIT:
					OnKillfocusXlscConfCalibregionhsize1Edit();
					break;
				case IDC_XLINE_CONF_CALIBREGIONHPOS2_EDIT:
					OnKillfocusXlscConfCalibregionhpos2Edit();
					break;
				case IDC_XLINE_CONF_CALIBREGIONHSIZE2_EDIT:
					OnKillfocusXlscConfCalibregionhsize2Edit();
					break;
				case IDC_XLINE_CONF_CALIBREGIONHPOS3_EDIT:
					OnKillfocusXlscConfCalibregionhpos3Edit();
					break;
				case IDC_XLINE_CONF_CALIBREGIONHSIZE3_EDIT:
					OnKillfocusXlscConfCalibregionhsize3Edit();
					break;

			}
			return 0;
		}
	}

	return CPropertyPage::PreTranslateMessage(pMsg);
}









