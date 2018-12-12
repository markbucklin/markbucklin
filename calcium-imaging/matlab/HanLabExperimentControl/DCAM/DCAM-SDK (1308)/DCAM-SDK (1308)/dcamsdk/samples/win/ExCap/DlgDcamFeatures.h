// DlgDcamFeatures.h : header file
//

#if _MSC_VER > 1000
#pragma once
#endif // _MSC_VER > 1000

/////////////////////////////////////////////////////////////////////////////
// CDlgDcamFeatures dialog

class CDlgDcamFeatures : public CDialog
{
// Construction
public:
	~CDlgDcamFeatures();
	CDlgDcamFeatures(CWnd* pParent = NULL);   // standard constructor

// Dialog Data
	//{{AFX_DATA(CDlgDcamFeatures)
	enum { IDD = IDD_DLGDCAMFEATURES };
	CButton	m_btnDirectEMGain;
	//}}AFX_DATA

// Common DCAM Dialog Data in ExCap
protected:
	BOOL	m_bCreateDialog;
	HDCAM	m_hdcam;

// Private Dialog Data
protected:
	long	m_nFeaturecount;
	struct feature*	m_feature;

	// to protect re-entrance of command messages.
	struct 
	{
		long	value;
		long	slider;
	} m_changing;

// Overrides
	// ClassWizard generated virtual function overrides
	//{{AFX_VIRTUAL(CDlgDcamFeatures)
	public:
	virtual BOOL Create( CWnd* pParentWnd = NULL );
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
			BOOL	GetDlgItemDbl( int nID, double& fValue );
			void	SetDlgItemDbl( int nID, double  fValue );

			void	update_values();
			void	update_control( int iFeature, BOOL bInitialize = FALSE );

protected:
			void	update_value( int iFeature );

// Generated message map functions
protected:
	//{{AFX_MSG(CDlgDcamFeatures)
	virtual BOOL OnInitDialog();
	afx_msg void OnDestroy();
	virtual void OnOK();
	virtual void OnCancel();
	afx_msg void OnHScroll(UINT nSBCode, UINT nPos, CScrollBar* pScrollBar);
	afx_msg void OnDlgdcamfeatureBtndirectemgain();
	//}}AFX_MSG
	void OnChangeValue( UINT id );
	void OnChangeMode( UINT id );

	DECLARE_MESSAGE_MAP()
};

//{{AFX_INSERT_LOCATION}}
// Microsoft Visual C++ will insert additional declarations immediately before the previous line.
