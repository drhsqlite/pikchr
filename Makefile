CC = gcc
CFLAGS = -O0 -g -Wall -Wextra
LIBS = -lm

all:	pikchr

pikchr:	pikchr.c
	$(CC) $(CFLAGS) -DPIKCHR_SHELL pikchr.c -o pikchr $(LIBS)

pikchrfuzz:	pikchr.c
	clang -g -O3 -fsanitize=fuzzer,undefined,address -o pikchrfuzz \
	  -DPIKCHR_FUZZ pikchr.c $(LIBS)

pikchr.c:	pikchr.y pikchr.h.in lempar.c lemon
	./lemon pikchr.y
	cat pikchr.h.in >pikchr.h

lemon:	lemon.c
	$(CC) $(CFLAGS) lemon.c -o lemon

test:	pikchr
	./pikchr */*.pikchr >out.html || true
	open out.html

clean:	
	rm -f pikchr pikchr.c pikchr.h pikchr.out lemon out.html
