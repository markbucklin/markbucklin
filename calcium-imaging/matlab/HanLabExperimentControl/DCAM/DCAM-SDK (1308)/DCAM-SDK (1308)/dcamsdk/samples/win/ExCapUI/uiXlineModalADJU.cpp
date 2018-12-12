// uiXlineModalADJU.cpp : Implementation file
//

#include "stdafx.h"
#include "excapui.h"
#include "uiXlineModalADJU.h"
#include ".\uixlinemodaladju.h"

#ifdef _DEBUG
#define new DEBUG_NEW
#undef THIS_FILE
static char THIS_FILE[] = __FILE__;
#endif

/////////////////////////////////////////////////////////////////////////////
// CuiXlineModalADJU Dialog


CuiXlineModalADJU::CuiXlineModalADJU(CWnd* pParent /*=NULL*/)
	: CDialog(CuiXlineModalADJU::IDD, pParent)
{
	//{{AFX_DATA_INIT(CuiXlineModalADJU)
	//}}AFX_DATA_INIT

	bInit = FALSE;

	// module ch
	m_sensorch		= 1;

	// for edit modules
	m_gtmodules		= 0;
	m_gtmodules_min	= 0;
	m_gtmodules_max	= 0;;

	// for edit ge low
	m_gtlow			= 0;
	m_gtlow_min		= 0;
	m_gtlow_max		= 0;

	// for edit ge high
	m_gthigh		= 0;
	m_gthigh_min	= 0;
	m_gthigh_max	= 0;

	p_gtlow			= NULL;
	p_gthigh		= NULL;

}


void CuiXlineModalADJU::DoDataExchange(CDataExchange* pDX)
{
	CDialog::DoDataExchange(pDX);

	//{{AFX_DATA_MAP(CuiXlineModalADJU)
		DDX_Control(pDX, IDC_XLINE_ADJU_GT_LIST, m_gtlistview);
		DDX_Text(pDX, IDC_XLINE_ADJU_GT_MODULE_EDIT, m_gtmodules);
		DDX_Text(pDX, IDC_XLINE_ADJU_GT_GAIN_LOW_EDIT, m_gtlow);
		DDX_Text(pDX, IDC_XLINE_ADJU_GT_GAIN_HIGH_EDIT, m_gthigh);
	//}}AFX_DATA_MAP
	DDV_DataCheck (pDX);

}

BOOL CuiXlineModalADJU::makestructure(int ch, int modules, int gtmin, int gtmax)
{
	if(modules > 0)
	{
		m_gtmodules_max	= modules-1;

		if(p_gtlow != NULL)		delete[] p_gtlow;
		if(p_gthigh != NULL)	delete[] p_gthigh;
		p_gtlow			= new int[m_gtmodules_max+1];
		p_gthigh		= new int[m_gtmodules_max+1];
		m_sensorch		= ch;
		m_gtlow_min		= gtmin;
		m_gtlow_max		= gtmax;
		m_gthigh_min	= gtmin;
		m_gthigh_max	= gtmax;

		return TRUE;
	}
	else
	{
		return FALSE;
	}
	
	return FALSE;
}

void CuiXlineModalADJU::destroystructure(void)
{
	if(p_gtlow != NULL)		delete[] p_gtlow;
	if(p_gthigh != NULL)	delete[] p_gthigh;
}

void CuiXlineModalADJU::setfirst(int modules, int gtlow, int gthigh)
{
	if(p_gtlow == NULL)						return;
	if(m_sensorch == 2 && p_gthigh == NULL)	return;

	m_gtmodules		= modules;
	m_gtlow			= gtlow;
	m_gthigh		= gthigh;

}

