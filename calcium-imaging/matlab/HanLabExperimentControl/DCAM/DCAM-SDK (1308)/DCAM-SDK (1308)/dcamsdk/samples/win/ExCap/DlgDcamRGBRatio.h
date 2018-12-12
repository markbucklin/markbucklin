// DlgDcamRGBRatio.h : header file

#if _MSC_VER > 1000
#pragma once
#endif // _MSC_VER > 1000
//

/////////////////////////////////////////////////////////////////////////////
// CDlgDcamRGBRatio dialog

class CDlgDcamRGBRatio : public CDialog
{
// Construction
public:
	~CDlgDcamRGBRatio();
	CDlgDcamRGBRatio(CWnd* pParent = NULL);   // standard constructor

// Dialog Data
	//{{AFX_DATA(CDlgDcamRGBRatio)
	enum { IDD = IDD_DLGDCAMRGBRATIO };
	//}}AFX_DATA

// Common DCAM Dialog Data in ExCap
protected:
	BOOL	m_bCreateDialog;
	HDCAM	m_hdcam;

// Private Dialog Data
protected:
	BOOL	m_bBlocked;
	struct _DCAM_PARAM_RGBRATIO* m_rgbratio;

// Overrides
	// ClassWizard generated virtual function overrides
	//{{AFX_VIRTUAL(CDlgDcamRGBRatio)
	public:
	virtual BOOL Create( CWnd* pParentWnd = NULL);
	protected:
	virtual void DoDataExchange(CDataExchange* pDX);    // DDX/DDV support
	//}}AFX_VIRTUAL

// Implementation

// Common implementation of DCAM Dialog in ExCap
public:
			BOOL	toggle_visible();
			HDCAM	set_hdcam( HDCAM hdcam );

// Private implementation
protected:
			void	update_ratiovalue( UINT id, double& value );
			BOOL	update_values( BOOL bSet = TRUE );

// Generated message map functions
protected:
	//{{AFX_MSG(CDlgDcamRGBRatio)
	virtual void OnOK();
	virtual void OnCancel();
	virtual BOOL OnInitDialog();
	afx_msg void OnRgbratioExpoBtnset1blue();
	afx_msg void OnRgbratioExpoBtnset1green();
	afx_msg void OnRgbratioExpoBtnset1red();
	afx_msg void OnRgbratioGainBtnset1blue();
	afx_msg void OnRgbratioGainBtnset1green();
	afx_msg void OnRgbratioGainBtnset1red();
	afx_msg void OnRgbratioExpoBtnhalfblue();
	afx_msg void OnRgbratioExpoBtnhalfgreen();
	afx_msg void OnRgbratioExpoBtnhalfred();
	afx_msg void OnRgbratioGainBtnhalfblue();
	afx_msg void OnRgbratioGainBtnhalfgreen();
	afx_msg void OnRgbratioGainBtnhalfred();
	afx_msg void OnRgbratioExpoBtntwiceblue();
	afx_msg void OnRgbratioExpoBtntwicegreen();
	afx_msg void OnRgbratioExpoBtntwicered();
	afx_msg void OnRgbratioGainBtntwiceblue();
	afx_msg void OnRgbratioGainBtntwicegreen();
	afx_msg void OnRgbratioGainBtntwicered();
	afx_msg void OnRgbratioExpoWhitebalance();
	afx_msg void OnChangeRgbvalue();
	afx_msg void OnTimer(UINT_PTR nIDEvent);	
	afx_msg void OnDestroy();
	//}}AFX_MSG
	DECLARE_MESSAGE_MAP()
};

//{{AFX_INSERT_LOCATION}}
// Microsoft Visual C++ will insert additional declarations immediately before the previous line.
