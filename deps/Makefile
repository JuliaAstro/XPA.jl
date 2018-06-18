CC = gcc
CFLAGS = -O
CPPFLAGS =
LDFLAGS = -lxpa

all: ../src/constants.jl

clean:
	rm -f *~ core gencode

gencode: gencode.c
	$(CC) $(CPPFLAGS) $(CFLAGS) -o "$@" "$<" $(LDFLAGS)

../src/constants.jl: gencode constants-header.jl
	rm -f "$@"
	cat constants-header.jl >"$@"
	"./$<" >>"$@"
	chmod 444 "$@"
