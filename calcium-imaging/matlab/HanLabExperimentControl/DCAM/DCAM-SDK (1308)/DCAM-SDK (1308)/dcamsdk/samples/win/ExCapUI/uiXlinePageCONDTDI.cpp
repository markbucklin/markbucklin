// uiXlinePageCONDTDI.cpp : implementation file
//

#include "stdafx.h"
#include "ExCapUI.h"
#include "uiXlinePageCONDTDI.h"
#include "dcamex.h"

#ifdef _DEBUG
#define new DEBUG_NEW
#undef THIS_FILE
static char THIS_FILE[] = __FILE__;
#endif

/////////////////////////////////////////////////////////////////////////////
// CuiXlinePageCONDTDI property page

IMPLEMENT_DYNCREATE(CuiXlinePageCONDTDI, CPropertyPage)

CuiXlinePageCONDTDI::CuiXlinePageCONDTDI() : CExCapUIPropertyPage(CuiXlinePageCONDTDI::IDD)
{
	//{{AFX_DATA_INIT(CuiXlinePageCONDTDI)
	m_radio_input = 1;
	m_radio_trigger = -1;
	//}}AFX_DATA_INIT

	// ExposureTime param disable (default)
	d_editExposureTime_disable			= IDC_XLINE_COND_EXPOSURETIME_EDIT2;
	d_spinExposureTime_disable			= IDC_XLINE_COND_EXPOSURETIME_SPIN;

	// ExposureTime_ms [ms]
	d_editExposureTime_ms		= IDC_XLINE_COND_EXPOSURETIME_MS_EDIT;		// ET [ms] edit box ID
	d_spinExposureTime_ms		= IDC_XLINE_COND_EXPOSURETIME_MS_SPIN;		// ET [ms] spin button ID

	// SensorDistance [m]
	d_SensorDistance_m			= 10.000;		// SensorDistance [m]
	d_minSensorDistance_m		= 0.100;		// SensorDistance [m] minimum
	d_maxSensorDistance_m		= 99.990;		// SensorDistance [m] maximum
	d_stepSensorDistance_m		= 0.010;		// SensorDistance [m] step
	d_editSensorDistance_m		= IDC_XLINE_COND_SENSORDISTANCE_EDIT;		// SensorDistance [m] edit box ID
	d_spinSensorDistance_m		= IDC_XLINE_COND_SENSORDISTANCE_SPIN;		// SensorDistance [m] spin button ID

	// ObjectDistance [m]
	d_ObjectDistance_m			= 10.000;		// ObjectDistance [m]
	d_minObjectDistance_m		= 0.100;		// ObjectDistance [m] minimum
	d_maxObjectDistance_m		= 99.990;		// ObjectDistance [m] maximum
	d_stepObjectDistance_m		= 0.010;		// ObjectDistance [m] step
	d_editObjectDistance_m		= IDC_XLINE_COND_OBJECTDISTANCE_EDIT;		// ObjectDistance [m] edit box ID
	d_spinObjectDistance_m		= IDC_XLINE_COND_OBJECTDISTANCE_SPIN;		// ObjectDistance [m] spin button ID


	// InternalLineSpeed [m/min]
	d_editInternalLineSpeed_mmin	= IDC_XLINE_COND_LINESPEED_EDIT;		// InternalLineSpeed [m/min] edit box ID
	
	// ConveyerSpeed [m/min]
	d_editConveyerSpeed_mmin	= IDC_XLINE_COND_CONVEYERSPEED_EDIT;		// ConveyerSpeed [m/min] edit box ID
	
	update_ConveyerSpeed_mmin_digits();
}

void CuiXlinePageCONDTDI::AddProperties()
{
	// ExposureTime
	AddPropertyID(DCAM_IDPROP_EXPOSURETIME);
	uipParam[ExposureTime].iEditBox		= IDC_XLINE_COND_EXPOSURETIME_EDIT;
	uipParam[ExposureTime].digits		= 6;

	// InternalLineSpeed
	AddPropertyID(DCAM_IDPROP_INTERNALLINESPEED);
	uipParam[InternalLineSpeed].iEditBox	= IDC_XLINE_COND_LINESPEED_MS_EDIT;
	uipParam[InternalLineSpeed].iSpin		= IDC_XLINE_COND_LINESPEED_SPIN;
	uipParam[InternalLineSpeed].digits		= 6;

	// InternalLineRate
	AddPropertyID(DCAM_IDPROP_INTERNALLINERATE);
	uipParam[InternalLineRate].iEditBox	= IDC_XLINE_COND_SCANSPEED_EDIT;
	uipParam[InternalLineRate].iSpin	= IDC_XLINE_COND_SCANSPEED_SPIN;
	uipParam[InternalLineRate].digits	= 3;

	// LineBundleHeight
	AddPropertyID(DCAM_IDPROP_SENSORMODE_LINEBUNDLEHEIGHT);
	uipParam[LineBundleHeight].iEditBox	= IDC_XLINE_COND_LINEBUNDLEHEIGHT_EDIT;
	uipParam[LineBundleHeight].iSpin		= IDC_XLINE_COND_LINEBUNDLEHEIGHT_SPIN;

	// TriggerEnableActive
	//AddPropertyID(DCAM_IDPROP_TRIGGER_ENABLE);
	AddPropertyID(DCAM_IDPROP_TRIGGERENABLE_ACTIVE);
	uipParam[TriggerEnableActive].iComboBox		= IDC_XLINE_COND_TRIGGERENABLEACTIVE_COMBO;

	// OutputIntensity
	AddPropertyID(DCAM_IDPROP_OUTPUT_INTENSITY);
	uipParam[OutputIntensity].iComboBox		= IDC_XLINE_COND_OUTPUTINTENSITY_COMBO;
	
	// TestPatternKind
	AddPropertyID(DCAM_IDPROP_TESTPATTERN_KIND);
	uipParam[TestPatternKind].iComboBox		= IDC_XLINE_COND_TESTPATTERNKIND_COMBO;

	// TestPatternOption
	AddPropertyID(DCAM_IDPROP_TESTPATTERN_OPTION);
	uipParam[TestPatternOption].iEditBox	= IDC_XLINE_COND_TESTPATTERNOPTION_EDIT;
	uipParam[TestPatternOption].iSpin		= IDC_XLINE_COND_TESTPATTERNOPTION_SPIN;

	// TriggerSource
	AddPropertyID(DCAM_IDPROP_TRIGGERSOURCE);

	// TriggerActive
	AddPropertyID(DCAM_IDPROP_TRIGGERACTIVE);

	// Binning
	AddPropertyID(DCAM_IDPROP_BINNING);
	uipParam[Binning].iComboBox	= IDC_XLINE_COND_BINNING_COMBO;

	// SensorMode
	AddPropertyID(DCAM_IDPROP_SENSORMODE);

}

CuiXlinePageCONDTDI::~CuiXlinePageCONDTDI()
{
}

void CuiXlinePageCONDTDI::DoDataExchange(CDataExchange* pDX)
{
	CPropertyPage::DoDataExchange(pDX);
	//{{AFX_DATA_MAP(CuiXlinePageCONDTDI)
	DDX_Radio(pDX, IDC_XLINE_COND_LINESPEED_RADIO, m_radio_input);
	DDX_Radio(pDX, IDC_XLINE_COND_TRIGGERACTIVE_INTERNAL_RADIO, m_radio_trigger);
	//}}AFX_DATA_MAP

	//	DCAMDDX_DCAM_REAL(pDX, IDC_DLGDCAMABOUT_EDITEXPOSURETIME, IDC_DLGDCAMABOUT_SPINEXPOSURETIME, m_hdcam, DCAM_IDPROP_EXPOSURETIME );
	DDX_Control(pDX, IDC_XLINE_COND_AREAMODE_CHECK, m_areamode);
}

