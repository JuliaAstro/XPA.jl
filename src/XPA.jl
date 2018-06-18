#
# XPA.jl --
#
# Implement XPA communication via the dynamic library.
#
#------------------------------------------------------------------------------
#
# This file is part of XPA.jl released under the MIT "expat" license.
# Copyright (C) 2016-2018, Éric Thiébaut (https://github.com/emmt/XPA.jl).
#
module XPA

const libxpa = "libxpa."*Libdl.dlext

const Byte = UInt8
const NULL = convert(Ptr{Byte}, 0)

# Super type for client and server XPA objects.
abstract type Handle end

# XPA client, must be mutable to be finalized.
mutable struct Client <: Handle
    ptr::Ptr{Void} # pointer to XPARec structure
end

# XPA server, must be mutable to be finalized.
mutable struct Server <: Handle
    ptr::Ptr{Void} # pointer to XPARec structure
end

struct AccessPoint
    class::String # class of the access point
    name::String  # name of the access point
    addr::String  # socket access method (host:port for inet,
                  # file for local/unix)
    user::String  # user name of access point owner
    access::UInt  # allowed access
end

# Server mode flags for receive, send, info.
const MODE_BUF     = 1
const MODE_FILLBUF = 2
const MODE_FREEBUF = 4
const MODE_ACL     = 8

const GET = UInt(1)
const SET = UInt(2)
const INFO = UInt(4)

"""

`XPA.TEMPORARY` can be specified wherever an `XPA.Client` instance is expected
to use a non-persistent XPA connection.

"""
const TEMPORARY = Client(C_NULL)

# Dictionary to maintain references to callbacks while they are used by an
# XPA server.
const _SERVERS = Dict{Ptr{Void},Any}()

"""
```julia
XPA.Client()
```

yields a persistent XPA client handle which can be used for calls to `XPA.set`
and XPA.get` methods.  Persistence means that a connection to an XPA server is
not closed when one of the above calls is completed but will be re-used on
successive calls.  Using `XPA.Client()` therefore saves the time it takes to
connect to a server, which could be significant with slow connections or if
there will be a large number of exchanges with a given access point.

See also: [`XPA.set`](@ref), [`XPA.get`](@ref)

"""
function Client()
    # The argument of XPAOpen is currently ignored (it is reserved for future
    # use).
    ptr = ccall((:XPAOpen, libxpa), Ptr{Void}, (Ptr{Void},), C_NULL)
    ptr != C_NULL || error("failed to create a persistent XPA connection")
    obj = Client(ptr)
    finalizer(obj, close)
    return obj
end

Base.isopen(xpa::Handle) = xpa.ptr != C_NULL

function Base.close(xpa::Client)
    if (ptr = xpa.ptr) != C_NULL
        xpa.ptr = C_NULL
        ccall((:XPAClose, libxpa), Void, (Ptr{Void},), ptr)
    end
    return nothing
end

function Base.close(xpa::Server)
    if (ptr = xpa.ptr) != C_NULL
        xpa.ptr = C_NULL
        ccall((:XPAFree, libxpa), Cint, (Ptr{Void},), ptr)
        haskey(_SERVERS, ptr) && pop!(_SERVERS, ptr)
    end
    return nothing
end

function list(xpa::Client = TEMPORARY)
    lst = Array{AccessPoint}(0)
    for str in get_lines(xpa, "xpans")
        arr = split(str)
        if length(arr) != 5
            warn("expecting 5 fields per access point (\"$str\")")
            continue
        end
        access = UInt(0)
        for c in arr[3]
            if c == 'g'
                access |= GET
            elseif c == 's'
                access |= SET
            elseif c == 'i'
                access |= INFO
            else
                warn("unexpected access string (\"$(arr[3])\")")
                continue
            end
        end
        push!(lst, AccessPoint(arr[1], arr[2], arr[4], arr[5], access))
    end
    return lst
end

function _fetch(::Type{String}, ptr::Ptr{Byte})
    if ptr == C_NULL
        str = ""
    else
        str = unsafe_string(ptr)
        _free(ptr)
    end
    return str
end

