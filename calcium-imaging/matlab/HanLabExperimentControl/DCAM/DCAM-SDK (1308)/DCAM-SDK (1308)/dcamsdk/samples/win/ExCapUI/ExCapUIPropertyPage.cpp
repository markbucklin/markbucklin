// ExCapUIPropertyPage.cpp : implementation file
//

#include "stdafx.h"
#include "ExCapUI.h"
#include "uiXlineSetupDialog.h"

#ifdef _DEBUG
#define new DEBUG_NEW
#undef THIS_FILE
static char THIS_FILE[] = __FILE__;
#endif

/////////////////////////////////////////////////////////////////////////////

inline int find_itemdata( CComboBox* combo, DWORD nValue )
{
	int	i;
	for( i = combo->GetCount(); i-- > 0; )
	{
		if( combo->GetItemData( i ) == nValue )
			break;
	}

	return i;
}

/////////////////////////////////////////////////////////////////////////////
// CExCapUIPropertyPage

CExCapUIPropertyPage::~CExCapUIPropertyPage()
{
}

CExCapUIPropertyPage::CExCapUIPropertyPage()
{
	m_hdcam = NULL;
	iNumberOfProperty = 0;

}

CExCapUIPropertyPage::CExCapUIPropertyPage(UINT nIDTemplate, UINT nIDCaption )
	: CPropertyPage( nIDTemplate, nIDCaption )
{
	m_hdcam = NULL;
	iNumberOfProperty = 0;
}

CExCapUIPropertyPage::CExCapUIPropertyPage( LPCTSTR lpszTemplateName, UINT nIDCaption )
	: CPropertyPage( lpszTemplateName, nIDCaption )
{
	m_hdcam = NULL;
	iNumberOfProperty = 0;
}


/////////////////////////////////////////////////////////////////////////////
// CExCapUIPropertyPage

void CExCapUIPropertyPage::set_hdcam( HDCAM hdcam )
{
	m_hdcam = hdcam;
}

/////////////////////////////////////////////////////////////////////////////
//	error(dcam error)
long CExCapUIPropertyPage::showerrorcode()
{
	CString		strErrCode;
	char		err[1024];
	long		error_code;

	error_code = dcam_getlasterror(m_hdcam,err,1024);
	strErrCode = err;
	AfxMessageBox(strErrCode,MB_OK);

	return error_code;

}

//	error(dcam error for no trigger enable)
long CExCapUIPropertyPage::showerrorcode_notriggerenable()
{
	CString		strErrCode;
	char		err[1024];
	long		error_code;

	error_code = dcam_getlasterror(m_hdcam,err,1024);
	strErrCode = err;
	if(error_code == DCAMERR_NOTRIGGER)
	{
		strErrCode += "\n(Can not calibrate if Trigger Enable Active is START.)";
	}
	AfxMessageBox(strErrCode,MB_OK);

	return error_code;

}


//	error(input invalid value)
void CExCapUIPropertyPage::showinvalidtovalid()
{
	CString	str;

	str.Format("Input value is invalid value. Replace to valid value.");
	AfxMessageBox(str,MB_OK);
}

//	error(out of range)
void CExCapUIPropertyPage::showoutofrange(int number)
{
	CString	str;
	
	if		(uipParam[number].digits == 0)
		str.Format("Input value is out of range. Set value in range.[%.0f to %.0f]",uipParam[number].attr.valuemin,uipParam[number].attr.valuemax);
	else if	(uipParam[number].digits == 1)
		str.Format("Input value is out of range. Set value in range.[%.1f to %.1f]",uipParam[number].attr.valuemin,uipParam[number].attr.valuemax);
	else if	(uipParam[number].digits == 2)
		str.Format("Input value is out of range. Set value in range.[%.2f to %.2f]",uipParam[number].attr.valuemin,uipParam[number].attr.valuemax);
	else if	(uipParam[number].digits == 3)
		str.Format("Input value is out of range. Set value in range.[%.3f to %.3f]",uipParam[number].attr.valuemin,uipParam[number].attr.valuemax);
	else if	(uipParam[number].digits == 4)
		str.Format("Input value is out of range. Set value in range.[%.4f to %.4f]",uipParam[number].attr.valuemin,uipParam[number].attr.valuemax);
	else if	(uipParam[number].digits == 5)
		str.Format("Input value is out of range. Set value in range.[%.5f to %.5f]",uipParam[number].attr.valuemin,uipParam[number].attr.valuemax);
	else if	(uipParam[number].digits == 6)
		str.Format("Input value is out of range. Set value in range.[%.6f to %.6f]",uipParam[number].attr.valuemin,uipParam[number].attr.valuemax);
	else
		str.Format("Input value is out of range. Set value in range.[%.0f to %.0f]",uipParam[number].attr.valuemin,uipParam[number].attr.valuemax);

	AfxMessageBox(str,MB_OK);

}

////////////////////////////////////////////////////////////////////////////
void CExCapUIPropertyPage::ClearParam(long lNumber)
{
	memset(&(uipParam[lNumber].attr),0,sizeof(uipParam[lNumber].attr));
	uipParam[lNumber].iEditBox		= 0;
	uipParam[lNumber].iSpin			= 0;
	uipParam[lNumber].iCheckBox		= 0;
	uipParam[lNumber].iComboBox		= 0;
	uipParam[lNumber].iSpin			= 0;
	uipParam[lNumber].bSupported	= FALSE;
	
}

