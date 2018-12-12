// uiXlinePageMASK.cpp : implementation file
//

#include "stdafx.h"
#include "ExCapUI.h"
#include "uiXlinePageMASK.h"
#include "dcamex.h"

#ifdef _DEBUG
#define new DEBUG_NEW
#undef THIS_FILE
static char THIS_FILE[] = __FILE__;
#endif

/////////////////////////////////////////////////////////////////////////////
// CuiXlinePageMASK property page

IMPLEMENT_DYNCREATE(CuiXlinePageMASK, CPropertyPage)

CuiXlinePageMASK::CuiXlinePageMASK() : CExCapUIPropertyPage(CuiXlinePageMASK::IDD)
{
	//{{AFX_DATA_INIT(CuiXlinePageMASK)
	m_radio = -1;
	//}}AFX_DATA_INIT

}

void CuiXlinePageMASK::AddProperties()
{
	// NumberOfMaskRegion
	AddPropertyID(DCAM_IDPROP_NUMBEROF_MASKREGION);
	uipParam[NumberOfMaskRegion].iEditBox	= IDC_XLINE_MASK_NUMBEROFMASKREGION_EDIT;
	uipParam[NumberOfMaskRegion].iSpin		= IDC_XLINE_MASK_NUMBEROFMASKREGION_SPIN;

	// MaskRegionHPos0
	AddPropertyID(DCAM_IDPROP_MASKREGION_HPOS);
	uipParam[MaskRegionHPos0].iEditBox		= IDC_XLINE_MASK_MASKREGIONHPOS0_EDIT;
	uipParam[MaskRegionHPos0].iSpin		= IDC_XLINE_MASK_MASKREGIONHPOS0_SPIN;

	// MaskRegionHPos1
	//AddPropertyID(DCAM_IDPROP_MASKREGION_HPOS + DCAM_IDPROP__MASKREGION * 1);
	AddPropertyID(MakeIDPROP_array(DCAM_IDPROP_MASKREGION_HPOS,1));
	uipParam[MaskRegionHPos1].iEditBox		= IDC_XLINE_MASK_MASKREGIONHPOS1_EDIT;
	uipParam[MaskRegionHPos1].iSpin		= IDC_XLINE_MASK_MASKREGIONHPOS1_SPIN;

	// MaskRegionHPos2
	//AddPropertyID(DCAM_IDPROP_MASKREGION_HPOS + DCAM_IDPROP__MASKREGION * 2);
	AddPropertyID(MakeIDPROP_array(DCAM_IDPROP_MASKREGION_HPOS,2));
	uipParam[MaskRegionHPos2].iEditBox		= IDC_XLINE_MASK_MASKREGIONHPOS2_EDIT;
	uipParam[MaskRegionHPos2].iSpin		= IDC_XLINE_MASK_MASKREGIONHPOS2_SPIN;

	// MaskRegionHPos3
	//AddPropertyID(DCAM_IDPROP_MASKREGION_HPOS + DCAM_IDPROP__MASKREGION * 3);
	AddPropertyID(MakeIDPROP_array(DCAM_IDPROP_MASKREGION_HPOS,3));
	uipParam[MaskRegionHPos3].iEditBox		= IDC_XLINE_MASK_MASKREGIONHPOS3_EDIT;
	uipParam[MaskRegionHPos3].iSpin		= IDC_XLINE_MASK_MASKREGIONHPOS3_SPIN;

	// MaskRegionHSize0
	AddPropertyID(DCAM_IDPROP_MASKREGION_HSIZE);
	uipParam[MaskRegionHSize0].iEditBox	= IDC_XLINE_MASK_MASKREGIONHSIZE0_EDIT;
	uipParam[MaskRegionHSize0].iSpin		= IDC_XLINE_MASK_MASKREGIONHSIZE0_SPIN;

	// MaskRegionHSize1
	//AddPropertyID(DCAM_IDPROP_MASKREGION_HSIZE + DCAM_IDPROP__MASKREGION * 1);
	AddPropertyID(MakeIDPROP_array(DCAM_IDPROP_MASKREGION_HSIZE,1));
	uipParam[MaskRegionHSize1].iEditBox	= IDC_XLINE_MASK_MASKREGIONHSIZE1_EDIT;
	uipParam[MaskRegionHSize1].iSpin		= IDC_XLINE_MASK_MASKREGIONHSIZE1_SPIN;
	
	// MaskRegionHSize2
	//AddPropertyID(DCAM_IDPROP_MASKREGION_HSIZE + DCAM_IDPROP__MASKREGION * 2);
	AddPropertyID(MakeIDPROP_array(DCAM_IDPROP_MASKREGION_HSIZE,2));
	uipParam[MaskRegionHSize2].iEditBox	= IDC_XLINE_MASK_MASKREGIONHSIZE2_EDIT;
	uipParam[MaskRegionHSize2].iSpin		= IDC_XLINE_MASK_MASKREGIONHSIZE2_SPIN;
	
	// MaskRegionHSize3
	//AddPropertyID(DCAM_IDPROP_MASKREGION_HSIZE + DCAM_IDPROP__MASKREGION * 3);
	AddPropertyID(MakeIDPROP_array(DCAM_IDPROP_MASKREGION_HSIZE,3));
	uipParam[MaskRegionHSize3].iEditBox	= IDC_XLINE_MASK_MASKREGIONHSIZE3_EDIT;
	uipParam[MaskRegionHSize3].iSpin		= IDC_XLINE_MASK_MASKREGIONHSIZE3_SPIN;

	// MaskRegionMode
	AddPropertyID(DCAM_IDPROP_MASKREGION_MODE);
	uipParam[MaskRegionMode].iRadio		= IDC_XLINE_MASK_MASKREGIONMODE_OFF_RADIO;

	// DefectCorrectMode
	AddPropertyID(DCAM_IDPROP_DEFECTCORRECT_MODE);

	// NumberOfDefectCorrect
	AddPropertyID(DCAM_IDPROP_NUMBEROF_DEFECTCORRECT);

	// DefectCorrectHPos0
	AddPropertyID(DCAM_IDPROP_DEFECTCORRECT_HPOS);

	// DefectCorrectHPos1
	//AddPropertyID(DCAM_IDPROP_DEFECTCORRECT_HPOS + DCAM_IDPROP__DEFECTCORRECT * 1);
	AddPropertyID(MakeIDPROP_array(DCAM_IDPROP_DEFECTCORRECT_HPOS,1));

	// DefectCorrectHPos2
	//AddPropertyID(DCAM_IDPROP_DEFECTCORRECT_HPOS + DCAM_IDPROP__DEFECTCORRECT * 2);
	AddPropertyID(MakeIDPROP_array(DCAM_IDPROP_DEFECTCORRECT_HPOS,2));

	// DefectCorrectHPos3
	//AddPropertyID(DCAM_IDPROP_DEFECTCORRECT_HPOS + DCAM_IDPROP__DEFECTCORRECT * 3);
	AddPropertyID(MakeIDPROP_array(DCAM_IDPROP_DEFECTCORRECT_HPOS,3));

	// DefectCorrectHPos4
	//AddPropertyID(DCAM_IDPROP_DEFECTCORRECT_HPOS + DCAM_IDPROP__DEFECTCORRECT * 4);
	AddPropertyID(MakeIDPROP_array(DCAM_IDPROP_DEFECTCORRECT_HPOS,4));

	// DefectCorrectMethod0
	AddPropertyID(DCAM_IDPROP_DEFECTCORRECT_METHOD);

	// DefectCorrectMethod1
	//AddPropertyID(DCAM_IDPROP_DEFECTCORRECT_METHOD + DCAM_IDPROP__DEFECTCORRECT * 1);
	AddPropertyID(MakeIDPROP_array(DCAM_IDPROP_DEFECTCORRECT_METHOD,1));

	// DefectCorrectMethod2
	//AddPropertyID(DCAM_IDPROP_DEFECTCORRECT_METHOD + DCAM_IDPROP__DEFECTCORRECT * 2);
	AddPropertyID(MakeIDPROP_array(DCAM_IDPROP_DEFECTCORRECT_METHOD,2));

	// DefectCorrectMethod3
	//AddPropertyID(DCAM_IDPROP_DEFECTCORRECT_METHOD + DCAM_IDPROP__DEFECTCORRECT * 3);
	AddPropertyID(MakeIDPROP_array(DCAM_IDPROP_DEFECTCORRECT_METHOD,3));

	// DefectCorrectMethod4
	//AddPropertyID(DCAM_IDPROP_DEFECTCORRECT_METHOD + DCAM_IDPROP__DEFECTCORRECT * 4);
	AddPropertyID(MakeIDPROP_array(DCAM_IDPROP_DEFECTCORRECT_METHOD,4));

}

