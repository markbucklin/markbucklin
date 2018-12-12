// uiXlinePageDCAL.cpp : implementation file
//

#include "stdafx.h"
#include "ExCapUI.h"
#include "uiXlinePageDCAL.h"
#include "dcamex.h"

#ifdef _DEBUG
#define new DEBUG_NEW
#undef THIS_FILE
static char THIS_FILE[] = __FILE__;
#endif

/////////////////////////////////////////////////////////////////////////////
// CuiXlinePageDCAL property page

IMPLEMENT_DYNCREATE(CuiXlinePageDCAL, CPropertyPage)

CuiXlinePageDCAL::CuiXlinePageDCAL() : CExCapUIPropertyPage(CuiXlinePageDCAL::IDD)
{
	//{{AFX_DATA_INIT(CuiXlinePageDCAL)
		// NOTE: the ClassWizard will add member initialization here
	//}}AFX_DATA_INIT

	nCalibrating = TYPE_NONE_CALIBRATION;

	m_CalibrationTimeout = 60;		// [s]
	m_minCalibrationTimeout = 3;
	m_maxCalibrationTimeout = 300;
	m_stepCalibrationTimeout = 1;
	m_editCalibrationTimeout = IDC_XLINE_DCAL_CALIBRATETIMEOUT_EDIT;
	m_spinCalibrationTimeout = IDC_XLINE_DCAL_CALIBRATETIMEOUT_SPIN;

	lTimeCounter = 0;

	uTimer = NULL;
	uTimerInterval = 500;	// 500[ms]

}

void CuiXlinePageDCAL::AddProperties()
{
	// ShadingCalibIntensityMaximumErrorPercentage
	AddPropertyID(DCAM_IDPROP_SHADINGCALIB_INTENSITYMAXIMUMERRORPERCENTAGE);
	uipParam[ShadingCalibIntensityMaximumErrorPercentage].iEditBox	= IDC_XLINE_DCAL_SHADINGCALIBINTENSITYMAXIMUMERRORPERCENTAGE_EDIT;
	uipParam[ShadingCalibIntensityMaximumErrorPercentage].iSpin		= IDC_XLINE_DCAL_SHADINGCALIBINTENSITYMAXIMUMERRORPERCENTAGE_SPIN;

	// ShadingCalibTarget
	AddPropertyID(DCAM_IDPROP_SHADINGCALIB_TARGET);
	uipParam[ShadingCalibTarget].iEditBox	= IDC_XLINE_DCAL_SHADINGCALIBCALIBRATETARGET_EDIT;
	uipParam[ShadingCalibTarget].iSpin		= IDC_XLINE_DCAL_SHADINGCALIBCALIBRATETARGET_SPIN;

	// ShadingCalibStableFrameCount
	AddPropertyID(DCAM_IDPROP_SHADINGCALIB_STABLEFRAMECOUNT);
	uipParam[ShadingCalibStableFrameCount].iEditBox		= IDC_XLINE_DCAL_SHADINGCALIBSTABLEFRAMECOUNT_EDIT;
	uipParam[ShadingCalibStableFrameCount].iSpin		= IDC_XLINE_DCAL_SHADINGCALIBSTABLEFRAMECOUNT_SPIN;

	// ShadingCalibAverageFrameCount
	AddPropertyID(DCAM_IDPROP_SHADINGCALIB_AVERAGEFRAMECOUNT);
	uipParam[ShadingCalibAverageFrameCount].iEditBox	= IDC_XLINE_DCAL_SHADINGCALIBAVERAGEFRAMECOUNT_EDIT;
	uipParam[ShadingCalibAverageFrameCount].iSpin		= IDC_XLINE_DCAL_SHADINGCALIBAVERAGEFRAMECOUNT_SPIN;


	// ShadingCalibMethod
	AddPropertyID(DCAM_IDPROP_SHADINGCALIB_METHOD);
	uipParam[ShadingCalibMethod].iComboBox		= IDC_XLINE_DCAL_SHADINGCALIBCALIBRATEMETHOD_COMBO;

	// SubtractImageMemory
	AddPropertyID(DCAM_IDPROP_SUBTRACTIMAGEMEMORY);
	uipParam[SubtractImageMemory].iComboBox		= IDC_XLINE_DCAL_DARKCALIBTABLE_COMBO;

	// ShadingCalibImageMemory
	AddPropertyID(DCAM_IDPROP_SHADINGCALIBDATAMEMORY);
	uipParam[ShadingCalibImageMemory].iComboBox	= IDC_XLINE_DCAL_SHADINGCALIBTABLE_COMBO;

	// Subtract
	AddPropertyID(DCAM_IDPROP_SUBTRACT);

	// DarkCalibMaximumIntensity
	AddPropertyID(DCAM_IDPROP_DARKCALIB_MAXIMUMINTENSITY);
	uipParam[DarkCalibMaximumIntensity].iEditBox	= IDC_XLINE_DCAL_DARKCALIBMAXIMUMINTENSITY_EDIT;
	uipParam[DarkCalibMaximumIntensity].iSpin		= IDC_XLINE_DCAL_DARKCALIBMAXIMUMINTENSITY_SPIN;

	// ShadingCalibMinimumIntensity
	AddPropertyID(DCAM_IDPROP_SHADINGCALIB_MINIMUMINTENSITY);
	uipParam[ShadingCalibMinimumIntensity].iEditBox	= IDC_XLINE_DCAL_SHADINGCALIBMINIMUMINTENSITY_EDIT;
	uipParam[ShadingCalibMinimumIntensity].iSpin	= IDC_XLINE_DCAL_SHADINGCALIBMINIMUMINTENSITY_SPIN;

	// SensorModeDCAL
	AddPropertyID(DCAM_IDPROP_SENSORMODE);
}

CuiXlinePageDCAL::~CuiXlinePageDCAL()
{
	end_timer();
}

void CuiXlinePageDCAL::DoDataExchange(CDataExchange* pDX)
{
	CPropertyPage::DoDataExchange(pDX);
	//{{AFX_DATA_MAP(CuiXlinePageDCAL)
		// NOTE: the ClassWizard will add DDX and DDV calls here
	//}}AFX_DATA_MAP

}

