# The XPA.jl package

[XPA Messaging System](https://github.com/ericmandel/xpa) provides seamless
communication between many kinds of Unix/Windows programs, including X
programs, Tcl/Tk programs or some popular astronomical tools such as
[SAOImage-DS9](http://ds9.si.edu/site/Home.html).

XPA.jl provides a [Julia](http://julialang.org/) interface to the XPA messaging
system.  XPA.jl can be used to send data ro commands to XPA servers or to query
data from XPA servers.  XPA.jl can also be used to implement an XPA server.
The package exploits the power of `ccall` to directly call the routines of the
compiled XPA library.


## Table of contents

```@contents
Pages = ["intro.md", "client.md", "install.md", "misc.md", "server.md",
         "library.md"]
```

## Index

```@index
```
