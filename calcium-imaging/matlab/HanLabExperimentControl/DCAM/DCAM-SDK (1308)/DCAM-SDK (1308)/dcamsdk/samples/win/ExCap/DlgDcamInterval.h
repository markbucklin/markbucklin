// DlgDcamInterval.h : header file
//

#if _MSC_VER > 1000
#pragma once
#endif // _MSC_VER > 1000

/////////////////////////////////////////////////////////////////////////////
// CDlgDcamInterval dialog

class CDlgDcamInterval : public CDialog
{
// Construction
public:
	CDlgDcamInterval(CWnd* pParent = NULL);   // standard constructor

// Dialog Data
	//{{AFX_DATA(CDlgDcamInterval)
	enum { IDD = IDD_DLGDCAMINTERVAL };
	CEdit	m_ebExposure;
	CEdit	m_ebLinerate;
	CSliderCtrl	m_sliderLinerate;
	CSliderCtrl	m_sliderExposure;
	//}}AFX_DATA


// Common DCAM Dialog Data in ExCap
protected:
	BOOL		m_bCreateDialog;
	HDCAM		m_hdcam;

// Private Dialog Data
protected:
	int		m_nBlockEnchange;

	struct {
		BOOL	bAvailable;
		double	value;
		double	max, min;
		long	barmax, barmin;
	} m_exposure, m_linerate;

// Overrides
	// ClassWizard generated virtual function overrides
	//{{AFX_VIRTUAL(CDlgDcamInterval)
	public:
	virtual BOOL Create( CWnd* pParentWnd = NULL );
	protected:
	virtual void DoDataExchange(CDataExchange* pDX);    // DDX/DDV support
	//}}AFX_VIRTUAL

// Implementation

// Common implementation in ExCap
public:
			HDCAM	set_hdcam( HDCAM hdcam );
			BOOL	toggle_visible();

// Private implementation
protected:
			BOOL	GetDlgItemDbl( int nID, double& fValue );
			void	SetDlgItemDbl( int nID, double  fValue );

			void	update_values();
			void	setup_controls();
			void	update_controls();

protected:
	// Generated message map functions
	//{{AFX_MSG(CDlgDcamInterval)
	virtual BOOL OnInitDialog();
	afx_msg void OnDestroy();
	virtual void OnOK();
	virtual void OnCancel();
	afx_msg void OnHScroll(UINT nSBCode, UINT nPos, CScrollBar* pScrollBar);
	afx_msg void OnChangeDlgdcamintervalEbexposure();
	afx_msg void OnChangeDlgdcamintervalEblinerate();
	//}}AFX_MSG
	DECLARE_MESSAGE_MAP()
};

//{{AFX_INSERT_LOCATION}}
// Microsoft Visual C++ will insert additional declarations immediately before the previous line.