void CuiXlinePageDCAL::updateStatus()
{
	CString	str;
	double	dValue;
	char	text [1024];
	BOOL	bRet;

	/////////////////////////////////////////////////////////////////////////////////////////////////
	// Camera Status Intensity
	bRet = dcam_getpropertyvalue( m_hdcam, DCAM_IDPROP_CAMERASTATUS_INTENSITY, &dValue );

	m_CameraStatusIntensity = (long)dValue;
	DCAM_PROPERTYVALUETEXT	pvt;
		memset (& pvt, 0, sizeof (pvt));
		pvt.cbSize		= sizeof (pvt);
		pvt.iProp		= DCAM_IDPROP_CAMERASTATUS_INTENSITY;
		pvt.value		= dValue;
		pvt.text		= text;
		pvt.textbytes	= sizeof (text);
	switch(m_CameraStatusIntensity)
	{
		case DCAMPROP_CAMERASTATUS_INTENSITY__GOOD:
			dcam_getpropertyvaluetext( m_hdcam , & pvt );
			str = pvt.text;
			break;
		case DCAMPROP_CAMERASTATUS_INTENSITY__TOODARK:
			dcam_getpropertyvaluetext( m_hdcam , & pvt );
			str = pvt.text;
			break;
		case DCAMPROP_CAMERASTATUS_INTENSITY__TOOBRIGHT:
			dcam_getpropertyvaluetext( m_hdcam , & pvt );
			str = pvt.text;
			break;
		case DCAMPROP_CAMERASTATUS_INTENSITY__UNCARE:
			dcam_getpropertyvaluetext( m_hdcam , & pvt );
			str = pvt.text;
			break;
		default:
			str.Format("Status is not available.");
			break;
	}
	SetDlgItemText( IDC_XLINE_DCAL_CAMERASTATUSINTENSITY_STS_STATIC, str );
	

	// Camera Status Input Trigger
	bRet = dcam_getpropertyvalue( m_hdcam, DCAM_IDPROP_CAMERASTATUS_INPUTTRIGGER, &dValue );

	m_CameraStatusInputTrigger = (long)dValue;
		memset (& pvt, 0, sizeof (pvt));
		pvt.cbSize		= sizeof (pvt);
		pvt.iProp		= DCAM_IDPROP_CAMERASTATUS_INPUTTRIGGER;
		pvt.value		= dValue;
		pvt.text		= text;
		pvt.textbytes	= sizeof (text);
	switch(m_CameraStatusInputTrigger)
	{
		case DCAMPROP_CAMERASTATUS_INPUTTRIGGER__GOOD:
			dcam_getpropertyvaluetext( m_hdcam , & pvt );
			str = pvt.text;
			break;
		case DCAMPROP_CAMERASTATUS_INPUTTRIGGER__NONE:
			dcam_getpropertyvaluetext( m_hdcam , & pvt );
			str = pvt.text;
			break;
		case DCAMPROP_CAMERASTATUS_INPUTTRIGGER__TOOFREQUENT:
			dcam_getpropertyvaluetext( m_hdcam , & pvt );
			str = pvt.text;
			break;
		default:
			str.Format("Status is not available.");
			break;
	}
	SetDlgItemText( IDC_XLINE_DCAL_CAMERASTATUSINPUTTRIGGER_STS_STATIC, str );


	// Camera Status Calibration
	bRet = dcam_getpropertyvalue( m_hdcam, DCAM_IDPROP_CAMERASTATUS_CALIBRATION, &dValue );

	m_CameraStatusCalibration = (long)dValue;
		memset (& pvt, 0, sizeof (pvt));
		pvt.cbSize		= sizeof (pvt);
		pvt.iProp		= DCAM_IDPROP_CAMERASTATUS_CALIBRATION;
		pvt.value		= dValue;
		pvt.text		= text;
		pvt.textbytes	= sizeof (text);
	switch(m_CameraStatusCalibration)
	{
		case DCAMPROP_CAMERASTATUS_CALIBRATION__DONE:
			dcam_getpropertyvaluetext( m_hdcam , & pvt );
			str = pvt.text;
			break;
		case DCAMPROP_CAMERASTATUS_CALIBRATION__NOTYET:
			dcam_getpropertyvaluetext( m_hdcam , & pvt );
			str = pvt.text;
			break;
		case DCAMPROP_CAMERASTATUS_CALIBRATION__NOTRIGGER:
			dcam_getpropertyvaluetext( m_hdcam , & pvt );
			str = pvt.text;
			break;
		case DCAMPROP_CAMERASTATUS_CALIBRATION__TOOFREQUENTTRIGGER:
			dcam_getpropertyvaluetext( m_hdcam , & pvt );
			str = pvt.text;
			break;
		case DCAMPROP_CAMERASTATUS_CALIBRATION__OUTOFADJUSTABLERANGE:
			dcam_getpropertyvaluetext( m_hdcam , & pvt );
			str = pvt.text;
			break;
		case DCAMPROP_CAMERASTATUS_CALIBRATION__UNSUITABLETABLE:
			dcam_getpropertyvaluetext( m_hdcam , & pvt );
			str = pvt.text;
			break;
		default:
			str.Format("Status is not available.");
			break;
	}
	SetDlgItemText( IDC_XLINE_DCAL_CAMERASTATUSCALIBRATION_STS_STATIC, str );

}

void CuiXlinePageDCAL::start_timer()
{
	if(uTimer != NULL)	return;

	uTimer = SetTimer(ID_TIMER_GETSTATUS,uTimerInterval,0);
}

void CuiXlinePageDCAL::end_timer()
{
	if(uTimer != NULL)
	{
		KillTimer(uTimer);
		uTimer = NULL;
	}

}

long CuiXlinePageDCAL::update_CalibrationTimeout()
{
	// CalibrationTimeout [s]
	DWORD	dwEdit	= m_editCalibrationTimeout;
	DWORD	dwSpin	= m_spinCalibrationTimeout;

	CString	str;
	str.Format("%d",m_CalibrationTimeout);
	CEdit* pEdit = (CEdit*)GetDlgItem(dwEdit);
	pEdit->SetWindowText(str);
	
	CSpinButtonCtrl* pSpin = (CSpinButtonCtrl*)GetDlgItem(dwSpin);
	pSpin->SetRange(-1,1);
	pSpin->SetPos(0);

	return m_CalibrationTimeout;

}

