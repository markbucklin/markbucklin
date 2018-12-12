//#if !defined(AFX_UIXLINEPAGEDCAL_H__8F077043_11FB_4414_9734_DAA17672B5D5__INCLUDED_)
//#define AFX_UIXLINEPAGEDCAL_H__8F077043_11FB_4414_9734_DAA17672B5D5__INCLUDED_

#if _MSC_VER > 1000
#pragma once
#endif // _MSC_VER > 1000
// uiXlinePageDCAL.h : header file
//

#include "ExCapUIPropertyPage.h"

#define		ShadingCalibIntensityMaximumErrorPercentage	0
#define		ShadingCalibTarget							1
#define		ShadingCalibStableFrameCount				2
#define		ShadingCalibAverageFrameCount				3
#define		ShadingCalibMethod							4
#define		SubtractImageMemory							5
#define		ShadingCalibImageMemory						6
#define		Subtract									7
#define		DarkCalibMaximumIntensity					8
#define		ShadingCalibMinimumIntensity				9
#define		SensorModeDCAL								10


#define		ID_TIMER_GETSTATUS							1

#define		TYPE_NONE_CALIBRATION						0
#define		TYPE_DARK_CALIBRATION						1
#define		TYPE_SHADING_CALIBRATION					2
#define		TYPE_TAPGAIN_CALIBRATION					3

/////////////////////////////////////////////////////////////////////////////
// CuiXlinePageDCAL dialog

class CuiXlinePageDCAL : public CExCapUIPropertyPage
{
	DECLARE_DYNCREATE(CuiXlinePageDCAL)

// Construction
public:
	CuiXlinePageDCAL();
	~CuiXlinePageDCAL();

// Dialog Data
	//{{AFX_DATA(CuiXlinePageDCAL)
	enum { IDD = IDD_XLINE_DCAL };
		// NOTE - ClassWizard will add data members here.
		//    DO NOT EDIT what you see in these blocks of generated code !
	//}}AFX_DATA


// Overrides
	// ClassWizard generate virtual function overrides
	//{{AFX_VIRTUAL(CuiXlinePageDCAL)
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
	//{{AFX_MSG(CuiXlinePageDCAL)
	virtual BOOL OnInitDialog();
	afx_msg void OnKillfocusXlscDcalDarkcalibmaximumintensityEdit();
	afx_msg void OnKillfocusXlscDcalShadingcalibminimumintensityEdit();
	afx_msg void OnKillfocusXlscDcalShadingcalibintensitymaximumerrorpercentage();
	afx_msg void OnKillfocusXlscDcalShadingcalibcalibratetargetEdit();
	afx_msg void OnKillfocusXlscDcalShadingcalibstableframecountEdit();
	afx_msg void OnKillfocusXlscDcalShadingcalibaverageframecountEdit();
	afx_msg void OnKillfocusXlscDcalCalibratetimeoutEdit();
	afx_msg void OnDeltaposXlscDcalDarkcalibmaximumintensitySpin(NMHDR* pNMHDR, LRESULT* pResult);
	afx_msg void OnDeltaposXlscDcalShadingcalibminimumintensitySpin(NMHDR* pNMHDR, LRESULT* pResult);
	afx_msg void OnDeltaposXlscDcalShadingcalibintensitymaximumerrorpercentageS(NMHDR* pNMHDR, LRESULT* pResult);
	afx_msg void OnDeltaposXlscDcalShadingcalibcalibratetargetSpin(NMHDR* pNMHDR, LRESULT* pResult);
	afx_msg void OnDeltaposXlscDcalShadingcalibstableframecountSpin(NMHDR* pNMHDR, LRESULT* pResult);
	afx_msg void OnDeltaposXlscDcalShadingcalibaverageframecountSpin(NMHDR* pNMHDR, LRESULT* pResult);
	afx_msg void OnDeltaposXlscDcalCalibratetimeoutSpin(NMHDR* pNMHDR, LRESULT* pResult);
	afx_msg void OnXlscDcalDarkcalibdatamemoryButton();
	afx_msg void OnXlscDcalShadingcalibdatamemoryButton();
	afx_msg void OnXlscDcalStoredarkcalibdatatomemoryButton();
	afx_msg void OnXlscDcalStoreshadingcalibdatatomemoryButton();
	afx_msg void OnTimer(UINT_PTR nIDEvent);
	afx_msg void OnXlscDcalDarkcalibrationButton();
	afx_msg void OnXlscDcalShadingcalibrationButton();
	afx_msg void OnXlscDcalClearcalibrationButton();
	afx_msg void OnSelendokXlscDcalShadingcalibcalibratemethodCombo();
	afx_msg void OnSetfocusXlscDcalDarkcalibmaximumintensityEdit();
	afx_msg void OnSetfocusXlscDcalShadingcalibminimumintensityEdit();
	afx_msg void OnSetfocusXlscDcalShadingcalibintensitymaximumerrorpercentage();
	afx_msg void OnSetfocusXlscDcalShadingcalibcalibratetargetEdit();
	afx_msg void OnSetfocusXlscDcalShadingcalibstableframecountEdit();
	afx_msg void OnSetfocusXlscDcalShadingcalibaverageframecountEdit();
	//}}AFX_MSG
	DECLARE_MESSAGE_MAP()

public:
	void		AddProperties();
	long		m_CameraStatusIntensity;
	long		m_CameraStatusInputTrigger;
	long		m_CameraStatusCalibration;
	long		m_CaptureMode;

	long		m_CalibrationTimeout;
	long		m_minCalibrationTimeout;
	long		m_maxCalibrationTimeout;
	long		m_stepCalibrationTimeout;
	DWORD		m_editCalibrationTimeout;
	DWORD		m_spinCalibrationTimeout;

	long		update_CalibrationTimeout();


	void		updateStatus();

	UINT_PTR	uTimer;
	UINT		uTimerInterval;
	void		start_timer();
	void		end_timer();
	long		lTimeCounter;

	int			nCalibrating;
	BOOL		start_calibration(int CalibrattionType);
	BOOL		cancel_calibration(BOOL bUpdate = TRUE);
	BOOL		check_calibration();
	void		update_calibration();

	void		update_EnableStatus();
	
};

//{{AFX_INSERT_LOCATION}}
// Microsoft Visual C++ will insert additional declarations immediately before the previous line.

//#endif // !defined(AFX_UIXLINEPAGEDCAL_H__8F077043_11FB_4414_9734_DAA17672B5D5__INCLUDED_)