"""
```julia
error(srv, msg) -> XPA.FAILURE
```

communicates error message `msg` to the client when serving a request by XPA
server `srv`.  This method shall only be used by the send/receive callbacks of
an XPA server.

"""
function Base.error(srv::Server, msg::AbstractString)
    ccall((:XPAError, libxpa), Cint, (Ptr{Void}, Cstring),
          srv.ptr, msg) == SUCCESS ||
              error("XPAError failed for message \"$msg\"");
    return FAILURE
end

"""
```julia
XPA.get([xpa,] apt [, params...]) -> tup
```

retrieves data from one or more XPA access points identified by `apt` (a
template name, a `host:port` string or the name of a Unix socket file) with
parameters `params` (automatically converted into a single string where the
parameters are separated by a single space).  The result is a tuple of tuples
`(data,name,mesg)` where `data` is a vector of bytes (`UInt8`), `name` is a
string identifying the server which answered the request and `mesg` is an error
message (a zero-length string `""` if there are no errors).  Optional argument
`xpa` specifies an XPA handle (created by `XPA.Client()`) for faster
connections.

The following keywords are available:

* `nmax` specifies the maximum number of answers, `nmax=1` by default.
  Specify `nmax=-1` to use the maximum number of XPA hosts.

* `mode` specifies options in the form `"key1=value1,key2=value2"`.

See also: [`XPA.Client`](@ref), [`XPA.set`](@ref).

"""
function get(xpa::Client, apt::AbstractString, params::AbstractString...;
             mode::AbstractString = "", nmax::Integer = 1)
    if nmax == -1
        nmax = config("XPA_MAXHOSTS")
    end
    bufs = Array{Ptr{Byte}}(nmax)
    lens = Array{Csize_t}(nmax)
    names = Array{Ptr{Byte}}(nmax)
    errs = Array{Ptr{Byte}}(nmax)
    n = ccall((:XPAGet, libxpa), Cint,
              (Ptr{Void}, Cstring, Cstring, Cstring, Ptr{Ptr{Byte}},
               Ptr{Csize_t}, Ptr{Ptr{Byte}}, Ptr{Ptr{Byte}}, Cint),
              xpa.ptr, apt, join(params, " "), mode,
              bufs, lens, names, errs, nmax)
    n ≥ 0 || error("unexpected result from XPAGet")
    return ntuple(i -> (_fetch(bufs[i], lens[i]),
                        _fetch(String, names[i]),
                        _fetch(String, errs[i])), n)
end

get(args::AbstractString...; kwds...) =
    get(TEMPORARY, args...; kwds...)

"""
```julia
XPA.get_bytes([xpa,] apt [, params...]; mode=...) -> buf
```

yields the `data` part of the answers received by an `XPA.get` request as a
vector of bytes.  Arguments `xpa`, `apt` and `params...` and keyword `mode` are
passed to `XPA.get` limiting the number of answers to be at most one.  An error
is thrown if `XPA.get` returns a non-empty error message.

See also: [`XPA.get`](@ref).

"""
function get_bytes(args...; kwds...)
    tup = get(args...; nmax=1, kwds...)
    local data::Vector{Byte}
    if length(tup) ≥ 1
        (data, name, mesg) = tup[1]
        length(mesg) > 0 && error(mesg)
    else
        data = Array{Byte}(0)
    end
    return data
end

"""
```julia
XPA.get_text([xpa,] apt [, params...]; mode=...) -> str
```

converts the result of `XPA.get_bytes` into a single string.

See also: [`XPA.get_bytes`](@ref).

"""
get_text(args...; kwds...) =
    unsafe_string(pointer(get_bytes(args...; kwds...)))

"""
```julia
XPA.get_lines([xpa,] apt [, params...]; keep=false, mode=...) -> arr
```

splits the result of `XPA.get_text` into an array of strings, one for each
line.  Keyword `keep` can be set `true` to keep empty lines.

See also: [`XPA.get_text`](@ref).

"""
get_lines(args...; keep::Bool = false, kwds...) =
    split(chomp(get_text(args...; kwds...)), r"\n|\r\n?", keep=keep)

"""
```julia
XPA.get_words([xpa,] apt [, params...]; mode=...) -> arr
```

splits the result of `XPA.get_text` into an array of words.

See also: [`XPA.get_text`](@ref).

"""
get_words(args...; kwds...) =
    split(get_text(args...; kwds...), r"[ \t\n\r]+", keep=false)

