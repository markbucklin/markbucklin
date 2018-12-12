// uiXlinePageACAL.cpp : implementation file
//

#include "stdafx.h"
#include "ExCapUI.h"
#include "uiXlinePageACALDUAL.h"
#include "dcamex.h"

#ifdef _DEBUG
#define new DEBUG_NEW
#undef THIS_FILE
static char THIS_FILE[] = __FILE__;
#endif

/////////////////////////////////////////////////////////////////////////////
// CuiXlinePageACALDUAL property page

IMPLEMENT_DYNCREATE(CuiXlinePageACALDUAL, CPropertyPage)

CuiXlinePageACALDUAL::CuiXlinePageACALDUAL() : CExCapUIPropertyPage(CuiXlinePageACALDUAL::IDD)
{
	//{{AFX_DATA_INIT(CuiXlinePageACALDUAL)
		// NOTE: the ClassWizard will add member initialization here
	//}}AFX_DATA_INIT

	// for set each
	p_gtlow		= NULL;
	p_gthigh	= NULL;
	m_gtcount	= 0;
	m_gtmin		= 0;
	m_gtmax		= 0;

	nCalibrating = TYPE_NONE_CALIBRATION;

	uTimer = NULL;
	uTimerInterval = 500;	// 500[ms]

}

void CuiXlinePageACALDUAL::AddProperties()
{
	// TapCalibMethod
	AddPropertyID(DCAM_IDPROP_TAPGAINCALIB_METHOD);
	uipParam[TapCalibMethod].iComboBox	= IDC_XLINE_ACAL_TAPCALIBMETHOD_COMBO;

	// TapCalibDataMemory
	AddPropertyID(DCAM_IDPROP_TAPCALIBDATAMEMORY);
	uipParam[TapCalibDataMemory].iComboBox	= IDC_XLINE_ACAL_TAPCALIBDATAMEMORY_COMBO;

	// TapCalibGain
	AddPropertyID(DCAM_IDPROP_TAPCALIB_GAIN);
	uipParam[TapCalibGain].iEditBox		= IDC_XLINE_ACAL_TAPCALIBGAIN_ALL_EDIT;
	uipParam[TapCalibGain].iSpin		= IDC_XLINE_ACAL_TAPCALIBGAIN_ALL_SPIN;

	// TapCalibBaseDataMemory_ch1
	//AddPropertyID(DCAM_IDPROP_TAPCALIB_BASEDATAMEMORY + 1 * DCAM_IDPROP__CHANNEL);
	AddPropertyID(MakeIDPROP_ch(DCAM_IDPROP_TAPCALIB_BASEDATAMEMORY,1));
	uipParam[TapCalibBaseDataMemory_ch1].iComboBox	= IDC_XLINE_ACAL_TAPCALIBBASEDATAMEMORY_COMBO1;

	// TapCalibBaseDataMemory_ch2
	//AddPropertyID(DCAM_IDPROP_TAPCALIB_BASEDATAMEMORY + 2 * DCAM_IDPROP__CHANNEL);
	AddPropertyID(MakeIDPROP_ch(DCAM_IDPROP_TAPCALIB_BASEDATAMEMORY,2));
	uipParam[TapCalibBaseDataMemory_ch2].iComboBox	= IDC_XLINE_ACAL_TAPCALIBBASEDATAMEMORY_COMBO2;

}

CuiXlinePageACALDUAL::~CuiXlinePageACALDUAL()
{
	if(uTimer != NULL)	KillTimer(uTimer);

	if(p_gtlow != NULL)		delete[] p_gtlow;
	if(p_gthigh != NULL)	delete[] p_gthigh;
}

void CuiXlinePageACALDUAL::DoDataExchange(CDataExchange* pDX)
{
	CPropertyPage::DoDataExchange(pDX);
	//{{AFX_DATA_MAP(CuiXlinePageACALDUAL)
		// NOTE: the ClassWizard will add DDX and DDV calls here
	//}}AFX_DATA_MAP

}

void CuiXlinePageACALDUAL::start_timer()
{
	if(uTimer != NULL)	return;

	uTimer = SetTimer(ID_TIMER_GETSTATUS,uTimerInterval,0);
}

void CuiXlinePageACALDUAL::end_timer()
{
	if(uTimer != NULL)
	{
		KillTimer(uTimer);
		uTimer = NULL;
	}
}

