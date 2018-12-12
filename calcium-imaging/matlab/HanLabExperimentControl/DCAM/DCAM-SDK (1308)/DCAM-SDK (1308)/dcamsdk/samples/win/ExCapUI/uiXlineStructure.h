/* **************************************************************** *

	structure declaration

 * **************************************************************** */


typedef struct EXCAP_UI_PARAM
{
	/*	supported	*/
	BOOL	bSupported;		// FALSE : target ID is not supported

	/*	DCAM-API property ID attribute	*/
	DCAM_PROPERTYATTR		attr;
	char					name[128];
	
	/*	value parameters	*/
	double	value;			/*	value or select											*/
	long	digits;			/*	value showing digits under decimal point [range 0 to 6]	*/		// for LONG or DOUBLE
	double	idvalue[128];		/*	id value set to DCAM property						*/		// for MODE
	long	numberofidvalue;	/*	id value set to DCAM property						*/

	/*	Dialog Resource ID parameters	*/
	int32	iEditBox;		/*	editbox for showing value								*/		// for LONG or DOUBLE
	int32	iSpin;			/*	spin button for changing value							*/		// for LONG or DOUBLE
	int32	iComboBox;		/*	combobox for showing select								*/		// for MODE
	int32	iRadio;			/*	radio button for showing select							*/		// for MODE
	int32	iCheckBox;		/*	checkbox for showing select								*/		// for MODE

} EXCAP_UI_PARAM;

