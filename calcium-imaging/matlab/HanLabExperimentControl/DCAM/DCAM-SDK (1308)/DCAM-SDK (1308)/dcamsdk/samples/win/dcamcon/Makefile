IS_MINGW32 := $(shell uname | grep 'MINGW32' -c)
IS_LINUX := $(shell uname | grep 'Linux' -c)

ifeq ($(IS_MINGW32), 1)
	PROG = dcamcon.exe
	MYOS = -DWIN32
	DCAM_INCDIR = /c/DCAMSDK/2010-04/inc/
	DCAM_LIBDIR = /c/DCAMSDK/2010-04/lib/win32/
endif
ifeq ($(IS_LINUX), 1)
	PROG = dcamcon
	MYOS = -DLINUX
	DCAM_INCDIR = /usr/include/dcamapi/
	DCAM_LIBDIR = /usr/lib/
endif

CC = gcc
CFLAGS = -I$(DCAM_INCDIR) $(MYOS)
LDFLAGS = -L$(DCAM_LIBDIR)
LDLIBS = -ldcamapi

SRCS = dcamcon.cpp
OBJS = $(SRCS:.cpp=.o)

all: $(PROG)

$(PROG): $(OBJS)
	$(CC) -o $@ $(LDFLAGS) $(OBJS) $(LDLIBS)

.cpp.o:
	$(CC) $(CFLAGS) -c -o $@ $<

clean:
	rm -f $(OBJS)
	rm -f $(PROG)

