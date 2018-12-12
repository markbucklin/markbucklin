// ExCapDoc.cpp : implementation of the CExCapDoc class
//

#include "stdafx.h"
#include "ExCap.h"

#include "ExCapApp.h"
#include "ExCapDoc.h"
#include "image.h"
#include "imagedcam.h"
#include "dcamimg.h"

#include "bitmap.h"
#include "dcamex.h"
#include "showdcamerr.h"

#include "DlgDcamOpen.h"
#include "DlgExcapDataframes.h"

#include <shlwapi.h>

#ifdef _DEBUG
#define new DEBUG_NEW
#undef THIS_FILE
static char THIS_FILE[] = __FILE__;
#endif

/////////////////////////////////////////////////////////////////////////////
// CExCapDoc

IMPLEMENT_DYNCREATE(CExCapDoc, CDocument)

BEGIN_MESSAGE_MAP(CExCapDoc, CDocument)
	//{{AFX_MSG_MAP(CExCapDoc)
	ON_COMMAND(ID_CAPTURE_SEQUENCE, OnCaptureSequence)
	ON_COMMAND(ID_CAPTURE_SNAP, OnCaptureSnap)
	ON_COMMAND(ID_CAPTURE_IDLE, OnCaptureIdle)
	ON_UPDATE_COMMAND_UI(ID_CAPTURE_SEQUENCE, OnUpdateCapture)
	ON_UPDATE_COMMAND_UI(ID_CAPTURE_IDLE, OnUpdateCaptureIdle)
	ON_COMMAND(ID_CAPTURE_FIRETRIGGER, OnCaptureFiretrigger)
	ON_UPDATE_COMMAND_UI(ID_CAPTURE_FIRETRIGGER, OnUpdateCaptureFiretrigger)
	ON_COMMAND(ID_CAPTURE_DATAFRAMES, OnCaptureDataframes)
	ON_UPDATE_COMMAND_UI(ID_CAPTURE_DATAFRAMES, OnUpdateCaptureDataframes)
	ON_UPDATE_COMMAND_UI(ID_FILE_SAVE_AS, OnUpdateFileSaveAs)
	ON_UPDATE_COMMAND_UI(ID_CAPTURE_SNAP, OnUpdateCapture)
	ON_COMMAND(ID_SETUP_CUSTOM, OnSetupCustom)
	ON_UPDATE_COMMAND_UI(ID_SETUP_CUSTOM, OnUpdateSetupCustom)
	//}}AFX_MSG_MAP
END_MESSAGE_MAP()

/////////////////////////////////////////////////////////////////////////////
// CExCapDoc construction/destruction

CExCapDoc::CExCapDoc()
{
	// TODO: add one-time construction code here

	m_image = NULL;

	m_hdcam				= NULL;
	m_nDatatype			= DCAM_DATATYPE_NONE;
	m_nFramecount		= 3;
	m_bUseAttachBuffer	= FALSE;
	m_bSupportCustomDialog	= FALSE;
	m_bBufferReady		= FALSE;

	m_idCapturingSequence = ID_CAPTURE_IDLE;
	m_nCapturedFramecount = 0;
	m_nCapturedOffset	= 0;
}

CExCapDoc::~CExCapDoc()
{
	ASSERT( m_hdcam == NULL );
	ASSERT( m_image == NULL );
}

