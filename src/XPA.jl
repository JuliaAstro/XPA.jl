#
# XPA.jl --
#
# Implement XPA communication via the dynamic library.
#
#------------------------------------------------------------------------------
#
# This file is part of XPA.jl released under the MIT "expat" license.
# Copyright (C) 2016-2017, Éric Thiébaut (https://github.com/emmt/XPA.jl).
#
module XPA

const libxpa = "libxpa."*Libdl.dlext

# Super type for client and server XPA objects.
abstract type Handle end

# Must be mutable to be finalized.
mutable struct Client <: Handle
    ptr::Ptr{Void}
end

mutable struct Server <: Handle
    ptr::Ptr{Void}
end

struct AccessPoint
    class::String # class of the access point
    name::String  # name of the access point
    addr::String  # socket access method (host:port for inet,
                  # file for local/unix)
    user::String  # user name of access point owner
    access::UInt  # allowed access
end

const MODE_BUF     = 1
const MODE_FILLBUF = 2
const MODE_FREEBUF = 4
const MODE_ACL     = 8

const GET = UInt(1)
const SET = UInt(2)
const INFO = UInt(4)

"""

`XPA.TEMPORARY` can be specified wherever a `Client` connection is expected to
use a non-persistent XPA connection.

"""
const TEMPORARY = Client(C_NULL)

# Dictionary to maintain references to callbacks while they are used by an
# XPA server.
const _SERVERS = Dict{Ptr{Void},Any}()

"""
    XPA.Client()

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
    if xpa.ptr != C_NULL
        ptr = xpa.ptr
        xpa.ptr = C_NULL
        ccall((:XPAClose, libxpa), Void, (Ptr{Void},), ptr)
    end
end

function Base.close(xpa::Server)
    if xpa.ptr != C_NULL
        ptr = xpa.ptr
        xpa.ptr = C_NULL
        ccall((:XPAFree, libxpa), Cint, (Ptr{Void},), ptr)
        haskey(_SERVERS, ptr) && pop!(_SERVERS, ptr)
    end
    nothing
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

function _fetch(::Type{String}, ptr::Ptr{UInt8})
    if ptr == C_NULL
        str = ""
    else
        str = unsafe_string(ptr)
        _free(ptr)
    end
    return str
end

doc"""
    XPA.get([xpa,] apt [, params...]) -> tup

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
    bufs = Array{Ptr{UInt8}}(nmax)
    lens = Array{Csize_t}(nmax)
    names = Array{Ptr{UInt8}}(nmax)
    errs = Array{Ptr{UInt8}}(nmax)
    n = ccall((:XPAGet, libxpa), Cint,
              (Ptr{Void}, Cstring, Cstring, Cstring, Ptr{Ptr{UInt8}},
               Ptr{Csize_t}, Ptr{Ptr{UInt8}}, Ptr{Ptr{UInt8}}, Cint),
              xpa.ptr, apt, join(params, " "), mode,
              bufs, lens, names, errs, nmax)
    n ≥ 0 || error("unexpected result from XPAGet")
    return ntuple(i -> (_fetch(bufs[i], lens[i]),
                        _fetch(String, names[i]),
                        _fetch(String, errs[i])), n)
end

get(args::AbstractString...; kwds...) =
    get(TEMPORARY, args...; kwds...)

doc"""
    XPA.get_bytes([xpa,] apt [, params...]; mode=...) -> buf

yields the `data` part of the answers received by an `XPA.get` request as a
vector of bytes.  Arguments `xpa`, `apt` and `params...` and keyword `mode` are
passed to `XPA.get` limiting the number of answers to be at most one.  An error
is thrown if `XPA.get` returns a non-empty error message.

See also: [`XPA.get`](@ref).
"""
function get_bytes(args...; kwds...)
    tup = get(args...; nmax=1, kwds...)
    local data::Vector{UInt8}
    if length(tup) ≥ 1
        (data, name, mesg) = tup[1]
        length(mesg) > 0 && error(mesg)
    else
        data = Array{UInt8}(0)
    end
    return data
end


doc"""
    XPA.get_text([xpa,] apt [, params...]; mode=...) -> str

converts the result of `XPA.get_bytes` into a single string.

See also: [`XPA.get_bytes`](@ref).
"""
get_text(args...; kwds...) =
    unsafe_string(pointer(get_bytes(args...; kwds...)))

doc"""
    XPA.get_lines([xpa,] apt [, params...]; keep=false, mode=...) -> arr

splits the result of `XPA.get_text` into an array of strings, one for each
line.  Keyword `keep` can be set `true` to keep empty lines.

See also: [`XPA.get_text`](@ref).
"""
get_lines(args...; keep::Bool = false, kwds...) =
    split(chomp(get_text(args...; kwds...)), r"\n|\r\n?", keep=keep)