int CuiXlinePageCONDTDI::getvaluefromDCAM_trig()
{
	int		nRadio;

	// SensorMode
	int		nIDSensorMode = SensorMode;
	if(uipParam[nIDSensorMode].value == DCAMPROP_SENSORMODE__TDI)
	{
		// TriggerSource
		int		nIDSource = TriggerSource;
		if(uipParam[nIDSource].value == DCAMPROP_TRIGGERSOURCE__INTERNAL)
		{
			nRadio = 0;
		}
		else if(uipParam[nIDSource].value == DCAMPROP_TRIGGERSOURCE__EXTERNAL)
		{
			// TriggerActive
			if(uipParam[TriggerActive].value == DCAMPROP_TRIGGERACTIVE__PULSE)
			{
				nRadio = 1;
			}
			else if(uipParam[TriggerActive].value == DCAMPROP_TRIGGERACTIVE__EDGE)
			{
				nRadio = 2;
			}
			else		// error
			{
				nRadio = -1;
			}
		}
		else			// error
		{
			nRadio = -1;
		}
	}
	else if(uipParam[nIDSensorMode].value == DCAMPROP_SENSORMODE__AREA)
	{
		nRadio = 0;
	}
	else
	{	// error
		nRadio = -1;
	}
	m_radio_trigger = nRadio;


	return nRadio;
}

void CuiXlinePageCONDTDI::setvaluetoDCAM_trig()
{
	BOOL	bRetSource;
	BOOL	bRetActive;
	
	UpdateData();

	if(m_radio_trigger == 0)
	{
		// TriggerSource(internal)
		bRetSource = setvaluetoDCAM(uipParam[TriggerSource].attr.iProp, DCAMPROP_TRIGGERSOURCE__INTERNAL);
	}
	else if(m_radio_trigger == 1)
	{
		// TriggerSource(external)
		bRetSource = setvaluetoDCAM(uipParam[TriggerSource].attr.iProp, DCAMPROP_TRIGGERSOURCE__EXTERNAL);
		
		// TriggerActive(pulse=syncreadout)
		bRetActive = setvaluetoDCAM(uipParam[TriggerActive].attr.iProp, DCAMPROP_TRIGGERACTIVE__PULSE);
	}
	else if(m_radio_trigger == 2)
	{
		// TriggerSource(external)
		bRetSource = setvaluetoDCAM(uipParam[TriggerSource].attr.iProp, DCAMPROP_TRIGGERSOURCE__EXTERNAL);

		// TriggerActive(edge)
		bRetActive = setvaluetoDCAM(uipParam[TriggerActive].attr.iProp, DCAMPROP_TRIGGERACTIVE__EDGE);
	}

}


void CuiXlinePageCONDTDI::updateenable_input()
{
	CWnd*	pWnd;
	BOOL	bEnable;
	int		nID;

	if(uipParam[SensorMode].value == DCAMPROP_SENSORMODE__AREA)
	{
		bEnable = FALSE;
	}
	else if(	uipParam[SensorMode].value != DCAMPROP_SENSORMODE__AREA
			&& (m_radio_trigger == 0	|| m_radio_trigger == 2) 
			&&	m_radio_input == 0									)
	{
		bEnable = TRUE;
	}
	else
	{
		bEnable = FALSE;
	}
	// ConveyerSpeed [m/min]
	pWnd = GetDlgItem(d_editConveyerSpeed_mmin);
	pWnd->EnableWindow(bEnable);
//	pWnd = GetDlgItem(d_spinConveyerSpeed_mmin);
//	pWnd->EnableWindow(bEnable);
	// ObjectDistance [m]
	pWnd = GetDlgItem(d_editObjectDistance_m);
	pWnd->EnableWindow(bEnable);
	pWnd = GetDlgItem(d_spinObjectDistance_m);
	pWnd->EnableWindow(bEnable);
	// SensorDistance [m]
	pWnd = GetDlgItem(d_editSensorDistance_m);
	pWnd->EnableWindow(bEnable);
	pWnd = GetDlgItem(d_spinSensorDistance_m);
	pWnd->EnableWindow(bEnable);
	// InternalLineSpeed [m/min]
	pWnd = GetDlgItem(d_editInternalLineSpeed_mmin);
	pWnd->EnableWindow(bEnable);


	if(uipParam[SensorMode].value == DCAMPROP_SENSORMODE__AREA)
	{
		bEnable = FALSE;
	}
	else if(	uipParam[SensorMode].value != DCAMPROP_SENSORMODE__AREA
			&& (m_radio_trigger == 0	|| m_radio_trigger == 2) 
			&&	m_radio_input == 0									)
	{
		bEnable = TRUE;
	}
	else
	{
		bEnable = FALSE;
	}
	// InternalLineSpeed[m/s]
	nID = InternalLineSpeed;
	pWnd = GetDlgItem(uipParam[nID].iEditBox);
	pWnd->EnableWindow(bEnable);
	pWnd = GetDlgItem(uipParam[nID].iSpin);
	pWnd->EnableWindow(bEnable);


	if(uipParam[SensorMode].value == DCAMPROP_SENSORMODE__AREA)
	{
		bEnable = FALSE;
	}
	else if(	uipParam[SensorMode].value != DCAMPROP_SENSORMODE__AREA
			&& (m_radio_trigger == 0	|| m_radio_trigger == 2) 
			&&	m_radio_input == 1									)
	{
		bEnable = TRUE;
	}
	else
	{
		bEnable = FALSE;
	}
	// InternalLineRate
	nID = InternalLineRate;
	pWnd = GetDlgItem(uipParam[nID].iEditBox);
	pWnd->EnableWindow(bEnable);
	pWnd = GetDlgItem(uipParam[nID].iSpin);
	pWnd->EnableWindow(bEnable);


	BOOL	bEnableExposureTimeTDI,bEnableExposureTimeTDI_ms;
	BOOL	bEnableExposureTimeAREA;
	if(uipParam[SensorMode].value == DCAMPROP_SENSORMODE__AREA)
	{
		bEnableExposureTimeAREA		= TRUE;
		bEnableExposureTimeTDI		= FALSE;
		bEnableExposureTimeTDI_ms	= FALSE;
	}
	else if(	uipParam[SensorMode].value != DCAMPROP_SENSORMODE__AREA
			&&	(m_radio_trigger == 0	|| m_radio_trigger == 2) 
			&&	m_radio_input == 2									)
	{
		bEnableExposureTimeAREA		= FALSE;
		bEnableExposureTimeTDI		= TRUE;
		bEnableExposureTimeTDI_ms	= TRUE;
	}
	else
	{
		bEnableExposureTimeAREA		= FALSE;
		bEnableExposureTimeTDI		= FALSE;
		bEnableExposureTimeTDI_ms	= FALSE;
	}
	// ExposureTime_ms [ms]
	pWnd = GetDlgItem(d_editExposureTime_ms);
	pWnd->EnableWindow(bEnableExposureTimeTDI_ms);
	pWnd = GetDlgItem(d_spinExposureTime_ms);
	pWnd->EnableWindow(bEnableExposureTimeTDI_ms);
	// ExposureTime
	if(uipParam[SensorMode].value == DCAMPROP_SENSORMODE__AREA)
	{
		// for area mode
		nID = ExposureTime;
		pWnd = GetDlgItem(uipParam[nID].iEditBox);
		pWnd->EnableWindow(bEnableExposureTimeAREA);
		pWnd = GetDlgItem(uipParam[nID].iSpin);
		pWnd->EnableWindow(bEnableExposureTimeAREA);

		// for TDI mode
		pWnd = GetDlgItem(d_editExposureTime_disable);
		pWnd->EnableWindow(bEnableExposureTimeTDI);
	}
	else
	{
		// for area mode
		pWnd = GetDlgItem(d_editExposureTime_disable);
		pWnd->EnableWindow(bEnableExposureTimeAREA);
		pWnd = GetDlgItem(d_spinExposureTime_disable);
		pWnd->EnableWindow(bEnableExposureTimeAREA);

		// for TDI mode
		nID = ExposureTime;
		pWnd = GetDlgItem(uipParam[nID].iEditBox);
		pWnd->EnableWindow(bEnableExposureTimeTDI);
	}
	
}


