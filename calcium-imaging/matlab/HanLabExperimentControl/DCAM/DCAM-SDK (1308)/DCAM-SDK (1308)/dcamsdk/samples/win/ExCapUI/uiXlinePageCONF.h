//#if !defined(AFX_UIXLINEPAGECONF_H__8F077043_11FB_4414_9734_DAA17672B5D5__INCLUDED_)
//#define AFX_UIXLINEPAGECONF_H__8F077043_11FB_4414_9734_DAA17672B5D5__INCLUDED_

#if _MSC_VER > 1000
#pragma once
#endif // _MSC_VER > 1000
// uiXlinePageCONF.h : header file
//

#define		NumberOfCalibRegion		0
#define		CalibRegionHPos0		1
#define		CalibRegionHPos1		2
#define		CalibRegionHPos2		3
#define		CalibRegionHPos3		4
#define		CalibRegionHSize0		5
#define		CalibRegionHSize1		6
#define		CalibRegionHSize2		7
#define		CalibRegionHSize3		8
#define		CalibRegionMode			9

#include "ExCapUIPropertyPage.h"

/////////////////////////////////////////////////////////////////////////////
// CuiXlinePageCONF dialog

class CuiXlinePageCONF : public CExCapUIPropertyPage
{
	DECLARE_DYNCREATE(CuiXlinePageCONF)

// Construction
public:
	CuiXlinePageCONF();
	~CuiXlinePageCONF();

// Dialog Data
	//{{AFX_DATA(CuiXlinePageCONF)
	enum { IDD = IDD_XLINE_CONF };
	int		m_radio;
	//}}AFX_DATA


// Overrides
	// ClassWizard generate virtual function overrides
	//{{AFX_VIRTUAL(CuiXlinePageCONF)
	public:
	virtual void OnOK();
	virtual void OnCancel();
	virtual BOOL OnApply();
	virtual BOOL PreTranslateMessage(MSG* pMsg);
	protected:
	virtual void DoDataExchange(CDataExchange* pDX);    // DDX/DDV support
	//}}AFX_VIRTUAL

// Implementation
protected:
	// Generated message map functions
	//{{AFX_MSG(CuiXlinePageCONF)
	virtual BOOL OnInitDialog();
	afx_msg void OnXlscConfCalibregionmodeAllRadio();
	afx_msg void OnXlscConfCalibregionmodeOnRadio();
	afx_msg void OnKillfocusXlscConfNumberofcalibregionEdit();
	afx_msg void OnDeltaposXlscConfNumberofcalibregionSpin(NMHDR* pNMHDR, LRESULT* pResult);
	afx_msg void OnKillfocusXlscConfCalibregionhpos0Edit();
	afx_msg void OnDeltaposXlscConfCalibregionhpos0Spin(NMHDR* pNMHDR, LRESULT* pResult);
	afx_msg void OnKillfocusXlscConfCalibregionhsize0Edit();
	afx_msg void OnDeltaposXlscConfCalibregionhsize0Spin(NMHDR* pNMHDR, LRESULT* pResult);
	afx_msg void OnKillfocusXlscConfCalibregionhpos1Edit();
	afx_msg void OnDeltaposXlscConfCalibregionhpos1Spin(NMHDR* pNMHDR, LRESULT* pResult);
	afx_msg void OnKillfocusXlscConfCalibregionhsize1Edit();
	afx_msg void OnDeltaposXlscConfCalibregionhsize1Spin(NMHDR* pNMHDR, LRESULT* pResult);
	afx_msg void OnKillfocusXlscConfCalibregionhpos2Edit();
	afx_msg void OnDeltaposXlscConfCalibregionhpos2Spin(NMHDR* pNMHDR, LRESULT* pResult);
	afx_msg void OnKillfocusXlscConfCalibregionhsize2Edit();
	afx_msg void OnDeltaposXlscConfCalibregionhsize2Spin(NMHDR* pNMHDR, LRESULT* pResult);
	afx_msg void OnKillfocusXlscConfCalibregionhpos3Edit();
	afx_msg void OnDeltaposXlscConfCalibregionhpos3Spin(NMHDR* pNMHDR, LRESULT* pResult);
	afx_msg void OnKillfocusXlscConfCalibregionhsize3Edit();
	afx_msg void OnDeltaposXlscConfCalibregionhsize3Spin(NMHDR* pNMHDR, LRESULT* pResult);
	afx_msg void OnSetfocusXlscConfNumberofcalibregionEdit();
	afx_msg void OnSetfocusXlscConfCalibregionhpos0Edit();
	afx_msg void OnSetfocusXlscConfCalibregionhsize0Edit();
	afx_msg void OnSetfocusXlscConfCalibregionhpos1Edit();
	afx_msg void OnSetfocusXlscConfCalibregionhsize1Edit();
	afx_msg void OnSetfocusXlscConfCalibregionhpos2Edit();
	afx_msg void OnSetfocusXlscConfCalibregionhsize2Edit();
	afx_msg void OnSetfocusXlscConfCalibregionhpos3Edit();
	afx_msg void OnSetfocusXlscConfCalibregionhsize3Edit();
	//}}AFX_MSG
	DECLARE_MESSAGE_MAP()

public:
	void		AddProperties();
	DWORD		dwStatusDCAM;
	void		setallenable();
	double		dHSizeMax;

};

//{{AFX_INSERT_LOCATION}}
// Microsoft Visual C++ will insert additional declarations immediately before the previous line.

//#endif // !defined(AFX_UIXLINEPAGECONF_H__8F077043_11FB_4414_9734_DAA17672B5D5__INCLUDED_)