CuiXlinePageMASK::~CuiXlinePageMASK()
{
}

void CuiXlinePageMASK::DoDataExchange(CDataExchange* pDX)
{
	CPropertyPage::DoDataExchange(pDX);
	//{{AFX_DATA_MAP(CuiXlinePageMASK)
	DDX_Radio(pDX, IDC_XLINE_MASK_MASKREGIONMODE_OFF_RADIO, m_radio);
	//}}AFX_DATA_MAP

//	DCAMDDX_DCAM_REAL(pDX, IDC_DLGDCAMABOUT_EDITEXPOSURETIME, IDC_DLGDCAMABOUT_SPINEXPOSURETIME, m_hdcam, DCAM_IDPROP_EXPOSURETIME );
}

BEGIN_MESSAGE_MAP(CuiXlinePageMASK, CPropertyPage)
	//{{AFX_MSG_MAP(CuiXlinePageMASK)
	ON_NOTIFY(UDN_DELTAPOS, IDC_XLINE_MASK_NUMBEROFMASKREGION_SPIN, OnDeltaposXlscMaskNumberofmaskregionSpin)
	ON_NOTIFY(UDN_DELTAPOS, IDC_XLINE_MASK_MASKREGIONHPOS0_SPIN, OnDeltaposXlscMaskMaskregionhpos0Spin)
	ON_NOTIFY(UDN_DELTAPOS, IDC_XLINE_MASK_MASKREGIONHPOS1_SPIN, OnDeltaposXlscMaskMaskregionhpos1Spin)
	ON_NOTIFY(UDN_DELTAPOS, IDC_XLINE_MASK_MASKREGIONHPOS2_SPIN, OnDeltaposXlscMaskMaskregionhpos2Spin)
	ON_NOTIFY(UDN_DELTAPOS, IDC_XLINE_MASK_MASKREGIONHPOS3_SPIN, OnDeltaposXlscMaskMaskregionhpos3Spin)
	ON_NOTIFY(UDN_DELTAPOS, IDC_XLINE_MASK_MASKREGIONHSIZE0_SPIN, OnDeltaposXlscMaskMaskregionhsize0Spin)
	ON_NOTIFY(UDN_DELTAPOS, IDC_XLINE_MASK_MASKREGIONHSIZE1_SPIN, OnDeltaposXlscMaskMaskregionhsize1Spin)
	ON_NOTIFY(UDN_DELTAPOS, IDC_XLINE_MASK_MASKREGIONHSIZE2_SPIN, OnDeltaposXlscMaskMaskregionhsize2Spin)
	ON_NOTIFY(UDN_DELTAPOS, IDC_XLINE_MASK_MASKREGIONHSIZE3_SPIN, OnDeltaposXlscMaskMaskregionhsize3Spin)
	ON_BN_CLICKED(IDC_XLINE_MASK_MASKREGIONMODE_OFF_RADIO, OnXlscMaskMaskregionmodeOffRadio)
	ON_BN_CLICKED(IDC_XLINE_MASK_MASKREGIONMODE_ON_RADIO, OnXlscMaskMaskregionmodeOnRadio)
	ON_EN_KILLFOCUS(IDC_XLINE_MASK_NUMBEROFMASKREGION_EDIT, OnKillfocusXlscMaskNumberofmaskregionEdit)
	ON_EN_KILLFOCUS(IDC_XLINE_MASK_MASKREGIONHPOS0_EDIT, OnKillfocusXlscMaskMaskregionhpos0Edit)
	ON_EN_KILLFOCUS(IDC_XLINE_MASK_MASKREGIONHPOS1_EDIT, OnKillfocusXlscMaskMaskregionhpos1Edit)
	ON_EN_KILLFOCUS(IDC_XLINE_MASK_MASKREGIONHPOS2_EDIT, OnKillfocusXlscMaskMaskregionhpos2Edit)
	ON_EN_KILLFOCUS(IDC_XLINE_MASK_MASKREGIONHPOS3_EDIT, OnKillfocusXlscMaskMaskregionhpos3Edit)
	ON_EN_KILLFOCUS(IDC_XLINE_MASK_MASKREGIONHSIZE0_EDIT, OnKillfocusXlscMaskMaskregionhsize0Edit)
	ON_EN_KILLFOCUS(IDC_XLINE_MASK_MASKREGIONHSIZE1_EDIT, OnKillfocusXlscMaskMaskregionhsize1Edit)
	ON_EN_KILLFOCUS(IDC_XLINE_MASK_MASKREGIONHSIZE2_EDIT, OnKillfocusXlscMaskMaskregionhsize2Edit)
	ON_EN_KILLFOCUS(IDC_XLINE_MASK_MASKREGIONHSIZE3_EDIT, OnKillfocusXlscMaskMaskregionhsize3Edit)
	ON_BN_CLICKED(IDC_XLINE_MASK_DEFECTCORRECT_BUTTON, OnXlscMaskDefectcorrectButton)
	ON_EN_SETFOCUS(IDC_XLINE_MASK_NUMBEROFMASKREGION_EDIT, OnSetfocusXlscMaskNumberofmaskregionEdit)
	ON_EN_SETFOCUS(IDC_XLINE_MASK_MASKREGIONHPOS0_EDIT, OnSetfocusXlscMaskMaskregionhpos0Edit)
	ON_EN_SETFOCUS(IDC_XLINE_MASK_MASKREGIONHSIZE0_EDIT, OnSetfocusXlscMaskMaskregionhsize0Edit)
	ON_EN_SETFOCUS(IDC_XLINE_MASK_MASKREGIONHPOS1_EDIT, OnSetfocusXlscMaskMaskregionhpos1Edit)
	ON_EN_SETFOCUS(IDC_XLINE_MASK_MASKREGIONHSIZE1_EDIT, OnSetfocusXlscMaskMaskregionhsize1Edit)
	ON_EN_SETFOCUS(IDC_XLINE_MASK_MASKREGIONHPOS2_EDIT, OnSetfocusXlscMaskMaskregionhpos2Edit)
	ON_EN_SETFOCUS(IDC_XLINE_MASK_MASKREGIONHSIZE2_EDIT, OnSetfocusXlscMaskMaskregionhsize2Edit)
	ON_EN_SETFOCUS(IDC_XLINE_MASK_MASKREGIONHPOS3_EDIT, OnSetfocusXlscMaskMaskregionhpos3Edit)
	ON_EN_SETFOCUS(IDC_XLINE_MASK_MASKREGIONHSIZE3_EDIT, OnSetfocusXlscMaskMaskregionhsize3Edit)
	//}}AFX_MSG_MAP