"""
```julia
XPA.set([xpa,] apt [, params...]; data=nothing) -> tup
```

sends `data` to one or more XPA access points identified by `apt` with
parameters `params` (automatically converted into a single string where the
parameters are separated by a single space).  The result is a tuple of tuples
`(name,mesg)` where `name` is a string identifying the server which received
the request and `mesg` is an error message (a zero-length string `""` if there
are no errors).  Optional argument `xpa` specifies an XPA handle (created by
`XPA.Client()`) for faster connections.

The following keywords are available:

* `data` the data to send, may be `nothing` or an array.  If it is an array, it
  must be an instance of a sub-type of `DenseArray` which implements the
  `pointer` and `sizeof` methods.

* `nmax` specifies the maximum number of recipients, `nmax=1` by default.
  Specify `nmax=-1` to use the maximum possible number of XPA hosts.

* `mode` specifies options in the form `"key1=value1,key2=value2"`.

* `check` specifies whether to check for errors.  If this keyword is set true,
  an error is thrown for the first error message `mesg` encountered in the list
  of answers.

See also: [`XPA.Client`](@ref), [`XPA.get`](@ref).

"""
function set(xpa::Client, apt::AbstractString, params::AbstractString...;
             data::Union{DenseArray,Void} = nothing,
             mode::AbstractString = "",
             nmax::Integer = 1,
             check::Bool = false)
    local buf::Ptr, len::Int
    if isa(data, Void)
        buf = C_NULL
        len = 0
    else
        @assert isbits(eltype(data))
        buf = pointer(data)
        len = sizeof(data)
    end
    if nmax == -1
        nmax = config("XPA_MAXHOSTS")
    end
    names = Array{Ptr{Byte}}(nmax)
    errs = Array{Ptr{Byte}}(nmax)
    n = ccall((:XPASet, libxpa), Cint,
              (Ptr{Void}, Cstring, Cstring, Cstring, Ptr{Void},
               Csize_t, Ptr{Ptr{Byte}}, Ptr{Ptr{Byte}}, Cint),
              xpa.ptr, apt, join(params, " "), mode,
              buf, len, names, errs, nmax)
    n ≥ 0 || error("unexpected result from XPASet")
    tup = ntuple(i -> (_fetch(String, names[i]),
                       _fetch(String, errs[i])), n)
    if check
        for (name, mesg) in tup
            if length(mesg) ≥ 9 && mesg[1:9] == "XPA\$ERROR"
                error(mesg)
            end
        end
    end
    return tup
end

set(args::AbstractString...; kwds...) =
    set(TEMPORARY, args...; kwds...)

# These default values are defined in "xpap.h" and can be changed by
# user environment variable:
const _DEFAULTS = Dict{AbstractString,Any}("XPA_MAXHOSTS" => 100,
                                           "XPA_SHORT_TIMEOUT" => 15,
                                           "XPA_LONG_TIMEOUT" => 180,
                                           "XPA_CONNECT_TIMEOUT" => 10,
                                           "XPA_TMPDIR" => "/tmp/.xpa",
                                           "XPA_VERBOSITY" => true,
                                           "XPA_IOCALLSXPA" => false)

function config(key::AbstractString)
    global _DEFAULTS, ENV
    haskey(_DEFAULTS, key) || error("unknown XPA parameter \"$key\"")
    def = _DEFAULTS[key]
    if haskey(ENV, key)
        val = haskey(ENV, key)
        return (isa(def, Bool) ? (parse(Int, val) != 0) :
                isa(def, Integer) ? parse(Int, val) : val)
    else
        return def
    end
end

function config(key::AbstractString, val::T) where {T<:Union{Integer,Bool,
                                                             AbstractString}}
    global _DEFAULTS, ENV
    old = config(key) # also check validity of key
    def = _DEFAULTS[key]
    if isa(def, Integer) && isa(val, Integer)
        ENV[key] = dec(val)
    elseif isa(def, Bool) && isa(val, Bool)
        ENV[key] = (val ? "1" : "0")
    elseif isa(def, AbstractString) && isa(val, AbstractString)
        ENV[key] = val
    else
        error("invalid type for XPA parameter \"$key\"")
    end
    return old
end