void CuiXlinePageACALDUAL::updateStatus()
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
	SetDlgItemText( IDC_XLINE_ACAL_CAMERASTATUSINTENSITY_STS_STATIC, str );
	

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
	SetDlgItemText( IDC_XLINE_ACAL_CAMERASTATUSINPUTTRIGGER_STS_STATIC, str );


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
	SetDlgItemText( IDC_XLINE_ACAL_CAMERASTATUSCALIBRATION_STS_STATIC, str );

}

BOOL CuiXlinePageACALDUAL::start_calibration(int CalibrattionType)
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

BOOL CuiXlinePageACALDUAL::cancel_calibration(BOOL bUpdate) 
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

BOOL CuiXlinePageACALDUAL::check_calibration()
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

void CuiXlinePageACALDUAL::update_calibration()
{
	CButton* pButtonTap	= (CButton*)GetDlgItem(IDC_XLINE_ACAL_TAPGAINCALIBRATION_BUTTON);
	CString	strTap;
	BOOL	bEnableTap;

	CButton* pButtonAI	= (CButton*)GetDlgItem(IDC_XLINE_ACAL_TAPCALIBDATAMEMORY_BUTTON);
	BOOL	bEnableAI;
	CButton* pButtonGW	= (CButton*)GetDlgItem(IDC_XLINE_ACAL_STORETAPCALIBDATAMEMORY_BUTTON);
	CButton* pButtonGTall	= (CButton*)GetDlgItem(IDC_XLINE_ACAL_TAPCALIBGAIN_ALL_BUTTON);
	CButton* pButtonGTeach	= (CButton*)GetDlgItem(IDC_XLINE_ACAL_TAPCALIBGAIN_EACH_BUTTON);
	BOOL	bEnableCom;

	double dValue;

	if(nCalibrating == TYPE_NONE_CALIBRATION)
	{
		// TAPGAIN calibration button = "TAP GAIN calibration"	Enable
		dValue = DCAMPROP_CAPTUREMODE__TAPGAINCALIB;
		strTap.Format("TAP GAIN Calibration");
		if(m_CameraStatusInputTrigger != DCAMPROP_CAMERASTATUS_INPUTTRIGGER__GOOD)
		{
			bEnableTap = FALSE;
			bEnableCom = FALSE;
			bEnableAI  = FALSE;
		}
		else if(! dcam_querypropertyvalue(m_hdcam,DCAM_IDPROP_CAPTUREMODE,&dValue,DCAMPROP_OPTION_NONE))
		{
			bEnableTap = FALSE;
			bEnableCom = FALSE;
			if(! dcam_getpropertyvalue(m_hdcam,DCAM_IDPROP_TAPCALIBDATAMEMORY,&dValue))
			{
				bEnableAI  = FALSE;
			}
			else
			{
				bEnableAI  = TRUE;
			}

		}
		else
		{
			bEnableTap = TRUE;
			bEnableCom = TRUE;
			bEnableAI  = TRUE;
		}

	}
	else if(nCalibrating == TYPE_TAPGAIN_CALIBRATION)
	{
		// dark calibration button = "cancel calibration"		Enable
		strTap.Format("Cancel Calibration");
		bEnableTap = TRUE;

		bEnableCom = FALSE;
		bEnableAI  = FALSE;
	}
	else
	{	// error
		// TAPGAIN calibration button = "TAP GAIN calibration"	Disable
		strTap.Format("TAP GAIN Calibration");
		bEnableTap = FALSE;

		bEnableCom = FALSE;
		bEnableAI  = FALSE;
	}

	pButtonTap->SetWindowText(strTap);
	pButtonTap->EnableWindow(bEnableTap);

	pButtonAI->EnableWindow(bEnableAI);

	pButtonGW->EnableWindow(bEnableCom);
	pButtonGTall->EnableWindow(bEnableCom);
	pButtonGTeach->EnableWindow(bEnableCom);

	update_EnableStatus();
}

