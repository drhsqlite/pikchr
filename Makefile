CC = gcc
CFLAGS = -O0 -g -Wall
LIBS = -lm

all:	pic

pic:	pic.c
	$(CC) $(CFLAGS) pic.c -o pic $(LIBS)

pic.c:	pic.y lempar.c lemon
	./lemon pic.y

lemon:	lemon.c
	$(CC) $(CFLAGS) lemon.c -o lemon

test:	pic
	./pic test*.txt >out.html
	open out.html

clean:	
	rm -f pic pic.c pic.h pic.out lemon
