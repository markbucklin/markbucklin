// image.h
//

class image
{
protected:
	virtual	~image();
			image();

public:
	static image*	load( LPCTSTR path );

public:
	virtual	BOOL	release();	// TRUE means still object is exist.

public:
	virtual	BOOL	allocateframes( long framecount, BOOL bUser );
	virtual	BOOL	freeframes();
	virtual	void**	getframes();
	virtual	void*	getframe( long index, int32& rowbytes );

public:
	virtual BOOL	get_bitmapinfoheader( BITMAPINFOHEADER& bmih ) const = 0;
	virtual	long	copybits( BYTE* dsttopleft, long rowbytes, long iFrame, long srcwidth, long srcheight, long hOffset, long vOffset, const BYTE* lut = NULL ) = 0;

public:
	enum {
		colortype_bw		= 1,
		colortype_oldbgr	= 2,
		colortype_oldrgb	= 3,
		colortype_rgb		= 4,
		colortype_bgr		= 5,
	};

public:
	virtual	long	width() const = 0;
	virtual	long	height() const = 0;
	virtual	long	colortype() const = 0;
	virtual long	pixelperchannel() const = 0;

	virtual long	numberof_frames() const = 0;

	virtual	BOOL	is_bitmap_updated() = 0;
	virtual	void	clear_bitmap_updated() = 0;
};