config(key::Symbol) = config(string(key))
config(key::Symbol, val) = config(string(key), val)

#------------------------------------------------------------------------------
# SERVER

abstract type Callback end

struct SendCallback{T} <: Callback
    send::Function # function to call on `XPAGet` requests
    data::T        # client data
    acl::Bool      # enable access control
    freebuf::Bool  # free buf after callback completes
end

SendCallback(send::Function; kwds...) =
    SendCallback(send, nothing; kwds...)

function SendCallback(send::Function,
                      data::T;
                      acl::Bool = true,
                      freebuf::Bool = true) where T
    SendCallback{T}(send, data, acl, freebuf)
end

struct ReceiveCallback{T} <: Callback
    recv::Function # function to call on `XPASet` requests
    data::T        # client data
    acl::Bool      # enable access control
    buf::Bool      # server expects data bytes from client
    fillbuf::Bool  # read data into buffer before executing callback
    freebuf::Bool  # free buffer after callback completes
end

ReceiveCallback(recv::Function; kwds...) =
    ReceiveCallback(recv, nothing; kwds...)

function ReceiveCallback(recv::Function,
                         data::T;
                         acl::Bool = true,
                         buf::Bool = true,
                         fillbuf::Bool = true,
                         freebuf::Bool = true) where T
    ReceiveCallback{T}(recv, data, acl, buf, fillbuf, freebuf)
end

# Addresses of callbacks cannot be precompiled so we set them at run time in
# the __init__() method of the module.
const _SEND_REF = Ref{Ptr{Void}}(0)
const _RECV_REF = Ref{Ptr{Void}}(0)
function __init__()
    global _SEND_REF, _RECV_REF
    _SEND_REF[] = cfunction(_send, Cint,
                            (Ptr{Void},      # client_data
                             Ptr{Void},      # call_data
                             Ptr{Byte},      # paramlist
                             Ptr{Ptr{Byte}}, # buf
                             Ptr{Csize_t}))  # len
    _RECV_REF[] = cfunction(_recv, Cint,
                            (Ptr{Void},      # client_data
                             Ptr{Void},      # call_data
                             Ptr{Byte},      # paramlist
                             Ptr{Byte},      # buf
                             Csize_t))       # len
end

function _send(clientdata::Ptr{Void}, handle::Ptr{Void}, params::Ptr{Byte},
               bufptr::Ptr{Ptr{Byte}}, lenptr::Ptr{Csize_t})
    # Check assumptions.
    srv = Server(handle)
    (get_send_mode(srv) & MODE_FREEBUF) != 0 ||
        return error(srv, "send mode must have `freebuf` option set")

    # Call actual callback providing the client data is the address of a known
    # SendCallback object.
    return _send(unsafe_pointer_to_objref(clientdata), srv,
                 (params == C_NULL ? "" : unsafe_string(params)),
                 bufptr, lenptr)
end

function _send(cb::SendCallback, srv::Server, params::String,
               bufptr::Ptr{Ptr{Byte}}, lenptr::Ptr{Csize_t})
    return cb.send(cb.data, srv, params, bufptr, lenptr)
end

# The receive callback is executed in response to an external request from the
# `xpaset` program, the `XPASet()` routine, or `XPASetFd()` routine.
function _recv(clientdata::Ptr{Void}, handle::Ptr{Void}, params::Ptr{Byte},
               buf::Ptr{Byte}, len::Csize_t)
    # Call actual callback providing the client data is the address of a known
    # ReceiveCallback object.
    return _recv(unsafe_pointer_to_objref(clientdata), Server(handle),
                 (params == C_NULL ? "" : unsafe_string(params)), buf, len)
end

# If the receive callback mode has option `freebuf=false`, then `buf` must be
# managed by the callback, by default `freebuf=true` and the buffer is
# automatically released after callback completes.
function _recv(cb::ReceiveCallback, srv::Server, params::String,
               buf::Ptr{Byte}, len::Csize_t)
    return cb.recv(cb.data, srv, params, buf, len)
end

_callback(::Void) = C_NULL
_context(::Void) = C_NULL
_mode(::Void) = ""

