# Utilities

The method:

```julia
XPA.list([xpa]) -> arr
```

returns a list of the existing XPA access points as an array of structured
elements of type `XPA.AccessPoint` such that:

```julia
arr[i].class    # class of the access point
arr[i].name     # name of the access point
arr[i].addr     # socket address
arr[i].user     # user name of access point owner
arr[i].access   # allowed access (g=xpaget,s=xpaset,i=xpainfo)
```

all fields but `access` are strings, the `addr` field is the name of the socket
used for the connection (either `host:port` for internet socket, or a file path
for local unix socket), `access` is a combination of the bits `XPA.GET`,
`XPA.SET` and/or `XPA.INFO` depending whether `XPA.get()`, `XPA.set()` and/or
`XPA.info()` access are granted.  Note that `XPA.info()` is not yet implemented.

XPA messaging system can be configured via environment variables.  The methods
`XPA.getconfig` and `XPA.setconfig!` provides means to get or set XPA settings:

```julia
XPA.getconfig(key) -> val
```

yields the current value of the XPA parameter `key` which is one of:

```julia
"XPA_MAXHOSTS"
"XPA_SHORT_TIMEOUT"
"XPA_LONG_TIMEOUT"
"XPA_CONNECT_TIMEOUT"
"XPA_TMPDIR"
"XPA_VERBOSITY"
"XPA_IOCALLSXPA"
```

The key may be a symbol or a string, the value of a parameter may be a boolean,
an integer or a string.  To set an XPA parameter, call the method:

```julia
XPA.setconfig!(key, val) -> old
```

which returns the previous value of the parameter.