// update ET[ms] from ET[s]
double CuiXlinePageCONDTDI::update_ExposureTime_ms()
{
	// ExposureTime
	int		nID		= ExposureTime;
	DWORD	dwEdit	= d_editExposureTime_ms;
	DWORD	dwSpin	= d_spinExposureTime_ms;

	d_minExposureTime_ms	= uipParam[nID].attr.valuemin * 1000;
	d_maxExposureTime_ms	= uipParam[nID].attr.valuemax * 1000;
	d_stepExposureTime_ms	= uipParam[nID].attr.valuestep * 1000;
	
	d_ExposureTime_ms		= uipParam[nID].value * 1000;

	CString	str;
	str.Format("%.3f",d_ExposureTime_ms);
	CEdit* pEdit = (CEdit*)GetDlgItem(dwEdit);
	pEdit->SetWindowText(str);
	
	CSpinButtonCtrl* pSpin = (CSpinButtonCtrl*)GetDlgItem(dwSpin);
	pSpin->SetRange(-1,1);
	pSpin->SetPos(0);

	return d_ExposureTime_ms;

}

// update SensorDistance[m]
double CuiXlinePageCONDTDI::update_SensorDistance_m()
{
	// SensorDistance [m]
	DWORD	dwEdit	= d_editSensorDistance_m;
	DWORD	dwSpin	= d_spinSensorDistance_m;

	CString	str;
	str.Format("%.2f",d_SensorDistance_m);
	CEdit* pEdit = (CEdit*)GetDlgItem(dwEdit);
	pEdit->SetWindowText(str);
	
	CSpinButtonCtrl* pSpin = (CSpinButtonCtrl*)GetDlgItem(dwSpin);
	pSpin->SetRange(-1,1);
	pSpin->SetPos(0);

	return d_SensorDistance_m;

}

// update ObjectDistance[m]
double CuiXlinePageCONDTDI::update_ObjectDistance_m()
{
	// ObjectDistance [m]
	DWORD	dwEdit	= d_editObjectDistance_m;
	DWORD	dwSpin	= d_spinObjectDistance_m;

	CString	str;
	str.Format("%.2f",d_ObjectDistance_m);
	CEdit* pEdit = (CEdit*)GetDlgItem(dwEdit);
	pEdit->SetWindowText(str);
	
	CSpinButtonCtrl* pSpin = (CSpinButtonCtrl*)GetDlgItem(dwSpin);
	pSpin->SetRange(-1,1);
	pSpin->SetPos(0);

	return d_ObjectDistance_m;

}

// update ConveyerSpeed [m/min]
double CuiXlinePageCONDTDI::update_ConveyerSpeed_mmin()
{
	// ConveyerSpeed [m/min]
	int		nID		= InternalLineSpeed;
	DWORD	dwEdit	= d_editConveyerSpeed_mmin;
//	DWORD	dwSpin	= d_spinConveyerSpeed_mmin;

	d_minConveyerSpeed_mmin	= uipParam[nID].attr.valuemin * 60 * d_ObjectDistance_m / d_SensorDistance_m;
	d_maxConveyerSpeed_mmin	= uipParam[nID].attr.valuemax * 60 * d_ObjectDistance_m / d_SensorDistance_m;
	
	d_ConveyerSpeed_mmin	= uipParam[nID].value * 60 * d_ObjectDistance_m / d_SensorDistance_m;

	CString	str;

	// change digit
	update_ConveyerSpeed_mmin_digits();

	// set CString
	if(d_digitConveyerSpeed_mmin == 3)
	{
		str.Format("%.3f",d_ConveyerSpeed_mmin);
	}
	else if(d_digitConveyerSpeed_mmin == 4)
	{
		str.Format("%.4f",d_ConveyerSpeed_mmin);
	}
	else if(d_digitConveyerSpeed_mmin == 5)
	{
		str.Format("%.5f",d_ConveyerSpeed_mmin);
	}
	else if(d_digitConveyerSpeed_mmin == 6)
	{
		str.Format("%.6f",d_ConveyerSpeed_mmin);
	}
	else
	{
		str.Format("%.3f",d_ConveyerSpeed_mmin);
	}
//	str.Format("%.3f",d_ConveyerSpeed_mmin);
	CEdit* pEdit = (CEdit*)GetDlgItem(dwEdit);
	pEdit->SetWindowText(str);

//	CSpinButtonCtrl* pSpin = (CSpinButtonCtrl*)GetDlgItem(dwSpin);
//	pSpin->SetRange(-1,1);
//	pSpin->SetPos(0);

	return d_ConveyerSpeed_mmin;

}

// update InternalLineSpeed [m/min]
double CuiXlinePageCONDTDI::update_InternalLineSpeed_mmin()
{
	// InternalLineSpeed [m/min]
	int		nID		= InternalLineSpeed;
	DWORD	dwEdit	= d_editInternalLineSpeed_mmin;

	d_InternalLineSpeed_mmin		= uipParam[nID].value * 60;

	CString	str;
	str.Format("%.3f",d_InternalLineSpeed_mmin);
	CEdit* pEdit = (CEdit*)GetDlgItem(dwEdit);
	pEdit->SetWindowText(str);

	return d_InternalLineSpeed_mmin;

}

// update speed param
void CuiXlinePageCONDTDI::update_SpeedParam()
{
	update_ExposureTime_ms();
	update_SensorDistance_m();
	update_ObjectDistance_m();
	update_ConveyerSpeed_mmin();
	update_InternalLineSpeed_mmin();

}


int CuiXlinePageCONDTDI::getvaluefromDCAM_area()
{
	BOOL	bRetSensorMode;
	double	dValue;
	BOOL	bAreaMode;

    // SensorMode
	bRetSensorMode = dcam_getpropertyvalue( m_hdcam, uipParam[SensorMode].attr.iProp, &dValue );
	if(bRetSensorMode)
	{
		if(dValue == DCAMPROP_SENSORMODE__AREA)		// AREA mode
		{
			bAreaMode = TRUE;
		}
		else if(dValue == DCAMPROP_SENSORMODE__TDI)		// TDI mode
		{
			bAreaMode = FALSE;
		}
		else	// error
		{
			bAreaMode = FALSE;
		}
	}

	return bAreaMode;
}


void CuiXlinePageCONDTDI::setvaluetoDCAM_area()
{
	UpdateData();

	BOOL	bRetSensorMode;
	BOOL	bAreaMode = m_areamode.GetCheck();

    // SensorMode
	if(bAreaMode == FALSE)		// TDI mode
	{
		bRetSensorMode = setvaluetoDCAM(uipParam[SensorMode].attr.iProp, DCAMPROP_SENSORMODE__TDI);
	}
	else if(bAreaMode == TRUE)	// AREA mode
	{
		bRetSensorMode = setvaluetoDCAM(uipParam[SensorMode].attr.iProp, DCAMPROP_SENSORMODE__AREA);
	}

}

void CuiXlinePageCONDTDI::changecontrol_exposure()
{
	UpdateData();

	BOOL	bAreaMode = m_areamode.GetCheck();

	// SensorMode
	if(bAreaMode == FALSE)		// TDI mode
	{
		// ExposureTime
		uipParam[ExposureTime].iEditBox		= IDC_XLINE_COND_EXPOSURETIME_EDIT;
		uipParam[ExposureTime].iSpin		= 0;
		uipParam[ExposureTime].digits		= 6;

		// ExposureTime param disable
		d_editExposureTime_disable			= IDC_XLINE_COND_EXPOSURETIME_EDIT2;
		d_spinExposureTime_disable			= IDC_XLINE_COND_EXPOSURETIME_SPIN;
	}
	else if(bAreaMode == TRUE)	// AREA mode
	{
		// ExposureTime
		uipParam[ExposureTime].iEditBox		= IDC_XLINE_COND_EXPOSURETIME_EDIT2;
		uipParam[ExposureTime].iSpin		= IDC_XLINE_COND_EXPOSURETIME_SPIN;
		uipParam[ExposureTime].digits		= 3;

		// ExposureTime param disable
		d_editExposureTime_disable			= IDC_XLINE_COND_EXPOSURETIME_EDIT;
		d_spinExposureTime_disable			= 0;
	}

	CheckSupportDCAMPROP();

}