_callback(::SendCallback) = _SEND_REF[]
_callback(::ReceiveCallback) = _RECV_REF[]
_context(cb::Callback) = pointer_from_objref(cb)
_mode(cb::SendCallback) = "acl=$(cb.acl),freebuf=$(cb.freebuf)"
_mode(cb::ReceiveCallback) =
    "acl=$(cb.acl),buf=$(cb.buf),fillbuf=$(cb.fillbuf),freebuf=$(cb.freebuf)"


"""

You must make sure that the `send` and `recv` callbacks exist during the
life of the server.

The send callback is will be called in response to an external request from the
`xpaget program`, the `XPAGet()` routine, or `XPAGetFd()` routine.  This
callback is used to send data to the requesting client and has the following
signature:

```julia
function sproc(data, srv::XPA.Server, params::String)
    println("send: \$params")
    result = ...
    return XPA.setbuf!(srv, result)
end

function rproc(data, srv::XPA.Server, params::String,
	       buf::Ptr{UInt8}, len::Integer)
    println("receive: \$params")
    arr = unsafe_wrap(buf, len, false)
    ...
    return XPA.SUCCESS
end

send = XPA.SendCallback(sproc, sdata)
recv = XPA.ReceiveCallback(rproc, rdata)

server = XPA.Server(class, name, help, send, recv)
```
"""
function Server(class::AbstractString,
                name::AbstractString,
                help::AbstractString,
                send::Union{SendCallback, Void},
                recv::Union{ReceiveCallback, Void})
    # Create an XPA server and a reference to the callback objects to make
    # sure they are not garbage collected while the server is running.
    server = Server(class, name, help,
                    _callback(send), _context(send), _mode(send),
	            _callback(recv), _context(recv), _mode(recv))
    _SERVERS[server.ptr] = (send, recv)
    return server
end

function Server(class::AbstractString, name::AbstractString,
                help::AbstractString,
                sproc::Ptr{Void}, sdata::Ptr{Void}, smode::AbstractString,
                rproc::Ptr{Void}, rdata::Ptr{Void}, rmode::AbstractString)
    ptr = ccall((:XPANew, libxpa), Ptr{Void},
                (Cstring, Cstring, Cstring,
	         Ptr{Void}, Ptr{Void}, Cstring,
	         Ptr{Void}, Ptr{Void}, Cstring),
                class, name, help,
                sproc, sdata, smode,
                rproc, rdata, rmode)
    ptr != C_NULL || error("failed to create an XPA server")
    obj = Server(ptr)
    finalizer(obj, close)
    (get_send_mode(obj) & MODE_FREEBUF) != 0 ||
        error("send mode must have `freebuf` option set")
    return obj
end


"""
 * Purpose:	non-blocking handling of XPA access points
 *		timeout in millisecs, but if negative, no timeout is used
 *
 * Returns:	number of requests processed (if maxreq >=0)
 *		number of requests pending   (if maxreq <0)
"""
poll(msec::Integer, maxreq::Integer) =
    ccall((:XPAPoll, libxpa), Cint, (Cint, Cint), msec, maxreq)

mainloop() =
    ccall((:XPAMainLoop, libxpa), Cint, ())

"""

`XPA.SUCCESS` and `XPA.FAILURE` are the possible values returned by the
callbacks of an XPA server.

"""
const SUCCESS = Cint(0)
const FAILURE = Cint(-1)

# FIXME: check return value!
seterror(srv::Server, msg::AbstractString) =
    ccall((:XPAError, libxpa), Cint, (Ptr{Void}, Cstring), srv.ptr, msg)

# FIXME: check return value!
setmessage(srv::Server, msg::AbstractString) =
    ccall((:XPAMessage, libxpa), Cint, (Ptr{Void}, Cstring), srv.ptr, msg)

