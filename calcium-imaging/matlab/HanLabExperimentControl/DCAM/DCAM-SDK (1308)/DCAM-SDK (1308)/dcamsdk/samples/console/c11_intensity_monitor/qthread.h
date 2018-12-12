// qthread.h
//

class qthread
{
protected:
	virtual ~qthread();
			qthread();

public:
			long	start();
			long	wait_terminate();

protected:
	virtual	long	main() = 0;

protected:
	void*	m_thread;
	long	m_exitcode;

#if defined( WIN32 )

	static	DWORD WINAPI threadentry( LPVOID pparam );

#elif defined( MACOSX ) || __ppc64__ || __i386__ || __x86_64__

	static	void*	threadentry(void* pparam );

#else
#error unknown operating system: class qthread
#endif

};