void CuiXlinePageCONDTDI::enable_radio()
{
	CWnd*	pWnd;
	BOOL	bAreaMode = m_areamode.GetCheck();

	if(bAreaMode == TRUE)	// Area Mode
	{
		//m_radio_trigger = 0;
		pWnd = (CWnd*)GetDlgItem(IDC_XLINE_COND_TRIGGERACTIVE_INTERNAL_RADIO);
		pWnd->EnableWindow(FALSE);
		pWnd = (CWnd*)GetDlgItem(IDC_XLINE_COND_TRIGGERACTIVE_SYNCREADOUT_RADIO);
		pWnd->EnableWindow(FALSE);
		pWnd = (CWnd*)GetDlgItem(IDC_XLINE_COND_TRIGGERACTIVE_EDGE_RADIO);
		pWnd->EnableWindow(FALSE);

		//m_radio_input = 2;
		pWnd = (CWnd*)GetDlgItem(IDC_XLINE_COND_LINESPEED_RADIO);
		pWnd->EnableWindow(FALSE);
		pWnd = (CWnd*)GetDlgItem(IDC_XLINE_COND_SCANSPEED_RADIO);
		pWnd->EnableWindow(FALSE);
		pWnd = (CWnd*)GetDlgItem(IDC_XLINE_COND_EXPOSURETIME_RADIO);
		pWnd->EnableWindow(FALSE);
	}
	else if(bAreaMode == FALSE)	// TDI Mode
	{
		pWnd = (CWnd*)GetDlgItem(IDC_XLINE_COND_TRIGGERACTIVE_INTERNAL_RADIO);
		pWnd->EnableWindow(TRUE);
		pWnd = (CWnd*)GetDlgItem(IDC_XLINE_COND_TRIGGERACTIVE_SYNCREADOUT_RADIO);
		pWnd->EnableWindow(TRUE);
		pWnd = (CWnd*)GetDlgItem(IDC_XLINE_COND_TRIGGERACTIVE_EDGE_RADIO);
		pWnd->EnableWindow(TRUE);

		//m_radio_input = 2;
		pWnd = (CWnd*)GetDlgItem(IDC_XLINE_COND_LINESPEED_RADIO);
		pWnd->EnableWindow(TRUE);
		pWnd = (CWnd*)GetDlgItem(IDC_XLINE_COND_SCANSPEED_RADIO);
		pWnd->EnableWindow(TRUE);
		pWnd = (CWnd*)GetDlgItem(IDC_XLINE_COND_EXPOSURETIME_RADIO);
		pWnd->EnableWindow(TRUE);
	}

}

void CuiXlinePageCONDTDI::enable_area(BOOL bEnable)
{
	CWnd* pWnd = (CWnd*)GetDlgItem(IDC_XLINE_COND_AREAMODE_CHECK);
	pWnd->EnableWindow(bEnable);
}


BEGIN_MESSAGE_MAP(CuiXlinePageCONDTDI, CPropertyPage)
	//{{AFX_MSG_MAP(CuiXlinePageCONDTDI)
	ON_BN_CLICKED(IDC_XLINE_COND_TRIGGERACTIVE_INTERNAL_RADIO, OnXlscCondTriggeractiveInternalRadio)
	ON_BN_CLICKED(IDC_XLINE_COND_TRIGGERACTIVE_SYNCREADOUT_RADIO, OnXlscCondTriggeractiveSyncreadoutRadio)
	ON_BN_CLICKED(IDC_XLINE_COND_TRIGGERACTIVE_EDGE_RADIO, OnXlscCondTriggeractiveEdgeRadio)
	ON_BN_CLICKED(IDC_XLINE_COND_LINESPEED_RADIO, OnXlscCondLinespeedRadio)
	ON_BN_CLICKED(IDC_XLINE_COND_SCANSPEED_RADIO, OnXlscCondScanspeedRadio)
	ON_BN_CLICKED(IDC_XLINE_COND_EXPOSURETIME_RADIO, OnXlscCondExposuretimeRadio)
	ON_EN_KILLFOCUS(IDC_XLINE_COND_LINESPEED_MS_EDIT, OnKillfocusXlscCondLinespeedEdit)
	ON_NOTIFY(UDN_DELTAPOS, IDC_XLINE_COND_LINESPEED_SPIN, OnDeltaposXlscCondLinespeedSpin)
	ON_EN_KILLFOCUS(IDC_XLINE_COND_SENSORDISTANCE_EDIT, OnKillfocusXlscCondSensordistanceEdit)
	ON_NOTIFY(UDN_DELTAPOS, IDC_XLINE_COND_SENSORDISTANCE_SPIN, OnDeltaposXlscCondSensordistanceSpin)
	ON_EN_KILLFOCUS(IDC_XLINE_COND_OBJECTDISTANCE_EDIT, OnKillfocusXlscCondObjectdistanceEdit)
	ON_NOTIFY(UDN_DELTAPOS, IDC_XLINE_COND_OBJECTDISTANCE_SPIN, OnDeltaposXlscCondObjectdistanceSpin)
	ON_EN_KILLFOCUS(IDC_XLINE_COND_SCANSPEED_EDIT, OnKillfocusXlscCondScanspeedEdit)
	ON_NOTIFY(UDN_DELTAPOS, IDC_XLINE_COND_SCANSPEED_SPIN, OnDeltaposXlscCondScanspeedSpin)
	ON_EN_KILLFOCUS(IDC_XLINE_COND_EXPOSURETIME_MS_EDIT, OnKillfocusXlscCondExposuretimeMsEdit)
	ON_NOTIFY(UDN_DELTAPOS, IDC_XLINE_COND_EXPOSURETIME_MS_SPIN, OnDeltaposXlscCondExposuretimeMsSpin)
	ON_EN_KILLFOCUS(IDC_XLINE_COND_LINEBUNDLEHEIGHT_EDIT, OnKillfocusXlscCondLinebundleheightEdit)
	ON_NOTIFY(UDN_DELTAPOS, IDC_XLINE_COND_LINEBUNDLEHEIGHT_SPIN, OnDeltaposXlscCondLinebundleheightSpin)
	ON_EN_KILLFOCUS(IDC_XLINE_COND_TESTPATTERNOPTION_EDIT, OnKillfocusXlscCondTestpatternoptionEdit)
	ON_NOTIFY(UDN_DELTAPOS, IDC_XLINE_COND_TESTPATTERNOPTION_SPIN, OnDeltaposXlscCondTestpatternoptionSpin)
	ON_BN_CLICKED(IDC_XLINE_COND_AREAMODE_CHECK, OnBnClickedXlscCondAreamodeCheck)
	ON_EN_KILLFOCUS(IDC_XLINE_COND_EXPOSURETIME_EDIT2, OnKillfocusXlscCondExposuretimeEdit2)
	ON_NOTIFY(UDN_DELTAPOS, IDC_XLINE_COND_EXPOSURETIME_SPIN, OnDeltaposXlscCondExposuretimeSpin)
	ON_CBN_SELENDOK(IDC_XLINE_COND_TRIGGERENABLEACTIVE_COMBO, OnSelendokXlscCondTriggerenableactiveCombo)
	ON_CBN_SELENDOK(IDC_XLINE_COND_BINNING_COMBO, OnSelendokXlscCondBinningCombo)
	ON_CBN_SELENDOK(IDC_XLINE_COND_OUTPUTINTENSITY_COMBO, OnSelendokXlscCondOutputintensityCombo)
	ON_CBN_SELENDOK(IDC_XLINE_COND_TESTPATTERNKIND_COMBO, OnSelendokXlscCondTestpatternkindCombo)
	ON_EN_SETFOCUS(IDC_XLINE_COND_LINESPEED_MS_EDIT, OnSetfocusXlscCondLinespeedEdit)
	ON_EN_SETFOCUS(IDC_XLINE_COND_SENSORDISTANCE_EDIT, OnSetfocusXlscCondSensordistanceEdit)
	ON_EN_SETFOCUS(IDC_XLINE_COND_OBJECTDISTANCE_EDIT, OnSetfocusXlscCondObjectdistanceEdit)
	ON_EN_SETFOCUS(IDC_XLINE_COND_SCANSPEED_EDIT, OnSetfocusXlscCondScanspeedEdit)
	ON_EN_SETFOCUS(IDC_XLINE_COND_EXPOSURETIME_MS_EDIT, OnSetfocusXlscCondExposuretimeMsEdit)
	ON_EN_SETFOCUS(IDC_XLINE_COND_EXPOSURETIME_EDIT2, OnSetfocusXlscCondExposuretimeEdit2)
	ON_EN_SETFOCUS(IDC_XLINE_COND_LINEBUNDLEHEIGHT_EDIT, OnSetfocusXlscCondLinebundleheightEdit)
	ON_EN_SETFOCUS(IDC_XLINE_COND_TESTPATTERNOPTION_EDIT, OnSetfocusXlscCondTestpatternoptionEdit)
	//}}AFX_MSG_MAP