long CExCapUIPropertyPage::AddPropertyID(int32 iProp)
{
	if(iNumberOfProperty == 128)
	{
		return -1;
	}

	ClearParam(iNumberOfProperty);
	uipParam[iNumberOfProperty].attr.iProp	= iProp;
	iNumberOfProperty++;
	return iNumberOfProperty;
}

void CExCapUIPropertyPage::CheckSupportDCAMPROP()
{
	if(m_hdcam == NULL)		return;
	
	int32	iProp;		// property ID

	iProp = 0;
	if( dcam_getnextpropertyid( m_hdcam , &iProp , DCAMPROP_OPTION_SUPPORT ) )		// get first iProp supported
	{
		do
		{
			// The iProp value is a property ID that device supports
			
			// Getting property attribute
			DCAM_PROPERTYATTR attr;
			memset( &attr , 0 , sizeof(attr) );
			attr.cbSize = sizeof(attr);
			attr.iProp = iProp;
			dcam_getpropertyattr( m_hdcam , &attr );

			// update attr supported
			updateattr(attr);
			// Getting property name and update
			updatename(attr.iProp);
			// Getting property value and update
			updatevalue(attr.iProp);

			// if has channel
			if((attr.attribute & DCAMPROP_ATTR_HASCHANNEL))
			{
				// loop for channel
				int32	ich = 1;
				int32	iChannelProp = MakeIDPROP_ch(iProp,ich);
				if(iChannelProp != 0)
				{
					do
					{
						DCAM_PROPERTYATTR attr_ch;
						memset( &attr_ch , 0 , sizeof(attr_ch) );
						attr_ch.cbSize = sizeof(attr_ch);
						attr_ch.iProp = iChannelProp;
						dcam_getpropertyattr( m_hdcam , &attr_ch );

						// update attr supported
						updateattr(attr_ch);
						// Getting property name and update
						updatename(attr_ch.iProp);
						// Getting property value and update
						updatevalue(attr_ch.iProp);

						// if has array
						if(attr_ch.attribute2 & DCAMPROP_ATTR2_ARRAYBASE)
						{
							int32	iarray = 1;
							int32	iChannelArrayProp = MakeIDPROP_ch(iChannelProp,iarray);

							if(iChannelArrayProp != 0)
							{
								do
								{
									DCAM_PROPERTYATTR attr_array;
									memset( &attr_array , 0 , sizeof(attr_array) );
									attr_array.cbSize = sizeof(attr_array);
									attr_array.iProp = iChannelArrayProp;
									dcam_getpropertyattr( m_hdcam , &attr_array );

									// update attr supported
									updateattr(attr_array);
									// Getting property name and update
									updatename(attr_array.iProp);
									// Getting property value and update
									updatevalue(attr_array.iProp);

									iChannelArrayProp = MakeIDPROP_array(iChannelArrayProp,iarray++);
								}while(iChannelArrayProp != 0);
							}
						}
						iChannelProp = MakeIDPROP_ch(iChannelProp,ich++);
						
					}while(iChannelProp != 0);
				}
			}
			// no channel
			else		
			{

				// if has array
				if( (attr.attribute2 & DCAMPROP_ATTR2_ARRAYBASE) )
				{
					int32	iarray = 1;
					int32	iArrayProp = MakeIDPROP_array(iProp,iarray);

					if(iArrayProp != 0)
					{
						do
						{
							DCAM_PROPERTYATTR attr_array;
							memset( &attr_array , 0 , sizeof(attr_array) );
							attr_array.cbSize = sizeof(attr_array);
							attr_array.iProp = iArrayProp;
							dcam_getpropertyattr( m_hdcam , &attr_array );

							// update attr supported
							updateattr(attr_array);
							// Getting property name and update
							updatename(attr_array.iProp);
							// Getting property value and update
							updatevalue(attr_array.iProp);

							iArrayProp = MakeIDPROP_array(iProp,iarray++);
						}while(iArrayProp != 0);
					}
				}
				// no channel and no array, go to next iProp
			}
		} while( dcam_getnextpropertyid( m_hdcam , &iProp , DCAMPROP_OPTION_SUPPORT )
			&& iProp != 0);
	}
	else
	{
		AfxMessageBox("dcam_getnextpropertyid(DCAMPROP_OPTION_SUPPORT) is failed.",MB_OK);
		return;
	}

	updatehide();

}

void CExCapUIPropertyPage::CheckUpdateDCAMPROP()
{
	if(m_hdcam == NULL)		return;
	
	int32	iProp;		// property ID

	iProp = 0;
	if( dcam_getnextpropertyid( m_hdcam , &iProp , DCAMPROP_OPTION_UPDATED ) )
	{
		do{
			// The iProp value is an UPDATED property ID

			// Getting property attribute
			DCAM_PROPERTYATTR attr;
			memset( &attr , 0 , sizeof(attr) );
			attr.cbSize	= sizeof (attr);
			attr.iProp = iProp;
			dcam_getpropertyattr( m_hdcam , &attr );
			// update attr supported
			updateattr(attr);

			// Getting property value and update
			updatevalue(iProp);

		} while( dcam_getnextpropertyid( m_hdcam , &iProp , DCAMPROP_OPTION_UPDATED )
			&& iProp != 0);
	}
}

BOOL CExCapUIPropertyPage::setvaluetoDCAM(int32 iProp,double value,BOOL bMessage)
{
	BOOL	bSendRet = FALSE;
	if(m_hdcam == NULL)		return bSendRet;
	
	// set to DCAM
	bSendRet = dcam_setpropertyvalue( m_hdcam, iProp, value );
	if(!bSendRet && bMessage)
	{
		showerrorcode();
		return bSendRet;
	}

	return bSendRet;

}


