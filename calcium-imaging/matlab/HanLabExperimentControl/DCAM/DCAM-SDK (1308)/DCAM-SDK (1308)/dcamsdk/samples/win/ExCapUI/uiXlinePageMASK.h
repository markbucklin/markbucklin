//#if !defined(AFX_UIXLINEPAGEMASK_H__8F077043_11FB_4414_9734_DAA17672B5D5__INCLUDED_)
#define AFX_UIXLINEPAGEMASK_H__8F077043_11FB_4414_9734_DAA17672B5D5__INCLUDED_

#if _MSC_VER > 1000
#pragma once
#endif // _MSC_VER > 1000
// uiXlinePageMASK.h : header file
//

#define		NumberOfMaskRegion		0
#define		MaskRegionHPos0			1
#define		MaskRegionHPos1			2
#define		MaskRegionHPos2			3
#define		MaskRegionHPos3			4
#define		MaskRegionHSize0		5
#define		MaskRegionHSize1		6
#define		MaskRegionHSize2		7
#define		MaskRegionHSize3		8
#define		MaskRegionMode			9

#define		DefectCorrectMode		10
#define		NumberOfDefectCorrect	11
#define		DefectCorrectHPos0		12
#define		DefectCorrectHPos1		13
#define		DefectCorrectHPos2		14
#define		DefectCorrectHPos3		15
#define		DefectCorrectHPos4		16
#define		DefectCorrectMethod0	17
#define		DefectCorrectMethod1	18
#define		DefectCorrectMethod2	19
#define		DefectCorrectMethod3	20
#define		DefectCorrectMethod4	21

#include "ExCapUIPropertyPage.h"

#include "uiXlineModalDEFE.h"

/////////////////////////////////////////////////////////////////////////////
// CuiXlinePageMASK dialog

class CuiXlinePageMASK : public CExCapUIPropertyPage
{
	DECLARE_DYNCREATE(CuiXlinePageMASK)

// Construction
public:
	CuiXlinePageMASK();
	~CuiXlinePageMASK();

// Dialog Data
	//{{AFX_DATA(CuiXlinePageMASK)
	enum { IDD = IDD_XLINE_MASK };
	int		m_radio;
	//}}AFX_DATA


// Overrides
	// ClassWizard generate virtual function overrides
	//{{AFX_VIRTUAL(CuiXlinePageMASK)
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
	//{{AFX_MSG(CuiXlinePageMASK)
	virtual BOOL OnInitDialog();
	afx_msg void OnDeltaposXlscMaskNumberofmaskregionSpin(NMHDR* pNMHDR, LRESULT* pResult);
	afx_msg void OnDeltaposXlscMaskMaskregionhpos0Spin(NMHDR* pNMHDR, LRESULT* pResult);
	afx_msg void OnDeltaposXlscMaskMaskregionhpos1Spin(NMHDR* pNMHDR, LRESULT* pResult);
	afx_msg void OnDeltaposXlscMaskMaskregionhpos2Spin(NMHDR* pNMHDR, LRESULT* pResult);
	afx_msg void OnDeltaposXlscMaskMaskregionhpos3Spin(NMHDR* pNMHDR, LRESULT* pResult);
	afx_msg void OnDeltaposXlscMaskMaskregionhsize0Spin(NMHDR* pNMHDR, LRESULT* pResult);
	afx_msg void OnDeltaposXlscMaskMaskregionhsize1Spin(NMHDR* pNMHDR, LRESULT* pResult);
	afx_msg void OnDeltaposXlscMaskMaskregionhsize2Spin(NMHDR* pNMHDR, LRESULT* pResult);
	afx_msg void OnDeltaposXlscMaskMaskregionhsize3Spin(NMHDR* pNMHDR, LRESULT* pResult);
	afx_msg void OnXlscMaskMaskregionmodeOffRadio();
	afx_msg void OnXlscMaskMaskregionmodeOnRadio();
	afx_msg void OnKillfocusXlscMaskNumberofmaskregionEdit();
	afx_msg void OnKillfocusXlscMaskMaskregionhpos0Edit();
	afx_msg void OnKillfocusXlscMaskMaskregionhpos1Edit();
	afx_msg void OnKillfocusXlscMaskMaskregionhpos2Edit();
	afx_msg void OnKillfocusXlscMaskMaskregionhpos3Edit();
	afx_msg void OnKillfocusXlscMaskMaskregionhsize0Edit();
	afx_msg void OnKillfocusXlscMaskMaskregionhsize1Edit();
	afx_msg void OnKillfocusXlscMaskMaskregionhsize2Edit();
	afx_msg void OnKillfocusXlscMaskMaskregionhsize3Edit();
	afx_msg void OnXlscMaskDefectcorrectButton();
	afx_msg void OnSetfocusXlscMaskNumberofmaskregionEdit();
	afx_msg void OnSetfocusXlscMaskMaskregionhpos0Edit();
	afx_msg void OnSetfocusXlscMaskMaskregionhsize0Edit();
	afx_msg void OnSetfocusXlscMaskMaskregionhpos1Edit();
	afx_msg void OnSetfocusXlscMaskMaskregionhsize1Edit();
	afx_msg void OnSetfocusXlscMaskMaskregionhpos2Edit();
	afx_msg void OnSetfocusXlscMaskMaskregionhsize2Edit();
	afx_msg void OnSetfocusXlscMaskMaskregionhpos3Edit();
	afx_msg void OnSetfocusXlscMaskMaskregionhsize3Edit();
	//}}AFX_MSG
	DECLARE_MESSAGE_MAP()

public:
	void		AddProperties();

};

//{{AFX_INSERT_LOCATION}}
// Microsoft Visual C++ will insert additional declarations immediately before the previous line.

//#endif // !defined(AFX_UIXLINEPAGEMASK_H__8F077043_11FB_4414_9734_DAA17672B5D5__INCLUDED_)