BOOL CExCapDoc::OnNewDocument()
{
	if (!CDocument::OnNewDocument())
		return FALSE;

	// TODO: add reinitialization code here
	// (SDI documents will reuse this document)

	ASSERT( m_hdcam == NULL );
	CExCapApp*	app = afxGetApp();
	
	// initialize DCAM-API and open camera
	if( CDlgDcamOpen::dcam_init_and_open( m_hdcam, app->get_dcaminit_option() ) != IDOK )
		return FALSE;

	ASSERT( m_hdcam != NULL );

	{
		CString	strModel;
		CString	strCameraId;
		CString	strBus;

		{
			char cbModel[ 64 ];
			char cbCameraId[ 64 ];
			char cbBus[ 64 ];

			VERIFY( dcam_getstring( m_hdcam, DCAM_IDSTR_MODEL,    cbModel,    sizeof( cbModel    )) );
			VERIFY( dcam_getstring( m_hdcam, DCAM_IDSTR_CAMERAID, cbCameraId, sizeof( cbCameraId )) );
			VERIFY( dcam_getstring( m_hdcam, DCAM_IDSTR_BUS,      cbBus,      sizeof( cbBus      )) );

			strModel	= cbModel;
			strCameraId	= cbCameraId;
			strBus		= cbBus;
		}

		CString	str;
		str = strModel + _T( " (" ) + strCameraId + _T( ") on " ) + strBus;

		SetTitle( str );

		VERIFY( dcam_getdatatype( m_hdcam, &m_nDatatype ) );

		m_bSupportCustomDialog = app->query_supportdialog( m_hdcam );
	}

	{
		image*	p = new_imagedcam( m_hdcam );
		ASSERT( p != NULL );

		if( m_image != NULL )
			m_image->release();

		m_image = p;
		UpdateAllViews( NULL, image_updated );
	}

	app->on_open_camera( m_hdcam );

	return TRUE;
}

void CExCapDoc::OnCloseDocument() 
{
	CExCapApp*	app = afxGetApp();

	// Close DCAM handle
	if( m_hdcam != NULL )
	{
		app->on_close_camera( m_hdcam );

		VERIFY( dcam_close( m_hdcam ) );
		m_hdcam = NULL;
		m_nDatatype = DCAM_DATATYPE_NONE;
	}

	if( m_image != NULL )
	{
		m_image->release();
		m_image = NULL;
	}

	app->on_close_document( this );
	
	m_bSupportCustomDialog = FALSE;

	CDocument::OnCloseDocument();
}

//-----------

BOOL CExCapDoc::start_capturing( BOOL bSequence )
{
	_DWORD	status;

	// check status and stop capturing if capturing is already started.
	if( ! dcam_getstatus( m_hdcam, &status ) )
	{
		show_dcamerrorbox( m_hdcam, "dcam_getstatus()" );
		return FALSE;
	}

	{
		switch( status )
		{
		case DCAM_STATUS_BUSY:
			if( ! dcam_idle( m_hdcam ) )
			{
				show_dcamerrorbox( m_hdcam, "dcam_idle()" );
				return FALSE;
			}
		case DCAM_STATUS_READY:
			ASSERT( m_bBufferReady );

			if( m_bUseAttachBuffer )
			{
				if( ! dcam_releasebuffer( m_hdcam ) )
				{
					show_dcamerrorbox( m_hdcam, "dcam_releasebuffer()" );
					return FALSE;
				}
				m_image->freeframes();
			}
			else
			{
				if( ! dcam_freeframe( m_hdcam ) )
				{
					show_dcamerrorbox( m_hdcam, "dcam_freeframe()" );
					return FALSE;
				}
			}

			m_bBufferReady = FALSE;

		case DCAM_STATUS_STABLE:
		case DCAM_STATUS_UNSTABLE:
			break;
		}
	}

	// set data type.
	if( ! dcam_setdatatype( m_hdcam, m_nDatatype ) )
	{
		show_dcamerrorbox( m_hdcam, "dcam_setdatatype()" );
		return FALSE;
	}

	// prepare capturing.
	if( ! dcam_precapture( m_hdcam, bSequence ? DCAM_CAPTUREMODE_SEQUENCE : DCAM_CAPTUREMODE_SNAP ) )
	{
		if( bSequence )
			show_dcamerrorbox( m_hdcam, "dcam_precapture( SEQUENCE )" );
		else
			show_dcamerrorbox( m_hdcam, "dcam_precapture( SNAP )" );

		return FALSE;
	}

	// status must be STABLE
	ASSERT( dcam_getstatus( m_hdcam, &status ) && status == DCAM_STATUS_STABLE );

	// prepare buffer
	if( m_bUseAttachBuffer )
	{
		// buffer is allocated by user.

		ASSERT( m_image != NULL );
		if( ! m_image->allocateframes( m_nFramecount, TRUE ) )
		{
			AfxMessageBox( IDS_ERR_NOTENOUGHMEMORY );
			return FALSE;
		}

		if( ! dcam_attachbuffer( m_hdcam, m_image->getframes(), sizeof( void* ) * m_nFramecount ) )
		{
			show_dcamerrorbox( m_hdcam, "dcam_attachbuffer()" );
			return FALSE;
		}

		m_bBufferReady = TRUE;
	}
	else
	{
		// buffer is allocated by DCAM.

		ASSERT( m_image != NULL );
		m_image->freeframes();

		if( ! m_image->allocateframes( m_nFramecount, FALSE ) )
		{
			show_dcamerrorbox( m_hdcam, "dcam_allocframe()" );
			return FALSE;
		}

		m_bBufferReady = TRUE;
	}

	// status must be READY
#ifdef _DEBUG
	{
	ASSERT( dcam_getstatus( m_hdcam, &status ) && status == DCAM_STATUS_READY );
	int32	dw;
	ASSERT( dcam_getframecount( m_hdcam, &dw ) && dw == m_nFramecount );
	}
#endif
	// start capturing
	if( ! dcam_capture( m_hdcam ) )
	{
		show_dcamerrorbox( m_hdcam, "dcam_capture()" );

		if( m_bUseAttachBuffer )
		{
			if( ! dcam_releasebuffer( m_hdcam ) )
				show_dcamerrorbox( m_hdcam, "dcam_releasebuffer()" );

			m_image->freeframes();
		}
		else
		{
			if( ! dcam_freeframe( m_hdcam ) )
				show_dcamerrorbox( m_hdcam, "dcam_freeframe()" );

		}
		m_bBufferReady = FALSE;
		return FALSE;
	}

	ASSERT( dcam_getstatus( m_hdcam, &status ) && status == DCAM_STATUS_BUSY );
	return TRUE;
}