BEGIN_MESSAGE_MAP(CuiXlinePageACALDUAL, CPropertyPage)
	//{{AFX_MSG_MAP(CuiXlinePageACALDUAL)
	ON_BN_CLICKED(IDC_XLINE_ACAL_TAPGAINCALIBRATION_BUTTON, OnXlscAcalTapgaincalibrationButton)
	ON_WM_TIMER()
	ON_BN_CLICKED(IDC_XLINE_ACAL_TAPCALIBGAIN_EACH_BUTTON, OnXlscAcalTapcalibgainEachButton)
	ON_EN_KILLFOCUS(IDC_XLINE_ACAL_TAPCALIBGAIN_ALL_EDIT, OnKillfocusXlscAcalTapcalibgainAllEdit)
	ON_NOTIFY(UDN_DELTAPOS, IDC_XLINE_ACAL_TAPCALIBGAIN_ALL_SPIN, OnDeltaposXlscAcalTapcalibgainAllSpin)
	ON_BN_CLICKED(IDC_XLINE_ACAL_TAPCALIBGAIN_ALL_BUTTON, OnXlscAcalTapcalibgainAllButton)
	ON_BN_CLICKED(IDC_XLINE_ACAL_TAPCALIBDATAMEMORY_BUTTON, OnXlscAcalTapcalibdatamemoryButton)
	ON_BN_CLICKED(IDC_XLINE_ACAL_STORETAPCALIBDATAMEMORY_BUTTON, OnXlscAcalStoretapcalibdatamemoryButton)
	ON_CBN_SELENDOK(IDC_XLINE_ACAL_TAPCALIBBASEDATAMEMORY_COMBO1, OnSelendokXlscAcalTapcalibbasedatamemoryCombo1)
	ON_CBN_SELENDOK(IDC_XLINE_ACAL_TAPCALIBBASEDATAMEMORY_COMBO2, OnSelendokXlscAcalTapcalibbasedatamemoryCombo2)
	ON_CBN_SELENDOK(IDC_XLINE_ACAL_TAPCALIBMETHOD_COMBO, OnSelendokXlscAcalTapcalibmethodCombo)
	//}}AFX_MSG_MAP
END_MESSAGE_MAP()

/////////////////////////////////////////////////////////////////////////////
// CuiXlinePageACALDUAL message handlers

BOOL CuiXlinePageACALDUAL::OnInitDialog() 
{
	AddProperties();

	// Tapcalib button is show/hide
	char	buf[256];
	CString str;
	dcam_getstring( m_hdcam, DCAM_IDSTR_MODEL, buf, sizeof( buf ) );
	str = buf;
	if(str.Find("M8815-01") >= 0)
	{
	}
	else
	{
		CWnd* pWnd;
		pWnd = (CWnd*)GetDlgItem(IDC_XLINE_ACALDUAL_LOW_STATIC);
		pWnd->ShowWindow(SW_HIDE);
		pWnd = (CWnd*)GetDlgItem(IDC_XLINE_ACALDUAL_HIGH_STATIC);
		pWnd->ShowWindow(SW_HIDE);

		pWnd = (CWnd*)GetDlgItem(IDC_XLINE_ACAL_TAPCALIBBASEDATAMEMORY_STATIC);
		pWnd->ShowWindow(SW_HIDE);
		pWnd = (CWnd*)GetDlgItem(IDC_XLINE_ACAL_TAPCALIBMETHOD_STATIC);
		pWnd->ShowWindow(SW_HIDE);
		pWnd = (CWnd*)GetDlgItem(IDC_XLINE_ACAL_TAPCALIBGAIN_ALL_STATIC);
		pWnd->ShowWindow(SW_HIDE);
		pWnd = (CWnd*)GetDlgItem(IDC_XLINE_ACAL_TAPCALIBGAIN_EACH_STATIC);
		pWnd->ShowWindow(SW_HIDE);
		pWnd = (CWnd*)GetDlgItem(IDC_XLINE_ACAL_TAPGAINCALIBRATION_BUTTON);
		pWnd->ShowWindow(SW_HIDE);
		pWnd = (CWnd*)GetDlgItem(IDC_XLINE_ACAL_STORETAPCALIBDATAMEMORY_BUTTON);
		pWnd->ShowWindow(SW_HIDE);
		pWnd = (CWnd*)GetDlgItem(IDC_XLINE_ACAL_TAPCALIBGAIN_ALL_BUTTON);
		pWnd->ShowWindow(SW_HIDE);
		pWnd = (CWnd*)GetDlgItem(IDC_XLINE_ACAL_TAPCALIBGAIN_EACH_BUTTON);
		pWnd->ShowWindow(SW_HIDE);

	}

	updateStatus();

	CheckSupportDCAMPROP();

	getfromDCAM_gtvalue();
	getfromDCAM_gtvaluearray();

	CPropertyPage::OnInitDialog();
	
	// TODO: Add extra initialization here
	
	return TRUE;  // return TRUE unless you set the focus to a control
	              // EXCEPTION: OCX Property Pages should return FALSE
}