END_MESSAGE_MAP()

/////////////////////////////////////////////////////////////////////////////
// CuiXlinePageMASK message handlers

BOOL CuiXlinePageMASK::OnInitDialog() 
{
	AddProperties();

	CheckSupportDCAMPROP();

	// defect correct button is show/hide
	char	buf[256];
	CString str;
	dcam_getstring( m_hdcam, DCAM_IDSTR_MODEL, buf, sizeof( buf ) );
	str = buf;
	if(str.Find("M10351-01") >= 0)
	{
	}
	else
	{
		CButton* pButton = (CButton*)GetDlgItem(IDC_XLINE_MASK_DEFECTCORRECT_BUTTON);
		pButton->ShowWindow(SW_HIDE);
	}

	// set check radio button
	for(int i = 0; i < uipParam[MaskRegionMode].numberofidvalue; i++)
	{
		if(uipParam[MaskRegionMode].value == uipParam[MaskRegionMode].idvalue[i])
		{
			m_radio = i;
		}
	}

	CPropertyPage::OnInitDialog();
	
	// TODO: Add extra initialization here
	
	return TRUE;  // return TRUE unless you set the focus to a control
	              // EXCEPTION: OCX Property Pages should return FALSE
}

void CuiXlinePageMASK::OnOK() 
{
	CPropertyPage::OnOK();
}