BOOL CExCapUIPropertyPage::updateattr(DCAM_PROPERTYATTR attr)
{
	long	lNumber = 0;

	for(lNumber=0;lNumber<iNumberOfProperty;lNumber++)
	{
		if(uipParam[lNumber].attr.iProp == attr.iProp)
		{
			uipParam[lNumber].bSupported = TRUE;
			uipParam[lNumber].attr = attr;
			if((uipParam[lNumber].attr.attribute & DCAMPROP_TYPE_MASK) == DCAMPROP_TYPE_LONG)
			{
				uipParam[lNumber].digits = 0;
				setcheckbox(uipParam[lNumber].attr.iProp);
			}
			if((uipParam[lNumber].attr.attribute & DCAMPROP_TYPE_MASK) == DCAMPROP_TYPE_MODE)
			{
				setcomboboxitem(uipParam[lNumber].attr.iProp);
				setradiobutton(uipParam[lNumber].attr.iProp);
				setcheckbox(uipParam[lNumber].attr.iProp);
			}

			updateenable(uipParam[lNumber].attr.iProp);

			return TRUE;
		}
	}
	return FALSE;
}

BOOL CExCapUIPropertyPage::updatename(int32 iProp)
{
	long	lNumber = 0;
	char	name[128];
	BOOL	bName = FALSE;
	for(lNumber=0;lNumber<iNumberOfProperty;lNumber++)
	{
		if(uipParam[lNumber].attr.iProp == iProp)
		{
			bName = dcam_getpropertyname( m_hdcam , iProp , name , sizeof(name) ) ;
			if(!bName)		return bName;

			strcpy_s(uipParam[lNumber].name, sizeof(uipParam[lNumber].name), name);
			return bName;
		}
	}
	return bName;
}

BOOL CExCapUIPropertyPage::updatevalue(int32 iProp)
{
	long	lNumber = 0;
	double	value;
	BOOL	bValue = FALSE;
	for(lNumber=0;lNumber<iNumberOfProperty;lNumber++)
	{
		if(uipParam[lNumber].attr.iProp == iProp)
		{
			bValue = dcam_getpropertyvalue( m_hdcam , iProp , &value );
			if(!bValue)	return bValue;

			uipParam[lNumber].value = value;
			seteditvalue(iProp);
			setspinvalue(iProp);
			// add source code for set combo box cursel
			return bValue;
		}
	}
	return bValue;
}

BOOL CExCapUIPropertyPage::updateenable(int32 iProp)
{
	DWORD	dwStatusDCAM;
	BOOL bStatus = dcam_getstatus(m_hdcam, &dwStatusDCAM);
	if(!bStatus)
	{
		return bStatus;
	}

	CWnd* pWnd;
	BOOL	bEnable;

	long	lNumber = 0;
	for(lNumber=0;lNumber<iNumberOfProperty;lNumber++)
	{
		if(uipParam[lNumber].attr.iProp == iProp)
		{
			if(dwStatusDCAM == DCAM_STATUS_BUSY)	// busy
			{
				if(uipParam[lNumber].attr.attribute & DCAMPROP_ATTR_ACCESSBUSY )	// access busy
				{
					if(uipParam[lNumber].attr.attribute & DCAMPROP_ATTR_EFFECTIVE)	// effective : enable
					{
						bEnable = TRUE;
					}
					else															// not effective : disable
					{
						bEnable = FALSE;
					}
				}
				else																// not access busy : disable
				{
					bEnable = FALSE;
				}
			}
			else if(dwStatusDCAM == DCAM_STATUS_READY)	// ready
			{
				if(uipParam[lNumber].attr.attribute & DCAMPROP_ATTR_ACCESSREADY )
				{
					if(uipParam[lNumber].attr.attribute & DCAMPROP_ATTR_EFFECTIVE)	// effective : enable
					{
						bEnable = TRUE;
					}
					else															// not effective : disable
					{
						bEnable = FALSE;
					}
				}
				else
				{
					bEnable = FALSE;
				}
			}
			else if(dwStatusDCAM == DCAM_STATUS_STABLE)	// stable
			{
				if(uipParam[lNumber].attr.attribute & DCAMPROP_ATTR_EFFECTIVE)	// effective : enable
				{
					bEnable = TRUE;
				}
				else															// not effective : disable
				{
					bEnable = FALSE;
				}
			}
			else if(dwStatusDCAM == DCAM_STATUS_UNSTABLE)	// unstable
			{
				if(uipParam[lNumber].attr.attribute & DCAMPROP_ATTR_EFFECTIVE)	// effective : enable
				{
					bEnable = TRUE;
				}
				else															// not effective : disable
				{
					bEnable = FALSE;
				}
			}
			else		// error : disable
			{
				bEnable = FALSE;
			}

			if(uipParam[lNumber].iEditBox != 0)		// edit box
			{
				pWnd = GetDlgItem(uipParam[lNumber].iEditBox);
				pWnd->EnableWindow(bEnable);
			}
			if(uipParam[lNumber].iSpin != 0)		// spin button
			{
				pWnd = GetDlgItem(uipParam[lNumber].iSpin);
				pWnd->EnableWindow(bEnable);
			}
			if(uipParam[lNumber].iComboBox != 0)		// combo box
			{
				pWnd = GetDlgItem(uipParam[lNumber].iComboBox);
				pWnd->EnableWindow(bEnable);
			}
			if(uipParam[lNumber].iCheckBox != 0)		// check box
			{
				pWnd = GetDlgItem(uipParam[lNumber].iCheckBox);
				pWnd->EnableWindow(bEnable);
			}
		}
	}
	return bStatus;
}

