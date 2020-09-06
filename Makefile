CC = gcc
CFLAGS = -O0 -g -Wall
LIBS = -lm

all:	pikchr

pikchr:	pikchr.c
	$(CC) $(CFLAGS) pikchr.c -o pikchr $(LIBS)

pikchr.c:	pikchr.y lempar.c lemon
	./lemon pikchr.y

lemon:	lemon.c
	$(CC) $(CFLAGS) lemon.c -o lemon

test:	pikchr
	./pikchr test*.txt >out.html
	open out.html

clean:	
	rm -f pikchr pikchr.c pikchr.h pikchr.out lemon out.html