BOOL CuiXlinePageDCAL::start_calibration(int CalibrattionType)
{
	// set capture mode
	double	dValue	= DCAMPROP_CAPTUREMODE__NORMAL;
	switch (CalibrattionType)
	{
	case TYPE_DARK_CALIBRATION:		dValue	= DCAMPROP_CAPTUREMODE__DARKCALIB;		break;
	case TYPE_SHADING_CALIBRATION:	dValue	= DCAMPROP_CAPTUREMODE__SHADINGCALIB;	break;
	case TYPE_TAPGAIN_CALIBRATION:	dValue	= DCAMPROP_CAPTUREMODE__TAPGAINCALIB;	break;
	}
	if (! dcam_setpropertyvalue (m_hdcam, DCAM_IDPROP_CAPTUREMODE, dValue))
	{
		showerrorcode();
		return	FALSE;
	}

	// set data type.
	if (! dcam_setdatatype (m_hdcam, DCAM_DATATYPE_UINT16))
	{
		showerrorcode();
		return	FALSE;
	}

	// prepare capturing.
	if (! dcam_precapture (m_hdcam, DCAM_CAPTUREMODE_SEQUENCE))
	{
		showerrorcode();
		return	FALSE;
	}

	// status must be STABLE
	_DWORD	dwStatus;
	ASSERT ((dcam_getstatus (m_hdcam, & dwStatus)) && (dwStatus == DCAM_STATUS_STABLE));

	// prepare buffer
	// buffer is allocated by DCAM.
	if (! dcam_allocframe (m_hdcam, 1))
	{
		showerrorcode();
		return	FALSE;
	}

	// start capturing
	if (! dcam_capture (m_hdcam))
	{
		showerrorcode_notriggerenable();

		if (! dcam_freeframe (m_hdcam))
		{
			showerrorcode();
		}

		return	FALSE;
	}

	ASSERT ((dcam_getstatus (m_hdcam, & dwStatus)) && (dwStatus == DCAM_STATUS_BUSY));

	nCalibrating	= CalibrattionType;

	update_calibration ();

	return TRUE;
}

BOOL CuiXlinePageDCAL::cancel_calibration(BOOL bUpdate) 
{
	ASSERT (m_hdcam != NULL);

	_DWORD	dwStatus;
	VERIFY (dcam_getstatus (m_hdcam, & dwStatus));

	if (dwStatus == DCAM_STATUS_BUSY)
	{
		if (! dcam_idle (m_hdcam))
		{
			AfxMessageBox("dcam_idle()",MB_OK);
		}
		if (! dcam_freeframe (m_hdcam))
		{
			AfxMessageBox("dcam_freeframe()",MB_OK);
		}
		if (! dcam_setpropertyvalue (m_hdcam, DCAM_IDPROP_CAPTUREMODE, DCAMPROP_CAPTUREMODE__NORMAL))
		{
			AfxMessageBox("dcam_setpropertyvalue(DCAM_IDPROP_CAPTUREMODE)",MB_OK);
		}
	}
	else if (dwStatus == DCAM_STATUS_READY)
	{
		if (! dcam_freeframe (m_hdcam))
		{
			AfxMessageBox("dcam_freeframe()",MB_OK);
		}
		if (! dcam_setpropertyvalue (m_hdcam, DCAM_IDPROP_CAPTUREMODE, DCAMPROP_CAPTUREMODE__NORMAL))
		{
			AfxMessageBox("dcam_setpropertyvalue( DCAM_IDPROP_CAPTUREMODE)",MB_OK);
		}
	}
	else
	{
		ASSERT (0);
	}

	nCalibrating	= TYPE_NONE_CALIBRATION;

	update_calibration ();

	return	TRUE;
}

BOOL CuiXlinePageDCAL::check_calibration()
{
	ASSERT (m_hdcam != NULL);

	if (nCalibrating != 0)
	{
		_DWORD	dwStatus;
		VERIFY (dcam_getstatus (m_hdcam, & dwStatus));

		if (dwStatus == DCAM_STATUS_READY)
		{
			cancel_calibration ();
		}
	}

	return	TRUE;
}

void CuiXlinePageDCAL::update_calibration()
{
	CButton* pButtonDark	= (CButton*)GetDlgItem(IDC_XLINE_DCAL_DARKCALIBRATION_BUTTON);
	CString	strDark;
	BOOL	bEnableDark;
	double	dValue;
	CButton* pButtonShading	= (CButton*)GetDlgItem(IDC_XLINE_DCAL_SHADINGCALIBRATION_BUTTON);
	CString	strShading;
	BOOL	bEnableShading;
	CButton* pButtonClear	= (CButton*)GetDlgItem(IDC_XLINE_DCAL_CLEARCALIBRATION_BUTTON);
	CString	strClear;
	BOOL	bEnableClear;

	CButton* pButtonStoreD	= (CButton*)GetDlgItem(IDC_XLINE_DCAL_STOREDARKCALIBDATATOMEMORY_BUTTON);
	CButton* pButtonStoreS	= (CButton*)GetDlgItem(IDC_XLINE_DCAL_STORESHADINGCALIBDATATOMEMORY_BUTTON);
	BOOL	bEnableStore;

	if(nCalibrating == TYPE_NONE_CALIBRATION)
	{
		// dark calibration button = "dark calibration"			Enable
		dValue = DCAMPROP_CAPTUREMODE__DARKCALIB;
		strDark.Format("Dark Calibration");
		if(uipParam[SensorModeDCAL].value == DCAMPROP_SENSORMODE__AREA)
		{
			bEnableDark = FALSE;
		}
		else if(m_CameraStatusInputTrigger != DCAMPROP_CAMERASTATUS_INPUTTRIGGER__GOOD)
		{
			bEnableDark = FALSE;
		}
		else if(! dcam_querypropertyvalue(m_hdcam,DCAM_IDPROP_CAPTUREMODE,&dValue,DCAMPROP_OPTION_NONE))
		{
			bEnableDark = FALSE;
		}
		else
		{
			bEnableDark = TRUE;
		}

		// shading calibration button = "shading calibration"	Enable/Disable
		dValue = DCAMPROP_CAPTUREMODE__SHADINGCALIB;
		strShading.Format("Shading Calibration");
		if(uipParam[SensorModeDCAL].value == DCAMPROP_SENSORMODE__AREA)
		{
			bEnableShading = FALSE;
		}
		else if(m_CameraStatusInputTrigger != DCAMPROP_CAMERASTATUS_INPUTTRIGGER__GOOD)
		{
			bEnableShading = FALSE;
		}
		else if(! dcam_querypropertyvalue(m_hdcam,DCAM_IDPROP_CAPTUREMODE,&dValue,DCAMPROP_OPTION_NONE))
		{
			bEnableShading = FALSE;
		}
		else
		{
			bEnableShading = TRUE;
		}
		
		// clear calibration button = "clear calibration"		Enable
		strClear.Format("Clear Calibration");
		if(m_CameraStatusInputTrigger != DCAMPROP_CAMERASTATUS_INPUTTRIGGER__GOOD)
		{
			bEnableClear = FALSE;
		}
		else
		{
			bEnableClear = TRUE;
		}

		// store button 		Enable / Disable
		if(m_CameraStatusInputTrigger != DCAMPROP_CAMERASTATUS_INPUTTRIGGER__GOOD)
		{
			bEnableStore = FALSE;
		}
		else
		{
			bEnableStore = TRUE;
		}
		
	}
	else if(nCalibrating == TYPE_DARK_CALIBRATION)
	{
		// dark calibration button = "cancel calibration"		Enable
		strDark.Format("Cancel Calibration");
		if(uipParam[SensorModeDCAL].value == DCAMPROP_SENSORMODE__AREA)
		{
			bEnableDark = FALSE;
		}
		else
		{
			bEnableDark = TRUE;
		}

		// shading calibration button = "shading calibration"	Disable
		strShading.Format("Shading Calibration");
		bEnableShading = FALSE;

		// clear calibration button = "clear calibration"		Disable
		strClear.Format("Clear Calibration");
		bEnableClear = FALSE;

		// store button 		Disable
		bEnableStore = FALSE;
	}
	else if(nCalibrating == TYPE_SHADING_CALIBRATION)
	{
		// dark calibration button = "dark calibration"			Disable
		strDark.Format("Dark Calibration");
		bEnableDark = FALSE;

		// shading calibration button = "cancel calibration"	Enable
		strShading.Format("Cancel Calibration");
		if(uipParam[SensorModeDCAL].value == DCAMPROP_SENSORMODE__AREA)
		{
			bEnableShading = FALSE;
		}
		else
		{
			bEnableShading = TRUE;
		}

		// clear calibration button = "clear calibration"		Disable
		strClear.Format("Clear Calibration");
		bEnableClear = FALSE;

		// store button 		Disable
		bEnableStore = FALSE;
	}
	else
	{	// error
		// dark calibration button = "cancel calibration"		Disable
		strDark.Format("Dark Calibration");
		bEnableDark = FALSE;

		// shading calibration button = "cancel calibration"	Disable
		strShading.Format("Shading Calibration");
		bEnableShading = FALSE;

		// clear calibration button = "clear calibration"		Disable
		strClear.Format("Clear Calibration");
		bEnableClear = FALSE;

		// store button 		Disable
		bEnableStore = FALSE;
	}

	pButtonDark->SetWindowText(strDark);
	pButtonDark->EnableWindow(bEnableDark);

	pButtonShading->SetWindowText(strShading);
	pButtonShading->EnableWindow(bEnableShading);

	pButtonClear->SetWindowText(strClear);
	pButtonClear->EnableWindow(bEnableClear);

	pButtonStoreD->EnableWindow(bEnableStore);
	pButtonStoreS->EnableWindow(bEnableStore);

	update_EnableStatus();
}