doc"""
    XPA.get_words([xpa,] apt [, params...]; mode=...) -> arr

splits the result of `XPA.get_text` into an array of words.

See also: [`XPA.get_text`](@ref).
"""
get_words(args...; kwds...) =
    split(get_text(args...; kwds...), r"[ \t\n\r]+", keep=false)

doc"""
    XPA.set([xpa,] apt [, params...]; data=nothing) -> tup

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
  `pointer` method.

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
    names = Array{Ptr{UInt8}}(nmax)
    errs = Array{Ptr{UInt8}}(nmax)
    n = ccall((:XPASet, libxpa), Cint,
              (Ptr{Void}, Cstring, Cstring, Cstring, Ptr{Void},
               Csize_t, Ptr{Ptr{UInt8}}, Ptr{Ptr{UInt8}}, Cint),
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

function config{T<:Union{Integer,Bool,AbstractString}}(key::AbstractString,
                                                           val::T)
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

abstract type UnsafeBuffer end

struct SendCallback{T} <: Callback
    send::Function
    data::T
    acl::Bool     # enable access control
    freebuf::Bool # free buf after callback completes
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
    recv::Function
    data::T
    acl::Bool     # enable access control
    buf::Bool     # server expects data bytes from client
    fillbuf::Bool # read data into buf before executing callback
    freebuf::Bool # free buf after callback completes
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
                            (Ptr{Void},       # client_data
                             Ptr{Void},       # call_data
                             Ptr{UInt8},      # paramlist
                             Ptr{Ptr{UInt8}}, # buf
                             Ptr{Csize_t}))   # len
    _RECV_REF[] = cfunction(_recv, Cint,
                            (Ptr{Void},       # client_data
                             Ptr{Void},       # call_data
                             Ptr{UInt8},      # paramlist
                             Ptr{UInt8},      # buf
                             Csize_t))        # len
end

function _send(clientdata::Ptr{Void}, handle::Ptr{Void}, params::Ptr{UInt8},
               buf::Ptr{Ptr{UInt8}}, len::Ptr{Csize_t})
    resetbuf!(buf, len)
    return _send(unsafe_pointer_to_objref(clientdata), Server(handle),
                 (params == C_NULL ? "" : unsafe_string(params)), buf, len)
end

function _send(cb::SendCallback, xpa::Server, params::String,
               buf::Ptr{Ptr{UInt8}}, len::Ptr{Csize_t})
    return cb.send(cb.data, xpa, params, buf, len)
end


# The receive callback is executed in response to an external request from the
# `xpaset` program, the `XPASet()` routine, or `XPASetFd()` routine.
function _recv(clientdata::Ptr{Void}, handle::Ptr{Void}, params::Ptr{UInt8},
               buf::Ptr{UInt8}, len::Csize_t)
    return _recv(unsafe_pointer_to_objref(clientdata), Server(handle),
                 (params == C_NULL ? "" : unsafe_string(params)),#FIXME: use unsafe_wrap(String, ..., false)
                 buf, len)
end

function _recv(cb::ReceiveCallback, xpa::Server, params::String,
               buf::Ptr{UInt8}, len::Csize_t)
    # If the receive callback mode has option `freebuf=false`, then
    # `buf` must be managed by the callback, by default `freebuf=true`
    # and the buffer is automatically released after callback completes.
    #unsafe_wrap(Array, buf, len, false)
    return cb.recv(cb.data, xpa, params, buf, len)
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


    function sproc(data, xpa::XPA.Server, params::String,
                   buf::Ptr{Ptr{UInt8}}, len::Ptr{Csize_t})
        println("send: \$params")
        result = ...
        return XPA.setbuf!(xpa, result, true)
    end

    function rproc(data, xpa::XPA.Server, params::String,
                   buf::Ptr{UInt8}, len::Integer)
        println("receive: \$params")
        arr = unsafe_wrap(buf, len, false)
        ...
        return XPA.SUCCESS
    end

    send = XPA.SendCallback(sproc, sdata)
    recv = XPA.ReceiveCallback(rproc, rdata)

    server = XPA.Server(class, name, help, send, recv)

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
seterror(xpa::Server, msg::AbstractString) =
    ccall((:XPAError, libxpa), Cint, (Ptr{Void}, Cstring), xpa.ptr, msg)

# FIXME: check return value!
setmessage(xpa::Server, msg::AbstractString) =
    ccall((:XPAMessage, libxpa), Cint, (Ptr{Void}, Cstring), xpa.ptr, msg)

function resetbuf!(buf::Ptr{Ptr{UInt8}}, len::Ptr{Csize_t})
    unsafe_store!(buf, Ptr{UInt8}(0))
    unsafe_store!(len, 0)
end

"""
    XPA.setbuf!(xpa, arg, cpy)

set the buffer of the XPA server `xpa` to store the result of an XPAGet()
request.

