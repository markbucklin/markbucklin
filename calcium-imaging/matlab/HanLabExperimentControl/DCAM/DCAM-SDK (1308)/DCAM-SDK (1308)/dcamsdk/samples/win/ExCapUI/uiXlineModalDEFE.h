#if !defined(AFX_UIXLINEMODALDEFE_H__5C894238_1146_4092_ABE2_76252F69C5A6__INCLUDED_)
#define AFX_UIXLINEMODALDEFE_H__5C894238_1146_4092_ABE2_76252F69C5A6__INCLUDED_

#if _MSC_VER > 1000
#pragma once
#endif // _MSC_VER > 1000
// uiXlineModalDEFE.h : header file
//

#include "ExCapUIPropertyPage.h"

/////////////////////////////////////////////////////////////////////////////
// CuiXlineModalDEFE Dialog

class CuiXlineModalDEFE : public CDialog
{
// Construction
public:
	CuiXlineModalDEFE(CWnd* pParent = NULL);

// Dialog Data
	//{{AFX_DATA(CuiXlineModalDEFE)
	enum { IDD = IDD_XLINE_DEFE };
	//}}AFX_DATA


// Overrides
	//{{AFX_VIRTUAL(CuiXlineModalDEFE)
	protected:
	virtual void DoDataExchange(CDataExchange* pDX);    // DDX/DDV Support
	//}}AFX_VIRTUAL

// Implementation
protected:

	//{{AFX_MSG(CuiXlineModalDEFE)
	virtual BOOL OnInitDialog();
	afx_msg void OnKillfocusXlscDefeDefectcorrecthpos1Edit();
	afx_msg void OnKillfocusXlscDefeDefectcorrecthpos2Edit();
	afx_msg void OnKillfocusXlscDefeDefectcorrecthpos3Edit();
	afx_msg void OnKillfocusXlscDefeDefectcorrecthpos4Edit();
	afx_msg void OnKillfocusXlscDefeDefectcorrecthpos5Edit();
	afx_msg void OnDeltaposXlscDefeDefectcorrecthpos1Spin(NMHDR* pNMHDR, LRESULT* pResult);
	afx_msg void OnDeltaposXlscDefeDefectcorrecthpos2Spin(NMHDR* pNMHDR, LRESULT* pResult);
	afx_msg void OnDeltaposXlscDefeDefectcorrecthpos3Spin(NMHDR* pNMHDR, LRESULT* pResult);
	afx_msg void OnDeltaposXlscDefeDefectcorrecthpos4Spin(NMHDR* pNMHDR, LRESULT* pResult);
	afx_msg void OnDeltaposXlscDefeDefectcorrecthpos5Spin(NMHDR* pNMHDR, LRESULT* pResult);
	afx_msg void OnXlscDefeDefectcorrecthpos1Check();
	afx_msg void OnXlscDefeDefectcorrecthpos2Check();
	afx_msg void OnXlscDefeDefectcorrecthpos3Check();
	afx_msg void OnXlscDefeDefectcorrecthpos4Check();
	afx_msg void OnXlscDefeDefectcorrecthpos5Check();
	//}}AFX_MSG
	DECLARE_MESSAGE_MAP()

public:
	EXCAP_UI_PARAM	uipDefectCorrectMode;
	EXCAP_UI_PARAM	uipNumberOfDefectCorrect;
	EXCAP_UI_PARAM	uipDefectCorrectHPos[5];
	EXCAP_UI_PARAM	uipDefectCorrectMethod[5];

	void	update_editspin();
	void	update_numberedit(BOOL first = FALSE);

	BOOL	b_checkbox[5];
	int		update_checkbox();
};

//{{AFX_INSERT_LOCATION}}
// Microsoft Visual C++ は前行の直前に追加の宣言を挿入します。

#endif // !defined(AFX_UIXLINEMODALDEFE_H__5C894238_1146_4092_ABE2_76252F69C5A6__INCLUDED_)
