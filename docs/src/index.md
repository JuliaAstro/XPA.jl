# The XPA package for Julia

The [XPA Messaging System](https://github.com/ericmandel/xpa) provides seamless
communication between many kinds of Unix/Windows programs, including X programs, Tcl/Tk
programs. It is used to control some popular astronomical tools such as
[SAOImage-DS9](http://ds9.si.edu/site/Home.html).

The `XPA.jl` package is a [Julia](http://julialang.org/) interface to the XPA Messaging
System. `XPA.jl` can be used to send data or commands to XPA servers, to query data from XPA
servers, or to implement an XPA server. The package uses `ccall` to directly call the
routines of the compiled XPA library.

[SAOImageDS9.jl](https://github.com/JuliaAstro/SAOImageDS9.jl) is a Julia package that
exploits `XPA.jl` to communicate with [SAOImage-DS9](http://ds9.si.edu/site/Home.html).

## Table of contents

```@contents
Pages = ["intro.md", "client.md", "install.md", "misc.md", "server.md", "faq.md", "library.md"]
```

## Index

```@index
```
