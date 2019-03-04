# Client operations

Client operations involve querying data from one or several XPA servers or
sending data to one or several XPA servers.


## Persistent client connection

For each client request, XPA is able to automatically establish a temporary
connection to the server.  This however implies some overheads and, to speed up
the connection, a persistent XPA client can be created by calling
[`XPA.Client()`](@ref) which returns an opaque object.  The
connection is automatically shutdown and related resources freed when the
client object is garbage collected.  The `close()` method can also by applied
to the client object, in that case all subsequent requests with the object will
establish a (slow) temporary connection.


## Getting data from one or more servers

### Available methods

To query something from one or more XPA servers, call [`XPA.get`](@ref) method:

```julia
XPA.get([xpa,] apt, args...) -> rep
```

which uses the client connection `xpa` to retrieve data from one or more XPA
access points identified by `apt` as a result of the command build from
arguments `args...`.  Argument `xpa` is optional, if it is not specified, a
(slow) temporary connection is established.  The XPA access point `apt` is a
string which can be a template name, a `host:port` string or the name of a Unix
socket file.  The utility [`XPA.list()`](@ref) can be called to list available
servers.  The arguments `args...` are automatically converted into a single
command string where the arguments are separated by a single space.

For instance:

```julia
julia> XPA.list()
1-element Array{XPA.AccessPoint,1}:
 XPA.AccessPoint("DS9", "ds9", "7f000001:44805", "eric", 0x0000000000000003)
```

