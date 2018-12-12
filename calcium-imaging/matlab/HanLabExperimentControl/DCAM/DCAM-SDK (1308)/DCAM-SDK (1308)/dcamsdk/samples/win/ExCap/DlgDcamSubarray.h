// DlgDcamSubarray.h : header file
//

#if _MSC_VER > 1000
#pragma once
#endif // _MSC_VER > 1000

/////////////////////////////////////////////////////////////////////////////
// CDlgDcamSubarray dialog

class CDlgDcamSubarray : public CDialog
{
// Construction
public:
	CDlgDcamSubarray(CWnd* pParent = NULL);   // standard constructor

// Dialog Data
	//{{AFX_DATA(CDlgDcamSubarray)
	enum { IDD = IDD_DLGDCAMSUBARRAY };
	long	m_nLeft;
	long	m_nTop;
	long	m_nWidth;
	long	m_nHeight;
	//}}AFX_DATA

// Common DCAM Dialog Data in ExCap
protected:
	BOOL	m_bCreateDialog;
	HDCAM	m_hdcam;

// Private Dialog Data
protected:
	long	m_hmax;
	long	m_vmax;
	long	m_hposunit;
	long	m_vposunit;
	long	m_hunit;
	long	m_vunit;

// Overrides
	// ClassWizard generated virtual function overrides
	//{{AFX_VIRTUAL(CDlgDcamSubarray)
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
			void	setup_controls();
			BOOL	update_controls();

// Generated message map functions
protected:
	//{{AFX_MSG(CDlgDcamSubarray)
	virtual BOOL OnInitDialog();
	afx_msg void OnDestroy();
	virtual void OnOK();
	virtual void OnCancel();
	//}}AFX_MSG
	DECLARE_MESSAGE_MAP()
};

//{{AFX_INSERT_LOCATION}}
// Microsoft Visual C++ will insert additional declarations immediately before the previous line.