"""
```julia
XPA.setbuf!(bufptr, lenptr, data)
```

or

```julia
XPA.setbuf!(bufptr, lenptr, buf, len)
```

set the values at addresses `bufptr` and `lenptr` to be the address and size of
a dynamically allocated buffer storing the contents of `data` (or a copy of the
`len` bytes at address `buf`).  This method is meant to be called by an XPA
server to store the result of an `XPAGet()` request.

The callback serving a send request should have the following structure:

```julia
function sendcallback(ctx::T, srv::XPA.Server, params::String,
                      bufptr::Ptr{Ptr{UInt8}}, lenptr::Ptr{Csize_t})
    result = ...
    try
        XPA.setbuf!(bufptr, lenptr, result)
        return XPA.SUCCESS
    catch err
        error(srv, err)
        return XPA.FAILURE
    end
end
```

with `ctx` the client data of the send callback, `srv` the XPA server serving
the request, `params` the parameter list of the `XPAGet()` call, `bufptr` and
`lenptr` the addresses where to store the result of the request and ist size
(in bytes).

"""
# FIXME: We are always assuming that the answer to a XPAGet request is a
#        dynamically allocated buffer which is deleted by `XPAHandler`.
#        We should make sure of that.
function setbuf!(bufptr::Ptr{Ptr{Byte}}, lenptr::Ptr{Csize_t},
                 ptr::Ptr{Byte}, len::Integer)
    # This function is similar to `XPASetBuf` except that it verifies that no
    # prior buffer has been set.
    (unsafe_load(bufptr) == NULL && unsafe_load(lenptr) == 0) ||
        error("setbuf! can be called only once")
    if ptr != NULL
        len > 0 || error("invalid number of bytes ($len) for non-NULL pointer")
        buf = ccall(:malloc, Ptr{Byte}, (Csize_t,), len)
        buf != NULL || throw(OutOfMemoryError())
        ccall(:memcpy, Ptr{Byte}, (Ptr{Byte}, Ptr{Byte}, Csize_t,),
              buf, ptr, len)
        unsafe_store!(bufptr, buf)
        unsafe_store!(lenptr, len)
    else
        len == 0 || error("invalid number of bytes ($len) for NULL pointer")
    end
    return nothing
end

setbuf!(bufptr::Ptr{Ptr{Byte}}, lenptr::Ptr{Csize_t}, ::Void) =
    setbuf!(bufptr, lenptr, NULL, 0)

function setbuf!(bufptr::Ptr{Ptr{Byte}}, lenptr::Ptr{Csize_t},
                 val::Union{Symbol,AbstractString})
    return setbuf!(bufptr, lenptr, String(val))
end

setbuf!(bufptr::Ptr{Ptr{Byte}}, lenptr::Ptr{Csize_t}, str::String) =
    setbuf!(bufptr, lenptr, Base.unsafe_convert(Ptr{Byte}, str), sizeof(str))

function setbuf!(bufptr::Ptr{Ptr{Byte}}, lenptr::Ptr{Csize_t},
                 arr::DenseArray{T,N}) where {T, N}
    @assert isbits(T)
    setbuf!(bufptr, lenptr, convert(Ptr{Byte}, pointer(arr)), sizeof(arr))
end

function setbuf!(bufptr::Ptr{Ptr{Byte}}, lenptr::Ptr{Csize_t}, val::T) where {T}
    @assert isbits(T)
    (unsafe_load(bufptr) == NULL && unsafe_load(lenptr) == 0) ||
        error("setbuf! can be called only once")
    len = sizeof(T)
    buf = ccall(:malloc, Ptr{Byte}, (Csize_t,), len)
    buf != NULL || throw(OutOfMemoryError())
    unsafe_store!(convert(Ptr{T}, buf), val)
    unsafe_store!(bufptr, buf)
    unsafe_store!(lenptr, len)
    return nothing
end

#------------------------------------------------------------------------------
# PRIVATE METHODS

"""
Private method:

```julia
_get_string(ptr, def = "")
```

converts a byte buffer into a Julia string.  If `ptr` is NULL, `def` is
returned.

"""
_get_string(ptr::Ptr{Byte}, def::String = "") =
    ptr == NULL ? def : unsafe_string(ptr)

"""
Private methods:

```julia
_get_field(T, ptr, off, def)
```

and

```julia
_get_field(T, ptr, off1, off2, def)
```

retrieve a field of type `T` at offset `off` (in bytes) with respect to address
`ptr`.  If two offsets are given, the first one refers to a pointer with
respect to which the second is applied.  If `ptr` is NULL, `def` is returned.

"""
_get_field(::Type{T}, ptr::Ptr{Void}, off::Int, def::T) where T =
    ptr == C_NULL ? def : unsafe_load(convert(Ptr{T}, ptr + off))

_get_field(::Type{String}, ptr::Ptr{Void}, off::Int, def::String) =
    _get_string(ptr == C_NULL ? NULL :
                unsafe_load(convert(Ptr{Ptr{Byte}}, ptr + off)), def)

