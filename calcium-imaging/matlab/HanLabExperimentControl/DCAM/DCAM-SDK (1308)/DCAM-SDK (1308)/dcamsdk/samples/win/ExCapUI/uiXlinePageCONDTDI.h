//#if !defined(AFX_UIXLINEPAGECONDTDI_H__8F077043_11FB_4414_9734_DAA17672B5D5__INCLUDED_)
//#define AFX_UIXLINEPAGECONDTDI_H__8F077043_11FB_4414_9734_DAA17672B5D5__INCLUDED_

#if _MSC_VER > 1000
#pragma once
#endif // _MSC_VER > 1000
// uiXlinePageCOND.h : header file
//

#define		ExposureTime			0		// [s]
#define		InternalLineSpeed		1		// [m/s]
#define		InternalLineRate		2		// [scan/s]
#define		LineBundleHeight		3		// [line]
#define		TriggerEnableActive		4		// mode
#define		OutputIntensity			5		// mode
#define		TestPatternKind			6		// mode
#define		TestPatternOption		7		// long
#define		TriggerSource			8		// mode
#define		TriggerActive			9		// mode
#define		Binning					10		// mode
#define		SensorMode				11		// mode
#define		ExposureTime_s			12		// [s]

#include "ExCapUIPropertyPage.h"
#include "afxwin.h"

/////////////////////////////////////////////////////////////////////////////
// CuiXlinePageCONDTDI dialog

class CuiXlinePageCONDTDI : public CExCapUIPropertyPage
{
	DECLARE_DYNCREATE(CuiXlinePageCONDTDI)

// Construction
public:
	CuiXlinePageCONDTDI();
	~CuiXlinePageCONDTDI();

// Dialog Data
	//{{AFX_DATA(CuiXlinePageCONDTDI)
	enum { IDD = IDD_XLINE_CONDTDI };
	CButton m_areamode;
	int		m_radio_input;
	int		m_radio_trigger;
	//}}AFX_DATA


// Overrides
	// ClassWizard generate virtual function overrides
	//{{AFX_VIRTUAL(CuiXlinePageCONDTDI)
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
	//{{AFX_MSG(CuiXlinePageCONDTDI)
	virtual BOOL OnInitDialog();
	afx_msg void OnXlscCondTriggeractiveInternalRadio();
	afx_msg void OnXlscCondTriggeractiveSyncreadoutRadio();
	afx_msg void OnXlscCondTriggeractiveEdgeRadio();
	afx_msg void OnXlscCondLinespeedRadio();
	afx_msg void OnXlscCondScanspeedRadio();
	afx_msg void OnXlscCondExposuretimeRadio();
	afx_msg void OnKillfocusXlscCondLinespeedEdit();
	afx_msg void OnDeltaposXlscCondLinespeedSpin(NMHDR* pNMHDR, LRESULT* pResult);
	afx_msg void OnKillfocusXlscCondSensordistanceEdit();
	afx_msg void OnDeltaposXlscCondSensordistanceSpin(NMHDR* pNMHDR, LRESULT* pResult);
	afx_msg void OnKillfocusXlscCondObjectdistanceEdit();
	afx_msg void OnDeltaposXlscCondObjectdistanceSpin(NMHDR* pNMHDR, LRESULT* pResult);
	afx_msg void OnKillfocusXlscCondScanspeedEdit();
	afx_msg void OnDeltaposXlscCondScanspeedSpin(NMHDR* pNMHDR, LRESULT* pResult);
	afx_msg void OnKillfocusXlscCondExposuretimeMsEdit();
	afx_msg void OnDeltaposXlscCondExposuretimeMsSpin(NMHDR* pNMHDR, LRESULT* pResult);
	afx_msg void OnKillfocusXlscCondLinebundleheightEdit();
	afx_msg void OnDeltaposXlscCondLinebundleheightSpin(NMHDR* pNMHDR, LRESULT* pResult);
	afx_msg void OnKillfocusXlscCondTestpatternoptionEdit();
	afx_msg void OnDeltaposXlscCondTestpatternoptionSpin(NMHDR* pNMHDR, LRESULT* pResult);
	afx_msg void OnBnClickedXlscCondAreamodeCheck();
	afx_msg void OnKillfocusXlscCondExposuretimeEdit2();
	afx_msg void OnDeltaposXlscCondExposuretimeSpin(NMHDR *pNMHDR, LRESULT *pResult);
	afx_msg void OnSelendokXlscCondTriggerenableactiveCombo();
	afx_msg void OnSelendokXlscCondBinningCombo();
	afx_msg void OnSelendokXlscCondOutputintensityCombo();
	afx_msg void OnSelendokXlscCondTestpatternkindCombo();
	afx_msg void OnSetfocusXlscCondLinespeedEdit();
	afx_msg void OnSetfocusXlscCondSensordistanceEdit();
	afx_msg void OnSetfocusXlscCondObjectdistanceEdit();
	afx_msg void OnSetfocusXlscCondScanspeedEdit();
	afx_msg void OnSetfocusXlscCondExposuretimeMsEdit();
	afx_msg void OnSetfocusXlscCondExposuretimeEdit2();
	afx_msg void OnSetfocusXlscCondLinebundleheightEdit();
	afx_msg void OnSetfocusXlscCondTestpatternoptionEdit();
	//}}AFX_MSG
	DECLARE_MESSAGE_MAP()

public:
	void		AddProperties();