long CExCapDoc::suspend_capturing()
{
	_DWORD	status;
	if( ! dcam_getstatus( m_hdcam, &status ) )
	{
		show_dcamerrorbox( m_hdcam, "dcam_getstatus()" );
		return 0;
	}

	switch( status )
	{
	case DCAM_STATUS_BUSY:
		if( ! dcam_idle( m_hdcam ) )
		{
			show_dcamerrorbox( m_hdcam, "dcam_idle()" );
			return 0;
		}
	case DCAM_STATUS_READY:
		if( m_bUseAttachBuffer )
		{
			if( ! dcam_releasebuffer( m_hdcam ) )
			{
				show_dcamerrorbox( m_hdcam, "dcam_releasebuffer()" );
				return 0;
			}

			m_image->freeframes();
		}
		else
		{
			if( ! dcam_freeframe( m_hdcam ) )
			{
				show_dcamerrorbox( m_hdcam, "dcam_freeframe()" );
				return 0;
			}
		}
		m_bBufferReady = FALSE;
	}

	return m_idCapturingSequence;
}

void CExCapDoc::resume_capturing( long param )
{
	if( param == ID_CAPTURE_SEQUENCE )
	{
		if( start_capturing( TRUE ) )
			UpdateAllViews( NULL, start_capture );
	}
	else
	if( param == ID_CAPTURE_SNAP )
	{
		if( start_capturing( FALSE ) )
			UpdateAllViews( NULL, start_capture );
	}
	else
		ASSERT( param == ID_CAPTURE_IDLE );
}

//-----------

BOOL CExCapDoc::is_bitmap_updated()
{
	if( m_image == NULL
	 || ! m_image->is_bitmap_updated() )
		return FALSE;

	return TRUE;
}

BOOL CExCapDoc::get_bitmapinfoheader( BITMAPINFOHEADER& bmih )
{
	return m_image->get_bitmapinfoheader( bmih );
}

long CExCapDoc::numberof_capturedframes() const
{
	return m_nCapturedFramecount;
}