END_MESSAGE_MAP()

/////////////////////////////////////////////////////////////////////////////
// CuiXlinePageCONDTDI message handlers

BOOL CuiXlinePageCONDTDI::OnInitDialog() 
{
	AddProperties();

	CheckSupportDCAMPROP();

	getvaluefromDCAM_trig();

	CPropertyPage::OnInitDialog();
	
	// TODO: Add extra initialization here

	// get sensormode(SensorMode)
	if(uipParam[SensorMode].value == DCAMPROP_SENSORMODE__AREA)
	{
		m_areamode.SetCheck(TRUE);
		changecontrol_exposure();
		CheckSupportDCAMPROP();
	}

	// get binning 
	if(uipParam[Binning].value == DCAMPROP_BINNING__1)
	{
		if(m_radio_trigger != 0)
		{
			enable_area(FALSE);	
		}
		else
		{
			enable_area(TRUE);
		}
	}
	else if(uipParam[Binning].value == DCAMPROP_BINNING__2)
	{
		enable_area(FALSE);
	}


	update_SpeedParam();

	enable_radio();
	
	updateenable_input();

	
		

	return TRUE;  // return TRUE unless you set the focus to a control
	              // EXCEPTION: OCX Property Pages should return FALSE
}

void CuiXlinePageCONDTDI::OnOK() 
{
	CPropertyPage::OnOK();
}

void CuiXlinePageCONDTDI::OnCancel() 
{
	CPropertyPage::OnCancel();
}

BOOL CuiXlinePageCONDTDI::OnApply() 
{
	return CPropertyPage::OnApply();
}

void CuiXlinePageCONDTDI::OnXlscCondTriggeractiveInternalRadio() 
{
	UpdateData();

	setvaluetoDCAM_trig();
	CheckUpdateDCAMPROP();

	update_SpeedParam();

	updateenable_input();

	int		nID = Binning;
	CComboBox* pCombo = (CComboBox*)GetDlgItem(uipParam[nID].iComboBox);
	int nSelect = pCombo->GetCurSel();
	DWORD_PTR dItemData = pCombo->GetItemData(nSelect);
	double dNewValue = (double)dItemData;
	if(dNewValue == DCAMPROP_BINNING__2)	enable_area(FALSE);
	else									enable_area(TRUE);
	
}

void CuiXlinePageCONDTDI::OnXlscCondTriggeractiveSyncreadoutRadio() 
{
	UpdateData();

	setvaluetoDCAM_trig();
	CheckUpdateDCAMPROP();

	update_SpeedParam();

	updateenable_input();

	enable_area(FALSE);
	
}

void CuiXlinePageCONDTDI::OnXlscCondTriggeractiveEdgeRadio() 
{
	UpdateData();

	setvaluetoDCAM_trig();
	CheckUpdateDCAMPROP();

	update_SpeedParam();

	updateenable_input();

	enable_area(FALSE);

}

void CuiXlinePageCONDTDI::OnXlscCondLinespeedRadio() 
{
	UpdateData();

	updateenable_input();
	
}

void CuiXlinePageCONDTDI::OnXlscCondScanspeedRadio() 
{
	UpdateData();

	updateenable_input();
	
}

void CuiXlinePageCONDTDI::OnXlscCondExposuretimeRadio() 
{
	UpdateData();

	updateenable_input();
	
}

void CuiXlinePageCONDTDI::OnSetfocusXlscCondLinespeedEdit() 
{
	DWORD	dwEdit	= uipParam[InternalLineSpeed].iEditBox;
	CEdit* pEdit = (CEdit*)GetDlgItem(dwEdit);
	pEdit->GetWindowText(strModify);
}

void CuiXlinePageCONDTDI::OnKillfocusXlscCondLinespeedEdit() 
{
	// InternalLineSpeed [m/s]
	int		nID		= InternalLineSpeed;

	// get value from edit box
	CString	str;
	CEdit* pEdit = (CEdit*)GetDlgItem(uipParam[nID].iEditBox);
	pEdit->GetWindowText(str);

	// compare input
	if( ! str.Compare(strModify) )
	{
		return;
	}

	int number = str.Find(".");
	if(number > 0)
	{
		str = str.Left(number+1+6);
	}

	double value = atof(str);

	// show out of range 
	if(value < uipParam[nID].attr.valuemin || value > uipParam[nID].attr.valuemax)
	{
		seteditvalue(uipParam[nID].attr.iProp);
		showoutofrange(nID);
		pEdit->SetFocus();
		return;
	}

	// set value to DCAM
	setvaluetoDCAM(uipParam[nID].attr.iProp, value);
	updatevalue(uipParam[nID].attr.iProp);

	// show message if autorounding worked
	CString	strInput;
	CString	strOutput;
	strInput.Format("%.6f",value);
	strOutput.Format("%.6f",uipParam[nID].value);
	if(strInput != strOutput)
	{
		AfxMessageBox("AUTOROUNDING worked.",MB_OK);
		pEdit->SetFocus();
	}

	CheckUpdateDCAMPROP();

	update_SpeedParam();
	updateenable_input();

	// compare input
	pEdit->GetWindowText(strModify);
}

void CuiXlinePageCONDTDI::OnDeltaposXlscCondLinespeedSpin(NMHDR* pNMHDR, LRESULT* pResult) 
{
	NM_UPDOWN* pNMUpDown = (NM_UPDOWN*)pNMHDR;

	// InternalLineSpeed [m/min]
	int		nID		= InternalLineSpeed;
	DWORD	dwEdit	= uipParam[nID].iEditBox;

	// query
	double	value;
	BOOL	bQuery;
	value = uipParam[nID].value;
	
	if(pNMUpDown->iDelta > 0)
		bQuery = dcam_querypropertyvalue(m_hdcam,uipParam[nID].attr.iProp,&value,DCAMPROP_OPTION_NEXT);
	else
		bQuery = dcam_querypropertyvalue(m_hdcam,uipParam[nID].attr.iProp,&value,DCAMPROP_OPTION_PRIOR);
	if(!bQuery)		// out of range
	{
		*pResult = 0;
		return;
	}

	// set value to DCAM
	setvaluetoDCAM(uipParam[nID].attr.iProp, value);
	updatevalue(uipParam[nID].attr.iProp);

	CheckUpdateDCAMPROP();

	update_SpeedParam();
	updateenable_input();

	*pResult = 0;
}

void CuiXlinePageCONDTDI::OnSetfocusXlscCondSensordistanceEdit() 
{
	DWORD	dwEdit	= d_editSensorDistance_m;
	CEdit* pEdit = (CEdit*)GetDlgItem(dwEdit);
	pEdit->GetWindowText(strModify);
}

void CuiXlinePageCONDTDI::OnKillfocusXlscCondSensordistanceEdit() 
{
	// SensorDistance [m]
	int		nID		= InternalLineSpeed;
	DWORD	dwEdit	= d_editSensorDistance_m;

	// get value from edit box
	CString	str;
	CEdit* pEdit = (CEdit*)GetDlgItem(dwEdit);
	pEdit->GetWindowText(str);

	// compare input
	if( ! str.Compare(strModify) )
	{
		return;
	}

	int number = str.Find(".");
	if(number > 0)
	{
		str = str.Left(number+1+2);
	}

	double value = atof(str);

	// show out of range 
	double	min = d_minSensorDistance_m;
	double	max = d_maxSensorDistance_m;
	if(value < min || value > max)
	{
		update_SensorDistance_m();

		CString strOutofrange;
		strOutofrange.Format("Input value is out of range. Set value in range.[%.2f to %.2f]",min,max);
		AfxMessageBox(strOutofrange,MB_OK);
		
		pEdit->SetFocus();
		return;
	}


	d_SensorDistance_m = value;

	// change digit
	update_ConveyerSpeed_mmin_digits();

	update_SpeedParam();
	updateenable_input();

	// compare input
	pEdit->GetWindowText(strModify);
}

