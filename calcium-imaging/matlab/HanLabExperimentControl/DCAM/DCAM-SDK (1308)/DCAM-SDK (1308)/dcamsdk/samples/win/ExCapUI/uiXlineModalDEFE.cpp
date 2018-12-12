// uiXlineModalDEFE.cpp : Inplementation File
//

#include "stdafx.h"
#include "excapui.h"
#include "uiXlineModalDEFE.h"

#ifdef _DEBUG
#define new DEBUG_NEW
#undef THIS_FILE
static char THIS_FILE[] = __FILE__;
#endif

/////////////////////////////////////////////////////////////////////////////
// CuiXlineModalDEFE Dialog


CuiXlineModalDEFE::CuiXlineModalDEFE(CWnd* pParent /*=NULL*/)
	: CDialog(CuiXlineModalDEFE::IDD, pParent)
{
	//{{AFX_DATA_INIT(CuiXlineModalDEFE)
	//}}AFX_DATA_INIT
}


void CuiXlineModalDEFE::DoDataExchange(CDataExchange* pDX)
{
	CDialog::DoDataExchange(pDX);
	//{{AFX_DATA_MAP(CuiXlineModalDEFE)
	//}}AFX_DATA_MAP
}

void CuiXlineModalDEFE::update_editspin()
{
	int	i;
	CString		str;
	CEdit*		pEdit;
	CSpinButtonCtrl*	pSpin;

	for(i=0;i<5;i++)
	{
		str.Format("%.0f",uipDefectCorrectHPos[i].value);
		pEdit = (CEdit*)GetDlgItem(uipDefectCorrectHPos[i].iEditBox);
		pEdit->SetWindowText(str);
		pSpin = (CSpinButtonCtrl*)GetDlgItem(uipDefectCorrectHPos[i].iSpin);
		pSpin->SetRange(-1,1);
		pSpin->SetPos(0);
	}

}

void CuiXlineModalDEFE::update_numberedit(BOOL first)
{
	double		dValue = 0.00;
	CString		str;
	CEdit*		pEdit;
	CButton* pButton;

	if(first)
	{
		if(uipDefectCorrectMode.value == DCAMPROP_MODE__OFF)	// mode off
		{
			uipNumberOfDefectCorrect.value = 0.00;
		}
		else													// mode on
		{
			int iCount = (int)uipNumberOfDefectCorrect.value;
			pButton = (CButton*)GetDlgItem(IDC_XLINE_DEFE_DEFECTCORRECTHPOS1_CHECK);
			pButton->SetCheck(TRUE);	iCount--;
			if(iCount > 0)
			{
				pButton = (CButton*)GetDlgItem(IDC_XLINE_DEFE_DEFECTCORRECTHPOS2_CHECK);
				pButton->SetCheck(TRUE);	iCount--;
			}
			if(iCount > 0)
			{
				pButton = (CButton*)GetDlgItem(IDC_XLINE_DEFE_DEFECTCORRECTHPOS3_CHECK);
				pButton->SetCheck(TRUE);	iCount--;
			}
			if(iCount > 0)
			{
				pButton = (CButton*)GetDlgItem(IDC_XLINE_DEFE_DEFECTCORRECTHPOS4_CHECK);
				pButton->SetCheck(TRUE);	iCount--;
			}
			if(iCount > 0)
			{
				pButton = (CButton*)GetDlgItem(IDC_XLINE_DEFE_DEFECTCORRECTHPOS5_CHECK);
				pButton->SetCheck(TRUE);	iCount--;
			}
		}
	}
	else
	{
		uipNumberOfDefectCorrect.value = (double)update_checkbox();
	}

	str.Format("%.0f",uipNumberOfDefectCorrect.value);
	pEdit = (CEdit*)GetDlgItem(uipNumberOfDefectCorrect.iEditBox);
	pEdit->SetWindowText(str);

}