long CExCapDoc::copy_dibits( BYTE* bits, const BITMAPINFOHEADER& bmih, long iFrame, long hOffset, long vOffset, RGBQUAD* rgb, const BYTE* lut )
{
	m_image->clear_bitmap_updated();

	long	rowbytes	= getrowbytes( bmih );
	BYTE*	dsttopleft;
	if( rowbytes < 0 )
	{
		ASSERT( bmih.biHeight > 0 );
		dsttopleft = bits - rowbytes * ( bmih.biHeight - 1 );
	}
	else
		dsttopleft = bits;

	if( iFrame != -1 && m_nCapturedFramecount > 0 )
		iFrame = ( iFrame + m_nCapturedOffset ) % m_nCapturedFramecount;

	if( m_image->copybits( dsttopleft, rowbytes, iFrame, bmih.biWidth, bmih.biHeight, hOffset, vOffset, lut ) )
	{
		if( rgb != NULL && m_image->colortype() == image::colortype_bw )
		{
			DWORD	i;
			for( i = 0; i < bmih.biClrUsed; i++ )
			{
				rgb[ i ].rgbRed		= (BYTE)(i * 255 / ( bmih.biClrUsed - 1 ) );
				rgb[ i ].rgbGreen	= (BYTE)(i * 255 / ( bmih.biClrUsed - 1 ) );
				rgb[ i ].rgbBlue	= (BYTE)(i * 255 / ( bmih.biClrUsed - 1 ) );
				rgb[ i ].rgbReserved= 0;
			}
		}

		return TRUE;
	}

	return FALSE;
}

/////////////////////////////////////////////////////////////////////////////
// CExCapDoc update

void CExCapDoc::update_datatype()
{
	if( m_hdcam != NULL )
		VERIFY( dcam_getdatatype( m_hdcam, &m_nDatatype ) );
}

/////////////////////////////////////////////////////////////////////////////
// CExCapDoc serialization

void CExCapDoc::Serialize(CArchive& ar)
{
	// Serialize is not used.
	ASSERT( 0 );

	if (ar.IsStoring())
	{
		// TODO: add storing code here
	}
	else
	{
		// TODO: add loading code here
	}
}

// ----------------

BOOL CExCapDoc::OnOpenDocument(LPCTSTR lpszPathName) 
{
//	if (!CDocument::OnOpenDocument(lpszPathName))
//		return FALSE;
	
	// TODO: Add your specialized creation code here
	image*	p = image::load( lpszPathName );
	if( p != NULL )
	{
		if( m_image != NULL )
			m_image->release();

		m_image = p;
		UpdateAllViews( NULL, image_updated );
		return TRUE;
	}

	return FALSE;
}

