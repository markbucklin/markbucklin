// CExCapCallback.h
//

class CExCapCallback
{
public:
	virtual	~CExCapCallback()	{}
protected:
			CExCapCallback()	{}

public:
	virtual	void	on_dcamwait( HDCAM hdcam, DWORD dwEvent )	{}
	virtual	void	on_lostframe( HDCAM hdcam )					{}

};
