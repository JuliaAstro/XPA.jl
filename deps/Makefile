#
# Define the following environment variables if the default definitions is not
# suitable for your installation.
#
#     XPA_DEFS is C-preprocessor flags for finding header "xpa.h".
#              For instance: XPA_DEFS=-I/usr/local/include
#
#     XPA_LIBS is linker flags for linking with the XPA dynamic library.
#              For instance: XPA_LIBS=-L/usr/local/lib -lxpa
#
XPA_DEFS ?=
XPA_LIBS ?= -lxpa

# CC =
# CFLAGS =
# CPPFLAGS =
# LDFLAGS =
srcdir = .

all: deps.jl

clean:
	rm -f *~ core gencode

distclean: clean
	rm -f deps.jl

gencode: gencode.c Makefile
	$(CC) $(CPPFLAGS) $(CFLAGS) -o "$@" "$<" $(LDFLAGS) $(XPA_LIBS)

deps.jl: gencode ${srcdir}/getdll.sh Makefile
	rm -f "$@"
	"./$<" >>"$@"
	echo >>"$@" ""
	echo >>"$@" "# Path to the XPA dynamic library."
	${srcdir}/getdll.sh xpa "./$<" | sed -e 's/\(.*\)/const libxpa = "\1"/' >>"$@"
	chmod 444 "$@"

.PHONY: all clean distclean