indicates that a single XPA server is available and that it is
[SAOImage-DS9](http://ds9.si.edu/site/Home.html), an astronomical tool to
display images.  The server name is `DS9:ds9` which can be matched by the
template `DS9:*`, its address is `7f000001:44805`. Either of these strings can
be used to identify this server but only the address is unique.  Indeed there
may be more than one server with class `DS9` and name `ds9`.

In order to get the address of a more specific server, you max call
[`XPA.find(ident)`](@ref) where `ident` is a regular expression or a string
template to match against the `CLASS:NAME` identifier of the server.  For
instance:

```julia
julia> addr = XPA.find(r"^DS9:")
"7f000001:44805"
```

Keywords `user` or `throwerrors` can be specified to match the name of the
owner of the server or to throw an exception if no match is found.

To query the version number of SAOImage-DS9, we can do:

```julia
rep = XPA.get("DS9:*", "version");
```

For best performances, we can do the following:

```julia
ds9 = (XPA.Client(), XPA.find(r"^DS9:"; throwerrors=true));
rep = XPA.get(ds9..., "version");
```

and use `ds9...` in all calls to `XPA.get` or `XPA.set` (described later) to
use a fast client connection to the uniquely identified SAOImage-DS9 server.

The answer, say `rep`, to the `XPA.get` request is an instance of
[`XPA.Reply`](@ref).  Various methods are available to retrieve information or
data from `rep`.  For instance, `length(rep)` yields the number of answers
which may be zero if no servers have answered the request (the maximum number
of answers can be specified via the `nmax` keyword of [`XPA.get`](@ref); by
default, `nmax=1` to retrieve at most one answer).

There may be errors or messages associated with the answers.  To check whether
the `i`-th answer has an associated error message, call the
[`XPA.has_error`](@ref) method:

```julia
XPA.has_error(rep, i=1) -> boolean
```

!!! note
    Here and in all methods related to a specific answer in a reply to
    [`XPA.get`](@ref) or [`XPA.set`](@ref) requests, the answer index `i` can
    be any integer value.  If it is not such that `1 ≤ i ≤ length(rep)`, it is
    assumed that there is no corresponding answer and an empty (or false)
    result is returned.  By default, the first answer is always assumed (as if
    `i=1`).

To check whether there are any errors, call the [`XPA.has_errors`](@ref)
method:

```julia
XPA.has_errors(rep) -> boolean
```

To avoid checking for errors for every answer to all requests, the
[`XPA.get`](@ref) method has a `throwerrors` keyword that can be set `true` in
order to automatically throw an exception if there are any errors in the
answers.

The check whether the `i`-th answer has an associated message, call the
[`XPA.has_message`](@ref) method:

```julia
XPA.has_message(rep, i=1) -> boolean
```

To retrieve the message (perhaps an error message), call the
[`XPA.get_message`](@ref) method:

```julia
XPA.get_message(rep, i=1) -> string
```

which yields a string, possibly empty if there are no associated message with
the `i`-th answer in `rep` or if `i` is out of range.

To retrieve the identity of the server which answered the request, call the
[`XPA.get_server`](@ref) method:

```julia
XPA.get_server(rep, i=1) -> string
```

Usually the most interesting part of a particular answer is its data part which
can be extracted with the [`XPA.get_data`](@ref) method.  The general syntax to
retrieve the data associated with the `i`-th answer in `rep` is:

```julia
XPA.get_data([T, [dims,]], rep, i=1; preserve=false) -> data
```

where optional arguments `T` (a type) and `dims` (a list of dimensions) may be
used to specify how to interpret the data.  If they are not specified, a vector
of bytes (`Vector{UInt8}`) is returned.

!!! note
    For efficiency reason, copying the associated data is avoided if possible.
    This means that a call to [`XPA.get_data`](@ref) can *steal* the data and
    subsequent calls will behave as if the data part of the answer is empty.
    To avoid this (and force copying the data), use keyword `preserve=true` in
    calls to [`XPA.get_data`](@ref).  Data are always preserved when a `String`
    is extracted from the associated data.

Assuming `rep` is the result of some [`XPA.get`](@ref) or [`XPA.set`](@ref)
request, the following lines of pseudo-code illustrate the roles of the
optional `T` and `dims` arguments:

```julia
XPA.get_data(rep, i=1; preserve=false) -> buf::Vector{UInt8}
XPA.get_data(String, rep, i=1; preserve=false) -> str::String
XPA.get_data(Vector{S}, [len,] rep, i=1; preserve=false) -> vec::Vector{S}
XPA.get_data(Array{S}, (dim1, ..., dimN), rep, i=1; preserve=false) -> arr::Array{S,N}
XPA.get_data(Array{S,N}, (dim1, ..., dimN), rep, i=1; preserve=false) -> arr::Array{S,N}
```

here `buf` is a vector of bytes, `str` is a string, `vec` is a vector of `len`
elements of type `S` (if `len` is unspecified, the length of the vector is the
maximum possible given the actual size of the associated data) and `arr` is an
`N`-dimensional array whose element type is `S` and dimensions `dim1, ...,
dimN`.

If you are only interested in the data associated to a single answer, you may
directly specify arguments `T` and `dims` in the [`XPA.get`](@ref) call:

```julia
XPA.get(String, [xpa,] apt, args...) -> str::String
XPA.get(Vector{S}, [len,] [xpa,] apt, args...) -> vec::Vector{S}
XPA.get(Array{S}, (dim1, ..., dimN), [xpa,] apt, args...) -> arr::Array{S,N}
XPA.get_data(Array{S,N}, (dim1, ..., dimN), [xpa,] apt, args...) -> arr::Array{S,N}
```

In that case, exactly one answer and no errors are expected from the request
(as if `nmax=1` and `throwerrors=true` were specified).


## Examples

The following examples assume that you have created an XPA client connection
and identified the address of a SAOImage-DS9 server.  For instance:

```julia
using XPA
conn = XPA.Client()
addr = split(XPA.get_server(XPA.get(conn, "DS9:*", "version"; nmax=1, throwerrors=true)); keepempty=false)[2]
ds9 = (conn, addr)
```

To retrieve the version as a string:

```julia
julia> XPA.get(String, ds9..., "version")
"ds9 8.0.1\n"
```

To split the answer in (non-empty) words:

```julia
split(XPA.get(String, ds9..., "version"); keepempty=false)
```

You may use keyword `keepempty=true` in `split(...)` to keep empty strings in
the result.

To retrieve the answer as (non-empty) lines:

```julia
split(XPA.get(String, ds9..., "about"), r"\n|\r\n?"; keepempty=false)
```

To retrieve the dimensions of the current image:

```julia
map(s -> parse(Int, s), split(XPA.get(String, ds9..., "fits size"); keepempty=false))
```


## Sending data to one or more servers

The [`XPA.set`](@ref) method is called to send a command and some optional data
to a server.  The general syntax is:

```julia
XPA.set([xpa,] apt, args...; data=nothing) -> rep
```

which sends `data` to one or more XPA access points identified by `apt` with
arguments `args...` (automatically converted into a single string where the
arguments are separated by a single space).  As with [`XPA.get`](@ref), the
result is an instance of [`XPA.Reply`](@ref).  See the documentation of
[`XPA.get`](@ref) for explanations about how to manipulate such a result.

The [`XPA.set`](@ref) method accepts the same keywords as [`XPA.get`](@ref)
plus the `data` keyword used to specify the data to send to the server(s).  Its
value may be `nothing`, an array or a string.  If it is an array, it must have
contiguous elements (as a for a *dense* array) and must implement the `pointer`
method.  By default, `data=nothing` which means that no data are sent to the
server(s), just the command string made of the arguments `args...`.


## Messages

The returned messages string are of the form:

```julia
XPA$ERROR message (class:name ip:port)
```

or

```julia
XPA$MESSAGE message (class:name ip:port)
```

depending whether an error or an informative message has been set (with
`XPA.error()` or `XPA.message()` respectively).  Note that when there is an
error stored in an messages entry, the corresponding data buffers may or may
not be empty, depending on the particularities of the server.
