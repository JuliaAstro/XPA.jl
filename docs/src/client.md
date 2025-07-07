# Client operations

Client operations involve querying data from one or several XPA servers or sending data to
one or several XPA servers.


## Persistent client connection

To avoid reconnecting to the XPA server for each client request, `XPA.jl` maintains a
per-task persistent connection to the server. The end-user should therefore not have to
worry about creating persistent XPA client connections by calling [`XPA.Client()`](@ref) for
its application. Persistent XPA client connections are automatically shutdown and related
resources freed when tasks are garbage collected. The `close()` method can be applied to a
persistent XPA client connection (if this is done for one of the memorized per-task
connection, the connection will be automatically re-open if necessary). If needed,
[`XPA.connection()`](@ref XPA.connection) yields the persistent XPA client of the calling
task.


## Identifying XPA servers

The utility [`XPA.list`](@ref) can be called to get a list of running XPA servers:

```julia-repl
julia> XPA.list()
2-element Vector{XPA.AccessPoint}:
 XPA.AccessPoint(class="DS9", name="ds9", address="/tmp/.xpa/DS9_ds9-8.7b1.17760", user="eric", access="gs")
 XPA.AccessPoint(class="DS9", name="ds9", address="7f000001:43881", user="eric", access="gs")
```

indicates that two XPA servers are available and that both are
[SAOImage-DS9](http://ds9.si.edu/site/Home.html), an astronomical tool to display images,
the first one is using a Unix socket connection, the 2nd one an internet socket. The
identities of XPA servers is the string `$class:$name` which can be matched by a template
like `$class:*`. In this case, both servers are identified by `"DS9:ds9"` and matched by
`"DS9:*"`, to distinguish them, their address (which is unique) must be used. Using the
address is thus the recommended way to identify a unique XPA server.

[`XPA.list`](@ref) may be called with a predicate function to filter the list of servers.
This function is called with each [`XPA.AccessPoint`](@ref) of the running XPA servers and
shall return a Boolean to indicate whether the server is to be selected. For example, using
the `do`-block syntax:

```julia-repl
julia> apts = XPA.list() do apt
           apt.class == "DS9" && startswith(apt.address, "/")
       end
1-element Vector{XPA.AccessPoint}:
 XPA.AccessPoint(class="DS9", name="ds9-8.7b1", address="/tmp/.xpa/DS9_ds9-8.7b1.17760", user="eric", access="gs")

```

lists the SAOImage/DS9 servers with a Unix socket connection while:

```julia-repl
julia> apts = XPA.list() do apt
           apt.class == "DS9" && startswith(apt.address, r"[0-9a-fA-F]")
       end
1-element Vector{XPA.AccessPoint}:
 XPA.AccessPoint(class="DS9", name="ds9-8.7b1", address="7f000001:43881", user="eric", access="gs")

```

lists the SAOImage/DS9 servers with an internet socket connection. The `method` keyword may
also be used to choose a specific connection type. See [`XPA.list`](@ref) documentation for
more details and for other keywords.

In order to get the address of a unique XPA server, you may call [`XPA.find`](@ref) with a
predicate function to filter the matching servers and a selection method to keep a single
one among all matching servers. For example:

```julia-repl
julia> apt = XPA.find(; select=first) do apt
           apt.class == "DS9" && startswith(apt.name, "ds9")
       end
XPA.AccessPoint(class="DS9", name="ds9-8.7b1", address="/tmp/.xpa/DS9_ds9-8.7b1.17760", user="eric", access="gs")

```

The `select` keyword may be a function (as above) or a symbol such as `:interact` to have an
interactive menu for the user to choose one of the servers if there are more than one
matching servers:

```julia-repl
julia> apt = XPA.find(; select=:interact) do apt
           apt.class == "DS9"
       end
Please select one of:
 > (none)
   DS9:ds9-8.7b1 [address="/tmp/.xpa/DS9_ds9-8.7b1.17760", user="eric"]
   DS9:ds9-8.7b1 [address="7f000001:43881", user="eric"]
```

If there are no matching servers, [`XPA.find`](@ref) returns `nothing` unless the
`throwerrors` keyword is `true` to throw an exception if no match is found. If there are
more than one matching servers and no `select` method is specified or if it is not
`:interact`, [`XPA.find`](@ref) throws an error.

The address of an [`XPA.AccessPoint`](@ref) instance `apt` is given by `apt.address`. See
the documentation of [`XPA.AccessPoint`](@ref) for other properties of `apt` that can be
used in the filter and select functions.


## Getting data from one or more servers

### Available methods

To query something from one or more XPA servers, call the [`XPA.get`](@ref) method:

```julia
XPA.get([conn,] apt, args...) -> rep
```

which uses the persistent client connection `conn` to retrieve data from one or more XPA
access-points identified by `apt` as a result of the command build from arguments `args...`.
Argument `conn` is optional, if it is not specified, a per-task persistent connection is
used. The XPA access-point `apt` is an instance of [`XPA.AccessPoint`](@ref) or a string
which can be a template name, a `host:port` string or the path to a Unix socket file. The
arguments `args...` are converted into a single command string where the elements of
`args...` are separated by a single space.

For example, to query the version number of up to 5 running SAOImage-DS9 servers:

```julia-repl
julia> rep = XPA.get("DS9:*", "version"; nmax=5)
XPA.Reply (2 answers):
  1: server = "DS9:ds9-8.7b1 7f000001:43881", message = "", data = "ds9-8.7b1 8.7b1\n"
  2: server = "DS9:ds9-8.7b1 7f000001:36785", message = "", data = "ds9-8.7b1 8.7b1\n"

```

For best performances or to make sure to receive answers from a single server, a unique
server address shall be used, not a template as above.

The answer, bound to variable `rep` in the above example, to the [`XPA.get`](@ref) request
is an instance of [`XPA.Reply`](@ref) which is an abstract vector of answer(s). To access
the different parts of the `i`-th answer, use its properties. Property `rep[i].server`
yields the identifier and address of the server who sent the answer. Properties
`rep[i].has_message` and `rep[i].has_error` indicate whether `rep[i]` has an associated
message, respectively a normal one or an error one, which is given by `rep[i].message` (see
the [*Messages*](#Messages) section below). For example:

```julia-repl
julia> rep[1].server
"DS9:ds9-8.7b1 7f000001:43881"

julia> rep[1].has_message
false

julia> rep[1].has_error
false

julia> rep[1].message
""

```

Usually the most interesting part of a particular answer is its data part and property
`rep[i].data` is a callable object to access such data with the following syntax:

```julia
rep[i].data()                  # a vector of bytes
rep[i].data(String)            # an ASCII string
rep[i].data(T)                 # a value of type `T`
rep[i].data(Vector{T})         # the largest possible vector with elements of type `T`
rep[i].data(Array{T}, dims...) # an array of element type `T` and size `dims...`
```

For example:

```julia-repl
julia> rep[1].data(String)
"ds9-8.7b1 8.7b1\n"

```

See the documentation of [`XPA.Reply`](@ref) for more details.

To avoid checking for errors for every answer to an XPA request,
[`XPA.has_errors(rep)`](@ref XPA.has_errors) yields whether any of the answers in `rep` has
an error. Otherwise, the [`XPA.get`](@ref) method has a `throwerrors` keyword that can be
set `true` in order to automatically throw an exception if there are any errors in the
answers.

The syntax `rep[]` can be used to index the **unique answer** in `rep` throwing an error if
`length(rep) != 1`. If you are only interested in the data associated to a single answer,
you may thus do:

```julia
XPA.get(apt, args...)[].data(T, dims...)
```

This is so common that the same result is obtained by directly specifying `T` and,
optionally, `dims` as the leading arguments of a [`XPA.get`](@ref) call:

```julia
XPA.get(T, apt, args...)
XPA.get(T, dims, apt, args...)
```

In this context, exactly one answer and no errors are expected from the request (as if
`nmax=1` and `throwerrors=true` were specified) and `dims`, if specified, must be a single
integer or a tuple of integers.


## Examples

The following examples assume that `apt` is the access-point or the unique address of a
SAOImage-DS9 server. For instance:

```julia
using XPA
apt = XPA.find(apt -> apt.class == "DS9"; select=:interact)
```

To retrieve the version as a string:

```julia-repl
julia> XPA.get(String, apt, "version")
"ds9-8.7b1 8.7b1\n"
```

To retrieve the *about* answer as (non-empty) lines:

```julia-repl
julia> split(XPA.get(String, apt, "about"), r"\n|\r\n?"; keepempty=false)
10-element Vector{SubString{String}}:
 "SAOImageDS9"
 "Version 8.7b1"
 "Authors"
 "William Joye (Smithsonian Astrophysical Observatory)"
 "Eric Mandel (Smithsonian Astrophysical Observatory)"
 "Steve Murray (Smithsonian Astrophysical Observatory)"
 "Development funding"
 "NASA's Applied Information Systems Research Program (NASA/ETSO)"
 "Chandra X-ray Science Center (CXC)"
 "High Energy Astrophysics Science Archive Center (NASA/HEASARC)"

```

To retrieve the bits-per-pixel and the dimensions of the current image:

```julia
bitpix = parse(Int, XPA.get(String, apt, "fits bitpix"))
dims = map(s -> parse(Int, s), split(XPA.get(String, apt, "fits size"); keepempty=false))
```


## Sending data to one or more servers

The [`XPA.set`](@ref) method is called to send a command and some optional data to a server.
The general syntax is:

```julia
XPA.set([conn,] apt, args...; data=nothing) -> rep
```

which sends `data` to one or more XPA access-points identified by `apt` with arguments
`args...`. As with [`XPA.get`](@ref), arguments `args...` are converted into a string with a
single space to separate them and the result `rep` is an abstract vector of answer(s) stored
by an instance of [`XPA.Reply`](@ref). The [`XPA.set`](@ref) method accepts the same
keywords as [`XPA.get`](@ref) plus the `data` keyword used to specify the data to send to
the server(s). The value of `data` may be `nothing` if there is no data to send (this is the
default). Otherwise, the value of `data` may be an array, or an ASCII string. Arrays are
sent as binary data, if the array `data` does not have contiguous elements (that is not a
*dense array*), it is converted to an `Array`.

As an example, here is how to make SAOImage-DS9 server to quit:

```julia
XPA.set(apt, "quit");
```


## Messages

If not empty, message strings associated with XPA answers are of the form:

```julia
XPA$ERROR message (class:name ip:port)
```

or

```julia
XPA$MESSAGE message (class:name ip:port)
```

depending whether an error or an informative message has been set. When a message indicates
an error, the corresponding data buffers may or may not be empty, depending on the
particularities of the server.