void CuiXlinePageACALDUAL::OnOK() 
{
	if (nCalibrating != TYPE_NONE_CALIBRATION)
	{
		cancel_calibration ();
	}

	end_timer();

	CPropertyPage::OnOK();
}

void CuiXlinePageACALDUAL::OnCancel() 
{
	if (nCalibrating != TYPE_NONE_CALIBRATION)
	{
		cancel_calibration ();
	}

	end_timer();

	CPropertyPage::OnCancel();
}

BOOL CuiXlinePageACALDUAL::OnApply() 
{
	return CPropertyPage::OnApply();
}

void CuiXlinePageACALDUAL::OnXlscAcalTapgaincalibrationButton() 
{
	if(nCalibrating == TYPE_NONE_CALIBRATION)
	{
		BOOL bStart = start_calibration(TYPE_TAPGAIN_CALIBRATION);
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
		cancel_calibration();
	}
	else if(nCalibrating == TYPE_TAPGAIN_CALIBRATION)
	{
		cancel_calibration();
	}
	else		// error
	{
		cancel_calibration();
	}

	
}

BOOL CuiXlinePageACALDUAL::OnKillActive() 
{
	if (nCalibrating != TYPE_NONE_CALIBRATION)
	{
		cancel_calibration ();
	}

	end_timer();
	
	return CPropertyPage::OnKillActive();
}

void CuiXlinePageACALDUAL::PostNcDestroy() 
{
	if (nCalibrating != TYPE_NONE_CALIBRATION)
	{
		cancel_calibration ();
	}
	
	CPropertyPage::PostNcDestroy();
}

void CuiXlinePageACALDUAL::OnTimer(UINT_PTR nIDEvent) 
{
	if(nIDEvent == ID_TIMER_GETSTATUS)
	{
		updateStatus();
		update_calibration();

		updateStatus();
		check_calibration();
	}
	
	CPropertyPage::OnTimer(nIDEvent);
}

void CuiXlinePageACALDUAL::OnXlscAcalTapcalibgainEachButton() 
{
	CuiXlineModalADJU pDlg;

	getfromDCAM_gtvaluearray();

	long	ch = 2;					// C10800 has 2 chennel
	long	modules = m_gtcount;		
	long	gtmin	= (long)m_gtmin;
	long	gtmax	= (long)m_gtmax;

	BOOL bRet = pDlg.makestructure(ch, modules, gtmin, gtmax);
	if(!bRet)
	{
	}

	long	i=0;
	// set gt table to pDlg
	for(i=0;i<modules;i++)
	{
		if(ch == 2)
		{
			pDlg.p_gtlow[i]		= (int)p_gtlow[i];
			pDlg.p_gthigh[i]	= (int)p_gthigh[i];
		}
	}
	pDlg.setfirst(0,pDlg.p_gtlow[0],pDlg.p_gthigh[0]);

	INT_PTR modal = pDlg.DoModal();
	if(modal == IDOK){
		int32	iProp_ch0 = DCAM_IDPROP_TAPCALIB_GAIN;
		int32	iProp_ch1 = MakeIDPROP_ch(iProp_ch0, 1);
		int32	iProp_ch2 = MakeIDPROP_ch(iProp_ch0, 2);
		
		// set gt table pDlg to DCAM
		if(ch == 2)
		{
			for(i=0;i<pDlg.m_gtmodules_max+1;i++)
			{
				p_gtlow[i]	= (double)pDlg.p_gtlow[i];
				setvaluetoDCAM(MakeIDPROP_array(iProp_ch1,i), p_gtlow[i]);

				p_gthigh[i]	= (double)pDlg.p_gthigh[i];
				setvaluetoDCAM(MakeIDPROP_array(iProp_ch2,i), p_gthigh[i]);
			}
		}
	}
	pDlg.destroystructure();
	
}