BOOL CExCapDoc::OnSaveDocument(LPCTSTR lpszPathName) 
{
	// TODO: Add your specialized code here and/or call the base class
	CString strPathName = lpszPathName;
	if( strPathName.IsEmpty() )
		return FALSE;

	// get filename extention
	LPCTSTR	lpszExtention = PathFindExtension( lpszPathName );
	CString	strExtention = ( lpszExtention == NULL || *lpszExtention == '\0' ? _T( ".img" ) : lpszExtention );

	// remove filename extention
	PathRemoveExtension( strPathName.LockBuffer() );
	strPathName.UnlockBuffer();

	// get count of images
	ASSERT( m_hdcam != NULL );

	int32	latest_frameindex, total_framecount;
	if( !dcam_gettransferinfo( m_hdcam, &latest_frameindex, &total_framecount ) )
	{
		ASSERT ( 0 );
		return FALSE;
	}

	// initialize frame index
	long fileindex;
	long framecount;
	if( total_framecount < m_nFramecount )
	{
		framecount = total_framecount;
		fileindex = 0;
	}
	else
	{
		framecount = m_nFramecount;
		if( latest_frameindex == m_nFramecount - 1 )
			fileindex = 0;
		else
			fileindex = latest_frameindex+1;
	}

	DWORD	bytesperframe;
	VERIFY( dcam_getdataframebytes( m_hdcam, &bytesperframe ) );
	ASSERT( bytesperframe > 0 );

	long rank = 0, q = framecount;

#ifdef _EXCAP_SUPPORTS_FRAMEBUNDLE_
	//
	// Check FRAMEBUNDLE MODE and get following 2 values if FRAMEBUNDLE MODE is ON.
	//

	BOOL	framebundle_mode = FALSE;
	long	framebundle_number = 1;
	long	framebundle_rowbytes = 0;
	{
		double	value;
		if( dcam_getpropertyvalue( m_hdcam, DCAM_IDPROP_FRAMEBUNDLE_MODE, &value )
		 && value == DCAMPROP_MODE__ON )
		{
			framebundle_mode = TRUE;

			VERIFY( dcam_getpropertyvalue( m_hdcam, DCAM_IDPROP_FRAMEBUNDLE_ROWBYTES, &value ) );
			framebundle_rowbytes = (long)value;

			VERIFY( dcam_getpropertyvalue( m_hdcam, DCAM_IDPROP_FRAMEBUNDLE_NUMBER, &value ) );
			framebundle_number = (long)value;

			// total frame count will be times of FRAMEBUNDLE_NUMBER.

			ASSERT( framebundle_number > 0 );
			q *= framebundle_number;
		}
	}

#endif // _EXCAP_SUPPORTS_FRAMEBUNDLE_ !

	while( q != 0 )
	{
		rank++;
		q /= 10;
	}
	if( rank == 0 )
	{
		// image is not captured
		ASSERT( 0 );
		return FALSE;
	}

	// save images
	for( int index=0; index<framecount; index++ )
	{
		void*	src = NULL;
		int32	rowbytes;

		if( m_bUseAttachBuffer )
		{
			// buffer is allocated by user.

			ASSERT( m_image != NULL );
			src = m_image->getframe( index, rowbytes );
		}
		else
		{
			VERIFY( dcam_lockdata( m_hdcam, &src, &rowbytes, fileindex ) );
		}

		if( src == NULL )
		{
			ASSERT( 0 );
		}
		else
		{
#ifdef _EXCAP_SUPPORTS_FRAMEBUNDLE_

			//
			// When FRAMEBUNDLE MODE is ON, several frames are bundled into one buffer.
			// This routine makes each frame into one file so it is nessesary to make another loop for file saving routine.
			//

			int	subindex;
			for( subindex=0; subindex<framebundle_number; subindex++ )
#endif // _EXCAP_SUPPORTS_FRAMEBUNDLE_ !
			{
				DCAMIMG	img;

				CString strFilename;
#ifdef _EXCAP_SUPPORTS_FRAMEBUNDLE_

				// suffix of file name is also times of FRAMEBUNDLE_NUMBER and added subindex.

				strFilename.Format( _T( "%s_%0*d%s" ), (LPCTSTR)strPathName, rank, index * framebundle_number + subindex, strExtention );

#else // _EXCAP_SUPPORTS_FRAMEBUNDLE_ !

				strFilename.Format( _T( "%s_%0*d%s" ), (LPCTSTR)strPathName, rank, index, strExtention );

#endif // _EXCAP_SUPPORTS_FRAMEBUNDLE_
				if( img.saveas( strFilename ) )
				{
					switch( dcamex_getcolortype( m_hdcam ) )
					{
					case DCAMPROP_COLORTYPE__RGB:	VERIFY( img.set_colortype( 4 ) );	break;
					case DCAMPROP_COLORTYPE__BGR:	VERIFY( img.set_colortype( 5 ) );	break;
					default:
						ASSERT( 0 );
					case DCAMPROP_COLORTYPE__BW:
						VERIFY( img.set_colortype( 1 ) );
						break;
					}

					VERIFY( img.set_bitsperchannel( dcamex_getbitsperchannel( m_hdcam ) ) );

					SIZE	sz;
					VERIFY( dcam_getdatasize( m_hdcam, &sz ) );

#ifdef _EXCAP_SUPPORTS_FRAMEBUNDLE_
					if( framebundle_mode )
					{
						// the offset to next line is FRAMEBUNDLE_ROWBYTES.

						img.set_width( sz.cx, framebundle_rowbytes );
						img.set_height( sz.cy );

						VERIFY( img.saveimage( (const char*)src + rowbytes * subindex, framebundle_rowbytes * sz.cy ) );
					}
					else
#endif // _EXCAP_SUPPORTS_FRAMEBUNDLE_ !
					{
						if( dcamex_is_sensormode_area( m_hdcam ) )
						{
							img.set_width( sz.cx, rowbytes );
							img.set_height( sz.cy );
						}
						else
						{
							img.set_numberof_line( sz.cy );
							img.set_width( sz.cx, rowbytes );
						}


						VERIFY( img.saveimage( src, bytesperframe ) );
					}

					img.saveclose();
				}
			}
		}

		if( ! m_bUseAttachBuffer )
			dcam_unlockdata( m_hdcam );

		// next frameindex
		if( ++fileindex >= m_nFramecount )
		{
			ASSERT( fileindex == m_nFramecount );
			fileindex = 0;
		}
	}
	
//	return CDocument::OnSaveDocument(lpszPathName);
	return TRUE;
}