int CuiXlineModalDEFE::update_checkbox()
{
	int		nCheck = 0;
	CButton* pButton;

	pButton = (CButton*)GetDlgItem(IDC_XLINE_DEFE_DEFECTCORRECTHPOS1_CHECK);
	if(pButton->GetCheck())
	{
		b_checkbox[0] = TRUE;
		nCheck++;
	}
	else
	{
		b_checkbox[0] = FALSE;
	}

	pButton = (CButton*)GetDlgItem(IDC_XLINE_DEFE_DEFECTCORRECTHPOS2_CHECK);
	if(pButton->GetCheck())
	{
		b_checkbox[1] = TRUE;
		nCheck++;
	}
	else
	{
		b_checkbox[1] = FALSE;
	}

	pButton = (CButton*)GetDlgItem(IDC_XLINE_DEFE_DEFECTCORRECTHPOS3_CHECK);
	if(pButton->GetCheck())
	{
		b_checkbox[2] = TRUE;
		nCheck++;
	}
	else
	{
		b_checkbox[2] = FALSE;
	}

	pButton = (CButton*)GetDlgItem(IDC_XLINE_DEFE_DEFECTCORRECTHPOS4_CHECK);
	if(pButton->GetCheck())
	{
		b_checkbox[3] = TRUE;
		nCheck++;
	}
	else
	{
		b_checkbox[3] = FALSE;
	}

	pButton = (CButton*)GetDlgItem(IDC_XLINE_DEFE_DEFECTCORRECTHPOS5_CHECK);
	if(pButton->GetCheck())
	{
		b_checkbox[4] = TRUE;
		nCheck++;
	}
	else
	{
		b_checkbox[4] = FALSE;
	}

	return nCheck;

}

BEGIN_MESSAGE_MAP(CuiXlineModalDEFE, CDialog)
	//{{AFX_MSG_MAP(CuiXlineModalDEFE)
	ON_EN_KILLFOCUS(IDC_XLINE_DEFE_DEFECTCORRECTHPOS1_EDIT, OnKillfocusXlscDefeDefectcorrecthpos1Edit)
	ON_EN_KILLFOCUS(IDC_XLINE_DEFE_DEFECTCORRECTHPOS2_EDIT, OnKillfocusXlscDefeDefectcorrecthpos2Edit)
	ON_EN_KILLFOCUS(IDC_XLINE_DEFE_DEFECTCORRECTHPOS3_EDIT, OnKillfocusXlscDefeDefectcorrecthpos3Edit)
	ON_EN_KILLFOCUS(IDC_XLINE_DEFE_DEFECTCORRECTHPOS4_EDIT, OnKillfocusXlscDefeDefectcorrecthpos4Edit)
	ON_EN_KILLFOCUS(IDC_XLINE_DEFE_DEFECTCORRECTHPOS5_EDIT, OnKillfocusXlscDefeDefectcorrecthpos5Edit)
	ON_NOTIFY(UDN_DELTAPOS, IDC_XLINE_DEFE_DEFECTCORRECTHPOS1_SPIN, OnDeltaposXlscDefeDefectcorrecthpos1Spin)
	ON_NOTIFY(UDN_DELTAPOS, IDC_XLINE_DEFE_DEFECTCORRECTHPOS2_SPIN, OnDeltaposXlscDefeDefectcorrecthpos2Spin)
	ON_NOTIFY(UDN_DELTAPOS, IDC_XLINE_DEFE_DEFECTCORRECTHPOS3_SPIN, OnDeltaposXlscDefeDefectcorrecthpos3Spin)
	ON_NOTIFY(UDN_DELTAPOS, IDC_XLINE_DEFE_DEFECTCORRECTHPOS4_SPIN, OnDeltaposXlscDefeDefectcorrecthpos4Spin)
	ON_NOTIFY(UDN_DELTAPOS, IDC_XLINE_DEFE_DEFECTCORRECTHPOS5_SPIN, OnDeltaposXlscDefeDefectcorrecthpos5Spin)
	ON_BN_CLICKED(IDC_XLINE_DEFE_DEFECTCORRECTHPOS1_CHECK, OnXlscDefeDefectcorrecthpos1Check)
	ON_BN_CLICKED(IDC_XLINE_DEFE_DEFECTCORRECTHPOS2_CHECK, OnXlscDefeDefectcorrecthpos2Check)
	ON_BN_CLICKED(IDC_XLINE_DEFE_DEFECTCORRECTHPOS3_CHECK, OnXlscDefeDefectcorrecthpos3Check)
	ON_BN_CLICKED(IDC_XLINE_DEFE_DEFECTCORRECTHPOS4_CHECK, OnXlscDefeDefectcorrecthpos4Check)
	ON_BN_CLICKED(IDC_XLINE_DEFE_DEFECTCORRECTHPOS5_CHECK, OnXlscDefeDefectcorrecthpos5Check)
	//}}AFX_MSG_MAP
END_MESSAGE_MAP()

/////////////////////////////////////////////////////////////////////////////
// CuiXlineModalDEFE Message Handler

