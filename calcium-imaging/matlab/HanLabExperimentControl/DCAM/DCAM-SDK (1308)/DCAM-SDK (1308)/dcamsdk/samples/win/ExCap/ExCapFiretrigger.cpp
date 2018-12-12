// ExCapFiretrigger.cpp : implementation file
//

#include "stdafx.h"
#include "ExcapFiretrigger.h"

#ifdef _DEBUG
#define new DEBUG_NEW
#undef THIS_FILE
static char THIS_FILE[] = __FILE__;
#endif

/////////////////////////////////////////////////////////////////////////////
// CExCapFiretrigger

CExCapFiretrigger::~CExCapFiretrigger()
{
}

CExCapFiretrigger::CExCapFiretrigger()
{
	m_bTerminate= FALSE;
	m_hThread	= NULL;
	m_idThread	= 0;

	m_hFire	= CreateEvent( NULL, FALSE, FALSE, FALSE );	// When this is active, the thread fires trigger.
	m_hAbort= CreateEvent( NULL, TRUE,  FALSE, FALSE );	// When this is active, the thread abort waiting and pause.
	m_hExited=CreateEvent( NULL, TRUE,  TRUE,  FALSE );	// When this is active, the thread is pausing.

	m_hThread = CreateThread( NULL, 0, entry_waiting, this, 0, &m_idThread );
	ASSERT( m_hThread != NULL );
}

void CExCapFiretrigger::release()
{
	m_bTerminate = TRUE;

	ResetEvent( m_hFire );
	SetEvent( m_hAbort );

	DWORD	dw = WaitForSingleObject( m_hExited, 10000 );	// wait 10 seconds
	ASSERT( dw == WAIT_OBJECT_0 );

	delete this;
}

void CExCapFiretrigger::firetrigger( HDCAM hdcam )
{
	m_hdcam = hdcam;

	SetEvent( m_hFire );
}

// ----------------

DWORD WINAPI CExCapFiretrigger::entry_waiting( LPVOID param )
{
	CExCapFiretrigger*	pThis = (CExCapFiretrigger*)param;

	pThis->on_waiting();

	return 0;
}

void CExCapFiretrigger::on_waiting()
{
	DWORD	dw;

	while( ! m_bTerminate )
	{
		dw = WaitForSingleObject( m_hFire, 1000 );
		if( dw == WAIT_TIMEOUT )
			continue;

		ASSERT( dw == WAIT_OBJECT_0 );
		dcam_firetrigger( m_hdcam );
	}

	SetEvent( m_hExited );
}
