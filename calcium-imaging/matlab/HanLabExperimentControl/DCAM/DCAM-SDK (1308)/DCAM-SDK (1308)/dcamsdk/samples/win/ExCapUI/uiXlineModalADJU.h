#if !defined(AFX_UIXLINEMODALADJU_H__84BE01B7_2478_46C9_B4D5_3C7D30391A69__INCLUDED_)
#define AFX_UIXLINEMODALADJU_H__84BE01B7_2478_46C9_B4D5_3C7D30391A69__INCLUDED_

#if _MSC_VER > 1000
#pragma once
#endif // _MSC_VER > 1000
// uiXlineModalADJU.h : header file
//

/////////////////////////////////////////////////////////////////////////////
// CuiXlineModalADJU Dialog

class CuiXlineModalADJU : public CDialog
{
// Construction
public:
	CuiXlineModalADJU(CWnd* pParent = NULL);

// Dialog Data
	//{{AFX_DATA(CuiXlineModalADJU)
	enum { IDD = IDD_XLINE_ADJU };
	//}}AFX_DATA


// Overrides
	//{{AFX_VIRTUAL(CuiXlineModalADJU)
	protected:
	virtual void DoDataExchange(CDataExchange* pDX);    // DDX/DDV Support
	//}}AFX_VIRTUAL

// Implementation
protected:

	//{{AFX_MSG(CuiXlineModalADJU)
	afx_msg void OnEnChangeXlscAdjuGtModuleEdit();
	afx_msg void OnEnChangeXlscAdjuGtGainLowEdit();
	afx_msg void OnEnChangeXlscAdjuGtGainHighEdit();
	virtual void OnOK();
	//}}AFX_MSG
	DECLARE_MESSAGE_MAP()

private:
	void PASCAL DDV_DataCheck (CDataExchange * pDX);

public:
	// module ch
	int		m_sensorch;

	// for edit modules
	int		m_gtmodules;
	int		m_gtmodules_min;
	int		m_gtmodules_max;

	// for edit ge low
	int		m_gtlow;
	int		m_gtlow_min;
	int		m_gtlow_max;

	// for edit ge high
	int		m_gthigh;
	int		m_gthigh_min;
	int		m_gthigh_max;

	int*		p_gtlow;
	int*		p_gthigh;

	BOOL	makestructure(int ch, int modules, int gtmin, int gtmax);
	void	destroystructure(void);
	void	setfirst(int modules, int gtlow, int gthigh);

	BOOL		bInit;
	CListCtrl	m_gtlistview;
	void		InitializeListView(void);
	void		UpdateListView(void);

	virtual BOOL DestroyWindow();
	virtual BOOL OnInitDialog();

};

//{{AFX_INSERT_LOCATION}}

#endif // !defined(AFX_UIXLINEMODALADJU_H__84BE01B7_2478_46C9_B4D5_3C7D30391A69__INCLUDED_)