	// ExposureTime_ms [ms]
	double		d_ExposureTime_ms;			// ET [ms]
	double		d_minExposureTime_ms;		// ET [ms] minimum
	double		d_maxExposureTime_ms;		// ET [ms] maximum
	double		d_stepExposureTime_ms;		// ET [ms] step
	DWORD		d_editExposureTime_ms;		// ET [ms] edit box ID
	DWORD		d_spinExposureTime_ms;		// ET [ms] spin button ID
	double		update_ExposureTime_ms();	// update ET[ms] from ET[s]

	// SensorDistance [m]
	double		d_SensorDistance_m;			// SensorDistance [m]
	double		d_minSensorDistance_m;		// SensorDistance [m] minimum
	double		d_maxSensorDistance_m;		// SensorDistance [m] maximum
	double		d_stepSensorDistance_m;		// SensorDistance [m] step
	DWORD		d_editSensorDistance_m;		// SensorDistance [m] edit box ID
	DWORD		d_spinSensorDistance_m;		// SensorDistance [m] spin button ID
	double		update_SensorDistance_m();	// update SensorDistance[m]

	// ObjectDistance [m]
	double		d_ObjectDistance_m;			// ObjectDistance [m]
	double		d_minObjectDistance_m;		// ObjectDistance [m] minimum
	double		d_maxObjectDistance_m;		// ObjectDistance [m] maximum
	double		d_stepObjectDistance_m;		// ObjectDistance [m] step
	DWORD		d_editObjectDistance_m;		// ObjectDistance [m] edit box ID
	DWORD		d_spinObjectDistance_m;		// ObjectDistance [m] spin button ID
	double		update_ObjectDistance_m();	// update ObjectDistance[m]

	// ConveyerSpeed [m/min]
	double		d_ConveyerSpeed_mmin;			// ConveyerSpeed [m/min]
	double		d_minConveyerSpeed_mmin;		// ConveyerSpeed [m/min] minimum
	double		d_maxConveyerSpeed_mmin;		// ConveyerSpeed [m/min] maximum
	DWORD		d_editConveyerSpeed_mmin;		// ConveyerSpeed [m/min] edit box ID
//	DWORD		d_spinConveyerSpeed_mmin;		// ConveyerSpeed [m/min] spin button ID
	double		update_ConveyerSpeed_mmin();	// update ConveyerSpeed [m/min]

	long	 	d_digitConveyerSpeed_mmin;		// ConveyerSpeed digit [m/min]
	long		update_ConveyerSpeed_mmin_digits();	// ConveyerSpeed digit [m/min]

	// InternalLineSpeed [m/min]
	double		d_InternalLineSpeed_mmin;			// InternalLineSpeed [m/min]
	DWORD		d_editInternalLineSpeed_mmin;		// InternalLineSpeed [m/min] edit box ID
	double		update_InternalLineSpeed_mmin();	// update InternalLineSpeed [m/min]

	// ExposureTime_area [s]
	double		d_ExposureTime_area;			// ET [s] for area mode
	DWORD		d_editExposureTime_disable;		// ET [s] edit box ID for area mode
	DWORD		d_spinExposureTime_disable;		// ET [s] spin button ID for area mode


	void		update_SpeedParam();			// update speed param

	int			getvaluefromDCAM_trig();
	void		setvaluetoDCAM_trig();

	void		updateenable_input();

	int			getvaluefromDCAM_area();
	void		setvaluetoDCAM_area();
	void		changecontrol_exposure();
	void		enable_radio();
	void		enable_area(BOOL bEnable);

	
};

//{{AFX_INSERT_LOCATION}}
// Microsoft Visual C++ will insert additional declarations immediately before the previous line.

//#endif // !defined(AFX_UIXLINEPAGECONDTDI_H__8F077043_11FB_4414_9734_DAA17672B5D5__INCLUDED_)