void CuiXlinePageACALDUAL::OnKillfocusXlscAcalTapcalibgainAllEdit() 
{
	CString	str;
	double	dNewValue;

	CEdit*	pEdit = (CEdit*)GetDlgItem(IDC_XLINE_ACAL_TAPCALIBGAIN_ALL_EDIT);
	pEdit->GetWindowText(str);
	dNewValue = atof(str);

	// show out of range 
	double	min = m_gtvaluemin;
	double	max = m_gtvaluemax;
	if(dNewValue < min || dNewValue > max)
	{
		CString strOutofrange;
		strOutofrange.Format("Input value is out of range. Set value in range.[%.0f to %.0f]",min,max);
		AfxMessageBox(strOutofrange,MB_OK);
		str.Format("%.0f",m_gtvalue);
		pEdit->SetWindowText(str);
		pEdit->SetFocus();
		return;
	}
	
	m_gtvalue = dNewValue;

	str.Format("%.0f",m_gtvalue);
	pEdit->SetWindowText(str);
	
}

void CuiXlinePageACALDUAL::OnDeltaposXlscAcalTapcalibgainAllSpin(NMHDR* pNMHDR, LRESULT* pResult) 
{
	NM_UPDOWN* pNMUpDown = (NM_UPDOWN*)pNMHDR;
	
	CString	str;
	double	dNewValue;

	CEdit*	pEdit = (CEdit*)GetDlgItem(IDC_XLINE_ACAL_TAPCALIBGAIN_ALL_EDIT);
	pEdit->GetWindowText(str);
	dNewValue = atof(str);

	dNewValue	= (pNMUpDown->iDelta > 0) ? (dNewValue + 1) : (dNewValue - 1);
	if(dNewValue < m_gtvaluemin)		dNewValue = m_gtvaluemin;
	if(dNewValue > m_gtvaluemax)		dNewValue = m_gtvaluemax;

	m_gtvalue = dNewValue;

	str.Format("%.0f",m_gtvalue);
	pEdit->SetWindowText(str);
	
	*pResult = 0;
}

BOOL CuiXlinePageACALDUAL::getfromDCAM_gtvalue()
{
	// TapCalibGain
	int32	iProp = uipParam[TapCalibGain].attr.iProp;	// ch0
	
	BOOL	bProp_valuelow;
	BOOL	bProp_rangelow;

	// no channel
	// low:ch0, high:do not use
	bProp_valuelow = GetValuefromIDPROP(iProp, m_gtvalue);
	bProp_rangelow = GetMinMaxfromIDPROP(iProp, m_gtvaluemin, m_gtvaluemax);
	
	return TRUE;
}

BOOL CuiXlinePageACALDUAL::getfromDCAM_gtvaluearray()
{
	// TapCalibGain
	int32	iProp_ch0,iPropStep_ch0;				// ch0 property ID and ID step
	iProp_ch0 = uipParam[TapCalibGain].attr.iProp;	// set ch0 property ID
	
	int32	iProp_ch1,iPropStep_ch1;						// ch1 property ID and ID step
	int32	iProp_ch2,iPropStep_ch2;						// ch2 property ID and ID step

	BOOL	bArrayRaram_ch0, bArrayRaram_ch1, bArrayRaram_ch2;
	double	d_numberofelement_ch0, d_numberofelement_ch1, d_numberofelement_ch2;
	long	numberofelement_ch0, numberofelement_ch1, numberofelement_ch2;

	// ch1
	iProp_ch1 = MakeIDPROP_ch(iProp_ch0, 1);
	if(iProp_ch1 == 0)
	{	// do not have channel
		bArrayRaram_ch0 = GetArrayParam(iProp_ch0, iPropStep_ch0, d_numberofelement_ch0);
		if(bArrayRaram_ch0)
		{
			numberofelement_ch0 = (long)d_numberofelement_ch0;
			m_gtcount = numberofelement_ch0;

			// make memory
			if(p_gtlow != NULL)		delete[] p_gtlow;
			p_gtlow = new double[m_gtcount];
			if(p_gthigh != NULL)	delete[] p_gthigh;

			// get range
			GetMinMaxfromIDPROP(iProp_ch0,m_gtmin,m_gtmax);

			// get data
			long	lCount;
			for(lCount=0;lCount<numberofelement_ch0;lCount++)
			{
				GetValuefromIDPROP( MakeIDPROP_array(iProp_ch0,(int)lCount), (p_gtlow[lCount]) );
			}
		}
	}
	else
	{	// have channel
		iProp_ch2 = MakeIDPROP_ch(iProp_ch0, 2);
		if(iProp_ch2 == 0)
		{	// ch1 is available but ch2 is not available
		}
		else
		{	// ch1 and ch2 are available
			bArrayRaram_ch1 = GetArrayParam(iProp_ch1, iPropStep_ch1, d_numberofelement_ch1);
			bArrayRaram_ch2 = GetArrayParam(iProp_ch2, iPropStep_ch2, d_numberofelement_ch2);
			if(bArrayRaram_ch1 == TRUE && bArrayRaram_ch2 == TRUE)
			{
				numberofelement_ch1 = (long)d_numberofelement_ch1 / 2;
				numberofelement_ch2 = (long)d_numberofelement_ch2 / 2;
				m_gtcount = numberofelement_ch1;

				// make memory
				if(p_gtlow != NULL)		delete[] p_gtlow;
				p_gtlow = new double[m_gtcount];
				if(p_gthigh != NULL)	delete[] p_gthigh;
				p_gthigh = new double[m_gtcount];

				// get range
				GetMinMaxfromIDPROP(iProp_ch1,m_gtmin,m_gtmax);

				// get data
				long	lCount;
				for(lCount=0;lCount<numberofelement_ch1;lCount++)
				{
					GetValuefromIDPROP( MakeIDPROP_array(iProp_ch1,(int)lCount), (p_gtlow[lCount]) );
					GetValuefromIDPROP( MakeIDPROP_array(iProp_ch2,(int)lCount), (p_gthigh[lCount]) );
				}
			}
		}

	}

	return TRUE;
}