BEGIN_MESSAGE_MAP(CuiXlinePageDCAL, CPropertyPage)
	//{{AFX_MSG_MAP(CuiXlinePageDCAL)
	ON_EN_KILLFOCUS(IDC_XLINE_DCAL_DARKCALIBMAXIMUMINTENSITY_EDIT, OnKillfocusXlscDcalDarkcalibmaximumintensityEdit)
	ON_EN_KILLFOCUS(IDC_XLINE_DCAL_SHADINGCALIBMINIMUMINTENSITY_EDIT, OnKillfocusXlscDcalShadingcalibminimumintensityEdit)
	ON_EN_KILLFOCUS(IDC_XLINE_DCAL_SHADINGCALIBINTENSITYMAXIMUMERRORPERCENTAGE_EDIT, OnKillfocusXlscDcalShadingcalibintensitymaximumerrorpercentage)
	ON_EN_KILLFOCUS(IDC_XLINE_DCAL_SHADINGCALIBCALIBRATETARGET_EDIT, OnKillfocusXlscDcalShadingcalibcalibratetargetEdit)
	ON_EN_KILLFOCUS(IDC_XLINE_DCAL_SHADINGCALIBSTABLEFRAMECOUNT_EDIT, OnKillfocusXlscDcalShadingcalibstableframecountEdit)
	ON_EN_KILLFOCUS(IDC_XLINE_DCAL_SHADINGCALIBAVERAGEFRAMECOUNT_EDIT, OnKillfocusXlscDcalShadingcalibaverageframecountEdit)
	ON_EN_KILLFOCUS(IDC_XLINE_DCAL_CALIBRATETIMEOUT_EDIT, OnKillfocusXlscDcalCalibratetimeoutEdit)
	ON_NOTIFY(UDN_DELTAPOS, IDC_XLINE_DCAL_DARKCALIBMAXIMUMINTENSITY_SPIN, OnDeltaposXlscDcalDarkcalibmaximumintensitySpin)
	ON_NOTIFY(UDN_DELTAPOS, IDC_XLINE_DCAL_SHADINGCALIBMINIMUMINTENSITY_SPIN, OnDeltaposXlscDcalShadingcalibminimumintensitySpin)
	ON_NOTIFY(UDN_DELTAPOS, IDC_XLINE_DCAL_SHADINGCALIBINTENSITYMAXIMUMERRORPERCENTAGE_SPIN, OnDeltaposXlscDcalShadingcalibintensitymaximumerrorpercentageS)
	ON_NOTIFY(UDN_DELTAPOS, IDC_XLINE_DCAL_SHADINGCALIBCALIBRATETARGET_SPIN, OnDeltaposXlscDcalShadingcalibcalibratetargetSpin)
	ON_NOTIFY(UDN_DELTAPOS, IDC_XLINE_DCAL_SHADINGCALIBSTABLEFRAMECOUNT_SPIN, OnDeltaposXlscDcalShadingcalibstableframecountSpin)
	ON_NOTIFY(UDN_DELTAPOS, IDC_XLINE_DCAL_SHADINGCALIBAVERAGEFRAMECOUNT_SPIN, OnDeltaposXlscDcalShadingcalibaverageframecountSpin)
	ON_NOTIFY(UDN_DELTAPOS, IDC_XLINE_DCAL_CALIBRATETIMEOUT_SPIN, OnDeltaposXlscDcalCalibratetimeoutSpin)
	ON_BN_CLICKED(IDC_XLINE_DCAL_DARKCALIBDATAMEMORY_BUTTON, OnXlscDcalDarkcalibdatamemoryButton)
	ON_BN_CLICKED(IDC_XLINE_DCAL_SHADINGCALIBDATAMEMORY_BUTTON, OnXlscDcalShadingcalibdatamemoryButton)
	ON_BN_CLICKED(IDC_XLINE_DCAL_STOREDARKCALIBDATATOMEMORY_BUTTON, OnXlscDcalStoredarkcalibdatatomemoryButton)
	ON_BN_CLICKED(IDC_XLINE_DCAL_STORESHADINGCALIBDATATOMEMORY_BUTTON, OnXlscDcalStoreshadingcalibdatatomemoryButton)
	ON_WM_TIMER()
	ON_BN_CLICKED(IDC_XLINE_DCAL_DARKCALIBRATION_BUTTON, OnXlscDcalDarkcalibrationButton)
	ON_BN_CLICKED(IDC_XLINE_DCAL_SHADINGCALIBRATION_BUTTON, OnXlscDcalShadingcalibrationButton)
	ON_BN_CLICKED(IDC_XLINE_DCAL_CLEARCALIBRATION_BUTTON, OnXlscDcalClearcalibrationButton)
	ON_CBN_SELENDOK(IDC_XLINE_DCAL_SHADINGCALIBCALIBRATEMETHOD_COMBO, OnSelendokXlscDcalShadingcalibcalibratemethodCombo)
	ON_EN_SETFOCUS(IDC_XLINE_DCAL_DARKCALIBMAXIMUMINTENSITY_EDIT, OnSetfocusXlscDcalDarkcalibmaximumintensityEdit)
	ON_EN_SETFOCUS(IDC_XLINE_DCAL_SHADINGCALIBMINIMUMINTENSITY_EDIT, OnSetfocusXlscDcalShadingcalibminimumintensityEdit)
	ON_EN_SETFOCUS(IDC_XLINE_DCAL_SHADINGCALIBINTENSITYMAXIMUMERRORPERCENTAGE_EDIT, OnSetfocusXlscDcalShadingcalibintensitymaximumerrorpercentage)
	ON_EN_SETFOCUS(IDC_XLINE_DCAL_SHADINGCALIBCALIBRATETARGET_EDIT, OnSetfocusXlscDcalShadingcalibcalibratetargetEdit)
	ON_EN_SETFOCUS(IDC_XLINE_DCAL_SHADINGCALIBSTABLEFRAMECOUNT_EDIT, OnSetfocusXlscDcalShadingcalibstableframecountEdit)
	ON_EN_SETFOCUS(IDC_XLINE_DCAL_SHADINGCALIBAVERAGEFRAMECOUNT_EDIT, OnSetfocusXlscDcalShadingcalibaverageframecountEdit)
	//}}AFX_MSG_MAP
