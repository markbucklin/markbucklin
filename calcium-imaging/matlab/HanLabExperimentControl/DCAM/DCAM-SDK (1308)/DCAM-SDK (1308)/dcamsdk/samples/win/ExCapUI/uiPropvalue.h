#if !defined(AFX_UIPROPVALUE_H__657F2E62_4DF3_4EC3_9C99_6460FD697C10__INCLUDED_)
#define AFX_UIPROPVALUE_H__657F2E62_4DF3_4EC3_9C99_6460FD697C10__INCLUDED_

#if _MSC_VER > 1000
#pragma once
#endif // _MSC_VER > 1000

// uiPropvalue.h : header file
//

/////////////////////////////////////////////////////////////////////////////
// CuiPropvalue dialog

class CuiPropvalue : public CDialog
{
// Construction
public:
	CuiPropvalue(CWnd* pParent, UINT idEdit );   // standard constructor

protected:
// Dialog Data
	//{{AFX_DATA(CuiPropvalue)
	enum { IDD = IDD_PROPERTYVALUE };
	CSpinButtonCtrl	m_spinValue;
	CSliderCtrl	m_sliderValue;
	CString m_strValue;
	CString	m_strMax;
	CString	m_strMin;
	//}}AFX_DATA

	double	m_value;
	double	m_valuemax;
	double	m_valuemin;
	double	m_valuestep;

	UINT	m_idEdit;
	double	m_fRatioSlider;
	double	m_fOffsetSlider;

// Overrides
	// ClassWizard generated virtual function overrides
	//{{AFX_VIRTUAL(CuiPropvalue)
	protected:
	virtual void DoDataExchange(CDataExchange* pDX);    // DDX/DDV support
	//}}AFX_VIRTUAL

// Implementation
public:
	void	setvalue( double value, double valuemax, double valuemin, double valuestep );
	double	getvalue() const;

protected:

	// Generated message map functions
	//{{AFX_MSG(CuiPropvalue)
	afx_msg void OnVScroll(UINT nSBCode, UINT nPos, CScrollBar* pScrollBar);
	virtual BOOL OnInitDialog();
	//}}AFX_MSG
	DECLARE_MESSAGE_MAP()
};

//{{AFX_INSERT_LOCATION}}
// Microsoft Visual C++ will insert additional declarations immediately before the previous line.

#endif // !defined(AFX_UIVALUE_H__657F2E62_4DF3_4EC3_9C99_6460FD697C10__INCLUDED_)
