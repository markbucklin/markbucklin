//#if !defined(AFX_UIXLINEPAGEACAL_H__8F077043_11FB_4414_9734_DAA17672B5D5__INCLUDED_)
//#define AFX_UIXLINEPAGEACAL_H__8F077043_11FB_4414_9734_DAA17672B5D5__INCLUDED_

#if _MSC_VER > 1000
#pragma once
#endif // _MSC_VER > 1000
// uiXlinePageACAL.h : header file
//

#define		TapCalibMethod				0
#define		TapCalibDataMemory			1
#define		TapCalibGain				2
#define		TapCalibBaseDataMemory		3
#define		SensorModeACAL				4


#define		ID_TIMER_GETSTATUS							1

#define		TYPE_NONE_CALIBRATION						0
#define		TYPE_DARK_CALIBRATION						1
#define		TYPE_SHADING_CALIBRATION					2
#define		TYPE_TAPGAIN_CALIBRATION					3

#include "ExCapUIPropertyPage.h"

#include "uiXlineModalADJU.h"

/////////////////////////////////////////////////////////////////////////////
// CuiXlinePageACAL dialog

class CuiXlinePageACAL : public CExCapUIPropertyPage
{
	DECLARE_DYNCREATE(CuiXlinePageACAL)

// Construction
public:
	CuiXlinePageACAL();
	~CuiXlinePageACAL();

// Dialog Data
	//{{AFX_DATA(CuiXlinePageACAL)
	enum { IDD = IDD_XLINE_ACAL };
		// NOTE - ClassWizard will add data members here.
		//    DO NOT EDIT what you see in these blocks of generated code !
	//}}AFX_DATA


// Overrides
	// ClassWizard generate virtual function overrides
	//{{AFX_VIRTUAL(CuiXlinePageACAL)
	public:
	virtual void OnOK();
	virtual void OnCancel();
	virtual BOOL OnApply();
	virtual BOOL OnKillActive();
	virtual BOOL OnSetActive();
	virtual BOOL PreTranslateMessage(MSG* pMsg);
	protected:
	virtual void DoDataExchange(CDataExchange* pDX);    // DDX/DDV support
	virtual void PostNcDestroy();
	//}}AFX_VIRTUAL

// Implementation
protected:
	// Generated message map functions
	//{{AFX_MSG(CuiXlinePageACAL)
	virtual BOOL OnInitDialog();
	afx_msg void OnXlscAcalTapgaincalibrationButton();
	afx_msg void OnTimer(UINT_PTR nIDEvent);
	afx_msg void OnXlscAcalTapcalibgainEachButton();
	afx_msg void OnKillfocusXlscAcalTapcalibgainAllEdit();
	afx_msg void OnDeltaposXlscAcalTapcalibgainAllSpin(NMHDR* pNMHDR, LRESULT* pResult);
	afx_msg void OnXlscAcalTapcalibdatamemoryButton();
	afx_msg void OnXlscAcalStoretapcalibdatamemoryButton();
	afx_msg void OnXlscAcalTapcalibgainAllButton();
	afx_msg void OnSelendokXlscAcalTapcalibbasedatamemoryCombo();
	afx_msg void OnSelendokXlscAcalTapcalibmethodCombo();
	//}}AFX_MSG
	DECLARE_MESSAGE_MAP()

public:
	void		AddProperties();

	long		m_CameraStatusIntensity;
	long		m_CameraStatusInputTrigger;
	long		m_CameraStatusCalibration;
	long		m_CaptureMode;

	void		updateStatus();

	UINT_PTR	uTimer;
	UINT		uTimerInterval;
	void		start_timer();
	void		end_timer();

	int			nCalibrating;
	BOOL		start_calibration(int CalibrattionType);
	BOOL		cancel_calibration(BOOL bUpdate = TRUE);
	BOOL		check_calibration();
	void		update_calibration();

	void		update_EnableStatus();


	// for set all(all:ch0)
	double		m_gtvalue;
	double		m_gtvaluemin;
	double		m_gtvaluemax;

	BOOL		getfromDCAM_gtvalue();

	// for set each(low:ch1,high:ch2)
	double*		p_gtlow;
	double*		p_gthigh;
	long		m_gtcount;
	double		m_gtmin;
	double		m_gtmax;

	BOOL		getfromDCAM_gtvaluearray();


};

//{{AFX_INSERT_LOCATION}}
// Microsoft Visual C++ will insert additional declarations immediately before the previous line.

//#endif // !defined(AFX_UIXLINEPAGEACAL_H__8F077043_11FB_4414_9734_DAA17672B5D5__INCLUDED_)
