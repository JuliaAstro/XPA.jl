CC = gcc
CFLAGS = -O
CPPFLAGS =
LDFLAGS = -lxpa

all: ../src/getfields.jl

clean:
	rm -f *~ core gencode

gencode: gencode.c
	$(CC) $(CPPFLAGS) $(CFLAGS) -o "$@" "$<" $(LDFLAGS)

../src/getfields.jl: gencode
	"./$<" >"$@"
