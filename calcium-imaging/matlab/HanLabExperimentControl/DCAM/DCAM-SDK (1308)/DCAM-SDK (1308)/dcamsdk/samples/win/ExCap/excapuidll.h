// excapuidll.h
//

class excapuidll
{
public:
			~excapuidll();
			excapuidll();

public:
			BOOL	load_dll();
			BOOL	unload_dll();

public:
			BOOL	query_supportdialog( HDCAM hdcam, long lparam = 0 );
			BOOL	modal_dialog( HDCAM hdcam, long lparam = 0 );
			BOOL	on_open_camera( HDCAM hdcam );
			BOOL	on_close_camera( HDCAM hdcam );

protected:
			BOOL	call_dll( HDCAM hdcam, UINT iCmd, LONG lparam = 0, void* pparam = NULL, long pparambytes = 0 );

	struct var_excapuidll*	m_var_excapuidll;
};

