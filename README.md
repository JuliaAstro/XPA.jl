# A Julia interface to the XPA messaging system

This [Julia](http://julialang.org/) package provides an interface to the
[XPA Messaging System](https://github.com/ericmandel/xpa) which provides
seamless communication between many kinds of Unix/Windows programs, including X
programs and Tcl/Tk programs.

The Julia interface to the XPA message system can be used as a client to send
or query data from one or more XPA servers or to implement an XPA server.  The
interface exploits the power of `ccall` to directly call the routines of the
compiled XPA library.

This message system is used for some popular astronomical tools such as
[SAOImage-DS9](http://ds9.si.edu/site/Home.html).

The documentation is split in several parts:

- [Using XPA as a client](docs/src/client.md) explains how to send requests to
  XPA server(s) to set or get data, to excute commands, etc.

- [Using XPA as a server](docs/src/server.md) explains how to implement
   and XPA server.

- [Installation](docs/src/install.md) explains how to install XPA and this
  Julia package.