void CuiXlineModalADJU::InitializeListView(void)
{
	int	i,iItem;
	iItem = m_gtmodules_max+1;
	CString		strColumnName,strValue;

	// make column
	strColumnName.Format("Value");
	m_gtlistview.InsertColumn(0, strColumnName, LVCFMT_LEFT, 48);
	for(i=0;i<iItem;i++)
	{
		strColumnName.Format("%d",i);
		m_gtlistview.InsertColumn( i+1, strColumnName, LVCFMT_LEFT, 32);
	}

	if(m_sensorch < 2)
	{	// single energy
		// make item
		strValue.Format(" ");
		m_gtlistview.InsertItem(LVIF_TEXT,0,strValue,0,0,0,0);
		for(i=0;i<iItem;i++)
		{
			strValue.Format("%d",p_gtlow[i]);
			m_gtlistview.SetItem(0,i+1,LVIF_TEXT,strValue,0,0,0,0);
		}
	}
	else if(m_sensorch == 2)
	{		// dual energy
		// make item
		strValue.Format("LOW");
		m_gtlistview.InsertItem(LVIF_TEXT,0,strValue,0,0,0,0);
		strValue.Format("HIGH");
		m_gtlistview.InsertItem(LVIF_TEXT,1,strValue,0,0,0,0);
		for(i=0;i<iItem;i++)
		{
			strValue.Format("%d",p_gtlow[i]);
			m_gtlistview.SetItem(0,i+1,LVIF_TEXT,strValue,0,0,0,0);
			strValue.Format("%d",p_gthigh[i]);
			m_gtlistview.SetItem(1,i+1,LVIF_TEXT,strValue,0,0,0,0);
		}
	}
	else
	{		// multi energy
	}
	
}

void CuiXlineModalADJU::UpdateListView(void)
{
	int	i,iItem;
	iItem = m_gtmodules_max+1;
	CString		strValue;

	if(!bInit)	return;

	if(m_sensorch < 2)
	{	// single energy
		// make item
		for(i=0;i<iItem;i++)
		{
			strValue.Format("%d",p_gtlow[i]);
			m_gtlistview.SetItem(0,i+1,LVIF_TEXT,strValue,0,0,0,0);
		}
	}
	else if(m_sensorch == 2)
	{	// dual energy
		// make item
		for(i=0;i<iItem;i++)
		{
			strValue.Format("%d",p_gtlow[i]);
			m_gtlistview.SetItem(0,i+1,LVIF_TEXT,strValue,0,0,0,0);
			strValue.Format("%d",p_gthigh[i]);
			m_gtlistview.SetItem(1,i+1,LVIF_TEXT,strValue,0,0,0,0);
		}
	}
	else
	{		// multi energy
	}

	m_gtlistview.RedrawWindow();
	
}


BEGIN_MESSAGE_MAP(CuiXlineModalADJU, CDialog)
	//{{AFX_MSG_MAP(CuiXlineModalADJU)
	ON_EN_CHANGE(IDC_XLINE_ADJU_GT_MODULE_EDIT, OnEnChangeXlscAdjuGtModuleEdit)
	ON_EN_CHANGE(IDC_XLINE_ADJU_GT_GAIN_LOW_EDIT, OnEnChangeXlscAdjuGtGainLowEdit)
	ON_EN_CHANGE(IDC_XLINE_ADJU_GT_GAIN_HIGH_EDIT, OnEnChangeXlscAdjuGtGainHighEdit)
	//}}AFX_MSG_MAP
END_MESSAGE_MAP()

/////////////////////////////////////////////////////////////////////////////
// CuiXlineModalADJU Message ハンドラ

BOOL CuiXlineModalADJU::DestroyWindow()
{
//	if(p_gtlow != NULL)		delete[] p_gtlow;
//	if(p_gthigh != NULL)	delete[] p_gthigh;

	return CDialog::DestroyWindow();
}

BOOL CuiXlineModalADJU::OnInitDialog()
{
	CDialog::OnInitDialog();

	((CSpinButtonCtrl*) GetDlgItem (IDC_XLINE_ADJU_GT_MODULE_SPIN	))->SetRange32 (m_gtmodules_min, m_gtmodules_max);
	((CSpinButtonCtrl*) GetDlgItem (IDC_XLINE_ADJU_GT_GAIN_LOW_SPIN	))->SetRange32 (m_gtlow_min, m_gtlow_max);
	((CSpinButtonCtrl*) GetDlgItem (IDC_XLINE_ADJU_GT_GAIN_HIGH_SPIN	))->SetRange32 (m_gthigh_min, m_gthigh_max);

	if(m_sensorch < 2){
		GetDlgItem (IDC_XLINE_ADJU_GT_LOW_STATIC     )->ShowWindow (SW_HIDE);

		GetDlgItem (IDC_XLINE_ADJU_GT_CH2_STATIC		)->ShowWindow (SW_HIDE);
		GetDlgItem (IDC_XLINE_ADJU_GT_HIGH_STATIC	)->ShowWindow (SW_HIDE);
		GetDlgItem (IDC_XLINE_ADJU_GT_GAIN_HIGH_EDIT	)->ShowWindow (SW_HIDE);
		GetDlgItem (IDC_XLINE_ADJU_GT_GAIN_HIGH_SPIN	)->ShowWindow (SW_HIDE);
	}

	bInit = TRUE;

	InitializeListView();

	UpdateListView();

	UpdateData (FALSE);

	return TRUE;  // return TRUE unless you set the focus to a control

}