/////////////////////////////////////////////////////////////////////////////
// CExCapDoc diagnostics

#ifdef _DEBUG
void CExCapDoc::AssertValid() const
{
	CDocument::AssertValid();
}

void CExCapDoc::Dump(CDumpContext& dc) const
{
	CDocument::Dump(dc);
}
#endif //_DEBUG

/////////////////////////////////////////////////////////////////////////////
// CExCapDoc commands

void CExCapDoc::OnUpdateFileSaveAs(CCmdUI* pCmdUI) 
{
	BOOL	bEnable	= FALSE;

	if( m_bBufferReady && m_idCapturingSequence == ID_CAPTURE_IDLE )
		bEnable = TRUE;

	pCmdUI->Enable( bEnable );
}

void CExCapDoc::OnCaptureDataframes() 
{
	// TODO: Add your command handler code here

	CDlgExcapDataframes	dlg;

	dlg.m_hdcam				= m_hdcam;
	VERIFY( dcam_getdatatype( m_hdcam, &m_nDatatype ) );
	dlg.m_nDatatype			= m_nDatatype;
	VERIFY( dcam_getdatasize( m_hdcam, &dlg.m_szData ) );

	dlg.m_nFrames			= m_nFramecount;
	dlg.m_bUserAttachBuffer = m_bUseAttachBuffer;

	if( dlg.DoModal() == IDOK )
	{
		m_nDatatype			= dlg.m_nDatatype;
		m_nFramecount		= dlg.m_nFrames;
		m_bUseAttachBuffer	= dlg.m_bUserAttachBuffer;
	}
}

void CExCapDoc::OnUpdateCaptureDataframes(CCmdUI* pCmdUI) 
{
	// TODO: Add your command update UI handler code here
	
	BOOL	bEnable	= FALSE;

	if( m_hdcam != NULL )
	{
		if( ! m_bBufferReady )
			bEnable = ( afxGetApp()->number_of_visible_controldialogs() == 0 );
	}

	pCmdUI->Enable( bEnable );
}

void CExCapDoc::OnUpdateCapture(CCmdUI* pCmdUI) 
{
	BOOL	bEnable	= FALSE;
	BOOL	bRadio	= FALSE;

	if( m_hdcam != NULL )
	{
		if( m_idCapturingSequence == ID_CAPTURE_IDLE )
		{
			bEnable = TRUE;
		}
		else
		{
			_DWORD	status;
			if( ! dcam_getstatus( m_hdcam, &status ) )
				status = DCAM_STATUS_ERROR;

			if( status != DCAM_STATUS_BUSY )
			{
				m_idCapturingSequence = ID_CAPTURE_IDLE;
				bEnable = TRUE;

				int32	latest_frameindex, total_framecount;
				if( ! dcam_gettransferinfo( m_hdcam, &latest_frameindex, &total_framecount ) )
				{
					ASSERT( 0 );
					m_nCapturedFramecount = 0;
					m_nCapturedOffset = 0;
				}
				else
				if( total_framecount < m_nFramecount )
				{
					m_nCapturedFramecount = total_framecount;
					m_nCapturedOffset = 0;
				}
				else
				{
					m_nCapturedFramecount = m_nFramecount;
					m_nCapturedOffset = latest_frameindex+1;
				}

				UpdateAllViews( NULL, stop_capture );
			}
			else
			{
				bRadio = ( m_idCapturingSequence == pCmdUI->m_nID );
			}
		}
	}

	pCmdUI->Enable( bEnable );
	pCmdUI->SetRadio( bRadio );
}