END_MESSAGE_MAP()

/////////////////////////////////////////////////////////////////////////////
// CuiXlinePageDCAL message handlers

BOOL CuiXlinePageDCAL::OnInitDialog() 
{
	AddProperties();

	updateStatus();

	CheckSupportDCAMPROP();

	update_CalibrationTimeout();

	CPropertyPage::OnInitDialog();
	
	// TODO: Add extra initialization here
	update_calibration();
	
	return TRUE;  // return TRUE unless you set the focus to a control
	              // EXCEPTION: OCX Property Pages should return FALSE
}

void CuiXlinePageDCAL::OnOK() 
{
	if (nCalibrating != TYPE_NONE_CALIBRATION)
	{
		cancel_calibration ();
	}

	end_timer();

	CPropertyPage::OnOK();
}

void CuiXlinePageDCAL::OnCancel() 
{
	if (nCalibrating != TYPE_NONE_CALIBRATION)
	{
		cancel_calibration ();
	}

	end_timer();

	CPropertyPage::OnCancel();
}

BOOL CuiXlinePageDCAL::OnApply() 
{
	return CPropertyPage::OnApply();
}

void CuiXlinePageDCAL::OnSetfocusXlscDcalDarkcalibmaximumintensityEdit() 
{
	int		nID = DarkCalibMaximumIntensity;
	input_on_setfocus(nID);
}

void CuiXlinePageDCAL::OnKillfocusXlscDcalDarkcalibmaximumintensityEdit() 
{
	int		nID = DarkCalibMaximumIntensity;
	input_on_killfocus(nID);
}

void CuiXlinePageDCAL::OnSetfocusXlscDcalShadingcalibminimumintensityEdit() 
{
	int		nID = ShadingCalibMinimumIntensity;
	input_on_setfocus(nID);	
}

void CuiXlinePageDCAL::OnKillfocusXlscDcalShadingcalibminimumintensityEdit() 
{
	int		nID = ShadingCalibMinimumIntensity;
	input_on_killfocus(nID);
}

void CuiXlinePageDCAL::OnSetfocusXlscDcalShadingcalibintensitymaximumerrorpercentage() 
{
	int		nID = ShadingCalibIntensityMaximumErrorPercentage;
	input_on_setfocus(nID);
}

void CuiXlinePageDCAL::OnKillfocusXlscDcalShadingcalibintensitymaximumerrorpercentage() 
{
	int		nID = ShadingCalibIntensityMaximumErrorPercentage;
	input_on_killfocus(nID);
}

void CuiXlinePageDCAL::OnSetfocusXlscDcalShadingcalibcalibratetargetEdit() 
{
	int		nID = ShadingCalibTarget;
	input_on_setfocus(nID);		
}

void CuiXlinePageDCAL::OnKillfocusXlscDcalShadingcalibcalibratetargetEdit() 
{
	int		nID = ShadingCalibTarget;
	input_on_killfocus(nID);
}

void CuiXlinePageDCAL::OnSetfocusXlscDcalShadingcalibstableframecountEdit() 
{
	int		nID = ShadingCalibStableFrameCount;
	input_on_setfocus(nID);
}

void CuiXlinePageDCAL::OnKillfocusXlscDcalShadingcalibstableframecountEdit() 
{
	int		nID = ShadingCalibStableFrameCount;
	input_on_killfocus(nID);
}

void CuiXlinePageDCAL::OnSetfocusXlscDcalShadingcalibaverageframecountEdit() 
{
	int		nID = ShadingCalibAverageFrameCount;
	input_on_setfocus(nID);	
}

void CuiXlinePageDCAL::OnKillfocusXlscDcalShadingcalibaverageframecountEdit() 
{
	int		nID = ShadingCalibAverageFrameCount;
	input_on_killfocus(nID);
}

void CuiXlinePageDCAL::OnKillfocusXlscDcalCalibratetimeoutEdit() 
{
	// CalibrationTimeout [s]
	DWORD	dwEdit	= m_editCalibrationTimeout;

	// get value from edit box
	CString	str;
	CEdit* pEdit = (CEdit*)GetDlgItem(dwEdit);
	pEdit->GetWindowText(str);
	long value = atol(str);

	// show out of range 
	long	min = m_minCalibrationTimeout;
	long	max = m_maxCalibrationTimeout;
	if(value < min || value > max)
	{
		CString strOutofrange;
		strOutofrange.Format("Input value is out of range. Set value in range.[%d to %d]",min,max);
		AfxMessageBox(strOutofrange,MB_OK);
		update_CalibrationTimeout();
		pEdit->SetFocus();
		return;
	}

	m_CalibrationTimeout = value;

	update_CalibrationTimeout();
	
}

void CuiXlinePageDCAL::OnDeltaposXlscDcalDarkcalibmaximumintensitySpin(NMHDR* pNMHDR, LRESULT* pResult) 
{
	NM_UPDOWN* pNMUpDown = (NM_UPDOWN*)pNMHDR;
	
	int		nID = DarkCalibMaximumIntensity;
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
	
	*pResult = 0;
}

