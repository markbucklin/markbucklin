// ExCapApp.h : interface of the CExCapApp class
//
/////////////////////////////////////////////////////////////////////////////

#if _MSC_VER > 1000
#pragma once
#endif // _MSC_VER > 1000

/////////////////////////////////////////////////////////////////////////////
// CExCapApp:
// See ExCap.cpp for the implementation of this class
//

class CExCapDoc;
class luttable;

class CExCapApp : public CWinApp
{
	DECLARE_DYNAMIC(CExCapApp)
public:
	~CExCapApp();
	CExCapApp();

// Overrides
	// ClassWizard generated virtual function overrides
	//{{AFX_VIRTUAL(CExCapApp)
	public:
	virtual BOOL InitInstance();
	virtual int ExitInstance();
	//}}AFX_VIRTUAL

protected:
	void OnUpdateSetup(CCmdUI* pCmdUI, CDialog* dlg, BOOL bAvailable = TRUE );

// Implementation
	//{{AFX_MSG(CExCapApp)
	afx_msg void OnAppAbout();
	afx_msg void OnUpdateSetupProperties(CCmdUI* pCmdUI);
	afx_msg void OnSetupProperties();
	afx_msg void OnUpdateSetupGeneral(CCmdUI* pCmdUI);
	afx_msg void OnSetupGeneral();
	afx_msg void OnUpdateSetupScanmode(CCmdUI* pCmdUI);
	afx_msg void OnSetupScanmode();
	afx_msg void OnUpdateSetupSubarray(CCmdUI* pCmdUI);
	afx_msg void OnSetupSubarray();
	afx_msg void OnUpdateSetupFeatures(CCmdUI* pCmdUI);
	afx_msg void OnSetupFeatures();
	afx_msg void OnUpdateSetupRgbratio(CCmdUI* pCmdUI);
	afx_msg void OnSetupRgbratio();
	afx_msg void OnSetupInterval();
	afx_msg void OnUpdateSetupInterval(CCmdUI* pCmdUI);
	afx_msg void OnViewLut();
	afx_msg void OnUpdateViewLut(CCmdUI* pCmdUI);
	afx_msg void OnViewFramerate();
	afx_msg void OnUpdateViewFramerate(CCmdUI* pCmdUI);
	afx_msg void OnViewStatus();
	afx_msg void OnUpdateViewStatus(CCmdUI* pCmdUI);
	//}}AFX_MSG
	DECLARE_MESSAGE_MAP()

public:
	void	get_active_objects( HDCAM& hdcam, CExCapDoc*& doc, luttable*& lut ) const;
	void	set_active_objects( HDCAM hdcam, CExCapDoc* doc, luttable* lut );
	void	update_availables();
	void	on_close_document( CExCapDoc* doc );

	long	suspend_capturing();
	void	resume_capturing( long param );

	long	number_of_visible_controldialogs();

	BOOL	query_supportdialog( HDCAM hdcam, long lparam = 0 );
	BOOL	modal_dialog( HDCAM hdcam );
	BOOL	on_open_camera( HDCAM hdcam );
	BOOL	on_close_camera( HDCAM hdcam );

	const char*	get_dcaminit_option() const;

protected:
	struct {
	HDCAM		hdcam;
	CExCapDoc*	docForHDCAM;
	luttable*	lut;
	char		cameraname[256];
	char		dcamapiver[64];
	} m_active;

	class excapuidll*	m_excapuidll;

	struct {
		char	dcaminit[256];
	} m_option;

	struct {
	class CDlgDcamProperty*		property;
	class CDlgExcapLUT*			lut;
	class CDlgExcapFramerate*	framerate;
	class CDlgExcapStatus*		status;

	class CDlgDcamGeneral*		general;
	class CDlgDcamScanmode*		scanmode;
	class CDlgDcamSubarray*		subarray;
	class CDlgDcamFeatures*		features;
	class CDlgDcamRGBRatio*		rgbratio;
	class CDlgDcamInterval*		interval;
	} m_dlg;

	struct {
	BOOL	property;
	BOOL	framerate;
	BOOL	status;

	BOOL	general;
	BOOL	scanmode;
	BOOL	subarray;
	BOOL	features;
	BOOL	rgbratio;
	BOOL	interval;
	} m_available;
};

inline CExCapApp* afxGetApp()
{
	return DYNAMIC_DOWNCAST( CExCapApp, AfxGetApp() );
}

/////////////////////////////////////////////////////////////////////////////

//{{AFX_INSERT_LOCATION}}
// Microsoft Visual C++ will insert additional declarations immediately before the previous line.