void CExCapDoc::OnCaptureSequence() 
{
	ASSERT( m_hdcam != NULL );

	if( start_capturing( TRUE ) )
	{
		m_idCapturingSequence = ID_CAPTURE_SEQUENCE;
		m_nCapturedFramecount = 0;
		m_nCapturedOffset	= 0;
		UpdateAllViews( NULL, start_capture );
	}
}

void CExCapDoc::OnCaptureSnap() 
{
	ASSERT( m_hdcam != NULL );

	if( start_capturing( FALSE ) )
	{
		m_idCapturingSequence = ID_CAPTURE_SNAP;
		m_nCapturedFramecount = 0;
		m_nCapturedOffset	= 0;
		UpdateAllViews( NULL, start_capture );
	}
}

// ----

void CExCapDoc::OnUpdateCaptureIdle(CCmdUI* pCmdUI) 
{
	BOOL	bEnable	= FALSE;
	BOOL	bRadio	= FALSE;

	if( m_hdcam != NULL )
	{
		if( m_bBufferReady )
			bEnable = TRUE;
	}

	pCmdUI->Enable( bEnable );
	pCmdUI->SetRadio( bRadio );
}

void CExCapDoc::OnCaptureIdle() 
{
	ASSERT( m_hdcam != NULL );

	_DWORD	status;
	if( ! dcam_getstatus( m_hdcam, &status) )
		status = DCAM_STATUS_ERROR;

	if( status == DCAM_STATUS_BUSY )
	{
		if( ! dcam_idle( m_hdcam ) )
			show_dcamerrorbox( m_hdcam, "dcam_idle()" );

		int32	latest_frameindex, total_framecount;
		if( ! dcam_gettransferinfo( m_hdcam, &latest_frameindex, &total_framecount ) )
		{
			ASSERT( 0 );
			m_nCapturedFramecount = 0;
			m_nCapturedOffset	= 0;
		}
		else
		if( total_framecount < m_nFramecount )
		{
			m_nCapturedFramecount = total_framecount;
			m_nCapturedOffset	= 0;
		}
		else
		{
			m_nCapturedFramecount = m_nFramecount;
			m_nCapturedOffset	= latest_frameindex+1;
		}
	}
	else
	if( status == DCAM_STATUS_READY )
	{
		ASSERT( m_bBufferReady );

		if( m_bUseAttachBuffer )
		{
			if( ! dcam_releasebuffer( m_hdcam ) )
				show_dcamerrorbox( m_hdcam, "dcam_releasebuffer()" );

			m_image->freeframes();
		}
		else
		{
			if( ! dcam_freeframe( m_hdcam ) )
				show_dcamerrorbox( m_hdcam, "dcam_freeframe()" );
		}

		m_bBufferReady = FALSE;
		m_nCapturedFramecount = 0;
		m_nCapturedOffset	= 0;
	}
	else
		ASSERT( 0 );

	m_idCapturingSequence = ID_CAPTURE_IDLE;
	UpdateAllViews( NULL, stop_capture );
}

// ----

void CExCapDoc::OnUpdateCaptureFiretrigger(CCmdUI* pCmdUI) 
{
	// TODO: Add your command update UI handler code here
	
	pCmdUI->Enable( m_hdcam != NULL );
}

void CExCapDoc::OnCaptureFiretrigger() 
{
	ASSERT( m_hdcam != NULL );

	if( ! dcam_firetrigger( m_hdcam ) )
		show_dcamerrorbox( m_hdcam, "dcam_firetrigger()" );
}

void CExCapDoc::OnSetupCustom() 
{
	ASSERT( m_hdcam != NULL );
	ASSERT( m_bSupportCustomDialog );

	CExCapApp*	app = afxGetApp();
	app->modal_dialog( m_hdcam );
}

void CExCapDoc::OnUpdateSetupCustom(CCmdUI* pCmdUI) 
{
	// TODO: Add your command update UI handler code here

	pCmdUI->Enable( m_bSupportCustomDialog );
}
