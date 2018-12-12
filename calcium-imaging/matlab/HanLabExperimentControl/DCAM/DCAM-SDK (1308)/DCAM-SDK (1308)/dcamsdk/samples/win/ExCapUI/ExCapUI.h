// ExCapUI.h : main header file for the ExCapUI DLL
//

#if !defined(AFX_EXCAPUI_H__D5110F81_9174_40A4_B82C_0BBC5A44E3B8__INCLUDED_)
#define AFX_EXCAPUI_H__D5110F81_9174_40A4_B82C_0BBC5A44E3B8__INCLUDED_

#if _MSC_VER > 1000
#pragma once
#endif // _MSC_VER > 1000

#ifndef __AFXWIN_H__
	#error "include 'stdafx.h' before including this file for PCH"
#endif

#include "resource.h"		// main symbols

// ----

struct DCAMSTRINGS
{
	char*	m_model;
	char*	m_ver;

public:
	~DCAMSTRINGS();
	DCAMSTRINGS();

public:
	EXCAPUIERR	initialize( HDCAM hdcam );

	BOOL	is_model( const char* pattern ) const;
	BOOL	is_equal_or_newer_than( const char* ver ) const;

protected:
	void safe_strdup( char*& dst, const char* src );
};

// ----

void show_dcamerrorbox( HDCAM hdcam, const char* function );

/////////////////////////////////////////////////////////////////////////////

//{{AFX_INSERT_LOCATION}}
// Microsoft Visual C++ will insert additional declarations immediately before the previous line.

#endif // !defined(AFX_EXCAPUI_H__D5110F81_9174_40A4_B82C_0BBC5A44E3B8__INCLUDED_)
