# A Julia interface to the XPA messaging system

This [Julia](http://julialang.org/) package provides an interface to the [XPA
Messaging System](https://github.com/ericmandel/xpa) for seamless communication
between many kinds of Unix/Windows programs, including X programs and Tcl/Tk
programs.  For instance, this message system is used for some popular
astronomical tools such as [SAOImage-DS9](http://ds9.si.edu/site/Home.html).

XPA.jl can be used to send commands and data to XPA servers, to query data from
XPA servers or to implement an XPA server.  The interface exploits the power of
`ccall` to directly call the routines of the compiled XPA library.

| Documentation                              | License                                                                                      | Travis                                                                                                    |
|:-------------------------------------------|:---------------------------------------------------------------------------------------------|:----------------------------------------------------------------------------------------------------------|
| [Devel](https://emmt.github.io/XPA.jl/dev) | [![License](http://img.shields.io/badge/license-MIT-brightgreen.svg?style=flat)](LICENSE.md) | [![Build Status](https://travis-ci.org/emmt/XPA.jl.svg?branch=master)](https://travis-ci.org/emmt/XPA.jl) |