void CuiXlinePageCONDTDI::OnDeltaposXlscCondSensordistanceSpin(NMHDR* pNMHDR, LRESULT* pResult) 
{
	NM_UPDOWN* pNMUpDown = (NM_UPDOWN*)pNMHDR;

	// SensorDistance [m]
	int		nID		= InternalLineSpeed;
	DWORD	dwEdit	= d_editSensorDistance_m;

	// get value from edit box
	CString	str;
	CEdit* pEdit = (CEdit*)GetDlgItem(dwEdit);
	pEdit->GetWindowText(str);

	int number = str.Find(".");
	if(number > 0)
	{
		str = str.Left(number+1+2);
	}

	double value = atof(str);

	// change at spin and limit on min,max
	double	min		= d_minSensorDistance_m;
	double	max		= d_maxSensorDistance_m;
	double	step	= d_stepSensorDistance_m;
	value	= (pNMUpDown->iDelta > 0) ? (value + step) : (value - step);
	if(value < min)	value = min;
	if(value > max)	value = max;

	d_SensorDistance_m = value;

	// change digit
	update_ConveyerSpeed_mmin_digits();

	update_SpeedParam();
	updateenable_input();

	*pResult = 0;
}

void CuiXlinePageCONDTDI::OnSetfocusXlscCondObjectdistanceEdit() 
{
	DWORD	dwEdit	= d_editObjectDistance_m;
	CEdit* pEdit = (CEdit*)GetDlgItem(dwEdit);
	pEdit->GetWindowText(strModify);
}

void CuiXlinePageCONDTDI::OnKillfocusXlscCondObjectdistanceEdit() 
{
	// ObjectDistance [m]
	int		nID		= InternalLineSpeed;
	DWORD	dwEdit	= d_editObjectDistance_m;

	// get value from edit box
	CString	str;
	CEdit* pEdit = (CEdit*)GetDlgItem(dwEdit);
	pEdit->GetWindowText(str);

	// compare input
	if( ! str.Compare(strModify) )
	{
		return;
	}

	int number = str.Find(".");
	if(number > 0)
	{
		str = str.Left(number+1+2);
	}

	double value = atof(str);

	// show out of range 
	double	min = d_minObjectDistance_m;
	double	max = d_maxObjectDistance_m;
	if(value < min || value > max)
	{
		update_ObjectDistance_m();

		CString strOutofrange;
		strOutofrange.Format("Input value is out of range. Set value in range.[%.2f to %.2f]",min,max);
		AfxMessageBox(strOutofrange,MB_OK);
		
		pEdit->SetFocus();
		return;
	}

	d_ObjectDistance_m = value;

	// change digit
	update_ConveyerSpeed_mmin_digits();

	update_SpeedParam();
	updateenable_input();

	// compare input
	pEdit->GetWindowText(strModify);

}

void CuiXlinePageCONDTDI::OnDeltaposXlscCondObjectdistanceSpin(NMHDR* pNMHDR, LRESULT* pResult) 
{
	NM_UPDOWN* pNMUpDown = (NM_UPDOWN*)pNMHDR;

	// ObjectDistance [m]
	int		nID		= InternalLineSpeed;
	DWORD	dwEdit	= d_editObjectDistance_m;

	// get value from edit box
	CString	str;
	CEdit* pEdit = (CEdit*)GetDlgItem(dwEdit);
	pEdit->GetWindowText(str);

	int number = str.Find(".");
	if(number > 0)
	{
		str = str.Left(number+1+2);
	}

	double value = atof(str);

	// change at spin and limit on min,max
	double	min		= d_minObjectDistance_m;
	double	max		= d_maxObjectDistance_m;
	double	step	= d_stepObjectDistance_m;
	value	= (pNMUpDown->iDelta > 0) ? (value + step) : (value - step);
	if(value < min)	value = min;
	if(value > max)	value = max;

	d_ObjectDistance_m = value;

	// change digit
	update_ConveyerSpeed_mmin_digits();

	update_SpeedParam();
	updateenable_input();

	*pResult = 0;
}

void CuiXlinePageCONDTDI::OnSetfocusXlscCondScanspeedEdit() 
{
	DWORD	dwEdit	= uipParam[InternalLineRate].iEditBox;
	CEdit* pEdit = (CEdit*)GetDlgItem(dwEdit);
	pEdit->GetWindowText(strModify);
	
}

void CuiXlinePageCONDTDI::OnKillfocusXlscCondScanspeedEdit() 
{
	int		nID = InternalLineRate;
	CString	str;
	double	dNewValue;

	CEdit*	pEdit = (CEdit*)GetDlgItem(uipParam[nID].iEditBox);
	pEdit->GetWindowText(str);

	// compare input
	if( ! str.Compare(strModify) )
	{
		return;
	}

	int number = str.Find(".");
	if(number > 0)
	{
		str = str.Left(number+1+3);
	}

	dNewValue = atof(str);

	if(dNewValue < uipParam[nID].attr.valuemin || dNewValue > uipParam[nID].attr.valuemax)
	{
		seteditvalue(uipParam[nID].attr.iProp);
		showoutofrange(nID);
		pEdit->SetFocus();
		return;
	}

	setvaluetoDCAM(uipParam[nID].attr.iProp, dNewValue);
	updatevalue(uipParam[nID].attr.iProp);

	CheckUpdateDCAMPROP();

	update_SpeedParam();
	updateenable_input();

	// compare input
	pEdit->GetWindowText(strModify);
}

void CuiXlinePageCONDTDI::OnDeltaposXlscCondScanspeedSpin(NMHDR* pNMHDR, LRESULT* pResult) 
{
	NM_UPDOWN* pNMUpDown = (NM_UPDOWN*)pNMHDR;

	int		nID = InternalLineRate;
	CString	str;
	double	dNewValue;
	double	min = uipParam[nID].attr.valuemin;
	double	max = uipParam[nID].attr.valuemax;
	double	step = uipParam[nID].attr.valuestep;

	CEdit*	pEdit = (CEdit*)GetDlgItem(uipParam[nID].iEditBox);
	pEdit->GetWindowText(str);
	dNewValue = atof(str);

	dNewValue	= (pNMUpDown->iDelta > 0) ? (dNewValue + step) : (dNewValue - step);
	if(dNewValue < min)		dNewValue = min;
	if(dNewValue > max)		dNewValue = max;


	setvaluetoDCAM(uipParam[nID].attr.iProp, dNewValue);
	updatevalue(uipParam[nID].attr.iProp);

	CheckUpdateDCAMPROP();

	update_SpeedParam();
	updateenable_input();

	*pResult = 0;
}

void CuiXlinePageCONDTDI::OnSetfocusXlscCondExposuretimeMsEdit() 
{
	DWORD	dwEdit	= d_editExposureTime_ms;
	CEdit* pEdit = (CEdit*)GetDlgItem(dwEdit);
	pEdit->GetWindowText(strModify);
}