void CExCapUIPropertyPage::updatehide()
{
	CWnd* pWnd;

	long	lNumber = 0;
	for(lNumber=0;lNumber<iNumberOfProperty;lNumber++)
	{
		if(!uipParam[lNumber].bSupported)
		{
			if(uipParam[lNumber].iEditBox != 0)		// edit box
			{
				pWnd = GetDlgItem(uipParam[lNumber].iEditBox);
				pWnd->ShowWindow(SW_HIDE);
			}
			if(uipParam[lNumber].iSpin != 0)		// spin button
			{
				pWnd = GetDlgItem(uipParam[lNumber].iSpin);
				pWnd->ShowWindow(SW_HIDE);
			}
			if(uipParam[lNumber].iComboBox != 0)		// combo box
			{
				pWnd = GetDlgItem(uipParam[lNumber].iComboBox);
				pWnd->ShowWindow(SW_HIDE);
			}
			if(uipParam[lNumber].iCheckBox != 0)		// check box
			{
				pWnd = GetDlgItem(uipParam[lNumber].iCheckBox);
				pWnd->ShowWindow(SW_HIDE);
			}
		}
	}
}

void CExCapUIPropertyPage::seteditvalue(int32 iProp)
{
	CString	str;
	CEdit*	pEdit;

	long	lNumber = 0;
	for(lNumber=0;lNumber<iNumberOfProperty;lNumber++)
	{
		if(uipParam[lNumber].attr.iProp == iProp)	// id is supported
		{
			if(uipParam[lNumber].iEditBox != 0)		// edit box is supported
			{
				pEdit = (CEdit*)GetDlgItem(uipParam[lNumber].iEditBox);
				if(uipParam[lNumber].digits == 0)			// showing digits is 0
				{
					str.Format("%.0f",uipParam[lNumber].value);
					pEdit->SetWindowText(str);
				}
				else if(uipParam[lNumber].digits == 1)	// showing digits is 1
				{
					str.Format("%.1f",uipParam[lNumber].value);
					pEdit->SetWindowText(str);
				}
				else if(uipParam[lNumber].digits == 2)	// showing digits is 2
				{
					str.Format("%.2f",uipParam[lNumber].value);
					pEdit->SetWindowText(str);
				}
				else if(uipParam[lNumber].digits == 3)	// showing digits is 3
				{
					str.Format("%.3f",uipParam[lNumber].value);
					pEdit->SetWindowText(str);
				}
				else if(uipParam[lNumber].digits == 4)	// showing digits is 4
				{
					str.Format("%.4f",uipParam[lNumber].value);
					pEdit->SetWindowText(str);
				}
				else if(uipParam[lNumber].digits == 5)	// showing digits is 5
				{
					str.Format("%.5f",uipParam[lNumber].value);
					pEdit->SetWindowText(str);
				}
				else if(uipParam[lNumber].digits == 6)	// showing digits is 6
				{
					str.Format("%.6f",uipParam[lNumber].value);
					pEdit->SetWindowText(str);
				}
				else									// showing digits is anything
				{
					str.Format("%.0f",uipParam[lNumber].value);
					pEdit->SetWindowText(str);
				}
			}
		}
	}
}

void CExCapUIPropertyPage::setspinvalue(int32 iProp)
{
	CSpinButtonCtrl*	pSpin;

	long	lNumber = 0;
	for(lNumber=0;lNumber<iNumberOfProperty;lNumber++)
	{
		if(uipParam[lNumber].attr.iProp == iProp)
		{
			if(uipParam[lNumber].iSpin != 0)
			{
				pSpin = (CSpinButtonCtrl*)GetDlgItem(uipParam[lNumber].iSpin);
				pSpin->SetRange(-1,1);
				pSpin->SetPos(0);
			}
		}
	}

}

void CExCapUIPropertyPage::setcomboboxitem(int32 iProp)
{
	char	text[ 128 ];
	CString	str;
	double	fValue;
	CComboBox*	pComboBox;

	BOOL	bRetAttr;
	// for DCAM-API
	DCAM_PROPERTYATTR	attr;
	memset (& attr, 0, sizeof (attr));
	attr.cbSize	= sizeof (attr);

	long	lNumber = 0;
	for(lNumber=0;lNumber<iNumberOfProperty;lNumber++)
	{
		if(uipParam[lNumber].attr.iProp == iProp)
		{
			if(uipParam[lNumber].iComboBox != 0)
			{
				attr.iProp	= iProp;
				bRetAttr = dcam_getpropertyattr( m_hdcam, & attr );

				pComboBox = (CComboBox*)GetDlgItem(uipParam[lNumber].iComboBox);
				pComboBox->ResetContent();

				if(attr.attribute & DCAMPROP_ATTR_HASVALUETEXT)		// ID has textvalue
				{
					// set textvalue to combobox
					for(fValue = uipParam[lNumber].attr.valuemin; fValue <= uipParam[lNumber].attr.valuemax;)
					{
						DCAM_PROPERTYVALUETEXT	pvt;
						memset( &pvt, 0, sizeof( pvt ) );
						pvt.cbSize	= sizeof( pvt );
						pvt.iProp	= uipParam[lNumber].attr.iProp;
						pvt.value	= fValue;
						pvt.text	= text;
						pvt.textbytes=sizeof( text );

						if( dcam_getpropertyvaluetext( m_hdcam, &pvt ) )
						{
							str = text;
							uipParam[lNumber].numberofidvalue = pComboBox->AddString( str );
							pComboBox->SetItemData( uipParam[lNumber].numberofidvalue, (long)floor( fValue ) );
						}

						if(! dcam_querypropertyvalue( m_hdcam, uipParam[lNumber].attr.iProp, &fValue, DCAMPROP_OPTION_NEXT ) )
						{
							break;
						}
					}

				}
				else		// ID do not has text
				{
					// set value to combobox
					for(fValue = uipParam[lNumber].attr.valuemin; fValue <= uipParam[lNumber].attr.valuemax;)
					{
						str.Format("%.0f",fValue);
						uipParam[lNumber].numberofidvalue = pComboBox->AddString( str );
						pComboBox->SetItemData( uipParam[lNumber].numberofidvalue, (long)floor( fValue ) );
						
						if(! dcam_querypropertyvalue( m_hdcam, uipParam[lNumber].attr.iProp, &fValue, DCAMPROP_OPTION_NEXT ) )
						{
							break;
						}
					}
				}

				// get value from DCAM and set cursol to combobox
				dcam_getpropertyvalue( m_hdcam, uipParam[lNumber].attr.iProp, &fValue );
				int	nValue = (int)fValue;
				pComboBox->SetCurSel( find_itemdata( pComboBox, nValue ) );

			}
		}
	}

}

