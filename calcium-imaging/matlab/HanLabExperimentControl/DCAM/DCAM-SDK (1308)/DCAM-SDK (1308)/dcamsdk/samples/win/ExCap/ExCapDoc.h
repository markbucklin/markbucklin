// ExCapDoc.h : interface of the CExCapDoc class
//
/////////////////////////////////////////////////////////////////////////////

#if _MSC_VER > 1000
#pragma once
#endif // _MSC_VER > 1000


class CExCapDoc : public CDocument
{
protected: // create from serialization only
	CExCapDoc();
	DECLARE_DYNCREATE(CExCapDoc)

// Attributes
public:

protected:
	class image*	m_image;

	// related to DCAM
			HDCAM			m_hdcam;
			DCAM_DATATYPE	m_nDatatype;
			long			m_nFramecount;
			
			UINT	m_idCapturingSequence;
			BOOL	m_bBufferReady;
			long	m_nCapturedFramecount;
			long	m_nCapturedOffset;
			BOOL	m_bUseAttachBuffer;
			BOOL	m_bSupportCustomDialog;

// Operations
public:
	// for DCAM
	HDCAM	get_hdcam() const		{ return m_hdcam; }
	BOOL	start_capturing( BOOL bSequence );
	long	suspend_capturing();
	void	resume_capturing( long param );

	// for image
	image*	get_image() const		{ return m_image; }
	BOOL	is_bitmap_updated();
	BOOL	get_bitmapinfoheader( BITMAPINFOHEADER& bmih );
	long	numberof_capturedframes() const;
	long	copy_dibits( BYTE* bottomleft, const BITMAPINFOHEADER& bmih, long iFrame, long hOffset, long vOffset, RGBQUAD* rgb = NULL, const BYTE* lut = NULL );

	// for update
	void	update_datatype();

	// for notification
	enum {
		image_updated = 1,
		start_capture,
		stop_capture,
	};

// Overrides
	// ClassWizard generated virtual function overrides
	//{{AFX_VIRTUAL(CExCapDoc)
	public:
	virtual BOOL OnNewDocument();
	virtual void Serialize(CArchive& ar);
	virtual void OnCloseDocument();
	virtual BOOL OnOpenDocument(LPCTSTR lpszPathName);
	virtual BOOL OnSaveDocument(LPCTSTR lpszPathName);
	//}}AFX_VIRTUAL

// Implementation
public:
	virtual ~CExCapDoc();
#ifdef _DEBUG
	virtual void AssertValid() const;
	virtual void Dump(CDumpContext& dc) const;
#endif

// Generated message map functions
protected:
	//{{AFX_MSG(CExCapDoc)
	afx_msg void OnCaptureSequence();
	afx_msg void OnCaptureSnap();
	afx_msg void OnCaptureIdle();
	afx_msg void OnUpdateCapture(CCmdUI* pCmdUI);
	afx_msg void OnUpdateCaptureIdle(CCmdUI* pCmdUI);
	afx_msg void OnCaptureFiretrigger();
	afx_msg void OnUpdateCaptureFiretrigger(CCmdUI* pCmdUI);
	afx_msg void OnCaptureDataframes();
	afx_msg void OnUpdateCaptureDataframes(CCmdUI* pCmdUI);
	afx_msg void OnUpdateFileSaveAs(CCmdUI* pCmdUI);
	afx_msg void OnSetupCustom();
	afx_msg void OnUpdateSetupCustom(CCmdUI* pCmdUI);
	//}}AFX_MSG
	DECLARE_MESSAGE_MAP()
};

/////////////////////////////////////////////////////////////////////////////

//{{AFX_INSERT_LOCATION}}
// Microsoft Visual C++ will insert additional declarations immediately before the previous line.