void CuiXlinePageCONDTDI::OnKillfocusXlscCondExposuretimeMsEdit() 
{
	// ExposureTime
	int		nID		= ExposureTime;
	DWORD	dwEdit	= d_editExposureTime_ms;

	// get value from edit box
	CString	str;
	CEdit* pEdit = (CEdit*)GetDlgItem(dwEdit);
	pEdit->GetWindowText(str);

	// compare input
	if( ! str.Compare(strModify) )
	{
		return;
	}

	int number = str.Find(".");
	if(number > 0)
	{
		str = str.Left(number+1+3);
	}

	double value = atof(str);

	// show out of range 
	double	min = d_minExposureTime_ms;
	double	max = d_maxExposureTime_ms;
	if(value < min)
	{
		if(value + 0.0001 < min)
		{
			update_ExposureTime_ms();

			CString strOutofrange;
			strOutofrange.Format("Input value is out of range. Set value in range.[%.3f to %.3f]",min,max);
			AfxMessageBox(strOutofrange,MB_OK);
		
			pEdit->SetFocus();
			return;
		}
	}
	if(value > max)
	{
		if(value - 0.0001 > max)
		{

			update_ExposureTime_ms();

			CString strOutofrange;
			strOutofrange.Format("Input value is out of range. Set value in range.[%.3f to %.3f]",min,max);
			AfxMessageBox(strOutofrange,MB_OK);
			
			pEdit->SetFocus();
			return;
		}
	}

	// unit change for setting to DCAM
	value = value / 1000;

	// set value to DCAM
	setvaluetoDCAM(uipParam[nID].attr.iProp, value);
	updatevalue(uipParam[nID].attr.iProp);

	update_ExposureTime_ms();

	// show message if autorounding worked
	CString	strInput;
	CString	strOutput;
	strInput.Format("%.6f",value);
	strOutput.Format("%.6f",uipParam[nID].value);
	if(strInput != strOutput)
	{
		AfxMessageBox("AUTOROUNDING worked.",MB_OK);
		pEdit->SetFocus();
	}

	CheckUpdateDCAMPROP();

	update_SpeedParam();
	updateenable_input();

	// compare input
	pEdit->GetWindowText(strModify);
}

void CuiXlinePageCONDTDI::OnDeltaposXlscCondExposuretimeMsSpin(NMHDR* pNMHDR, LRESULT* pResult) 
{
	NM_UPDOWN* pNMUpDown = (NM_UPDOWN*)pNMHDR;

	// ExposureTime
	int		nID		= ExposureTime;
	DWORD	dwEdit	= d_editExposureTime_ms;

	// get value from edit box
	CString	str;
	CEdit* pEdit = (CEdit*)GetDlgItem(dwEdit);
	pEdit->GetWindowText(str);
	double value = atof(str);

	// change at spin and limit on min,max
	double	min		= d_minExposureTime_ms;
	double	max		= d_maxExposureTime_ms;
	double	step	= d_stepExposureTime_ms;
	value	= (pNMUpDown->iDelta > 0) ? (value + step) : (value - step);
	if(value < min)	value = min;
	if(value > max)	value = max;

	// unit change for setting to DCAM
	value = value / 1000;

	// set value to DCAM
	setvaluetoDCAM(uipParam[nID].attr.iProp, value);
	updatevalue(uipParam[nID].attr.iProp);

	update_ExposureTime_ms();

	CheckUpdateDCAMPROP();

	update_SpeedParam();
	updateenable_input();

	*pResult = 0;
}

void CuiXlinePageCONDTDI::OnSetfocusXlscCondLinebundleheightEdit() 
{
	int		nID = LineBundleHeight;
	input_on_setfocus(nID);
}

void CuiXlinePageCONDTDI::OnKillfocusXlscCondLinebundleheightEdit() 
{
	int		nID = LineBundleHeight;
	input_on_killfocus(nID);

	update_SpeedParam();
	updateenable_input();
	
}

void CuiXlinePageCONDTDI::OnDeltaposXlscCondLinebundleheightSpin(NMHDR* pNMHDR, LRESULT* pResult) 
{
	NM_UPDOWN* pNMUpDown = (NM_UPDOWN*)pNMHDR;
	
	int		nID = LineBundleHeight;
	CString	str;
	double	dNewValue;
	double	min = uipParam[nID].attr.valuemin;
	double	max = uipParam[nID].attr.valuemax;
	double	step = uipParam[nID].attr.valuestep;

	CEdit*	pEdit = (CEdit*)GetDlgItem(uipParam[nID].iEditBox);
	pEdit->GetWindowText(str);
	dNewValue = atof(str);

	dNewValue	= (pNMUpDown->iDelta > 0) ? (dNewValue + step) : (dNewValue - step);
	if(dNewValue < min)		dNewValue = min;
	if(dNewValue > max)		dNewValue = max;


	setvaluetoDCAM(uipParam[nID].attr.iProp, dNewValue);
	updatevalue(uipParam[nID].attr.iProp);

	CheckUpdateDCAMPROP();

	update_SpeedParam();

	updateenable_input();
	
	*pResult = 0;
}

void CuiXlinePageCONDTDI::OnSetfocusXlscCondTestpatternoptionEdit() 
{
	int		nID = TestPatternOption;
	input_on_setfocus(nID);	
}

void CuiXlinePageCONDTDI::OnKillfocusXlscCondTestpatternoptionEdit() 
{
	int		nID = TestPatternOption;
	input_on_killfocus(nID);

	update_SpeedParam();
	updateenable_input();
	
}

void CuiXlinePageCONDTDI::OnDeltaposXlscCondTestpatternoptionSpin(NMHDR* pNMHDR, LRESULT* pResult) 
{
	NM_UPDOWN* pNMUpDown = (NM_UPDOWN*)pNMHDR;
	
	int		nID = TestPatternOption;
	CString	str;
	double	dNewValue;
	double	min = uipParam[nID].attr.valuemin;
	double	max = uipParam[nID].attr.valuemax;
	double	step = uipParam[nID].attr.valuestep;

	CEdit*	pEdit = (CEdit*)GetDlgItem(uipParam[nID].iEditBox);
	pEdit->GetWindowText(str);
	dNewValue = atof(str);

	dNewValue	= (pNMUpDown->iDelta > 0) ? (dNewValue + step) : (dNewValue - step);
	if(dNewValue < min)		dNewValue = min;
	if(dNewValue > max)		dNewValue = max;


	setvaluetoDCAM(uipParam[nID].attr.iProp, dNewValue);
	updatevalue(uipParam[nID].attr.iProp);

	CheckUpdateDCAMPROP();

	update_SpeedParam();

	update_SpeedParam();

	updateenable_input();
	
	*pResult = 0;
}

void CuiXlinePageCONDTDI::OnBnClickedXlscCondAreamodeCheck()
{
	setvaluetoDCAM_area();

	changecontrol_exposure();

	CheckUpdateDCAMPROP();

	enable_radio();

	if(uipParam[SensorMode].value != DCAMPROP_SENSORMODE__AREA)
	{
		update_SpeedParam();
	}

	updateenable_input();

}

void CuiXlinePageCONDTDI::OnSetfocusXlscCondExposuretimeEdit2() 
{
	DWORD	dwEdit	= uipParam[ExposureTime].iEditBox;
	CEdit* pEdit = (CEdit*)GetDlgItem(dwEdit);
	pEdit->GetWindowText(strModify);

}

void CuiXlinePageCONDTDI::OnKillfocusXlscCondExposuretimeEdit2()
{
	// ExposureTime
	int		nID		= ExposureTime;
	DWORD	dwEdit	= uipParam[nID].iEditBox;

	// get value from edit box
	CString	str;
	CEdit* pEdit = (CEdit*)GetDlgItem(dwEdit);
	pEdit->GetWindowText(str);

	// compare input
	if( ! str.Compare(strModify) )
	{
		return;
	}

	int number = str.Find(".");
	if(number > 0)
	{
		str = str.Left(number+1+3);
	}

	double value = atof(str);

	// out of range
	if(value < uipParam[nID].attr.valuemin || value > uipParam[nID].attr.valuemax)
	{
		seteditvalue(uipParam[nID].attr.iProp);
		showoutofrange(nID);
		pEdit->SetFocus();
		return;
	}

	// set value to DCAM
	setvaluetoDCAM(uipParam[nID].attr.iProp, value);
	updatevalue(uipParam[nID].attr.iProp);

	// show message if autorounding worked
	CString	strInput;
	CString	strOutput;
	strInput.Format("%.3f",value);
	strOutput.Format("%.3f",uipParam[nID].value);
	if(strInput != strOutput)
	{
		AfxMessageBox("AUTOROUNDING worked.",MB_OK);
		pEdit->SetFocus();
	}

	CheckUpdateDCAMPROP();

	update_SpeedParam();

	updateenable_input();

	// compare input
	pEdit->GetWindowText(strModify);

}