BOOL CuiXlineModalDEFE::OnInitDialog() 
{
	CDialog::OnInitDialog();
	
	uipDefectCorrectHPos[0].iEditBox	= IDC_XLINE_DEFE_DEFECTCORRECTHPOS1_EDIT;
	uipDefectCorrectHPos[0].iSpin		= IDC_XLINE_DEFE_DEFECTCORRECTHPOS1_SPIN;
	uipDefectCorrectHPos[1].iEditBox	= IDC_XLINE_DEFE_DEFECTCORRECTHPOS2_EDIT;
	uipDefectCorrectHPos[1].iSpin		= IDC_XLINE_DEFE_DEFECTCORRECTHPOS2_SPIN;
	uipDefectCorrectHPos[2].iEditBox	= IDC_XLINE_DEFE_DEFECTCORRECTHPOS3_EDIT;
	uipDefectCorrectHPos[2].iSpin		= IDC_XLINE_DEFE_DEFECTCORRECTHPOS3_SPIN;
	uipDefectCorrectHPos[3].iEditBox	= IDC_XLINE_DEFE_DEFECTCORRECTHPOS4_EDIT;
	uipDefectCorrectHPos[3].iSpin		= IDC_XLINE_DEFE_DEFECTCORRECTHPOS4_SPIN;
	uipDefectCorrectHPos[4].iEditBox	= IDC_XLINE_DEFE_DEFECTCORRECTHPOS5_EDIT;
	uipDefectCorrectHPos[4].iSpin		= IDC_XLINE_DEFE_DEFECTCORRECTHPOS5_SPIN;

	uipDefectCorrectMethod[0].value		= DCAMPROP_DEFECTCORRECT_METHOD__PREVIOUS;
	uipDefectCorrectMethod[1].value		= DCAMPROP_DEFECTCORRECT_METHOD__PREVIOUS;
	uipDefectCorrectMethod[2].value		= DCAMPROP_DEFECTCORRECT_METHOD__PREVIOUS;
	uipDefectCorrectMethod[3].value		= DCAMPROP_DEFECTCORRECT_METHOD__PREVIOUS;
	uipDefectCorrectMethod[4].value		= DCAMPROP_DEFECTCORRECT_METHOD__PREVIOUS;

	update_editspin();

	uipNumberOfDefectCorrect.iEditBox	= IDC_XLINE_DEFE_NUMBEROFDEFECTCORRECT_STATIC;
	update_numberedit(TRUE);
	
	return TRUE;
}

void CuiXlineModalDEFE::OnKillfocusXlscDefeDefectcorrecthpos1Edit() 
{
	int i=0;
	CString	str;
	double	dNewValue;

	CEdit*	pEdit = (CEdit*)GetDlgItem(uipDefectCorrectHPos[i].iEditBox);
	pEdit->GetWindowText(str);
	dNewValue = atof(str);

	// show out of range 
	double	min = uipDefectCorrectHPos[i].attr.valuemin;
	double	max = uipDefectCorrectHPos[i].attr.valuemax;
	if(dNewValue < min || dNewValue > max)
	{
		CString strOutofrange;
		strOutofrange.Format("Input value is out of range. Set value in range.[%.0f to %.0f]",min,max);
		AfxMessageBox(strOutofrange,MB_OK);
		update_editspin();
		pEdit->SetFocus();
		return;
	}

	uipDefectCorrectHPos[i].value = dNewValue;
	update_editspin();

}

void CuiXlineModalDEFE::OnKillfocusXlscDefeDefectcorrecthpos2Edit() 
{
	int i=1;
	CString	str;
	double	dNewValue;

	CEdit*	pEdit = (CEdit*)GetDlgItem(uipDefectCorrectHPos[i].iEditBox);
	pEdit->GetWindowText(str);
	dNewValue = atof(str);

	// show out of range 
	double	min = uipDefectCorrectHPos[i].attr.valuemin;
	double	max = uipDefectCorrectHPos[i].attr.valuemax;
	if(dNewValue < min || dNewValue > max)
	{
		CString strOutofrange;
		strOutofrange.Format("Input value is out of range. Set value in range.[%.0f to %.0f]",min,max);
		AfxMessageBox(strOutofrange,MB_OK);
		update_editspin();
		pEdit->SetFocus();
		return;
	}

	uipDefectCorrectHPos[i].value = dNewValue;
	update_editspin();
	
}