void CExCapUIPropertyPage::setradiobutton(int32 iProp)
{
	CString	str;
	double	fValue;

	long	lNumber = 0;
	for(lNumber=0;lNumber<iNumberOfProperty;lNumber++)
	{
		if(uipParam[lNumber].attr.iProp == iProp)
		{
			if(uipParam[lNumber].iRadio != 0)
			{
				if(uipParam[lNumber].numberofidvalue != 0)
					uipParam[lNumber].numberofidvalue = 0;
				dcam_querypropertyvalue( m_hdcam , iProp , &fValue , DCAMPROP_OPTION_NEXT );
				// query idvalue 
				do
				{
					uipParam[lNumber].idvalue[uipParam[lNumber].numberofidvalue] = fValue;
					uipParam[lNumber].numberofidvalue++;
				}while(dcam_querypropertyvalue( m_hdcam , iProp , &fValue , DCAMPROP_OPTION_NEXT ));

				dcam_getpropertyvalue( m_hdcam, uipParam[lNumber].attr.iProp, &fValue );
			}
		}
	}
	
}


void CExCapUIPropertyPage::setcheckbox(int32 iProp)
{
	CString	str;
	double	fValue = 0.0000;
	CButton* pCheck;

	long	lNumber = 0;
	for(lNumber=0;lNumber<iNumberOfProperty;lNumber++)
	{
		if(uipParam[lNumber].attr.iProp == iProp)
		{
			if(uipParam[lNumber].iCheckBox != 0)
			{
				if(uipParam[lNumber].numberofidvalue != 0)
					uipParam[lNumber].numberofidvalue = 0;

				if( (uipParam[lNumber].attr.attribute & DCAMPROP_TYPE_MASK) == DCAMPROP_TYPE_MODE)
				{
					dcam_querypropertyvalue( m_hdcam , iProp , &fValue , DCAMPROP_OPTION_NEXT );
					// query idvalue 
					do
					{
						uipParam[lNumber].idvalue[uipParam[lNumber].numberofidvalue] = fValue;
						uipParam[lNumber].numberofidvalue++;
					}while(dcam_querypropertyvalue( m_hdcam , iProp , &fValue , DCAMPROP_OPTION_NEXT ));
	
					dcam_getpropertyvalue( m_hdcam, uipParam[lNumber].attr.iProp, &fValue );
					for(int i = 0; i < uipParam[lNumber].numberofidvalue; i++)
					{
						if(fValue == uipParam[lNumber].idvalue[0])
						{
							pCheck = (CButton*)GetDlgItem(uipParam[lNumber].iCheckBox);
							pCheck->SetCheck(BST_UNCHECKED);
						}
						else if(fValue == uipParam[lNumber].idvalue[1])
						{
							pCheck = (CButton*)GetDlgItem(uipParam[lNumber].iCheckBox);
							pCheck->SetCheck(BST_CHECKED);
						}
						else		// value is not found
						{
						}
					}
				}
				else if( (uipParam[lNumber].attr.attribute & DCAMPROP_TYPE_MASK) == DCAMPROP_TYPE_LONG)
				{	// for DigitalBinning only
					dcam_getpropertyvalue( m_hdcam, uipParam[lNumber].attr.iProp, &fValue );
					if(fValue == 1)
					{
						pCheck = (CButton*)GetDlgItem(uipParam[lNumber].iCheckBox);
						pCheck->SetCheck(BST_UNCHECKED);
					}
					else if(fValue == 2)
					{
						pCheck = (CButton*)GetDlgItem(uipParam[lNumber].iCheckBox);
						pCheck->SetCheck(BST_CHECKED);
					}
					else		// value is not found
					{
					}
				}
			}
		}
	}
	
}