void CuiXlinePageCONDTDI::OnDeltaposXlscCondExposuretimeSpin(NMHDR *pNMHDR, LRESULT *pResult)
{
	LPNMUPDOWN pNMUpDown = reinterpret_cast<LPNMUPDOWN>(pNMHDR);
	
	// ExposureTime
	int		nID		= ExposureTime;
	DWORD	dwEdit	= uipParam[nID].iEditBox;

	// get value from edit box
	CString	str;
	CEdit* pEdit = (CEdit*)GetDlgItem(dwEdit);
	pEdit->GetWindowText(str);
	double value = atof(str);

	// change at spin and limit on min,max
	double	min		= uipParam[nID].attr.valuemin;
	double	max		= uipParam[nID].attr.valuemax;
	double	step	= uipParam[nID].attr.valuestep;
	value	= (pNMUpDown->iDelta > 0) ? (value + step) : (value - step);
	if(value < min)	value = min;
	if(value > max)	value = max;

	// set value to DCAM
	setvaluetoDCAM(uipParam[nID].attr.iProp, value);
	updatevalue(uipParam[nID].attr.iProp);

	CheckUpdateDCAMPROP();

	update_SpeedParam();

	updateenable_input();

	*pResult = 0;
}

BOOL CuiXlinePageCONDTDI::PreTranslateMessage(MSG* pMsg) 
{
		if(pMsg->message == WM_KEYDOWN)
	{
		if (pMsg->wParam == VK_RETURN)
		{
			return TRUE;
		}
	}

	if(pMsg->message == WM_KEYUP)
	{
		if (pMsg->wParam == VK_RETURN)
		{
			CWnd* pWnd = (CWnd*)FromHandle(pMsg->hwnd);
			int nDlgCtrlID = pWnd->GetDlgCtrlID();
			switch(nDlgCtrlID)
			{
				case IDC_XLINE_COND_TRIGGERACTIVE_INTERNAL_RADIO:
					OnXlscCondTriggeractiveInternalRadio();
					break;
				case IDC_XLINE_COND_TRIGGERACTIVE_SYNCREADOUT_RADIO:
					OnXlscCondTriggeractiveSyncreadoutRadio();
					break;
				case IDC_XLINE_COND_TRIGGERACTIVE_EDGE_RADIO:
					OnXlscCondTriggeractiveEdgeRadio();
					break;
				case IDC_XLINE_COND_LINESPEED_RADIO:
					OnXlscCondLinespeedRadio();
					break;
				case IDC_XLINE_COND_SCANSPEED_RADIO:
					OnXlscCondScanspeedRadio();
					break;
				case IDC_XLINE_COND_EXPOSURETIME_RADIO:
					OnXlscCondExposuretimeRadio();
					break;
				case IDC_XLINE_COND_LINESPEED_MS_EDIT:
					OnKillfocusXlscCondLinespeedEdit();
					break;
				case IDC_XLINE_COND_SENSORDISTANCE_EDIT:
					OnKillfocusXlscCondSensordistanceEdit();
					break;
				case IDC_XLINE_COND_OBJECTDISTANCE_EDIT:
					OnKillfocusXlscCondObjectdistanceEdit();
					break;
				case IDC_XLINE_COND_SCANSPEED_EDIT:
					OnKillfocusXlscCondScanspeedEdit();
					break;
				case IDC_XLINE_COND_EXPOSURETIME_MS_EDIT:
					OnKillfocusXlscCondExposuretimeMsEdit();
					break;
				case IDC_XLINE_COND_TRIGGERENABLEACTIVE_COMBO:
					break;
				case IDC_XLINE_COND_BINNING_COMBO:
					break;
				case IDC_XLINE_COND_TESTPATTERNKIND_COMBO:
					break;
				case IDC_XLINE_COND_LINEBUNDLEHEIGHT_EDIT:
					OnKillfocusXlscCondLinebundleheightEdit();
					break;
				case IDC_XLINE_COND_TESTPATTERNOPTION_EDIT:
					OnKillfocusXlscCondTestpatternoptionEdit();
					break;
				case IDC_XLINE_COND_OUTPUTINTENSITY_COMBO:
					break;
				case IDC_XLINE_COND_AREAMODE_CHECK:
					OnBnClickedXlscCondAreamodeCheck();
					break;
				case IDC_XLINE_COND_EXPOSURETIME_EDIT2:
					OnKillfocusXlscCondExposuretimeEdit2();
					break;

			}
			return 0;
		}
	}
	
	return CPropertyPage::PreTranslateMessage(pMsg);
}

void CuiXlinePageCONDTDI::OnSelendokXlscCondTriggerenableactiveCombo() 
{
	// TriggerEnableActive
	int		nID = TriggerEnableActive;
	CComboBox* pCombo = (CComboBox*)GetDlgItem(uipParam[nID].iComboBox);

	int nSelect = pCombo->GetCurSel();
	DWORD_PTR dItemData = pCombo->GetItemData(nSelect);
	double dNewValue = (double)dItemData;

	setvaluetoDCAM(uipParam[nID].attr.iProp, dNewValue);

	CheckUpdateDCAMPROP();

	update_SpeedParam();

	updateenable_input();
	
}

void CuiXlinePageCONDTDI::OnSelendokXlscCondBinningCombo() 
{
	// Binning
	int		nID = Binning;
	CComboBox* pCombo = (CComboBox*)GetDlgItem(uipParam[nID].iComboBox);

	int nSelect = pCombo->GetCurSel();
	DWORD_PTR dItemData = pCombo->GetItemData(nSelect);
	double dNewValue = (double)dItemData;

	setvaluetoDCAM(uipParam[nID].attr.iProp, dNewValue);

	CheckUpdateDCAMPROP();

	// update exposure time and conveyer speed
	update_SpeedParam();
	updateenable_input();


	if(dNewValue == DCAMPROP_BINNING__2)	enable_area(FALSE);
	else
	{
		if(m_radio_trigger != 0)			enable_area(FALSE);
		else								enable_area(TRUE);
	}
	
}

void CuiXlinePageCONDTDI::OnSelendokXlscCondOutputintensityCombo() 
{
	// TestPatternKind
	int		nID = OutputIntensity;
	CComboBox* pCombo = (CComboBox*)GetDlgItem(uipParam[nID].iComboBox);

	int nSelect = pCombo->GetCurSel();
	DWORD_PTR dItemData = pCombo->GetItemData(nSelect);
	double dNewValue = (double)dItemData;

	setvaluetoDCAM(uipParam[nID].attr.iProp, dNewValue);

	CheckUpdateDCAMPROP();

	update_SpeedParam();

	updateenable_input();
	
}

void CuiXlinePageCONDTDI::OnSelendokXlscCondTestpatternkindCombo() 
{
	// TestPatternKind
	int		nID = TestPatternKind;
	CComboBox* pCombo = (CComboBox*)GetDlgItem(uipParam[nID].iComboBox);

	int nSelect = pCombo->GetCurSel();
	DWORD_PTR dItemData = pCombo->GetItemData(nSelect);
	double dNewValue = (double)dItemData;

	setvaluetoDCAM(uipParam[nID].attr.iProp, dNewValue);

	CheckUpdateDCAMPROP();

	update_SpeedParam();

	updateenable_input();
	
}

// ConveyerSpeed digit [m/min]
long CuiXlinePageCONDTDI::update_ConveyerSpeed_mmin_digits()
{
	// change digits at (d_SensorDistance_m / d_ObjectDistance_m)
	if(d_SensorDistance_m / d_ObjectDistance_m > 100.000 && d_SensorDistance_m / d_ObjectDistance_m <= 1000.000)
	{
		d_digitConveyerSpeed_mmin = 6;
	}
	else if(d_SensorDistance_m / d_ObjectDistance_m > 10.000 && d_SensorDistance_m / d_ObjectDistance_m <= 100.000)
	{
		d_digitConveyerSpeed_mmin = 5;
	}
	else if(d_SensorDistance_m / d_ObjectDistance_m > 1.000 && d_SensorDistance_m / d_ObjectDistance_m <= 10.000)
	{
		d_digitConveyerSpeed_mmin = 4;
	}
	else
	{
		d_digitConveyerSpeed_mmin = 3;
	}

	return d_digitConveyerSpeed_mmin;
}
