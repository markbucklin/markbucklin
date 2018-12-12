//#if !defined(AFX_UIXLINEPAGEINFO_H__8F077043_11FB_4414_9734_DAA17672B5D5__INCLUDED_)
//#define AFX_UIXLINEPAGEINFO_H__8F077043_11FB_4414_9734_DAA17672B5D5__INCLUDED_

#if _MSC_VER > 1000
#pragma once
#endif // _MSC_VER > 1000
// uiXlinePageINFO.h : header file
//

#include "ExCapUIPropertyPage.h"

/////////////////////////////////////////////////////////////////////////////
// CuiXlinePageINFO dialog

class CuiXlinePageINFO : public CExCapUIPropertyPage
{
	DECLARE_DYNCREATE(CuiXlinePageINFO)

// Construction
public:
	CuiXlinePageINFO();
	~CuiXlinePageINFO();

// Dialog Data
	//{{AFX_DATA(CuiXlinePageINFO)
	enum { IDD = IDD_XLINE_INFO };
		// NOTE - ClassWizard will add data members here.
		//    DO NOT EDIT what you see in these blocks of generated code !
	//}}AFX_DATA


// Overrides
	// ClassWizard generate virtual function overrides
	//{{AFX_VIRTUAL(CuiXlinePageINFO)
	public:
	virtual BOOL PreTranslateMessage(MSG* pMsg);
	protected:
	virtual void DoDataExchange(CDataExchange* pDX);    // DDX/DDV support
	//}}AFX_VIRTUAL

// Implementation
protected:
	// Generated message map functions
	//{{AFX_MSG(CuiXlinePageINFO)
	virtual BOOL OnInitDialog();
	//}}AFX_MSG
	DECLARE_MESSAGE_MAP()

public:
	CString		s_CameraModel;
	CString		s_CameraOption;
	CString		s_SerialNumber;
	CString		s_CameraVersion;
	double		d_PixelSize;
	double		d_PixelClock;
	long		m_BitsPerChannel;
	long		m_NumberOfPixel;

	void		getvaluefromDCAM();

	void		CheckSupportDCAMPROP();

};

//{{AFX_INSERT_LOCATION}}
// Microsoft Visual C++ will insert additional declarations immediately before the previous line.

//#endif // !defined(AFX_UIXLINEPAGEINFO_H__8F077043_11FB_4414_9734_DAA17672B5D5__INCLUDED_)