void CuiXlinePageMASK::OnCancel() 
{
	CPropertyPage::OnCancel();
}

BOOL CuiXlinePageMASK::OnApply() 
{
	return CPropertyPage::OnApply();
}

void CuiXlinePageMASK::OnDeltaposXlscMaskNumberofmaskregionSpin(NMHDR* pNMHDR, LRESULT* pResult) 
{
	NM_UPDOWN* pNMUpDown = (NM_UPDOWN*)pNMHDR;

	int		nID = NumberOfMaskRegion;
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

void CuiXlinePageMASK::OnDeltaposXlscMaskMaskregionhpos0Spin(NMHDR* pNMHDR, LRESULT* pResult) 
{
	NM_UPDOWN* pNMUpDown = (NM_UPDOWN*)pNMHDR;
	
	int		nID = MaskRegionHPos0;
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

void CuiXlinePageMASK::OnDeltaposXlscMaskMaskregionhpos1Spin(NMHDR* pNMHDR, LRESULT* pResult) 
{
	NM_UPDOWN* pNMUpDown = (NM_UPDOWN*)pNMHDR;

	int		nID = MaskRegionHPos1;
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

void CuiXlinePageMASK::OnDeltaposXlscMaskMaskregionhpos2Spin(NMHDR* pNMHDR, LRESULT* pResult) 
{
	NM_UPDOWN* pNMUpDown = (NM_UPDOWN*)pNMHDR;
	
	int		nID = MaskRegionHPos2;
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

void CuiXlinePageMASK::OnDeltaposXlscMaskMaskregionhpos3Spin(NMHDR* pNMHDR, LRESULT* pResult) 
{
	NM_UPDOWN* pNMUpDown = (NM_UPDOWN*)pNMHDR;
	
	int		nID = MaskRegionHPos3;
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

void CuiXlinePageMASK::OnDeltaposXlscMaskMaskregionhsize0Spin(NMHDR* pNMHDR, LRESULT* pResult) 
{
	NM_UPDOWN* pNMUpDown = (NM_UPDOWN*)pNMHDR;

	int		nID = MaskRegionHSize0;
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

void CuiXlinePageMASK::OnDeltaposXlscMaskMaskregionhsize1Spin(NMHDR* pNMHDR, LRESULT* pResult) 
{
	NM_UPDOWN* pNMUpDown = (NM_UPDOWN*)pNMHDR;

	int		nID = MaskRegionHSize1;
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

void CuiXlinePageMASK::OnDeltaposXlscMaskMaskregionhsize2Spin(NMHDR* pNMHDR, LRESULT* pResult) 
{
	NM_UPDOWN* pNMUpDown = (NM_UPDOWN*)pNMHDR;
	
	int		nID = MaskRegionHSize2;
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

void CuiXlinePageMASK::OnDeltaposXlscMaskMaskregionhsize3Spin(NMHDR* pNMHDR, LRESULT* pResult) 
{
	NM_UPDOWN* pNMUpDown = (NM_UPDOWN*)pNMHDR;

	int		nID = MaskRegionHSize3;
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

void CuiXlinePageMASK::OnXlscMaskMaskregionmodeOffRadio() 
{
	BOOL	bRet = FALSE;
	UpdateData();

	if(m_radio == 0)
		bRet = setvaluetoDCAM(uipParam[MaskRegionMode].attr.iProp, DCAMPROP_MODE__OFF);
	else if(m_radio == 1)
		bRet = setvaluetoDCAM(uipParam[MaskRegionMode].attr.iProp, DCAMPROP_MODE__ON);

	CheckUpdateDCAMPROP();

}

void CuiXlinePageMASK::OnXlscMaskMaskregionmodeOnRadio() 
{
	BOOL	bRet = FALSE;
	UpdateData();

	if(m_radio == 0)
		bRet = setvaluetoDCAM(uipParam[MaskRegionMode].attr.iProp, DCAMPROP_MODE__OFF);
	else if(m_radio == 1)
		bRet = setvaluetoDCAM(uipParam[MaskRegionMode].attr.iProp, DCAMPROP_MODE__ON);

	CheckUpdateDCAMPROP();
}

void CuiXlinePageMASK::OnSetfocusXlscMaskNumberofmaskregionEdit() 
{
	int		nID = NumberOfMaskRegion;
	input_on_setfocus(nID);	
}

void CuiXlinePageMASK::OnKillfocusXlscMaskNumberofmaskregionEdit() 
{
	int		nID = NumberOfMaskRegion;
	input_on_killfocus(nID);
}

void CuiXlinePageMASK::OnSetfocusXlscMaskMaskregionhpos0Edit() 
{
	int		nID = MaskRegionHPos0;
	input_on_setfocus(nID);	
}

void CuiXlinePageMASK::OnKillfocusXlscMaskMaskregionhpos0Edit() 
{
	int		nID = MaskRegionHPos0;
	input_on_killfocus(nID);
}

void CuiXlinePageMASK::OnSetfocusXlscMaskMaskregionhpos1Edit() 
{
	int		nID = MaskRegionHPos1;
	input_on_setfocus(nID);	
}

void CuiXlinePageMASK::OnKillfocusXlscMaskMaskregionhpos1Edit() 
{
	int		nID = MaskRegionHPos1;
	input_on_killfocus(nID);
}

void CuiXlinePageMASK::OnSetfocusXlscMaskMaskregionhpos2Edit() 
{
	int		nID = MaskRegionHPos2;
	input_on_setfocus(nID);	
}

void CuiXlinePageMASK::OnKillfocusXlscMaskMaskregionhpos2Edit() 
{
	int		nID = MaskRegionHPos2;
	input_on_killfocus(nID);
}

void CuiXlinePageMASK::OnSetfocusXlscMaskMaskregionhpos3Edit() 
{
	int		nID = MaskRegionHPos3;
	input_on_setfocus(nID);	
}

void CuiXlinePageMASK::OnKillfocusXlscMaskMaskregionhpos3Edit() 
{
	int		nID = MaskRegionHPos3;
	input_on_killfocus(nID);
}

void CuiXlinePageMASK::OnSetfocusXlscMaskMaskregionhsize0Edit() 
{
	int		nID = MaskRegionHSize0;
	input_on_setfocus(nID);	
}

void CuiXlinePageMASK::OnKillfocusXlscMaskMaskregionhsize0Edit() 
{
	int		nID = MaskRegionHSize0;
	input_on_killfocus(nID);
}

void CuiXlinePageMASK::OnSetfocusXlscMaskMaskregionhsize1Edit() 
{
	int		nID = MaskRegionHSize1;
	input_on_setfocus(nID);	
}

void CuiXlinePageMASK::OnKillfocusXlscMaskMaskregionhsize1Edit() 
{
	int		nID = MaskRegionHSize1;
	input_on_killfocus(nID);
}

void CuiXlinePageMASK::OnSetfocusXlscMaskMaskregionhsize2Edit() 
{
	int		nID = MaskRegionHSize2;
	input_on_setfocus(nID);	
}

void CuiXlinePageMASK::OnKillfocusXlscMaskMaskregionhsize2Edit() 
{
	int		nID = MaskRegionHSize2;
	input_on_killfocus(nID);
}

void CuiXlinePageMASK::OnSetfocusXlscMaskMaskregionhsize3Edit() 
{
	int		nID = MaskRegionHSize3;
	input_on_setfocus(nID);	
}

void CuiXlinePageMASK::OnKillfocusXlscMaskMaskregionhsize3Edit() 
{
	int		nID = MaskRegionHSize3;
	input_on_killfocus(nID);
}

void CuiXlinePageMASK::OnXlscMaskDefectcorrectButton() 
{
	BOOL	bRet;

	CuiXlineModalDEFE pDlg;

	int	nID;
	nID = DefectCorrectMode;
	pDlg.uipDefectCorrectMode = uipParam[nID];

	nID = NumberOfDefectCorrect;
	pDlg.uipNumberOfDefectCorrect = uipParam[nID];

	nID = DefectCorrectHPos0;
	pDlg.uipDefectCorrectHPos[0] = uipParam[nID];
	nID = DefectCorrectHPos1;
	pDlg.uipDefectCorrectHPos[1] = uipParam[nID];
	nID = DefectCorrectHPos2;
	pDlg.uipDefectCorrectHPos[2] = uipParam[nID];
	nID = DefectCorrectHPos3;
	pDlg.uipDefectCorrectHPos[3] = uipParam[nID];
	nID = DefectCorrectHPos4;
	pDlg.uipDefectCorrectHPos[4] = uipParam[nID];

	nID = DefectCorrectMethod0;
	pDlg.uipDefectCorrectMethod[0] = uipParam[nID];
	nID = DefectCorrectMethod1;
	pDlg.uipDefectCorrectMethod[1] = uipParam[nID];
	nID = DefectCorrectMethod2;
	pDlg.uipDefectCorrectMethod[2] = uipParam[nID];
	nID = DefectCorrectMethod3;
	pDlg.uipDefectCorrectMethod[3] = uipParam[nID];
	nID = DefectCorrectMethod4;
	pDlg.uipDefectCorrectMethod[4] = uipParam[nID];
	
	int		nCount = 0;
	INT_PTR modal = pDlg.DoModal();
	if(modal == IDOK)
	{
		if(pDlg.uipNumberOfDefectCorrect.value > 0)		// DefectCorrect ON
		{
			for(int i=0;i<5;i++)
			{
				if(pDlg.b_checkbox[i])
				{
					nID = DefectCorrectHPos0 + nCount;
					uipParam[nID].value = pDlg.uipDefectCorrectHPos[i].value;
					bRet = setvaluetoDCAM(uipParam[nID].attr.iProp, uipParam[nID].value);	// set value to DCAM
					CheckUpdateDCAMPROP();

					nID = DefectCorrectMethod0 + nCount;
					uipParam[nID].value = DCAMPROP_DEFECTCORRECT_METHOD__PREVIOUS;
					bRet = setvaluetoDCAM(uipParam[nID].attr.iProp, uipParam[nID].value);	// set value to DCAM
					CheckUpdateDCAMPROP();

					nCount++;
				}
			}
			if(nCount < 5)
			{
				for(int i=0;i<5;i++)
				{
					if(!pDlg.b_checkbox[i])
					{
						nID = DefectCorrectHPos0 + nCount;
						uipParam[nID].value = pDlg.uipDefectCorrectHPos[i].value;
						bRet = setvaluetoDCAM(uipParam[nID].attr.iProp, uipParam[nID].value);	// set value to DCAM
						CheckUpdateDCAMPROP();

						nID = DefectCorrectMethod0 + nCount;
						uipParam[nID].value = DCAMPROP_DEFECTCORRECT_METHOD__PREVIOUS;
						bRet = setvaluetoDCAM(uipParam[nID].attr.iProp, uipParam[nID].value);	// set value to DCAM
						CheckUpdateDCAMPROP();

						nCount++;

					}
				}

			}

			nID = NumberOfDefectCorrect;
			uipParam[nID].value = pDlg.uipNumberOfDefectCorrect.value;
			bRet = setvaluetoDCAM(uipParam[nID].attr.iProp, uipParam[nID].value);	// set value to DCAM
			CheckUpdateDCAMPROP();

			nID = DefectCorrectMode;
			uipParam[nID].value = DCAMPROP_MODE__ON;
			setvaluetoDCAM(uipParam[nID].attr.iProp, uipParam[nID].value);	// set value to DCAM
			CheckUpdateDCAMPROP();

		}
		else		// DefectCorrectMode is OFF
		{
			nID = DefectCorrectMode;
			uipParam[nID].value = DCAMPROP_MODE__OFF;
			setvaluetoDCAM(uipParam[nID].attr.iProp, uipParam[nID].value);	// set value to DCAM
			CheckUpdateDCAMPROP();
			for(int i=0;i<5;i++)
			{
				nID = DefectCorrectHPos0 + nCount;
				uipParam[nID].value = pDlg.uipDefectCorrectHPos[i].value;
				setvaluetoDCAM(uipParam[nID].attr.iProp, uipParam[nID].value);	// set value to DCAM
				CheckUpdateDCAMPROP();
				nID = DefectCorrectMethod0 + nCount;
				uipParam[nID].value = DCAMPROP_DEFECTCORRECT_METHOD__PREVIOUS;
				setvaluetoDCAM(uipParam[nID].attr.iProp, DCAMPROP_DEFECTCORRECT_METHOD__PREVIOUS);	// set value to DCAM
				CheckUpdateDCAMPROP();
				nCount++;
			}
		}
		CheckUpdateDCAMPROP();
	}

	
}

BOOL CuiXlinePageMASK::PreTranslateMessage(MSG* pMsg) 
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
				case IDC_XLINE_MASK_NUMBEROFMASKREGION_EDIT:
					OnKillfocusXlscMaskNumberofmaskregionEdit();
					break;
				case IDC_XLINE_MASK_MASKREGIONHPOS0_EDIT:
					OnKillfocusXlscMaskMaskregionhpos0Edit();
					break;
				case IDC_XLINE_MASK_MASKREGIONHPOS1_EDIT:
					OnKillfocusXlscMaskMaskregionhpos1Edit();
					break;
				case IDC_XLINE_MASK_MASKREGIONHPOS2_EDIT:
					OnKillfocusXlscMaskMaskregionhpos2Edit();
					break;
				case IDC_XLINE_MASK_MASKREGIONHPOS3_EDIT:
					OnKillfocusXlscMaskMaskregionhpos3Edit();
					break;
				case IDC_XLINE_MASK_MASKREGIONHSIZE0_EDIT:
					OnKillfocusXlscMaskMaskregionhsize0Edit();
					break;
				case IDC_XLINE_MASK_MASKREGIONHSIZE1_EDIT:
					OnKillfocusXlscMaskMaskregionhsize1Edit();
					break;
				case IDC_XLINE_MASK_MASKREGIONHSIZE2_EDIT:
					OnKillfocusXlscMaskMaskregionhsize2Edit();
					break;
				case IDC_XLINE_MASK_MASKREGIONHSIZE3_EDIT:
					OnKillfocusXlscMaskMaskregionhsize3Edit();
					break;

			}
			return 0;
		}
	}
	
	return CPropertyPage::PreTranslateMessage(pMsg);
}

