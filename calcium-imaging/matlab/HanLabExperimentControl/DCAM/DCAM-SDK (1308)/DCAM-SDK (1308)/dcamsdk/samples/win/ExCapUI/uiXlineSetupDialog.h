#if !defined(AFX_UIXLINESETUPDIALOG_H__B29AEB61_030C_427B_AC80_3498B35EFEBE__INCLUDED_)
#define AFX_UIXLINESETUPDIALOG_H__B29AEB61_030C_427B_AC80_3498B35EFEBE__INCLUDED_

#if _MSC_VER > 1000
#pragma once
#endif // _MSC_VER > 1000

// uiXlineSetupDialog.h : header file
//

#include "uiXlinePageINFO.h"
#include "uiXlinePageCOND.h"
#include "uiXlinePageDCAL.h"
#include "uiXlinePageCONF.h"
#include "uiXlinePageMASK.h"
#include "uiXlinePageACAL.h"

#include "uiXlinePageCONDTDI.h"
#include "uiXlinePageDCALDUAL.h"
#include "uiXlinePageACALDUAL.h"

//	use m_CameraType only
#define		cameratype_NONE		0
#define		cameratype_C9750	1
#define		cameratype_C10400	2
#define		cameratype_C10650	3
#define		cameratype_C10800	4

/////////////////////////////////////////////////////////////////////////////
// CuiXlineSetupDialog

class CuiXlineSetupDialog : public CPropertySheet
{
	DECLARE_DYNAMIC(CuiXlineSetupDialog)

// Construction
public:
	CuiXlineSetupDialog(CWnd* pParentWnd = NULL, UINT iSelectPage = 0);
	CuiXlineSetupDialog(UINT nIDCaption, CWnd* pParentWnd = NULL, UINT iSelectPage = 0);
	CuiXlineSetupDialog(LPCTSTR pszCaption, CWnd* pParentWnd = NULL, UINT iSelectPage = 0);

// Attributes
public:
	CuiXlinePageINFO	m_INFO;

	CuiXlinePageCOND*		p_COND;
	CuiXlinePageCONDTDI*	p_CONDTDI;

	CuiXlinePageDCAL*		p_DCAL;
	CuiXlinePageDCALDUAL*	p_DCALDUAL;
	
	CuiXlinePageCONF	m_CONF;
	CuiXlinePageMASK	m_MASK;

	CuiXlinePageACAL*		p_ACAL;
	CuiXlinePageACALDUAL*	p_ACALDUAL;

// Operations
public:
	void	set_hdcam( HDCAM hdcam );

// Overrides
	// ClassWizard generated virtual function overrides
	//{{AFX_VIRTUAL(CuiXlineSetupDialog)
	public:
	virtual BOOL OnInitDialog();
	//}}AFX_VIRTUAL

// Implementation
public:
	virtual ~CuiXlineSetupDialog();

	// Generated message map functions
protected:
	//{{AFX_MSG(CuiXlineSetupDialog)
	//}}AFX_MSG
	DECLARE_MESSAGE_MAP()

	void	addpages();

public:
	BOOL		b_M8815_0X;

	long		m_CameraType;

	long		m_ImageWidth;
	long		m_ImageHeight;

	void	getdcamparams( HDCAM hdcam );

};

/////////////////////////////////////////////////////////////////////////////

//{{AFX_INSERT_LOCATION}}
// Microsoft Visual C++ will insert additional declarations immediately before the previous line.

#endif // !defined(AFX_UIXLINESETUPDIALOG_H__B29AEB61_030C_427B_AC80_3498B35EFEBE__INCLUDED_)