void CuiXlineModalDEFE::OnKillfocusXlscDefeDefectcorrecthpos3Edit() 
{
	int i=2;
	CString	str;
	double	dNewValue;

	CEdit*	pEdit = (CEdit*)GetDlgItem(uipDefectCorrectHPos[i].iEditBox);
	pEdit->GetWindowText(str);
	dNewValue = atof(str);

	// show out of range 
	double	min = uipDefectCorrectHPos[i].attr.valuemin;
	double	max = uipDefectCorrectHPos[i].attr.valuemax;
	if(dNewValue < min || dNewValue > max)
	{
		CString strOutofrange;
		strOutofrange.Format("Input value is out of range. Set value in range.[%.0f to %.0f]",min,max);
		AfxMessageBox(strOutofrange,MB_OK);
		update_editspin();
		pEdit->SetFocus();
		return;
	}

	uipDefectCorrectHPos[i].value = dNewValue;
	update_editspin();
	
}

void CuiXlineModalDEFE::OnKillfocusXlscDefeDefectcorrecthpos4Edit() 
{
	int i=3;
	CString	str;
	double	dNewValue;

	CEdit*	pEdit = (CEdit*)GetDlgItem(uipDefectCorrectHPos[i].iEditBox);
	pEdit->GetWindowText(str);
	dNewValue = atof(str);

	// show out of range 
	double	min = uipDefectCorrectHPos[i].attr.valuemin;
	double	max = uipDefectCorrectHPos[i].attr.valuemax;
	if(dNewValue < min || dNewValue > max)
	{
		CString strOutofrange;
		strOutofrange.Format("Input value is out of range. Set value in range.[%.0f to %.0f]",min,max);
		AfxMessageBox(strOutofrange,MB_OK);
		update_editspin();
		pEdit->SetFocus();
		return;
	}

	uipDefectCorrectHPos[i].value = dNewValue;
	update_editspin();
	
}

void CuiXlineModalDEFE::OnKillfocusXlscDefeDefectcorrecthpos5Edit() 
{
	int i=4;
	CString	str;
	double	dNewValue;

	CEdit*	pEdit = (CEdit*)GetDlgItem(uipDefectCorrectHPos[i].iEditBox);
	pEdit->GetWindowText(str);
	dNewValue = atof(str);

	// show out of range 
	double	min = uipDefectCorrectHPos[i].attr.valuemin;
	double	max = uipDefectCorrectHPos[i].attr.valuemax;
	if(dNewValue < min || dNewValue > max)
	{
		CString strOutofrange;
		strOutofrange.Format("Input value is out of range. Set value in range.[%.0f to %.0f]",min,max);
		AfxMessageBox(strOutofrange,MB_OK);
		update_editspin();
		pEdit->SetFocus();
		return;
	}

	uipDefectCorrectHPos[i].value = dNewValue;
	update_editspin();
	
}

void CuiXlineModalDEFE::OnDeltaposXlscDefeDefectcorrecthpos1Spin(NMHDR* pNMHDR, LRESULT* pResult) 
{
	NM_UPDOWN* pNMUpDown = (NM_UPDOWN*)pNMHDR;
	
	int i=0;
	CString	str;
	double	dNewValue;
	double	min = uipDefectCorrectHPos[i].attr.valuemin;
	double	max = uipDefectCorrectHPos[i].attr.valuemax;
	double	step = uipDefectCorrectHPos[i].attr.valuestep;

	CEdit*	pEdit = (CEdit*)GetDlgItem(uipDefectCorrectHPos[i].iEditBox);
	pEdit->GetWindowText(str);
	dNewValue = atof(str);

	dNewValue	= (pNMUpDown->iDelta > 0) ? (dNewValue + step) : (dNewValue - step);
	if(dNewValue < min)		dNewValue = min;
	if(dNewValue > max)		dNewValue = max;

	uipDefectCorrectHPos[i].value = dNewValue;
	update_editspin();

	*pResult = 0;
}

void CuiXlineModalDEFE::OnDeltaposXlscDefeDefectcorrecthpos2Spin(NMHDR* pNMHDR, LRESULT* pResult) 
{
	NM_UPDOWN* pNMUpDown = (NM_UPDOWN*)pNMHDR;
	
	int i=1;
	CString	str;
	double	dNewValue;
	double	min = uipDefectCorrectHPos[i].attr.valuemin;
	double	max = uipDefectCorrectHPos[i].attr.valuemax;
	double	step = uipDefectCorrectHPos[i].attr.valuestep;

	CEdit*	pEdit = (CEdit*)GetDlgItem(uipDefectCorrectHPos[i].iEditBox);
	pEdit->GetWindowText(str);
	dNewValue = atof(str);

	dNewValue	= (pNMUpDown->iDelta > 0) ? (dNewValue + step) : (dNewValue - step);
	if(dNewValue < min)		dNewValue = min;
	if(dNewValue > max)		dNewValue = max;

	uipDefectCorrectHPos[i].value = dNewValue;
	update_editspin();
	
	*pResult = 0;
}

