// uiXline.cpp
//

#include "stdafx.h"
#include "excapui.h"
#include "uiXline.h"

#include "uiXlineSetupDialog.h"

#ifdef _DEBUG
#define new DEBUG_NEW
#undef THIS_FILE
static char THIS_FILE[] = __FILE__;
#endif

EXCAPUIERR uiXline_query_supportdialog_setup( const DCAMSTRINGS& strs )
{
	if( strs.is_model( "C7390*" )
	 || strs.is_model( "C8133*" )
	 || strs.is_model( "C8750-*")
	 || strs.is_model( "C9133-*")
	 || strs.is_model( "C9750*" )
	 || strs.is_model( "C10400*" )
	 || strs.is_model( "C10650-*" )
	 || strs.is_model( "Hamamatsu USB XLINE" )
	 || strs.is_model( "Hamamatsu USB XLINE TDI" )
	)
		return EXCAPUIERR_SUCCESS;

	return EXCAPUIERR_UNKNOWNCAMERA;
}

EXCAPUIERR uiXline_modal_dialog_setup( HDCAM hdcam, const DCAMSTRINGS& strs )
{
	if( strs.is_model( "C7390*" )
	 || strs.is_model( "C8133*" )
	 || strs.is_model( "C8750-*")
	 || strs.is_model( "C9133-*")
	 || strs.is_model( "C9750*" )
	 || strs.is_model( "C10400*" )
	 || strs.is_model( "C10650-*" )
	 || strs.is_model( "Hamamatsu USB XLINE" )
	 || strs.is_model( "Hamamatsu USB XLINE TDI" )
	)
	{
		CuiXlineSetupDialog	dlg;
		dlg.m_psh.dwFlags |= PSH_NOAPPLYNOW;

		DWORD dw;
		VERIFY( dcam_getstatus( hdcam, &dw ) );

		if( dw != DCAM_STATUS_BUSY && dw != DCAM_STATUS_READY )
		{
			dlg.set_hdcam( hdcam );
			dlg.DoModal();

			return EXCAPUIERR_SUCCESS;
		}
		else
			return EXCAPUIERR_NOTSUPPORT;
	}

	return EXCAPUIERR_UNKNOWNCAMERA;
}
