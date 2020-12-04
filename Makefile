CC = gcc
CFLAGS = -O0 -g -Wall -Wextra
LIBS = -lm

TCL_PACKAGE_NAME    = pikchr
TCL_PACKAGE_VERSION = 1.0
TCL_PACKAGE_FLAGS = \
  -DPACKAGE_NAME="\"$(TCL_PACKAGE_NAME)\"" \
  -DPACKAGE_VERSION="\"$(TCL_PACKAGE_VERSION)\""

all:	pikchr

pikchr:	pikchr.c
	$(CC) $(CFLAGS) -DPIKCHR_SHELL pikchr.c -o pikchr $(LIBS)

pikchrfuzz:	pikchr.c
	clang -g -O3 -fsanitize=fuzzer,undefined,address -o pikchrfuzz \
	  -DPIKCHR_FUZZ pikchr.c $(LIBS)

pikchr.c:	pikchr.y pikchr.h.in lempar.c lemon
	./lemon pikchr.y
	cat pikchr.h.in >pikchr.h

piktcl: pikchr.c
	mkdir piktcl
	$(CC) -shared -fPIC -o piktcl/libpikchr.so \
	      $(CFLAGS) \
	      -DPIKCHR_TCL $(TCL_PACKAGE_FLAGS) \
	      -I /usr/include/tcl8.6 \
	      pikchr.c \
	      -lm \
	      -L /usr/lib/x86_64-linux-gnu/ \
	      -ltcl8.6
	echo >> piktcl/pkgIndex.tcl \
	      "package ifneeded $(TCL_PACKAGE_NAME) $(TCL_PACKAGE_VERSION) [list load [file join" '$$dir' "libpikchr.so]]"

lemon:	lemon.c
	$(CC) $(CFLAGS) lemon.c -o lemon

test:	pikchr
	./pikchr */*.pikchr >out.html || true
	open out.html || true
	./pikchr --dark-mode */*.pikchr >darkmode.html || true
	open darkmode.html

clean:	
	rm -f pikchr pikchr.c pikchr.h pikchr.out lemon out.html