function _get_field(::Type{T}, ptr::Ptr{Void}, off1::Int, off2::Int,
                    def::T) where T
    _get_field(T, _get_field(Ptr{Void}, ptr, off1, C_NULL), off2, def)
end

function _set_field(::Type{T}, ptr::Ptr{Void}, off::Int, val) where T
    @assert ptr != C_NULL
    unsafe_store!(convert(Ptr{T}, ptr + off), val)
end

include("constants.jl")

_get_comm(xpa::Handle) =
    _get_field(Ptr{Void}, xpa.ptr, _offsetof_comm, C_NULL)

for (memb, T, def) in ((:name,      String, ""),
                       (:class,     String, ""),
                       (:send_mode, Cint,   Cint(0)),
                       (:recv_mode, Cint,   Cint(0)),
                       (:method,    String, ""),
                       (:sendian,   String, "?"))
    off = Symbol(:_offsetof_, memb)
    func = Symbol(:get_, memb)
    @eval begin
        $func(xpa::Handle) = _get_field($T, xpa.ptr, $off, $def)
    end
end

for (memb, T, def) in ((:comm_status,  Cint,       Cint(0)),
                       (:comm_cmdfd,   Cint,       Cint(-1)),
                       (:comm_datafd,  Cint,       Cint(-1)),
                       (:comm_ack,     Cint,       Cint(1)),
                       (:comm_cendian, String,     "?"),
                       (:comm_buf,     Ptr{Byte},  NULL),
                       (:comm_len,     Csize_t,    Csize_t(0)))
    off = Symbol(:_offsetof_, memb)
    func = Symbol(:get_, memb)
    @eval begin
        $func(xpa::Handle) = _get_field($T, _get_comm(xpa), $off, $def)
    end
    if memb == :comm_buf || memb == :comm_len
        func = Symbol(:_set_, memb)
        @eval begin
            $func(xpa::Handle, val) =
                unsafe_store!(convert(Ptr{$T}, _get_comm(xpa) + $off), val)
        end
    end
end

"""

Private method `_fetch(...)` converts a pointer into a Julia vector or a
string and let Julia manage the memory.

"""
_fetch(ptr::Ptr{T}, nbytes::Integer) where T =
    ptr == C_NULL ? Array{T}(0) :
    unsafe_wrap(Array, ptr, div(nbytes, sizeof(T)), true)

_fetch(::Type{T}, ptr::Ptr, nbytes::Integer) where T =
    _fetch(convert(Ptr{T}, ptr), nbytes)

_fetch(ptr::Ptr{Void}, nbytes::Integer) = _fetch(Byte, ptr, nbytes)


"""
```julia
_malloc(n)
```

dynamically allocates `n` bytes and returns the corresponding byte pointer
(type `Ptr{UInt8}`).

"""
function _malloc(n::Integer) :: Ptr{Byte}
    ptr = ccall(:malloc, Ptr{Byte}, (Csize_t,), n)
    ptr != C_NULL || error("insufficient memory for $n byte(s)")
    return ptr
end

"""
```julia
_free(ptr)
```

frees dynamically allocated memory at address givne by `ptr` unless it is NULL.

"""
_free(ptr::Ptr) = (ptr == C_NULL || ccall(:free, Void, (Ptr{Void},), ptr))

"""
```julia
_memcpy!(dst, src, n)` -> dst
```

copies `n` bytes from address `src` to `dst` and return `dst` as a byte pointer
(type `Ptr{UInt8}`).

"""
_memcpy!(dst::Ptr, src::Ptr, n::Integer) :: Ptr{Byte} =
    ccall(:memcpy, Ptr{Byte}, (Ptr{Void}, Ptr{Void}, Csize_t), dst, src, n)

"""
```julia
_copy(arg)
```

yields a dynamically allocated copy of `arg` in the form of a byte pointer
(type `Ptr{UInt8}`).

"""
_copy(str::AbstractString) = _copy(push!(Vector{Byte}(str), 0))

function _copy(arr::DenseArray) :: Ptr{Byte}
    n = sizeof(arr)
    return _memcpy!(_malloc(n), pointer(arr), n)
end

end # module
