# A Julia interface to the XPA messaging system

[![][https://img.shields.io/badge/docs-stable-blue.svg]][https://juliaastro.org/XPA/stable/]
[![][https://img.shields.io/badge/docs-dev-blue.svg]][https://juliaastro.org/XPA.jl/dev/]
[![][http://img.shields.io/badge/license-MIT-brightgreen.svg?style=flat]][./LICENSE.md]
[![][https://github.com/JuliaAstro/XPA.jl/actions/workflows/CI.yml/badge.svg]][https://github.com/JuliaAstro/XPA.jl/actions/workflows/CI.yml]
[![][https://codecov.io/github/JuliaAstro/XPA.jl/graph/badge.svg?token=S2G8C2AIDP]][https://codecov.io/github/JuliaAstro/XPA.jl]

This [Julia](http://julialang.org/) package provides an interface to the [XPA Messaging
System](https://github.com/ericmandel/xpa) for seamless communication between many kinds of
Unix/Windows programs, including X programs and Tcl/Tk programs. For instance, this message
system is used for some popular astronomical tools such as
[SAOImage-DS9](http://ds9.si.edu/site/Home.html).

`XPA.jl` can be used to send commands and data to XPA servers, to query data from XPA
servers or to implement an XPA server. The interface uses `ccall` to directly call the
routines of the compiled XPA library.

[SAOImageDS9.jl](https://github.com/JuliaAstro/SAOImageDS9.jl) is a Julia package that
exploits `XPA.jl` to communicate with [SAOImage-DS9](http://ds9.si.edu/site/Home.html).
