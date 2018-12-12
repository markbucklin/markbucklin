// DlgExcapStatus.h : header file
//

#if _MSC_VER > 1000
#pragma once
#endif // _MSC_VER > 1000

/////////////////////////////////////////////////////////////////////////////
// CDlgExcapStatus dialog

class CExCapDoc;

class CDlgExcapStatus : public CDialog
{
// Construction
public:
	CDlgExcapStatus(CWnd* pParent = NULL);   // standard constructor

// Dialog Data
	//{{AFX_DATA(CDlgExcapStatus)
	enum { IDD = IDD_EXCAPSTATUS };
	CString	m_strStatus;
	CString	m_strArea;
	CString	m_strBitstype;
	CString	m_strDataframebytes;
	CString	m_strDatarange;
	CString	m_strDatatype;
	CString	m_strExposure;
	CString	m_strResolution;
	CString	m_strTrigger;
	//}}AFX_DATA

// Common DCAM Dialog Data in ExCap
protected:
	BOOL		m_bCreateDialog;
	HDCAM		m_hdcam;
	CExCapDoc*	m_doc;

// Overrides
	// ClassWizard generated virtual function overrides
	//{{AFX_VIRTUAL(CDlgExcapStatus)
	public:
	virtual BOOL Create( CWnd* pParentWnd = NULL );
	protected:
	virtual void DoDataExchange(CDataExchange* pDX);    // DDX/DDV support
	//}}AFX_VIRTUAL

// Implementation

// Common implementation of DCAM Dialog in ExCap
public:
			BOOL	toggle_visible();
			void	set_hdcamdoc( HDCAM hdcam, CExCapDoc* doc );
			BOOL	is_visible()	{ return IsWindow( GetSafeHwnd() ) && IsWindowVisible(); }

protected:
			void	update_values( BOOL bForce );
			void	update_controls();

	// Generated message map functions
	//{{AFX_MSG(CDlgExcapStatus)
	virtual BOOL OnInitDialog();
	afx_msg void OnDestroy();
	virtual void OnOK();
	virtual void OnCancel();
	afx_msg void OnTimer(UINT_PTR nIDEvent);
	//}}AFX_MSG
	DECLARE_MESSAGE_MAP()
};

//{{AFX_INSERT_LOCATION}}
// Microsoft Visual C++ will insert additional declarations immediately before the previous line.
