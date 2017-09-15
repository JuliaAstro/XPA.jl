# Julia interface to XPA Messaging System

This [Julia](http://julialang.org/) package provides an interface to the
[XPA Messaging System](https://github.com/ericmandel/xpa) which provides
seamless communication between many kinds of Unix/Windows programs, including X
programs and Tcl/Tk programs.


## Prerequisites

To use this package, **XPA** must be installed on your computer.
If this is not the case, they are available for different operating systems.
For example, on Ubuntu, just do:

    sudo apt-get install libxpa1

You may also install the package `libxpa-dev` but this is only mandatory if you
want to compile C programs using XPA.

Optionally, you may want to install [IPC.jl](https://github.com/emmt/IPC.jl)
package to benefit from shared memory.

In your Julia code/session, it is sufficient to do:

    import XPA

or:

    using XPA


## Using the XPA Message System

For now, only a subset of the client routines has been interfaced with Julia.
The interface exploits the power of `ccall` to directly call the routines of
the compiled XPA library.  The implemented methods are described in what
follows, more extensive XPA documentation can be found
[here](http://hea-www.harvard.edu/RD/xpa/help.html).


### Get data

The method:

    xpa_get(src [, params...]) -> tup

retrieves data from one or more XPA access points identified by `src` (a
template name, a `host:port` string or the name of a Unix socket file) with
parameters `params...` (automatically converted into a single string where the
parameters are separated by a single space).  The result is a tuple of tuples
`(data,name,mesg)` where `data` is a vector of bytes (`UInt8`), `name` is a
string identifying the server which answered the request and `mesg` is an error
message (a zero-length string `""` if there are no errors).

The following keywords are accepted:

* `nmax` specifies the maximum number of answers, `nmax=1` by default.
  Use `nmax=-1` to use the maximum number of XPA hosts.

* `xpa` specifies an XPA handle (created by `xpa_open`) for faster connections.

* `mode` specifies options in the form `"key1=value1,key2=value2"`.


There are simpler methods which return only the data part of the answer,
possibly after conversion.  These methods limit the number of answers to be at
most one and throw an error if `xpa_get` returns a non-empty error message.  To
retrieve the `data` part of the answer received by an `xpa_get` request as a
vector of bytes, call the method:

    xpa_get_bytes(src [, params...]; xpa=..., mode=...) -> buf

where arguments `src` and `params...` and keywords `xpa` and `mode` are passed
to `xpa_get`.  To convert the result of `xpa_get_bytes` into a single string,
call the method:

    xpa_get_text(src [, params...]; xpa=..., mode=...) -> str

To split the result of `xpa_get_text` into an array of strings, one for each
line, call the method:

    xpa_get_lines(src [, params...]; keep=false, xpa=..., mode=...) -> arr

where keyword `keep` can be set `true` to keep empty lines.  Finally, to split
the result of `xpa_get_text` into an array of words, call the method:

    xpa_get_words(src [, params...]; xpa=..., mode=...) -> arr


### Send data or commands

The method:

    xpa_set(dest [, params...]; data=nothing) -> tup

send `data` to one or more XPA access points identified by `dest` with
parameters `params...` (automatically converted into a single string where the
parameters are separated by a single space).  The result is a tuple of tuples
`(name,mesg)` where `name` is a string identifying the server which received
the request and `mesg` is an error message (a zero-length string `""` if there
are no errors).

The following keywords are accepted:

* `data` the data to send, may be `nothing` or an array.  If it is an array, it
  must be an instance of a sub-type of `DenseArray` which implements the
  `pointer` method.

* `nmax` specifies the maximum number of answers, `nmax=1` by default.
  Use `nmax=-1` to use the maximum number of XPA hosts.

* `xpa` specifies an XPA handle (created by `xpa_open`) for faster connections.

* `mode` specifies options in the form `"key1=value1,key2=value2"`.

* `check` specifies whether to check for errors.  If this keyword is set
  `true`, an error is thrown for the first non-empty error message `mesg`
  encountered in the list of answers.


## Open a persistent client connection

The method:

    xpa_open() -> handle

returns a handle to an XPA persistent connection and which can be used as the
argument of the `xpa` keyword of the `xpa_get` and `xpa_set` methods to speed
up requests.  The persistent connection is automatically closed when the handle
is finalized by the garbage collector.


## Utilities

The method:

    xpa_list(; xpa=...) -> arr

returns a list of the existing XPA access points as an array of structured
elements:

    arr[i].class    # class of the access point
    arr[i].name     # name of the access point
    arr[i].addr     # socket address
    arr[i].user     # user name of access point owner
    arr[i].access   # allowed access (g=xpaget,s=xpaset,i=xpainfo)

all members but `access` are strings, the `addr` member is the name of the
socket used for the connection (either `host:port` for internet socket, or a
file path for local unix socket), `access` is a combination of the bits
`XPA.GET`, `XPA.SET` and/or `XPA.INFO` depending whether `xpa_get`, `xpa_set`
and/or `xpa_info` access are granted.  Note that `xpa_info` is not yet
implemented.

XPA messaging system can be configured via environment variables.  The
method `xpa_config` provides means to get or set XPA settings:

    xpa_config(key) -> val

yields the current value of the XPA parameter `key` which is one of:

    "XPA_MAXHOSTS"
    "XPA_SHORT_TIMEOUT"
    "XPA_LONG_TIMEOUT"
    "XPA_CONNECT_TIMEOUT"
    "XPA_TMPDIR"
    "XPA_VERBOSITY"
    "XPA_IOCALLSXPA"

The key may be a symbol or a string, the value of a parameter may be a boolean,
an integer or a string.  To set an XPA parameter, call the method:

    xpa_config(key, val) -> old

which returns the previous value of the parameter.
