// DlgDcamScanmode.h : header file
//

#if _MSC_VER > 1000
#pragma once
#endif // _MSC_VER > 1000

/////////////////////////////////////////////////////////////////////////////
// CDlgDcamScanmode dialog

class CDlgDcamScanmode : public CDialog
{
// Construction
public:
	CDlgDcamScanmode(CWnd* pParent = NULL);   // standard constructor

// Dialog Data
	//{{AFX_DATA(CDlgDcamScanmode)
	enum { IDD = IDD_DLGDCAMSCANMODE };
	CSliderCtrl	m_slider;
	//}}AFX_DATA

// Common DCAM Dialog Data in ExCap
protected:
	BOOL	m_bCreateDialog;
	HDCAM	m_hdcam;

// Private Dialog Data
protected:
	BOOL	m_bChangingEditbox;

	struct {
		int	min, max;
		int	value;
	} m_speed;

// Overrides
	// ClassWizard generated virtual function overrides
	//{{AFX_VIRTUAL(CDlgDcamScanmode)
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
			void	update_values();
			void	setup_controls();
			void	update_controls();

// Generated message map functions
protected:
	//{{AFX_MSG(CDlgDcamScanmode)
	virtual BOOL OnInitDialog();
	afx_msg void OnHScroll(UINT nSBCode, UINT nPos, CScrollBar* pScrollBar);
	afx_msg void OnChangeEbspeed();
	afx_msg void OnDestroy();
	virtual void OnOK();
	virtual void OnCancel();
	//}}AFX_MSG
	DECLARE_MESSAGE_MAP()

};

//{{AFX_INSERT_LOCATION}}
// Microsoft Visual C++ will insert additional declarations immediately before the previous line.