void CuiXlinePageACALDUAL::OnXlscAcalTapcalibgainAllButton() 
{
	int32	iProp_ch0 = DCAM_IDPROP_TAPCALIB_GAIN;
	double	value;
	CString	str;
	CEdit*	pEdit = (CEdit*)GetDlgItem(IDC_XLINE_ACAL_TAPCALIBGAIN_ALL_EDIT);
	pEdit->GetWindowText(str);
	value = atof(str);

	// set gt value to DCAM
	for(int i=0;i<m_gtcount;i++)
	{
		setvaluetoDCAM(MakeIDPROP_array(iProp_ch0,i), value);

	}
	
}

void CuiXlinePageACALDUAL::update_EnableStatus()
{
	CWnd*	pWnd;

	int		dwEnable[64];
	int		iCountEnable = 0;
	int		dwDisable[64];
	int		iCountDisable = 0;
	
	if(nCalibrating == TYPE_NONE_CALIBRATION)
	{
		dwEnable[iCountEnable] = IDC_XLINE_ACAL_TAPCALIBBASEDATAMEMORY_COMBO1;
		iCountEnable++;
		dwEnable[iCountEnable] = IDC_XLINE_ACAL_TAPCALIBBASEDATAMEMORY_COMBO2;
		iCountEnable++;
		dwEnable[iCountEnable] = IDC_XLINE_ACAL_TAPCALIBMETHOD_COMBO;
		iCountEnable++;
		dwEnable[iCountEnable] = IDC_XLINE_ACAL_TAPCALIBDATAMEMORY_COMBO;
		iCountEnable++;
		dwEnable[iCountEnable] = IDC_XLINE_ACAL_TAPCALIBGAIN_ALL_EDIT;
		iCountEnable++;
		dwEnable[iCountEnable] = IDC_XLINE_ACAL_TAPCALIBGAIN_ALL_SPIN;
		iCountEnable++;

	}
	else
	{
		dwDisable[iCountDisable] = IDC_XLINE_ACAL_TAPCALIBBASEDATAMEMORY_COMBO1;
		iCountDisable++;
		dwDisable[iCountDisable] = IDC_XLINE_ACAL_TAPCALIBBASEDATAMEMORY_COMBO2;
		iCountDisable++;
		dwDisable[iCountDisable] = IDC_XLINE_ACAL_TAPCALIBMETHOD_COMBO;
		iCountDisable++;
		dwDisable[iCountDisable] = IDC_XLINE_ACAL_TAPCALIBDATAMEMORY_COMBO;
		iCountDisable++;
		dwDisable[iCountDisable] = IDC_XLINE_ACAL_TAPCALIBGAIN_ALL_EDIT;
		iCountDisable++;
		dwDisable[iCountDisable] = IDC_XLINE_ACAL_TAPCALIBGAIN_ALL_SPIN;
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

BOOL CuiXlinePageACALDUAL::OnSetActive() 
{
	start_timer();
	
	return CPropertyPage::OnSetActive();
}

BOOL CuiXlinePageACALDUAL::PreTranslateMessage(MSG* pMsg) 
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
				case IDC_XLINE_ACAL_TAPGAINCALIBRATION_BUTTON:
					OnXlscAcalTapgaincalibrationButton();
					break;
				case IDC_XLINE_ACAL_TAPCALIBGAIN_EACH_BUTTON:
					OnXlscAcalTapcalibgainEachButton();
					break;
				case IDC_XLINE_ACAL_TAPCALIBBASEDATAMEMORY_COMBO1:
					break;
				case IDC_XLINE_ACAL_TAPCALIBBASEDATAMEMORY_COMBO2:
					break;
				case IDC_XLINE_ACAL_TAPCALIBMETHOD_COMBO:
					break;
				case IDC_XLINE_ACAL_TAPCALIBGAIN_ALL_EDIT:
					OnKillfocusXlscAcalTapcalibgainAllEdit();
					break;
				case IDC_XLINE_ACAL_TAPCALIBGAIN_ALL_BUTTON:
					OnXlscAcalTapcalibgainAllButton();
					break;
			}
			return 0;
		}
	}

	return CPropertyPage::PreTranslateMessage(pMsg);
}