////////////////////////////////////////////////////////////////////////////
void CExCapUIPropertyPage::input_on_killfocus(int nID)
{
	CString	str;
	double	dNewValue;

	CEdit*	pEdit = (CEdit*)GetDlgItem(uipParam[nID].iEditBox);
	pEdit->GetWindowText(str);

	// compare input
	if( ! str.Compare(strModify) )
	{
		return;
	}

	dNewValue = atof(str);

	// out of range
	if(dNewValue < uipParam[nID].attr.valuemin || dNewValue > uipParam[nID].attr.valuemax)
	{
		seteditvalue(uipParam[nID].attr.iProp);
		showoutofrange(nID);
		pEdit->SetFocus();
		return;
	}
	
	// invalid value
	if( ! dcam_querypropertyvalue(m_hdcam,uipParam[nID].attr.iProp,&dNewValue,DCAMPROP_OPTION_NONE) )
	{
		seteditvalue(uipParam[nID].attr.iProp);
		showinvalidtovalid();
		pEdit->SetFocus();
		return;
	}

	// error on dcam_setpropertyvalue
	if( ! setvaluetoDCAM(uipParam[nID].attr.iProp, dNewValue, FALSE) )
	{
		seteditvalue(uipParam[nID].attr.iProp);
		AfxMessageBox("dcam_setpropertyvalue is failed.",MB_OK);
		pEdit->SetFocus();
		return;
	}

	updatevalue(uipParam[nID].attr.iProp);

	CheckUpdateDCAMPROP();

	// compare input
	pEdit->GetWindowText(strModify);
}

////////////////////////////////////////////////////////////////////////////
void CExCapUIPropertyPage::input_on_setfocus(int nID)
{
	CEdit*	pEdit = (CEdit*)GetDlgItem(uipParam[nID].iEditBox);
	pEdit->GetWindowText(strModify);

}

////////////////////////////////////////////////////////////////////////////
int32 CExCapUIPropertyPage::MakeIDPROP_ch(int32 iPropBase, int32 ch)
{
	int32 iProp = 0;
	if(m_hdcam == NULL)		return iProp;

	BOOL	bAttr;

	// get attribute
	DCAM_PROPERTYATTR attr;
	memset( &attr , 0 , sizeof(attr) );
	attr.cbSize	= sizeof (attr);
	attr.iProp = iPropBase;
	bAttr = dcam_getpropertyattr( m_hdcam , &attr );
	if(!bAttr)
	{
		return iProp;	// now iProp=0 and return error
	}

	// check attribute
	if( !(attr.attribute & DCAMPROP_ATTR_HASCHANNEL) )
	{	// iPropBase do not have channel
		return iProp;	// now iProp=0 and return error
	}

	// check the channel number
	if( ch > attr.nMaxChannel )
	{	// ch is over max of channel
		return iProp;	// now iProp=0 and return error
	}

	// make iProp
	iProp = attr.iProp + ch * DCAM_IDPROP__CHANNEL;

	return iProp;
}

int32 CExCapUIPropertyPage::MakeIDPROP_array(int32 iPropBase, int32 number)
{
	int32 iProp = 0;
	if(m_hdcam == NULL)		return iProp;

	BOOL	bAttr,bAttr_element;

	// get attribute
	DCAM_PROPERTYATTR attr;
	memset( &attr , 0 , sizeof(attr) );
	attr.cbSize	= sizeof (attr);
	attr.iProp = iPropBase;
	bAttr = dcam_getpropertyattr( m_hdcam , &attr );
	if(!bAttr)
	{
		return iProp;	// now iProp=0 and return error
	}

	// check attribute
	if( !(attr.attribute2 & DCAMPROP_ATTR2_ARRAYBASE) )
	{	// iPropBase is not arraybase
		return iProp;	// now iProp=0 and return error
	}

	// check the channel number
	DCAM_PROPERTYATTR attr_element;
	memset( &attr_element , 0 , sizeof(attr_element) );
	attr_element.cbSize	= sizeof (attr_element);
	attr_element.iProp = attr.iProp_NumberOfElement;
	bAttr_element = dcam_getpropertyattr( m_hdcam , &attr_element );
	if(!bAttr_element)
	{	// number of element is not supported
		return iProp;	// now iProp=0 and return error
	}

	if( number >= attr_element.valuemax )
	{	// number is over number of element
		return iProp;	// now iProp=0 and return error
	}

	// make iProp
	iProp = attr.iProp + number * attr.iPropStep_Element;

	return iProp;
}


BOOL CExCapUIPropertyPage::GetArrayParam(int32 iPropBase, int32 &iPropStep, double &numberofelement)
{
	BOOL	bSuccess = FALSE;
	if(m_hdcam == NULL)		return bSuccess;

	BOOL	bAttr,bAttr_element;

	// get attribute
	DCAM_PROPERTYATTR attr;
	memset( &attr , 0 , sizeof(attr) );
	attr.cbSize	= sizeof (attr);
	attr.iProp = iPropBase;
	bAttr = dcam_getpropertyattr( m_hdcam , &attr );
	if(!bAttr)
	{
		return bSuccess;	// now iProp=0 and return error
	}

	// check attribute
	if( !(attr.attribute2 & DCAMPROP_ATTR2_ARRAYBASE) )
	{	// iPropBase is not arraybase
		return bSuccess;	// now iProp=0 and return error
	}
	iPropStep = attr.iPropStep_Element;

	// check the channel number
	DCAM_PROPERTYATTR attr_element;
	memset( &attr_element , 0 , sizeof(attr_element) );
	attr_element.cbSize	= sizeof (attr_element);
	attr_element.iProp = attr.iProp_NumberOfElement;
	bAttr_element = dcam_getpropertyattr( m_hdcam , &attr_element );
	if(!bAttr_element)
	{	// number of element is not supported
		return bSuccess;	// now iProp=0 and return error
	}
	numberofelement = attr_element.valuemax;

	bSuccess = TRUE;

	return bSuccess;
}

