# Client operations

## Persistent client connection

For each client request, XPA is able to automatically establish a temporary
connection to the server.  This however implies some overheads and, to speed up
the connection, a persistent XPA client can be created by calling
`XPA.Client()` which returns an opaque object.  The connection is automatically
shutdown and related resources freed when the client object is garbage
collected.  The `close()` method can also by applied to the client object, in
that case all subsequent requests with the object will establish a (slow)
temporary connection.


## Getting data from one or more servers

### General method

To query something from one or more XPA servers, the most general method is:

```julia
XPA.get([xpa,] apt, params...) -> tup
```

which retrieves data from one or more XPA access points identified by `apt` (a
template name, a `host:port` string or the name of a Unix socket file) with
parameters `params...` (automatically converted into a single string where the
parameters are separated by a single space).  The result is a tuple of tuples
`(data,name,mesg)` where `data` is a vector of bytes (`UInt8`), `name` is a
string identifying the server which answered the request and `mesg` is an empty
string or a message (either an error or an informative message).  Optional
argument `xpa` specifies a persistent XPA client (created by `XPA.Client()`)
for faster connections.

The `XPA.get()` method recognizes the following keywords:

* Keyword `nmax` specifies the maximum number of answers, `nmax=1` by default.
  Use `nmax=-1` to use the maximum number of XPA hosts.  Note that there are as
  many tuples as answers in the result.

* `mode` specifies options in the form `"key1=value1,key2=value2"`.


### Simpler methods

There are simpler methods which return only the data part of the answer,
possibly after conversion.  These methods limit the number of answers to be at
most one and throw an error if `XPA.get()` returns a non-empty error message.
To retrieve the `data` part of the answer received by an `XPA.get()` request as
a vector of bytes, call the method:

```julia
XPA.get_bytes([xpa,] apt, params...; mode="") -> buf
```

where arguments `xpa`, `apt` and `params...` and keyword `mode` are passed to
`XPA.get()`.  To convert the result of `XPA.get_bytes()` into a single string,
call the method:

```julia
XPA.get_text([xpa,] apt, params...; mode="") -> str
```

To split the result of `XPA.get_text` into an array of strings, one for each
line, call the method:

```julia
XPA.get_lines([xpa,] apt, params...; keepempty=false, mode="") -> arr
```

where keyword `keepempty` can be set `true` to keep empty lines.

Finally, to split the result of `XPA.get_text()` into an array of words, call
the method:

```julia
XPA.get_words([xpa,] apt, params...; mode="") -> arr
```

## Examples

To retrieve the answer as a string:
```julia
XPA.get(String, [xpa,] apt, params...)
```

To retrieve the answer as (non-empty) words:

```julia
split(XPA.get(String, [xpa,] apt, params...))
```

add keyword `keepempty=true`to the call to `split(...)` to keep empty strings
in the result.

To retrieve the answer as (non-empty) lines:

```julia
split(XPA.get(String, [xpa,] apt, params...), r"\n|\r\n?")
```


## Sending data to one or more servers

The `XPA.set()` method is called to send a command and some optional data to a
server:

```julia
XPA.set([xpa,] apt, params...; data=nothing) -> tup
```

send `data` to one or more XPA access points identified by `apt` with
parameters `params...` (automatically converted into a single string where the
parameters are separated by a single space).  The result is a tuple of tuples
`(name,mesg)` where `name` is a string identifying the server which received
the request and `mesg` is an empty string or a message.  Optional argument
`xpa` specifies a persistent XPA client (created by `XPA.Client()`) for faster
connections.

The following keywords are accepted:

* `data` specifies the data to send, may be `nothing`, an array or a string.
  If it is an array, it must be an instance of a sub-type of `DenseArray` which
  implements the `pointer` method.

* `nmax` specifies the maximum number of recipients, `nmax=1` by default.
  Specify `nmax=-1` to use the maximum possible number of XPA hosts.

* `mode` specifies options in the form `"key1=value1,key2=value2"`.

* `check` specifies whether to check for errors.  If this keyword is set
  `true`, an error is thrown for the first non-empty error message `mesg`
  encountered in the list of answers.


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
