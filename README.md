# A Julia interface to the XPA messaging system

This [Julia](http://julialang.org/) package provides an interface to the [XPA
Messaging System](https://github.com/ericmandel/xpa) for seamless communication
between many kinds of Unix/Windows programs, including X programs and Tcl/Tk
programs.  For instance, this message system is used for some popular
astronomical tools such as [SAOImage-DS9](http://ds9.si.edu/site/Home.html).

XPA.jl can be used to send commands and data to XPA servers, to query data from
XPA servers or to implement an XPA server.  The interface exploits the power of
`ccall` to directly call the routines of the compiled XPA library.

The [DS9.jl](https://github.com/JuliaAstro/DS9.jl) package is a Julia package
that exploits XPA.jl to communicate with [SAOImage-DS9](http://ds9.si.edu/site/Home.html).

| **Documentation**                                                     | **License**                     | **Build Status**              | **Code Coverage**               |
|:---------------------------------------------------------------------:|:-------------------------------:|:-----------------------------:|:-------------------------------:|
| [![][doc-stable-img]][doc-stable-url] [![][doc-dev-img]][doc-dev-url] | [![][license-img]][license-url] | [![][ci-img]][ci-url]         | [![][codecov-img]][codecov-url] |


[doc-stable-img]: https://img.shields.io/badge/docs-stable-blue.svg
[doc-stable-url]: https://juliaastro.org/XPA/stable/

[doc-dev-img]: https://img.shields.io/badge/docs-dev-blue.svg
[doc-dev-url]: https://juliaastro.org/XPA.jl/dev/

[license-url]: ./LICENSE.md
[license-img]: http://img.shields.io/badge/license-MIT-brightgreen.svg?style=flat

[ci-img]: https://github.com/JuliaAstro/XPA.jl/actions/workflows/CI.yml/badge.svg
[ci-url]: https://github.com/JuliaAstro/XPA.jl/actions/workflows/CI.yml

[appveyor-img]: https://ci.appveyor.com/api/projects/status/github/JuliaAstro/XPA.jl?branch=master
[appveyor-url]: https://ci.appveyor.com/project/JuliaAstro/XPA-jl/branch/master

[coveralls-img]: https://coveralls.io/repos/JuliaAstro/XPA.jl/badge.svg?branch=master&service=github
[coveralls-url]: https://coveralls.io/github/JuliaAstro/XPA.jl?branch=master

[codecov-img]: https://codecov.io/github/JuliaAstro/XPA.jl/graph/badge.svg?token=S2G8C2AIDP
[codecov-url]: https://codecov.io/github/JuliaAstro/XPA.jl

[julia-url]: https://julialang.org/
[julia-pkgs-url]: https://pkg.julialang.org/
