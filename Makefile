CC = gcc
CFLAGS = -O0 -g -Wall
LIBS = -lm

all:	pic

pic:	pic.y lempar.c lemon
	./lemon pic.y
	$(CC) $(CFLAGS) pic.c -o pic $(LIBS)

lemon:	lemon.c
	$(CC) $(CFLAGS) lemon.c -o lemon
