// ExCapUIPropertyPage.h

#ifndef _INCLUDE_EXCAPUI_PROPERTYPAGE_H_

#include	"uiXlineStructure.h"

class CExCapUIPropertyPage : public CPropertyPage
{
protected:
			~CExCapUIPropertyPage();
			CExCapUIPropertyPage();
			CExCapUIPropertyPage(UINT nIDTemplate, UINT nIDCaption = 0);
			CExCapUIPropertyPage(LPCTSTR lpszTemplateName, UINT nIDCaption = 0);

public:
	virtual	void	set_hdcam( HDCAM hdcam );

	long		showerrorcode();
	long		showerrorcode_notriggerenable();
	void		showinvalidtovalid();
	void		showoutofrange(int number);

	////////////////////////////////////////////////////////////////////////////
	long			iNumberOfProperty;
	EXCAP_UI_PARAM	uipParam[128];
	void			ClearParam(long lNumber);
	long			AddPropertyID(int32 iProp);
	void			CheckSupportDCAMPROP();
	void			CheckUpdateDCAMPROP();

	BOOL			updateattr(DCAM_PROPERTYATTR attr);
	BOOL			updatename(int32 iProp);
	BOOL			updatevalue(int32 iProp);		// get value from DCAM and set value to editbox and set spin range and pos for link with editbox
	BOOL			updateenable(int32 iProp);		// enable or disable control ID
	void			updatehide();					// hide if property ID is not supported

	BOOL			setvaluetoDCAM(int32 iProp,double value,BOOL bMessage = TRUE);	// set value to DCAM

	void			seteditvalue(int32 iProp);		// set value to editbox
	void			setspinvalue(int32 iProp);		// set spin range and pos for link with editbox
	void			setcomboboxitem(int32 iProp);	// set item to combobox
	void			setradiobutton(int32 iProp);	// set radio button (OFF/ON only)
	void			setcheckbox(int32 iProp);		// set check box 
	
	////////////////////////////////////////////////////////////////////////////
	void			input_on_killfocus(int nID);

	////////////////////////////////////////////////////////////////////////////
	// compare input
	CString			strModify;
	void			input_on_setfocus(int nID);

	////////////////////////////////////////////////////////////////////////////
	int32			MakeIDPROP_ch(int32 iPropBase, int32 ch);
	int32			MakeIDPROP_array(int32 iPropBase, int32 number);

	BOOL			GetArrayParam(int32 iPropBase, int32 &iPropStep, double &numberofelement);

	BOOL			GetValuefromIDPROP(int32 iProp, double &value);
	BOOL			GetMinMaxfromIDPROP(int32 iProp, double &min, double &max);

protected:
			void DDXDcam_LongSpin( CDataExchange* pDX, int idcEdit, int idcSpin, long idprop );
			void DDXDcam_TextLongSpin( CDataExchange* pDX, int idcText, int idcEdit, int idcSpin, long idprop );
			void DDXDcam_CBString( CDataExchange* pDX, int idcCombo, long idprop );
			void DDXDcam_Check(CDataExchange* pDX, int idcButton, long idprop );
			void DDXDcam_Radio(CDataExchange* pDX, int idcRadio, long idprop, long nStart = 0 );
			void modal_dcampropvalue( int idcEdit, long idprop );

protected:
	HDCAM	m_hdcam;
};

#define _INCLUDE_EXCAPUI_PROPERTYPAGE_H_
#endif