void PASCAL CuiXlineModalADJU::DDV_DataCheck(CDataExchange * pDX)
{
	if (pDX->m_bSaveAndValidate)
	{
		BOOL	errFlag	= FALSE;
		DWORD	nID;
		int		nMin, nMax;

		if ((m_gtlow_min <= m_gtlow_max) && ((m_gtlow < m_gtlow_min) || (m_gtlow_max < m_gtlow)))
		{
			errFlag	= TRUE;	nID		= IDC_XLINE_ADJU_GT_GAIN_LOW_EDIT;	nMin	= m_gtlow_min;	nMax	= m_gtlow_max;
		}
		else if ((m_sensorch ==2) && ((m_gthigh_min <= m_gthigh_max) && ((m_gthigh < m_gthigh_min) || (m_gthigh_max < m_gthigh))))
		{
			errFlag	= TRUE;	nID		= IDC_XLINE_ADJU_GT_GAIN_HIGH_EDIT;	nMin	= m_gthigh_min;	nMax	= m_gthigh_max;
		}

		if (errFlag)
		{
			pDX->PrepareEditCtrl (nID);
			pDX->Fail ();
		}
	}
	else
	{
	}

}

void CuiXlineModalADJU::OnEnChangeXlscAdjuGtModuleEdit()
{
	BOOL	errFlag	= FALSE;
	DWORD	nID = IDC_XLINE_ADJU_GT_MODULE_EDIT;
	int		nMin = m_gtmodules_min;
	int		nMax = m_gtmodules_max;

	int	n	= GetDlgItemInt (nID);
	if (nMin > n)
	{
		errFlag	= TRUE;
		n = nMin;
		SetDlgItemInt (nID,n);
	}
	if (nMax < n)
	{
		errFlag	= TRUE;
		n = nMax;
		SetDlgItemInt (nID,n);
	}

	SetDlgItemInt (IDC_XLINE_ADJU_GT_GAIN_LOW_EDIT,p_gtlow[n]);
	if(p_gthigh != NULL)
		SetDlgItemInt (IDC_XLINE_ADJU_GT_GAIN_HIGH_EDIT,p_gthigh[n]);

}

void CuiXlineModalADJU::OnEnChangeXlscAdjuGtGainLowEdit()
{
	int	lLow;
	if(bInit)
	{
		lLow	= GetDlgItemInt (IDC_XLINE_ADJU_GT_GAIN_LOW_EDIT);
	}
	else
	{
		lLow	= m_gtlow;
	}

	int	lModule	= GetDlgItemInt (IDC_XLINE_ADJU_GT_MODULE_EDIT);

	if ((m_gtlow_min <= lLow) && (lLow <= m_gtlow_max))
	{
		//	set value to list
		p_gtlow[lModule] = lLow;
	}

	//	update listview
	UpdateListView();

}

void CuiXlineModalADJU::OnEnChangeXlscAdjuGtGainHighEdit()
{
	int	lHigh;
	if(bInit)
	{
		lHigh	= GetDlgItemInt (IDC_XLINE_ADJU_GT_GAIN_HIGH_EDIT);
	}
	else
	{
		lHigh	= m_gthigh;
	}
	//int	lHigh	= GetDlgItemInt (IDC_XLINE_ADJU_GT_GAIN_HIGH_EDIT);
	//int		lHigh	= m_gthigh;
	int	lModule	= GetDlgItemInt (IDC_XLINE_ADJU_GT_MODULE_EDIT);

	if ((m_gthigh_min <= lHigh) && (lHigh <= m_gthigh_max))
	{
		//	set value to list
		p_gthigh[lModule] = lHigh;
	}

	//	update listview
	UpdateListView();

}


void CuiXlineModalADJU::OnOK() 
{
	// TODO: この位置にその他の検証用のコードを追加してください
	
	CDialog::OnOK();
}