BOOL CExCapUIPropertyPage::GetValuefromIDPROP(int32 iProp, double &value)
{
	BOOL	bSuccess = FALSE;
	BOOL	bValue;
	double	dValue;
	if(m_hdcam == NULL)		return bSuccess;

	// get value
	bValue = dcam_getpropertyvalue( m_hdcam, iProp, &dValue );
	if(!bValue)
	{
		return bSuccess;	// now iProp=0 and return error
	}
	value = dValue;
	bSuccess = TRUE;

	return bSuccess;
}

BOOL CExCapUIPropertyPage::GetMinMaxfromIDPROP(int32 iProp, double &min, double &max)
{
	BOOL	bSuccess = FALSE;
	BOOL	bAttr;
	if(m_hdcam == NULL)		return bSuccess;

	// get attribute
	DCAM_PROPERTYATTR attr;
	memset( &attr , 0 , sizeof(attr) );
	attr.cbSize	= sizeof (attr);
	attr.iProp = iProp;
	bAttr = dcam_getpropertyattr( m_hdcam , &attr );
	if(!bAttr)
	{
		return bSuccess;	// now iProp=0 and return error
	}

	// check attribute
	if( !(attr.attribute & DCAMPROP_ATTR_HASRANGE) )
	{	// iPropBase do not have range
		return bSuccess;	// now iProp=0 and return error
	}

	// get min and max
	min = attr.valuemin;
	max	= attr.valuemax;

	bSuccess = TRUE;

	return bSuccess;
}

/////////////////////////////////////////////////////////////////////////////

void CExCapUIPropertyPage::DDXDcam_LongSpin( CDataExchange* pDX, int idcEdit, int idcSpin, long idprop )
{
	ASSERT( m_hdcam != NULL );

	if( pDX->m_bSaveAndValidate )
	{
		if( GetDlgItem( idcEdit )->IsWindowEnabled() )
		{
			long	nValue = GetDlgItemInt( idcEdit );

			if( ! dcam_setpropertyvalue( m_hdcam, idprop, nValue ) )
			{
				pDX->Fail();
			}
		}
	}
	else
	{
		double	fValue;

		CSpinButtonCtrl*	spin = (CSpinButtonCtrl*)GetDlgItem( idcSpin );

		if( ! dcam_getpropertyvalue( m_hdcam, idprop, &fValue ) )
		{
			spin->EnableWindow( FALSE );
			GetDlgItem( idcEdit )->EnableWindow( FALSE );
		}
		else
		{
			spin->EnableWindow( TRUE );

			int	nCurrent = (int)fValue;

			SetDlgItemInt( idcEdit, nCurrent );

			DCAM_PROPERTYATTR	attr;
			memset( &attr, 0, sizeof( attr ) );
			attr.cbSize = sizeof( attr );
			attr.iProp = idprop;

			VERIFY( dcam_getpropertyattr( m_hdcam, &attr ) );
			ASSERT( ( attr.attribute & DCAMPROP_TYPE_MASK ) == DCAMPROP_TYPE_LONG );

			int	nLower = (int)attr.valuemin;
			int	nHigher = (int)attr.valuemax;
			spin->SetRange32( nLower, nHigher );

			UDACCEL	udaccel[3];
			udaccel[0].nSec = 1;
			udaccel[0].nInc = 1;
			udaccel[1].nSec = 2;
			udaccel[1].nInc = 10;
			udaccel[2].nSec = 3;
			udaccel[2].nInc = 100;
			spin->SetAccel( 3, udaccel );

			spin->SetPos( nCurrent );
		}
	}
}

void CExCapUIPropertyPage::DDXDcam_TextLongSpin( CDataExchange* pDX, int idcText, int idcEdit, int idcSpin, long idprop )
{
	CWnd*	wndText = GetDlgItem( idcText );

	ASSERT( m_hdcam != NULL );

	if( pDX->m_bSaveAndValidate )
	{
		if( wndText->IsWindowEnabled() )
		{
			DDXDcam_LongSpin( pDX, idcEdit, idcSpin, idprop );
		}
	}
	else
	{
		double	fValue;

		if( ! dcam_getpropertyvalue( m_hdcam, idprop, &fValue ) )
		{
			wndText->EnableWindow( FALSE );	// this makes no calling DDXDcam_LongSpin at saving.
		}
		else
		{
			wndText->EnableWindow( TRUE );
			DDXDcam_LongSpin( pDX, idcEdit, idcSpin, idprop );
		}
	}
}

