CC = gcc
CFLAGS = -O0 -g -Wall
LIBS = -lm

all:	pikchr

pikchr:	pikchr.c
	$(CC) $(CFLAGS) -DPIKCHR_SHELL pikchr.c -o pikchr $(LIBS)

pikchrfuzz:	pikchr.c
	clang -g -O3 -fsanitize=fuzzer,undefined,address -o pikchrfuzz \
	  -DPIKCHR_FUZZ pikchr.c $(LIBS)

pikchr.c:	pikchr.y lempar.c lemon
	./lemon pikchr.y

lemon:	lemon.c
	$(CC) $(CFLAGS) lemon.c -o lemon

test:	pikchr
	./pikchr --no-echo examples/* grammar/*.txt tests/*.txt >out.html
	open out.html

clean:	
	rm -f pikchr pikchr.c pikchr.h pikchr.out lemon out.html