void CuiXlinePageDCAL::OnDeltaposXlscDcalShadingcalibminimumintensitySpin(NMHDR* pNMHDR, LRESULT* pResult) 
{
	NM_UPDOWN* pNMUpDown = (NM_UPDOWN*)pNMHDR;
	
	int		nID = ShadingCalibMinimumIntensity;
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
	
	*pResult = 0;
}

void CuiXlinePageDCAL::OnDeltaposXlscDcalShadingcalibintensitymaximumerrorpercentageS(NMHDR* pNMHDR, LRESULT* pResult) 
{
	NM_UPDOWN* pNMUpDown = (NM_UPDOWN*)pNMHDR;
	
	int		nID = ShadingCalibIntensityMaximumErrorPercentage;
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
	
	*pResult = 0;
}

void CuiXlinePageDCAL::OnDeltaposXlscDcalShadingcalibcalibratetargetSpin(NMHDR* pNMHDR, LRESULT* pResult) 
{
	NM_UPDOWN* pNMUpDown = (NM_UPDOWN*)pNMHDR;
	
	int		nID = ShadingCalibTarget;
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
	
	*pResult = 0;
}

void CuiXlinePageDCAL::OnDeltaposXlscDcalShadingcalibstableframecountSpin(NMHDR* pNMHDR, LRESULT* pResult) 
{
	NM_UPDOWN* pNMUpDown = (NM_UPDOWN*)pNMHDR;
	
	int		nID = ShadingCalibStableFrameCount;
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
	
	*pResult = 0;
}

void CuiXlinePageDCAL::OnDeltaposXlscDcalShadingcalibaverageframecountSpin(NMHDR* pNMHDR, LRESULT* pResult) 
{
	NM_UPDOWN* pNMUpDown = (NM_UPDOWN*)pNMHDR;
	
	int		nID = ShadingCalibAverageFrameCount;
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
	
	*pResult = 0;
}

void CuiXlinePageDCAL::OnDeltaposXlscDcalCalibratetimeoutSpin(NMHDR* pNMHDR, LRESULT* pResult) 
{
	NM_UPDOWN* pNMUpDown = (NM_UPDOWN*)pNMHDR;
	
	// CalibrationTimeout [s]
	DWORD	dwEdit	= m_editCalibrationTimeout;

	// get value from edit box
	CString	str;
	CEdit* pEdit = (CEdit*)GetDlgItem(dwEdit);
	pEdit->GetWindowText(str);
	long value = atol(str);

	// change at spin and limit on min,max
	long	min		= m_minCalibrationTimeout;
	long	max		= m_maxCalibrationTimeout;
	long	step	= m_stepCalibrationTimeout;
	value	= (pNMUpDown->iDelta > 0) ? (value + step) : (value - step);
	if(value < min)	value = min;
	if(value > max)	value = max;

	m_CalibrationTimeout = value;

	update_CalibrationTimeout();

	*pResult = 0;
}


void CuiXlinePageDCAL::OnXlscDcalDarkcalibdatamemoryButton() 
{
	// SubtractImageMemory
	int		nID = SubtractImageMemory;
	CComboBox* pCombo = (CComboBox*)GetDlgItem(uipParam[nID].iComboBox);

	int nSelect = pCombo->GetCurSel();
	DWORD_PTR dItemData = pCombo->GetItemData(nSelect);
	double dNewValue = (double)dItemData;

	setvaluetoDCAM(uipParam[nID].attr.iProp, dNewValue);

	CheckUpdateDCAMPROP();
	
}

void CuiXlinePageDCAL::OnXlscDcalShadingcalibdatamemoryButton() 
{
	// ShadingCalibImageMemory
	int		nID = ShadingCalibImageMemory;
	CComboBox* pCombo = (CComboBox*)GetDlgItem(uipParam[nID].iComboBox);

	int nSelect = pCombo->GetCurSel();
	DWORD_PTR dItemData = pCombo->GetItemData(nSelect);
	double dNewValue = (double)dItemData;

	setvaluetoDCAM(uipParam[nID].attr.iProp, dNewValue);

	CheckUpdateDCAMPROP();
}

void CuiXlinePageDCAL::OnXlscDcalStoredarkcalibdatatomemoryButton() 
{
	// StoreSubtractImageToMemory
	int		nID = SubtractImageMemory;
	CComboBox* pCombo = (CComboBox*)GetDlgItem(uipParam[nID].iComboBox);

	int nSelect = pCombo->GetCurSel();
	DWORD_PTR dItemData = pCombo->GetItemData(nSelect);
	double dNewValue = (double)dItemData;

	setvaluetoDCAM(DCAM_IDPROP_STORESUBTRACTIMAGETOMEMORY, dNewValue);

	CheckUpdateDCAMPROP();

	
}

void CuiXlinePageDCAL::OnXlscDcalStoreshadingcalibdatatomemoryButton() 
{
	// StoreShadingCalibImageToMemory
	int		nID = ShadingCalibImageMemory;
	CComboBox* pCombo = (CComboBox*)GetDlgItem(uipParam[nID].iComboBox);

	int nSelect = pCombo->GetCurSel();
	DWORD_PTR dItemData = pCombo->GetItemData(nSelect);
	double dNewValue = (double)dItemData;

	setvaluetoDCAM(DCAM_IDPROP_STORESHADINGCALIBDATATOMEMORY, dNewValue);

	CheckUpdateDCAMPROP();

	
}

void CuiXlinePageDCAL::OnTimer(UINT_PTR nIDEvent) 
{
	if(nIDEvent == ID_TIMER_GETSTATUS)
	{
		updateStatus();
		update_calibration();

		if(nCalibrating != TYPE_NONE_CALIBRATION)	lTimeCounter++;
		else										lTimeCounter = 0;
		if(lTimeCounter > m_CalibrationTimeout*2)
		{
			cancel_calibration();
			AfxMessageBox("Calibration is timeout.",MB_OK);
		}

		updateStatus();
		check_calibration();

	}
	
	CPropertyPage::OnTimer(nIDEvent);
}