void CExCapUIPropertyPage::DDXDcam_CBString( CDataExchange* pDX, int idcCombo, long idprop )
{
	ASSERT( m_hdcam != NULL );

	CComboBox*	combo = (CComboBox*)GetDlgItem( idcCombo );

	if( pDX->m_bSaveAndValidate )
	{
		if( combo->IsWindowEnabled() )
		{
			long	i = combo->GetCurSel();
			long	nValue = (long)combo->GetItemData( i );

			if( ! dcam_setpropertyvalue( m_hdcam, idprop, nValue ) )
			{
				pDX->Fail();
			}
		}
	}
	else
	{
		combo->ResetContent();

		DCAM_PROPERTYATTR	attr;
		memset( &attr, 0, sizeof( attr ) );
		attr.cbSize = sizeof( attr );
		attr.iProp = idprop;

		if( ! dcam_getpropertyattr( m_hdcam, &attr ) )
		{
			combo->EnableWindow( FALSE );
		}
		else
		{
			combo->EnableWindow( TRUE );

			ASSERT( ( attr.attribute & DCAMPROP_TYPE_MASK ) != DCAMPROP_TYPE_REAL );

			double	fValue;

			fValue = attr.valuemin;
			do {
				ASSERT( fValue == floor( fValue ) );

				CString	str;

				if( attr.attribute & DCAMPROP_TYPE_MODE )
				{
					char	text[ 128 ];

					DCAM_PROPERTYVALUETEXT	pvt;
					memset( &pvt, 0, sizeof( pvt ) );
					pvt.cbSize	= sizeof( pvt );
					pvt.iProp	= idprop;
					pvt.value	= fValue;
					pvt.text	= text;
					pvt.textbytes=sizeof( text );

					VERIFY( dcam_getpropertyvaluetext( m_hdcam, &pvt ) );
					str = text;
				}
				else
				if( attr.attribute & DCAMPROP_TYPE_LONG )
				{
					str.Format( _T( "%d" ), (long)fValue );
				}
				else
					ASSERT( 0 );

				int	i = combo->AddString( str );
				combo->SetItemData( i, (long)floor( fValue ) );
			} while( dcam_querypropertyvalue( m_hdcam, idprop, &fValue, DCAMPROP_OPTION_NEXT ) );

			VERIFY( dcam_getpropertyvalue( m_hdcam, idprop, &fValue ) );

			int	nValue = (int)fValue;

			combo->SetCurSel( find_itemdata( combo, nValue ) );
		}
	}
}

void CExCapUIPropertyPage::DDXDcam_Check(CDataExchange* pDX, int idcButton, long idprop )
{
	if( pDX->m_bSaveAndValidate )
	{
		if( GetDlgItem( idcButton )->IsWindowEnabled() )
		{
			int	nValue;

			DDX_Check( pDX, idcButton, nValue );

			VERIFY( dcam_setpropertyvalue( m_hdcam, idprop, nValue ? DCAMPROP_MODE__ON : DCAMPROP_MODE__OFF ) );
		}
	}
	else
	{
		double	fValue;

		if( ! dcam_getpropertyvalue( m_hdcam, idprop, &fValue ) )
		{
			GetDlgItem( idcButton )->EnableWindow( FALSE );
		}
		else
		{
			GetDlgItem( idcButton )->EnableWindow( TRUE );

			ASSERT( fValue == DCAMPROP_MODE__ON || fValue == DCAMPROP_MODE__OFF );

			int	nValue = ( fValue != DCAMPROP_MODE__OFF );

			DDX_Check( pDX, idcButton, nValue );
		}
	}
}

void CExCapUIPropertyPage::DDXDcam_Radio(CDataExchange* pDX, int idcRadio, long idprop, long nStart )
{
	BOOL	bEnable;
	int	value = -1;

	if (pDX->m_bSaveAndValidate)
	{
	//	value = -1;     // value if none found
	}
	else
	{
		double	fValue;

		bEnable = dcam_getpropertyvalue( m_hdcam, idprop, &fValue );
		if( bEnable )
		{
			ASSERT( fValue == floor( fValue ) );
			value = (int)fValue - nStart;
		}
	}

	// void AFXAPI DDX_Radio(CDataExchange* pDX, int nIDC, int& value)
	{
		HWND hWndCtrl = pDX->PrepareCtrl(idcRadio);

		ASSERT(::GetWindowLong(hWndCtrl, GWL_STYLE) & WS_GROUP);
		ASSERT(::SendMessage(hWndCtrl, WM_GETDLGCODE, 0, 0L) & DLGC_RADIOBUTTON);

		// walk all children in group
		int iButton = 0;
		do
		{
			if (::SendMessage(hWndCtrl, WM_GETDLGCODE, 0, 0L) & DLGC_RADIOBUTTON)
			{
				// control in group is a radio button
				if (pDX->m_bSaveAndValidate)
				{
					if (::SendMessage(hWndCtrl, BM_GETCHECK, 0, 0L) != 0)
					{
						ASSERT(value == -1);    // only set once
						value = iButton;
					}
				}
				else
				{
					::EnableWindow( hWndCtrl, bEnable );
					// select button
					::SendMessage(hWndCtrl, BM_SETCHECK, (iButton == value), 0L);
				}
				iButton++;
			}
			else
			{
				TRACE0("Warning: skipping non-radio button in group.\n");
			}
			hWndCtrl = ::GetWindow(hWndCtrl, GW_HWNDNEXT);

		} while (hWndCtrl != NULL &&
			!(GetWindowLong(hWndCtrl, GWL_STYLE) & WS_GROUP));
	} // end of DDX_Radio()
	
	if( pDX->m_bSaveAndValidate )
	{
		if( value >= 0 )	// value is found
			VERIFY( dcam_setpropertyvalue( m_hdcam, idprop, value + nStart ) );
	}
}

#include "uiPropvalue.h"

void CExCapUIPropertyPage::modal_dcampropvalue( int idcEdit, long idprop )
{
	CuiPropvalue	dlg( this, idcEdit );

	DCAM_PROPERTYATTR	attr;
	memset( &attr, 0, sizeof( attr ) );
	attr.cbSize = sizeof( attr );
	attr.iProp = idprop;

	VERIFY( dcam_getpropertyattr( m_hdcam, &attr ) );
	
	double	value;
	VERIFY( dcam_getpropertyvalue( m_hdcam, idprop, &value ) );

	dlg.setvalue( value, attr.valuemax, attr.valuemin, attr.valuestep );

	if( dlg.DoModal() == IDOK )
	{
		value = dlg.getvalue();

		if( ! dcam_setpropertyvalue( m_hdcam, idprop, value ) )
			show_dcamerrorbox (m_hdcam, "dcam_setpropertyvalue()");
	}
}

