// CExCapFramerate.cpp : implementation file
//

#include "stdafx.h"
#include "ExcapFramerate.h"
#include "ExcapCallback.h"

#ifdef _DEBUG
#define new DEBUG_NEW
#undef THIS_FILE
static char THIS_FILE[] = __FILE__;
#endif

/////////////////////////////////////////////////////////////////////////////
// CExCapFramerate

CExCapFramerate::~CExCapFramerate()
{
	CloseHandle( m_hMutex );

	CloseHandle( m_hStart );
	CloseHandle( m_hAbort );
	CloseHandle( m_hPause );

	delete m_timestamp.stamp;
}

CExCapFramerate::CExCapFramerate( long stampcount )
{
	m_hdcam		= NULL;
	m_bTerminate= FALSE;
	m_hThread	= NULL;
	m_idThread	= 0;

	m_hMutex = CreateMutex( NULL, FALSE, NULL );

	m_hStart = CreateEvent( NULL, FALSE, FALSE, FALSE );	// When this is active, the thread measures frame rate.
	m_hAbort = CreateEvent( NULL, TRUE,  FALSE, FALSE );	// When this is active, the thread abort waiting and pause.
	m_hPause = CreateEvent( NULL, TRUE,  TRUE,  FALSE );	// When this is active, the thread is pausing.

	memset( &m_timestamp, 0, sizeof( m_timestamp ));
	VERIFY( QueryPerformanceFrequency( &m_timestamp.freq ) );
	
	m_timestamp.stamp = new LARGE_INTEGER[ stampcount ];
	m_timestamp.count = stampcount;

	memset( &m_framecount, 0, sizeof( m_framecount ) );

	m_pCallback = NULL;
}

void CExCapFramerate::release()
{
	m_bTerminate = TRUE;
	abort_waiting( TRUE );

	delete this;
}

HDCAM CExCapFramerate::set_hdcam( HDCAM hdcam )
{
	abort_waiting( FALSE );

	HDCAM	old = m_hdcam;
	m_hdcam = hdcam;

	start_waiting();

	return old;
}

// ----------------

void CExCapFramerate::start_waiting()
{
	if( m_hThread == NULL )
	{
		m_hThread = CreateThread( NULL, 0, entry_waiting, this, 0, &m_idThread );
		if( m_hThread == NULL )
		{
			ASSERT( 0 );
			return;
		}
	}

	reset_timestamp();

	ResetEvent( m_hAbort );
	SetEvent( m_hStart );
}

void CExCapFramerate::abort_waiting( BOOL bTerminate )
{
	if( ! bTerminate )
		ResetEvent( m_hStart );
	SetEvent( m_hAbort );

	DWORD	dw = WaitForSingleObject( m_hPause, 10000 );	// wait 10 seconds
	ASSERT( dw == WAIT_OBJECT_0 );
}

// ----------------

void CExCapFramerate::enter_critical()
{
	DWORD	dw = WaitForSingleObject( m_hMutex, INFINITE );
	ASSERT( dw == WAIT_OBJECT_0 );
}

void CExCapFramerate::leave_critical()
{
	ReleaseMutex( m_hMutex );
}

void CExCapFramerate::reset_timestamp()
{
	enter_critical();

	m_timestamp.iNext = 0;
	m_timestamp.iTotal = 0;

	leave_critical();
}

void CExCapFramerate::mark_timestamp()
{
	LARGE_INTEGER	t;
	VERIFY( QueryPerformanceCounter( &t ) );

	enter_critical();

	m_timestamp.stamp[ m_timestamp.iNext++ ] = t;
	if( m_timestamp.iNext >= m_timestamp.count )
		m_timestamp.iNext = 0;
	m_timestamp.iTotal++;

	leave_critical();
}

LONGLONG CExCapFramerate::get_period( long end, long begin ) const
{
	LONGLONG	tEnd = m_timestamp.stamp[ end   % m_timestamp.count ].QuadPart;
	LONGLONG	tBegin=m_timestamp.stamp[ begin % m_timestamp.count ].QuadPart;

	return tEnd - tBegin;
}


BOOL CExCapFramerate::get_latestperiod( double& lastperiod ) const
{
	if( m_timestamp.iTotal < 2 )
		return FALSE;

	lastperiod = double( get_period( m_timestamp.iTotal - 1, m_timestamp.iTotal - 2 ) ) / m_timestamp.freq.QuadPart;
	
	return TRUE;
}