void CuiXlinePageDCAL::OnXlscDcalDarkcalibrationButton() 
{
	if(nCalibrating == TYPE_NONE_CALIBRATION)
	{
		BOOL bStart = start_calibration(TYPE_DARK_CALIBRATION);
		if(!bStart)
		{
			if (! dcam_setpropertyvalue (m_hdcam, DCAM_IDPROP_CAPTUREMODE, DCAMPROP_CAPTUREMODE__NORMAL))
			{
				AfxMessageBox("dcam_setpropertyvalue(DCAM_IDPROP_CAPTUREMODE)",MB_OK);
			}
		}
	}
	else if(nCalibrating == TYPE_DARK_CALIBRATION)
	{
		cancel_calibration();
	}
	else if(nCalibrating == TYPE_SHADING_CALIBRATION)
	{
		cancel_calibration();	// tempative
	}
	else if(nCalibrating == TYPE_TAPGAIN_CALIBRATION)
	{
		cancel_calibration();	// tempative
	}
	else		// error
	{
		cancel_calibration();	// tempative
	}

}

void CuiXlinePageDCAL::OnXlscDcalShadingcalibrationButton() 
{
	if(nCalibrating == TYPE_NONE_CALIBRATION)
	{
		BOOL bStart = start_calibration(TYPE_SHADING_CALIBRATION);
		if(!bStart)
		{
			if (! dcam_setpropertyvalue (m_hdcam, DCAM_IDPROP_CAPTUREMODE, DCAMPROP_CAPTUREMODE__NORMAL))
			{
				AfxMessageBox("dcam_setpropertyvalue(DCAM_IDPROP_CAPTUREMODE)",MB_OK);
			}
		}
	}
	else if(nCalibrating == TYPE_DARK_CALIBRATION)
	{
		cancel_calibration();
	}
	else if(nCalibrating == TYPE_SHADING_CALIBRATION)
	{
		cancel_calibration();	// tempative
	}
	else if(nCalibrating == TYPE_TAPGAIN_CALIBRATION)
	{
		cancel_calibration();	// tempative
	}
	else		// error
	{
		cancel_calibration();	// tempative
	}
	
}

void CuiXlinePageDCAL::OnXlscDcalClearcalibrationButton() 
{
	// Subtract
	int		nID = Subtract;
	setvaluetoDCAM(uipParam[nID].attr.iProp, DCAMPROP_MODE__OFF);

	CheckUpdateDCAMPROP();
	
}

BOOL CuiXlinePageDCAL::OnKillActive() 
{
	if (nCalibrating != TYPE_NONE_CALIBRATION)
	{
		cancel_calibration ();
	}

	end_timer();
	
	return CPropertyPage::OnKillActive();
}

void CuiXlinePageDCAL::PostNcDestroy() 
{
	if (nCalibrating != TYPE_NONE_CALIBRATION)
	{
		cancel_calibration ();
	}	

	end_timer();
	
	CPropertyPage::PostNcDestroy();
}


void CuiXlinePageDCAL::update_EnableStatus()
{
	CWnd*	pWnd;

	int		dwEnable[64];
	int		iCountEnable = 0;
	int		dwDisable[64];
	int		iCountDisable = 0;
	
	if(nCalibrating == TYPE_NONE_CALIBRATION)
	{
		dwEnable[iCountEnable] = IDC_XLINE_DCAL_DARKCALIBMAXIMUMINTENSITY_EDIT;
		iCountEnable++;
		dwEnable[iCountEnable] = IDC_XLINE_DCAL_DARKCALIBMAXIMUMINTENSITY_SPIN;
		iCountEnable++;
		dwEnable[iCountEnable] = IDC_XLINE_DCAL_SHADINGCALIBMINIMUMINTENSITY_EDIT;
		iCountEnable++;
		dwEnable[iCountEnable] = IDC_XLINE_DCAL_SHADINGCALIBMINIMUMINTENSITY_SPIN;
		iCountEnable++;
		dwEnable[iCountEnable] = IDC_XLINE_DCAL_SHADINGCALIBINTENSITYMAXIMUMERRORPERCENTAGE_EDIT;
		iCountEnable++;
		dwEnable[iCountEnable] = IDC_XLINE_DCAL_SHADINGCALIBINTENSITYMAXIMUMERRORPERCENTAGE_SPIN;
		iCountEnable++;
		dwEnable[iCountEnable] = IDC_XLINE_DCAL_SHADINGCALIBCALIBRATEMETHOD_COMBO;
		iCountEnable++;
		if(uipParam[ShadingCalibTarget].attr.attribute & DCAMPROP_ATTR_EFFECTIVE)
		{
			dwEnable[iCountEnable] = IDC_XLINE_DCAL_SHADINGCALIBCALIBRATETARGET_EDIT;
			iCountEnable++;
		}
		dwEnable[iCountEnable] = IDC_XLINE_DCAL_SHADINGCALIBCALIBRATETARGET_SPIN;
		iCountEnable++;
		dwEnable[iCountEnable] = IDC_XLINE_DCAL_SHADINGCALIBSTABLEFRAMECOUNT_EDIT;
		iCountEnable++;
		dwEnable[iCountEnable] = IDC_XLINE_DCAL_SHADINGCALIBSTABLEFRAMECOUNT_SPIN;
		iCountEnable++;
		dwEnable[iCountEnable] = IDC_XLINE_DCAL_SHADINGCALIBAVERAGEFRAMECOUNT_EDIT;
		iCountEnable++;
		dwEnable[iCountEnable] = IDC_XLINE_DCAL_SHADINGCALIBAVERAGEFRAMECOUNT_SPIN;
		iCountEnable++;
		dwEnable[iCountEnable] = IDC_XLINE_DCAL_DARKCALIBTABLE_COMBO;
		iCountEnable++;
		dwEnable[iCountEnable] = IDC_XLINE_DCAL_DARKCALIBDATAMEMORY_BUTTON;
		iCountEnable++;
		dwEnable[iCountEnable] = IDC_XLINE_DCAL_SHADINGCALIBTABLE_COMBO;
		iCountEnable++;
		dwEnable[iCountEnable] = IDC_XLINE_DCAL_SHADINGCALIBDATAMEMORY_BUTTON;
		iCountEnable++;

	}
	else
	{
		dwDisable[iCountDisable] = IDC_XLINE_DCAL_DARKCALIBMAXIMUMINTENSITY_EDIT;
		iCountDisable++;
		dwDisable[iCountDisable] = IDC_XLINE_DCAL_DARKCALIBMAXIMUMINTENSITY_SPIN;
		iCountDisable++;
		dwDisable[iCountDisable] = IDC_XLINE_DCAL_SHADINGCALIBMINIMUMINTENSITY_EDIT;
		iCountDisable++;
		dwDisable[iCountDisable] = IDC_XLINE_DCAL_SHADINGCALIBMINIMUMINTENSITY_SPIN;
		iCountDisable++;
		dwDisable[iCountDisable] = IDC_XLINE_DCAL_SHADINGCALIBINTENSITYMAXIMUMERRORPERCENTAGE_EDIT;
		iCountDisable++;
		dwDisable[iCountDisable] = IDC_XLINE_DCAL_SHADINGCALIBINTENSITYMAXIMUMERRORPERCENTAGE_SPIN;
		iCountDisable++;
		dwDisable[iCountDisable] = IDC_XLINE_DCAL_SHADINGCALIBCALIBRATEMETHOD_COMBO;
		iCountDisable++;
		dwDisable[iCountDisable] = IDC_XLINE_DCAL_SHADINGCALIBCALIBRATETARGET_EDIT;
		iCountDisable++;
		dwDisable[iCountDisable] = IDC_XLINE_DCAL_SHADINGCALIBCALIBRATETARGET_SPIN;
		iCountDisable++;
		dwDisable[iCountDisable] = IDC_XLINE_DCAL_SHADINGCALIBSTABLEFRAMECOUNT_EDIT;
		iCountDisable++;
		dwDisable[iCountDisable] = IDC_XLINE_DCAL_SHADINGCALIBSTABLEFRAMECOUNT_SPIN;
		iCountDisable++;
		dwDisable[iCountDisable] = IDC_XLINE_DCAL_SHADINGCALIBAVERAGEFRAMECOUNT_EDIT;
		iCountDisable++;
		dwDisable[iCountDisable] = IDC_XLINE_DCAL_SHADINGCALIBAVERAGEFRAMECOUNT_SPIN;
		iCountDisable++;
		dwDisable[iCountDisable] = IDC_XLINE_DCAL_DARKCALIBTABLE_COMBO;
		iCountDisable++;
		dwDisable[iCountDisable] = IDC_XLINE_DCAL_DARKCALIBDATAMEMORY_BUTTON;
		iCountDisable++;
		dwDisable[iCountDisable] = IDC_XLINE_DCAL_SHADINGCALIBTABLE_COMBO;
		iCountDisable++;
		dwDisable[iCountDisable] = IDC_XLINE_DCAL_SHADINGCALIBDATAMEMORY_BUTTON;
		iCountDisable++;

	}

	int	i;
	for(i=0;i<iCountEnable;i++)
	{
		pWnd = (CWnd*)GetDlgItem(dwEnable[i]);
		pWnd->EnableWindow(TRUE);
	}
	for(i=0;i<iCountDisable;i++)
	{
		pWnd = (CWnd*)GetDlgItem(dwDisable[i]);
		pWnd->EnableWindow(FALSE);
	}

}