void CuiXlinePageACALDUAL::OnXlscAcalTapcalibdatamemoryButton() 
{
	// TapCalibDataMemory
	int		nID = TapCalibDataMemory;
	CComboBox* pCombo = (CComboBox*)GetDlgItem(uipParam[nID].iComboBox);

	int nSelect = pCombo->GetCurSel();
	DWORD_PTR dItemData = pCombo->GetItemData(nSelect);
	double dNewValue = (double)dItemData;

	setvaluetoDCAM(uipParam[nID].attr.iProp, dNewValue);
	
	CheckUpdateDCAMPROP();

	
}

void CuiXlinePageACALDUAL::OnXlscAcalStoretapcalibdatamemoryButton() 
{
	// StoreTapCalibDataToMemory
	int		nID = TapCalibDataMemory;
	CComboBox* pCombo = (CComboBox*)GetDlgItem(uipParam[nID].iComboBox);

	int nSelect = pCombo->GetCurSel();
	DWORD_PTR dItemData = pCombo->GetItemData(nSelect);
	double dNewValue = (double)dItemData;

	setvaluetoDCAM(DCAM_IDPROP_STORETAPCALIBDATATOMEMORY, dNewValue);

	CheckUpdateDCAMPROP();
	
}


void CuiXlinePageACALDUAL::OnSelendokXlscAcalTapcalibbasedatamemoryCombo1() 
{
	// TapCalibBaseDataMemory_ch1
	int		nID = TapCalibBaseDataMemory_ch1;
	CComboBox* pCombo = (CComboBox*)GetDlgItem(uipParam[nID].iComboBox);

	int nSelect = pCombo->GetCurSel();
	DWORD_PTR dItemData = pCombo->GetItemData(nSelect);
	double dNewValue = (double)dItemData;

	setvaluetoDCAM(uipParam[nID].attr.iProp, dNewValue);

	CheckUpdateDCAMPROP();
	
}

void CuiXlinePageACALDUAL::OnSelendokXlscAcalTapcalibbasedatamemoryCombo2() 
{
	// TapCalibBaseDataMemory_ch2
	int		nID = TapCalibBaseDataMemory_ch2;
	CComboBox* pCombo = (CComboBox*)GetDlgItem(uipParam[nID].iComboBox);

	int nSelect = pCombo->GetCurSel();
	DWORD_PTR dItemData = pCombo->GetItemData(nSelect);
	double dNewValue = (double)dItemData;

	setvaluetoDCAM(uipParam[nID].attr.iProp, dNewValue);

	CheckUpdateDCAMPROP();
	
}

void CuiXlinePageACALDUAL::OnSelendokXlscAcalTapcalibmethodCombo() 
{
	// TapCalibMethod
	int		nID = TapCalibMethod;
	CComboBox* pCombo = (CComboBox*)GetDlgItem(uipParam[nID].iComboBox);

	int nSelect = pCombo->GetCurSel();
	DWORD_PTR dItemData = pCombo->GetItemData(nSelect);
	double dNewValue = (double)dItemData;

	setvaluetoDCAM(uipParam[nID].attr.iProp, dNewValue);

	CheckUpdateDCAMPROP();
	
}