BOOL CExCapFramerate::get_averageperiod( double& period ) const
{
	if( m_timestamp.iTotal < m_timestamp.count )
		return FALSE;

	const long	n = m_timestamp.count;
	ASSERT( n >= 2 );
	period = double( get_period( m_timestamp.iTotal - 1, m_timestamp.iTotal - n ) ) / m_timestamp.freq.QuadPart / (n - 1);
	return TRUE;
}

BOOL CExCapFramerate::get_minimumperiod( double& minperiod ) const
{
	if( m_timestamp.iTotal < 2 )
		return FALSE;

	long	i, n;
	n = min( m_timestamp.iTotal, m_timestamp.count ) - 1;
	LONGLONG	tmin = get_period( m_timestamp.iTotal - 1, m_timestamp.iTotal - 2 );

	for( i = 2; i <= n; i++ )
	{
		LONGLONG	t = get_period( m_timestamp.iTotal - i, m_timestamp.iTotal - i - 1 );
		if( tmin > t )
			tmin = t;
	}

	minperiod = double( tmin ) / m_timestamp.freq.QuadPart;
	return TRUE;
}

BOOL CExCapFramerate::get_maximumperiod( double& maxperiod ) const
{
	if( m_timestamp.iTotal < 2 )
		return FALSE;

	long	i, n;
	n = min( m_timestamp.iTotal, m_timestamp.count ) - 1;
	LONGLONG	tmax = get_period( m_timestamp.iTotal - 1, m_timestamp.iTotal - 2 );

	for( i = 2; i <= n; i++ )
	{
		LONGLONG	t = get_period( m_timestamp.iTotal - i, m_timestamp.iTotal - i - 1 );
		if( tmax < t )
			tmax = t;
	}

	maxperiod = double( tmax ) / m_timestamp.freq.QuadPart;
	return TRUE;
}

void CExCapFramerate::get_framecount( long& total, long& lost ) const
{
	total = m_framecount.total;
	lost = m_framecount.lost;
}

void CExCapFramerate::get_eventcount( long& exposureend, long& frameend, long& captureend, long& unknown ) const
{
	unknown		= m_framecount.unknown;
	exposureend	= m_framecount.exposureend;
	frameend	= m_framecount.frameend;
	captureend	= m_framecount.captureend;
}

void CExCapFramerate::reset_framecount()
{
	memset( &m_framecount, 0, sizeof( m_framecount ) );
}


void CExCapFramerate::set_callback( class CExCapCallback* pCallback )
{
	m_pCallback = pCallback;
}

// ----------------

DWORD WINAPI CExCapFramerate::entry_waiting( LPVOID param )
{
	CExCapFramerate*	pThis = (CExCapFramerate*)param;

	pThis->on_waiting();

	return 0;
}

void CExCapFramerate::on_waiting()
{
	DWORD	dw;

	while( ! m_bTerminate )
	{
		dw = WaitForSingleObject( m_hStart, 1000 );
		if( dw == WAIT_TIMEOUT )
			continue;

		ASSERT( dw == WAIT_OBJECT_0 );

		ResetEvent( m_hPause );

		while( m_hdcam != NULL && ! m_bTerminate )
		{
			DWORD	dwEvent = DCAM_EVENT_EXPOSUREEND | DCAM_EVENT_FRAMESTART | DCAM_EVENT_FRAMEEND | DCAM_EVENT_CAPTUREEND;

			if( dcam_wait( m_hdcam, &dwEvent, 1000, m_hAbort ) )
			{
				if( dwEvent == DCAM_EVENT_FRAMESTART )
				{
					// frame comes
					mark_timestamp();

					m_framecount.total++;
				}
				else
				if( dwEvent == DCAM_EVENT_EXPOSUREEND )
				{
					m_framecount.exposureend++;
				}
				else
				if( dwEvent == DCAM_EVENT_FRAMEEND )
				{
					m_framecount.frameend++;
				}
				else
				if( dwEvent == DCAM_EVENT_CAPTUREEND )
				{
					m_framecount.captureend++;
				}
				else
				{
					ASSERT( 0 );
					m_framecount.unknown++;
				}

				if( m_pCallback )
					m_pCallback->on_dcamwait( m_hdcam, dwEvent );

				continue;
			}

			// check DCAM error code
			long	err = dcam_getlasterror( m_hdcam );
			if( err == DCAMERR_TIMEOUT )
				continue;

			if( err == DCAMERR_LOSTFRAME
			 || err == DCAMERR_MISSINGFRAME_TROUBLE )
			{
				m_framecount.lost++;

				if( m_pCallback )
					m_pCallback->on_lostframe( m_hdcam );

				continue;
			}

			ASSERT( err == DCAMERR_ABORT || err == DCAMERR_INVALIDHANDLE );
			break;
		}

		SetEvent( m_hPause );
	}
}