BOOL CuiXlinePageDCAL::OnSetActive() 
{
	CheckSupportDCAMPROP();

	CButton* pButtonDark	= (CButton*)GetDlgItem(IDC_XLINE_DCAL_DARKCALIBRATION_BUTTON);
	CButton* pButtonShading	= (CButton*)GetDlgItem(IDC_XLINE_DCAL_SHADINGCALIBRATION_BUTTON);

	// if sensor mode is area mode, disable calibration button.
	if(uipParam[SensorModeDCAL].value == DCAMPROP_SENSORMODE__AREA)
	{
		pButtonDark->EnableWindow(FALSE);
		pButtonShading->EnableWindow(FALSE);
	}
	else
	{
		pButtonDark->EnableWindow(TRUE);
		pButtonShading->EnableWindow(TRUE);
	}

	start_timer();
	
	return CPropertyPage::OnSetActive();
}

BOOL CuiXlinePageDCAL::PreTranslateMessage(MSG* pMsg) 
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
				case IDC_XLINE_DCAL_DARKCALIBMAXIMUMINTENSITY_EDIT:
					OnKillfocusXlscDcalDarkcalibmaximumintensityEdit();
					break;
				case IDC_XLINE_DCAL_SHADINGCALIBMINIMUMINTENSITY_EDIT:
					OnKillfocusXlscDcalShadingcalibminimumintensityEdit();
					break;
				case IDC_XLINE_DCAL_SHADINGCALIBINTENSITYMAXIMUMERRORPERCENTAGE_EDIT:
					OnKillfocusXlscDcalShadingcalibintensitymaximumerrorpercentage();
					break;
				case IDC_XLINE_DCAL_SHADINGCALIBCALIBRATETARGET_EDIT:
					OnKillfocusXlscDcalShadingcalibcalibratetargetEdit();
					break;
				case IDC_XLINE_DCAL_SHADINGCALIBSTABLEFRAMECOUNT_EDIT:
					OnKillfocusXlscDcalShadingcalibstableframecountEdit();
					break;
				case IDC_XLINE_DCAL_SHADINGCALIBAVERAGEFRAMECOUNT_EDIT:
					OnKillfocusXlscDcalShadingcalibaverageframecountEdit();
					break;
				case IDC_XLINE_DCAL_CALIBRATETIMEOUT_EDIT:
					OnKillfocusXlscDcalCalibratetimeoutEdit();
					break;
				case IDC_XLINE_DCAL_DARKCALIBDATAMEMORY_BUTTON:
					OnXlscDcalDarkcalibdatamemoryButton();
					break;
				case IDC_XLINE_DCAL_SHADINGCALIBDATAMEMORY_BUTTON:
					OnXlscDcalShadingcalibdatamemoryButton();
					break;
				case IDC_XLINE_DCAL_STOREDARKCALIBDATATOMEMORY_BUTTON:
					OnXlscDcalStoredarkcalibdatatomemoryButton();
					break;
				case IDC_XLINE_DCAL_STORESHADINGCALIBDATATOMEMORY_BUTTON:
					OnXlscDcalStoreshadingcalibdatatomemoryButton();
					break;
				case IDC_XLINE_DCAL_DARKCALIBRATION_BUTTON:
					OnXlscDcalDarkcalibrationButton();
					break;
				case IDC_XLINE_DCAL_SHADINGCALIBRATION_BUTTON:
					OnXlscDcalShadingcalibrationButton();
					break;
				case IDC_XLINE_DCAL_CLEARCALIBRATION_BUTTON:
					OnXlscDcalClearcalibrationButton();
					break;
				case IDC_XLINE_DCAL_SHADINGCALIBCALIBRATEMETHOD_COMBO:
					break;
			}
			return 0;
		}
	}

	return CPropertyPage::PreTranslateMessage(pMsg);
}

void CuiXlinePageDCAL::OnSelendokXlscDcalShadingcalibcalibratemethodCombo() 
{
	// ShadingCalibMethod
	int		nID = ShadingCalibMethod;
	CComboBox* pCombo = (CComboBox*)GetDlgItem(uipParam[nID].iComboBox);

	int nSelect = pCombo->GetCurSel();
	DWORD_PTR dItemData = pCombo->GetItemData(nSelect);
	double dNewValue = (double)dItemData;

	setvaluetoDCAM(uipParam[nID].attr.iProp, dNewValue);

	CheckUpdateDCAMPROP();
	
}