"""
function setbuf!(xpa::Server, buf::Ptr{Void}, len::Csize_t, copy::Bool)
    # Second argument of `XPASetBuf` is a `char*` but we just want to deal with
    # an address.
    if ccall((:XPASetBuf, libxpa), Cint,
             (Ptr{Void}, Ptr{Void}, Csize_t, Cint),
             xpa.ptr, buf, len, copy) != SUCCESS
        error("illegal XPA server or insufficient memory")
    end
    nothing
end

setbuf!(xpa::Server, ::Void, ::Bool) = setbuf!(xpa, C_NULL, 0, false)

function setbuf!(xpa::Server, str::AbstractString, copy::Bool)
    copy == true || error("strings must be copied")
    arr = push!(Vector{UInt8}(str), 0)
    setbuf!(xpa, arr, sizeof(arr), copy)
end

function setbuf!(buf::Ptr{Ptr{UInt8}}, len::Ptr{Csize_t},
                 str::AbstractString, copy::Bool)
    copy == true || error("strings must be copied")
    arr = push!(Vector{UInt8}(str), 0)
    unsafe_store!(buf, _copy(arr))
    unsafe_store!(len, sizeof(arr))
    nothing
end

function setbuf!(buf::Ptr{Ptr{UInt8}}, len::Ptr{Csize_t},
                 arr::DenseArray{T,N}, copy::Bool) where {T, N}
    unsafe_store!(buf, copy ? _copy(arr) : Ptr{UInt8}(pointer(arr)))
    unsafe_store!(len, sizeof(arr))
    nothing
end

#------------------------------------------------------------------------------
# PRIVATE METHODS

"""
Private method:

    _get_string(ptr, def = "")

converts a byte buffer into a Julia string.  If `ptr` is NULL, `def` is
returned.
"""
_get_string(ptr::Ptr{UInt8}, def::String = "") =
    ptr == Ptr{UInt8}(0) ? def : unsafe_string(ptr)

"""
Private methods:

    _get_field(T, ptr, off, def)

and

    _get_field(T, ptr, off1, off2, def)

retrieve a field of type `T` at offset `off` (in bytes) with respect to address
`ptr`.  If two offsets are given, the first one refers to a pointer with
respect to which the second is applied.  If `ptr` is NULL, `def` is returned.

"""
_get_field(::Type{T}, ptr::Ptr{Void}, offset::Int, def::T) where T =
    ptr == C_NULL ? def : unsafe_load(Ptr{T}(ptr + offset))

_get_field(::Type{String}, ptr::Ptr{Void}, offset::Int, def::String) =
    _get_string(ptr == C_NULL ? Ptr{UInt8}(0) :
                unsafe_load(Ptr{Ptr{UInt8}}(ptr + offset)), def)

function _get_field(::Type{T}, ptr::Ptr{Void}, offset1::Int, offset2::Int,
                    def::T) where T
    _get_field(T, _get_field(Ptr{Void}, ptr, offset1, C_NULL), offset2, def)
end

include("getfields.jl")

"""

Private method `_fetch(...)` converts a pointer into a Julia vector or a
string and let Julia manage the memory.

"""
_fetch(ptr::Ptr{T}, nbytes::Integer) where T =
    ptr == C_NULL ? Array{T}(0) :
    unsafe_wrap(Array, ptr, div(nbytes, sizeof(T)), true)

_fetch(::Type{T}, ptr::Ptr, nbytes::Integer) where T =
    _fetch(convert(Ptr{T}, ptr), nbytes)

_fetch(ptr::Ptr{Void}, nbytes::Integer) = _fetch(UInt8, ptr, nbytes)


"""
    `_malloc(n)`

dynamically allocates `n` bytes and returns the corresponding byte pointer
(type `Ptr{UInt8}`).

"""
function _malloc(n::Integer) :: Ptr{UInt8}
    ptr = ccall(:malloc, Ptr{UInt8}, (Csize_t,), n)
    ptr != C_NULL || error("insufficient memory for $n byte(s)")
    return ptr
end

"""
    `_free(ptr)`

frees dynamically allocated memory at address givne by `ptr` unless it is NULL.

"""
_free(ptr::Ptr) = (ptr == C_NULL || ccall(:free, Void, (Ptr{Void},), ptr))

"""
    `_memcpy!(dst, src, n)` -> dst

copies `n` bytes from address `src` to `dst` and return `dst` as a byte pointer
(type `Ptr{UInt8}`).

"""
_memcpy!(dst::Ptr, src::Ptr, n::Integer) :: Ptr{UInt8} =
    ccall(:memcpy, Ptr{UInt8}, (Ptr{Void}, Ptr{Void}, Csize_t), dst, src, n)

"""
    `_copy(arg)`

yields a dynamically allocated copy of `arg` in the form of a byte pointer
(type `Ptr{UInt8}`).

"""
_copy(str::AbstractString) = _copy(push!(Vector{UInt8}(str), 0))

function _copy(arr::DenseArray) :: Ptr{UInt8}
    n = sizeof(arr)
    return _memcpy!(_malloc(n), pointer(arr), n)
end

end # module
