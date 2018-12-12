// DlgDcamGeneral.h : header file
//

#if _MSC_VER > 1000
#pragma once
#endif // _MSC_VER > 1000

/////////////////////////////////////////////////////////////////////////////
// CDlgDcamGeneral dialog

class CDlgDcamGeneral : public CDialog
{
// construction
public:
	CDlgDcamGeneral(CWnd* pParent = NULL);   // standard constructor

	DWORD		m_dwCapability;

// dialog data
	//{{AFX_DATA(CDlgDcamGeneral)
	enum { IDD = IDD_DLGDCAMGENERAL };
	CEdit	m_ebExposure;
	CComboBox	m_cbTrigPol;
	CComboBox	m_cbTrigMode;
	CComboBox	m_cbBinning;
	int32		m_nBinning;
	int32		m_nTriggerMode;
	int32		m_nTriggerPolarity;
	double		m_fExposureTime;
	BOOL		m_bAutoAdjustExposureTime;
	//}}AFX_DATA

// Common DCAM Dialog Data in ExCap
protected:
	BOOL		m_bCreateDialog;
	HDCAM		m_hdcam;

// Private Dialog Data
protected:
	BOOL		m_bModifiedBinning;
	BOOL		m_bModifiedExposureTime;
	BOOL		m_bModifiedTriggerMode;
	BOOL		m_bModifiedTriggerPolarity;
	CDWordArray	m_arrayBinning;

// Override
	// virtual member
	//{{AFX_VIRTUAL(CDlgDcamGeneral)
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

			void	update_binning_capability();

protected:
	// message map
	//{{AFX_MSG(CDlgDcamGeneral)
	virtual BOOL OnInitDialog();
	afx_msg void OnDestroy();
	virtual void OnOK();
	virtual void OnCancel();
	afx_msg void OnChangeEbExposure();
	afx_msg void OnSelchangeGeneralCbBinning();
	afx_msg void OnGeneralBtnAdjustExpotime();
	afx_msg void OnSelchangeDlgdcamgeneralCbtrigmode();
	afx_msg void OnSelchangeDlgdcamgeneralCbtrigpol();
	//}}AFX_MSG
	DECLARE_MESSAGE_MAP()
};

//{{AFX_INSERT_LOCATION}}
// Microsoft Visual C++ will insert additional declarations immediately before the previous line.
