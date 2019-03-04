# Installation

To use XPA.jl package, XPA dynamic library and header files must be installed
on your computer.  If this is not the case, they may be available for your
operating system.  Otherwise, you'll have to build it and install it yourself.
Depending on this condition, there are two possibilities described below.

The source code of XPA.jl is available [here](https://github.com/emmt/XPA.jl).


## Easy installation

The easiest installation is when your system provides XPA dynamic library and
header files as a package.  For example, on Ubuntu, just do:

```sh
sudo apt-get install xpa-tools libxpa-dev
```

Then, to install XPA.jl package from Julia, just do:

```julia
using Pkg
Pkg.add("XPA")
```


## Custom installation

If XPA dynamic library and header files are not provided by your system, you
may install it manually.  That's easy but make sure that you compile and
install the shared library of XPA since this is the one that will be used by
Julia.  You have to download the source archive
[here](https://github.com/ericmandel/xpa/releases/latest), unpack it in some
directory, build and install it.  For instance:

```sh
cd "$SRCDIR"
wget -O xpa-2.1.18.tar.gz https://github.com/ericmandel/xpa/archive/v2.1.18.tar.gz
tar -zxvf xpa-2.1.18.tar.gz
cd xpa-2.1.18
./configure --prefix="$PREFIX" --enable-shared
mkdir -p "$PREFIX/lib" "$PREFIX/include" "$PREFIX/bin"
make install
```

where `$SRCDIR` is the directory where to download the archive and extract the
source while `$PREFIX` is the directory where to install XPA library, header
file(s) and executables.  You may consider other configuration options (run
`./configure --help` for a list) but make sure to have `--enable-shared` for
building the shared library.  As of the current version of XPA (2.1.18), the
installation script does not automatically build some destination directories,
hence the `mkdir -p ...` command above.

In order to use XPA.jl with a custom XPA installation, you may define the
environment variables `XPA_DEFS` and `XPA_LIBS` to suitable values before
building XPA package.  The environment variable `XPA_DEFS` specifies the
C-preprocessor flags for finding the headers `"xpa.h"` and `"prsetup.h"` while
the environment variable `XPA_LIBS` specifies the linker flags for linking with
the XPA dynamic library.  If you have installed XPA as explained above, do:

```sh
export XPA_DEFS="-I$PREFIX/include"
export XPA_LIBS="-L$PREFIX/lib -lxpa"
```

It may also be the case that you want to use a specific XPA dynamic library
even though your system provides one.  Then define the environment variable
`XPA_DEFS` as explained above and define the environment variable `XPA_DLL`
with the full path to the dynamic library to use.  For instance:

```sh
export XPA_DEFS="-I$PREFIX/include"
export XPA_DLL="$PREFIX/lib/libxpa.so"
```

Note that if both `XPA_LIBS` and `XPA_DLL` are defined, the latter has
precedence.

These variables must be defined before launching Julia and cloning/building the
XPA package.  You may also add the following lines in
`~/.julia/config/startup.jl`:

```julia
ENV["XPA_DEFS"] = "-I/InstallDir/include"
ENV["XPA_LIBS"] = "-L/InstallDir/lib -lxpa"
```

or (depending on the situation):

```julia
ENV["XPA_DEFS"] = "-I/InstallDir/include"
ENV["XPA_DLL"] = "/InstallDir/lib/libxpa.so"
```

where `InstallDir` should be modified according to your specific installation.