void CuiXlineModalDEFE::OnDeltaposXlscDefeDefectcorrecthpos3Spin(NMHDR* pNMHDR, LRESULT* pResult) 
{
	NM_UPDOWN* pNMUpDown = (NM_UPDOWN*)pNMHDR;
	
	int i=2;
	CString	str;
	double	dNewValue;
	double	min = uipDefectCorrectHPos[i].attr.valuemin;
	double	max = uipDefectCorrectHPos[i].attr.valuemax;
	double	step = uipDefectCorrectHPos[i].attr.valuestep;

	CEdit*	pEdit = (CEdit*)GetDlgItem(uipDefectCorrectHPos[i].iEditBox);
	pEdit->GetWindowText(str);
	dNewValue = atof(str);

	dNewValue	= (pNMUpDown->iDelta > 0) ? (dNewValue + step) : (dNewValue - step);
	if(dNewValue < min)		dNewValue = min;
	if(dNewValue > max)		dNewValue = max;

	uipDefectCorrectHPos[i].value = dNewValue;
	update_editspin();
	
	*pResult = 0;
}

void CuiXlineModalDEFE::OnDeltaposXlscDefeDefectcorrecthpos4Spin(NMHDR* pNMHDR, LRESULT* pResult) 
{
	NM_UPDOWN* pNMUpDown = (NM_UPDOWN*)pNMHDR;
	
	int i=3;
	CString	str;
	double	dNewValue;
	double	min = uipDefectCorrectHPos[i].attr.valuemin;
	double	max = uipDefectCorrectHPos[i].attr.valuemax;
	double	step = uipDefectCorrectHPos[i].attr.valuestep;

	CEdit*	pEdit = (CEdit*)GetDlgItem(uipDefectCorrectHPos[i].iEditBox);
	pEdit->GetWindowText(str);
	dNewValue = atof(str);

	dNewValue	= (pNMUpDown->iDelta > 0) ? (dNewValue + step) : (dNewValue - step);
	if(dNewValue < min)		dNewValue = min;
	if(dNewValue > max)		dNewValue = max;

	uipDefectCorrectHPos[i].value = dNewValue;
	update_editspin();

	
	*pResult = 0;
}

void CuiXlineModalDEFE::OnDeltaposXlscDefeDefectcorrecthpos5Spin(NMHDR* pNMHDR, LRESULT* pResult) 
{
	NM_UPDOWN* pNMUpDown = (NM_UPDOWN*)pNMHDR;
	
	int i=4;
	CString	str;
	double	dNewValue;
	double	min = uipDefectCorrectHPos[i].attr.valuemin;
	double	max = uipDefectCorrectHPos[i].attr.valuemax;
	double	step = uipDefectCorrectHPos[i].attr.valuestep;

	CEdit*	pEdit = (CEdit*)GetDlgItem(uipDefectCorrectHPos[i].iEditBox);
	pEdit->GetWindowText(str);
	dNewValue = atof(str);

	dNewValue	= (pNMUpDown->iDelta > 0) ? (dNewValue + step) : (dNewValue - step);
	if(dNewValue < min)		dNewValue = min;
	if(dNewValue > max)		dNewValue = max;

	uipDefectCorrectHPos[i].value = dNewValue;
	update_editspin();
	
	*pResult = 0;
}


void CuiXlineModalDEFE::OnXlscDefeDefectcorrecthpos1Check() 
{
	update_numberedit();
	
}

void CuiXlineModalDEFE::OnXlscDefeDefectcorrecthpos2Check() 
{
	update_numberedit();
	
}

void CuiXlineModalDEFE::OnXlscDefeDefectcorrecthpos3Check() 
{
	update_numberedit();
	
}

void CuiXlineModalDEFE::OnXlscDefeDefectcorrecthpos4Check() 
{
	update_numberedit();
	
}

void CuiXlineModalDEFE::OnXlscDefeDefectcorrecthpos5Check() 
{
	update_numberedit();
	
}
