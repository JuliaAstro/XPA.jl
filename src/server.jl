#
# server.jl --
#
# Implement XPA client methods.
#
#------------------------------------------------------------------------------
#
# This file is part of XPA.jl released under the MIT "expat" license.
# Copyright (C) 2016-2019, Éric Thiébaut (https://github.com/emmt/XPA.jl).
#

# We must make sure that the `send` and `recv` callbacks exist during the life
# of the server.  To that end, we use the following dictionary to maintain
# references to callbacks while they are used by an XPA server.
const _SERVERS = Dict{Ptr{Cvoid},Tuple{Union{SendCallback, Nothing},
                                       Union{ReceiveCallback, Nothing}}}()

"""
```julia
XPA.Server(class, name, help, send, recv) -> srv
```

yields an XPA server identified by `class` and `name` (both specified as two
strings).

Argument `help` is a string which is meant to be returned by a help request
from `xpaget`:

```sh
xpaget class:name -help
```

Arguments `send` and `recv` are callbacks which will be called upon a client
[`XPA.get`](@ref) or [`XPA.set`](@ref) respectively.  At most one callback may
be `nothing`.

The send callback will be called in response to an external request from the
`xpaget` program, the `XPAGet()` or `XPAGetFd()` C routines, or the
[`XPA.get`](@ref) Julia method.  This callback is used to send data to the
requesting client and is a combination of a function (`sfunc` below) and
private data (`sdata` below) as summarized by the following typical example:

```julia
# Method to handle a send request:
function sfunc(sdata::S, srv::XPA.Server, params::String, buf::XPA.SendBuffer)
    result = ... # build up the result of the request
    try
        XPA.store!(buf, result)
        return XPA.SUCCESS
    catch err
        error(srv, err)
        return XPA.FAILURE
    end
end

# A send callback combines a method and some contextual data:
send = XPA.SendCallback(sfunc, sdata)
```

Here `sdata` is the client data (of type `S`) of the send callback, `srv` is
the XPA server serving the request, `params` is the parameter list of the
`[XPA.get](@ref)` call and `buf` specifies the addresses where to store the
result of the request and its size (in bytes).

The receive callback will be called in response to an external request from the
`xpaset` program, the `XPASet()` or `XPASetFd()` C routines, or the
[`XPA.set`](@ref) Julia method.  This callback is used to process sent data to
the requesting client and is a combination of a function (`rfunc` below) and
private data (`rdata` below) as summarized by the following typical example:

```julia
# Method to handle a send request:
function rfunc(rdata::R, srv::XPA.Server, params::String, buf::XPA.ReceiveBuffer)
    println("receive: \$params")
    # Temporarily wrap the received data into an array.
    bytes = XPA.peek(Vector{UInt8}, buf; temporary=true)
    ... # process the received bytes
    return XPA.SUCCESS
end

# A receive callback combines a method and some contextual data:
send = XPA.ReceiveCallback(rfunc, rdata)
```

Here `rdata` is the client data (of type `R`) of the receive callback, `srv` is
the XPA server serving the request, `params` is the parameter list of the
[`XPA.set`](@ref) call and `buf` specifies the address and size of the data to
process.

The callback methods `sfunc` and/or `rfunc` should return [`XPA.SUCCESS`](@ref)
if no error occurs, or [`XPA.FAILURE`](@ref) to signal an error.  The Julia XPA
package takes care of maintaining a reference on the client data and callback
methods.

See also [`XPA.poll`](@ref), [`XPA.mainloop`](@ref), [`XPA.store!`](@ref),
[`XPA.SendCallback`](@ref), [`XPA.ReceiveCallback`](@ref) and
[`XPA.peek`](@ref).

"""
function Server(class::AbstractString,
                name::AbstractString,
                help::AbstractString,
                send::Union{SendCallback, Nothing},
                recv::Union{ReceiveCallback, Nothing})
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
                sproc::Ptr{Cvoid}, sdata::Ptr{Cvoid}, smode::AbstractString,
                rproc::Ptr{Cvoid}, rdata::Ptr{Cvoid}, rmode::AbstractString)
    ptr = ccall((:XPANew, libxpa), Ptr{Cvoid},
                (Cstring, Cstring, Cstring,
	         Ptr{Cvoid}, Ptr{Cvoid}, Cstring,
	         Ptr{Cvoid}, Ptr{Cvoid}, Cstring),
                class, name, help,
                sproc, sdata, smode,
                rproc, rdata, rmode)
    ptr != C_NULL || error("failed to create an XPA server")
    obj = finalizer(close, Server(ptr))
    (get_send_mode(obj) & MODE_FREEBUF) != 0 ||
        error("send mode must have `freebuf` option set")
    return obj
end

# The following methods are helpers to build instances of an XPA server.
_callback(::Nothing) = C_NULL
_callback(::SendCallback) = _SEND_REF[]
_callback(::ReceiveCallback) = _RECV_REF[]
_context(::Nothing) = C_NULL
_context(cb::Callback) = pointer_from_objref(cb)
_mode(::Nothing) = ""
_mode(cb::SendCallback) = "acl=$(cb.acl),freebuf=true"
_mode(cb::ReceiveCallback) =
    "acl=$(cb.acl),buf=true,fillbuf=true,freebuf=true"

# The following method is called upon garbage collection of an XPA server.
function Base.close(srv::Server)
    if (ptr = srv.ptr) != C_NULL
        srv.ptr = C_NULL # avoid closing more than once!
        ccall((:XPAFree, libxpa), Cint, (Ptr{Cvoid},), ptr)
        haskey(_SERVERS, ptr) && pop!(_SERVERS, ptr)
    end
    return nothing
end

"""
```julia
SendCallback(func, data=nothing; acl=true)
```

yields an instance of `SendCallback` for sending the data requested by a call
to [`XPA.get`](@ref) (or similar) to an XPA server.  Argument `func` is the
method to be called to process the request and optional argument `data` is some
associated contextual data.

Keyword `acl` can be used to specify whether access control is enabled (true by
default).

!!! note
    The `freebuf` option is not available because we are always assuming that
    the answer to a [`XPA.get`](@ref) request is a dynamically allocated buffer
    which is automatically deleted by the XPA library.  This is like imposing
    that the `freebuf` option is laways true.  This choice has been made
    because it would otherwise be difficult to warrant that data passed by a
    Julia send callback be not garbage collected before being fully transfered
    to the client.

See also [`XPA.Server`](@ref), [`XPA.store!`](@ref) and
[`XPA.ReceiveCallback`](@ref).

"""
function SendCallback(func::F,
                      data::T = nothing;
                      acl::Bool = true) where {T,F<:Function}
    return SendCallback{T,F}(func, data, acl)
end

"""
```julia
ReceiveCallback(func, data=nothing; acl=true)
```

yields an instance of `ReceiveCallback` for processing the data sent by a call
to [`XPA.set`](@ref) (or similar) to an XPA server.  Argument `rfunc` is the
method to be called to process the request and optional argument `data` is some
associated contextual data.

Keyword `acl` can be used to specify whether access control is enabled (true by
default).

!!! note
    The `buf`, `fillbuf` and `freebuf` options are not available because we are
    always assuming that the data buffer accompanying an [`XPA.set`](@ref)
    request is always provided as a dynamically allocated buffer by the XPA
    library.  This is like imposing that the `buf`, `fillbuf` and `freebuf`
    options are always true.  This choice has been made because it would
    otherwise be difficult to warrant that data passed to a Julia receive
    callback can be safely stealed by Julia.

Also see [`XPA.Server`](@ref), [`XPA.SendCallback`](@ref) and
[`XPA.set`](@ref).

"""
function ReceiveCallback(func::F,
                         data::T = nothing;
                         acl::Bool = true) where {T,F<:Function}
    return ReceiveCallback{T,F}(func, data, acl)
end

const _MINIMAL_SEND_MODE = MODE_FREEBUF
const _MINIMAL_RECEIVE_MODE = (MODE_BUF | MODE_FILLBUF | MODE_FREEBUF)

getsendmode(xpa::Server) =
    (xpa.ptr == C_NULL ? zero(_typeof_send_mode) :
     unsafe_load(Ptr{_typeof_send_mode}(xpa.ptr + _offsetof_send_mode)))

getreceivemode(xpa::Server) =
    (xpa.ptr == C_NULL ? zero(_typeof_receive_mode) :
     unsafe_load(Ptr{_typeof_receive_mode}(xpa.ptr + _offsetof_receive_mode)))

# The send callback is executed in response to an external request from the
# `xpaget` program, the `XPAGet()` routine, or `XPAGetFd()` routine.
function _send(clientdata::Ptr{Cvoid}, handle::Ptr{Cvoid}, params::Ptr{Byte},
               bufptr::Ptr{Ptr{Byte}}, lenptr::Ptr{Csize_t})::Cint
    # Check assumptions.
    srv = Server(handle)
    (getsendmode(srv) & _MINIMAL_SEND_MODE) == _MINIMAL_SEND_MODE ||
        return error(srv, "send mode must have option `freebuf=true`")

    # Call actual callback providing the client data is the address of a known
    # SendCallback object.
    return _send(unsafe_pointer_to_objref(clientdata), srv,
                 (params == C_NULL ? "" : unsafe_string(params)),
                 SendBuffer(bufptr, lenptr))
end

_send(cb::SendCallback, srv::Server, params::String, buf::SendBuffer) =
    cb.send(cb.data, srv, params, buf)

# The receive callback is executed in response to an external request from the
# `xpaset` program, the `XPASet()` routine, or `XPASetFd()` routine.
function _recv(clientdata::Ptr{Cvoid}, handle::Ptr{Cvoid}, params::Ptr{Byte},
               buf::Ptr{Byte}, len::Csize_t)::Cint
    # Check assumptions.
    srv = Server(handle)
    (getreceivemode(srv) & _MINIMAL_RECEIVE_MODE) == _MINIMAL_RECEIVE_MODE ||
        return error(srv, "receive mode must have options `buf=true`, `fillbuf=true` and `freebuf=true`")

    # Call actual callback providing the client data is the address of a known
    # ReceiveCallback object.
    return _recv(unsafe_pointer_to_objref(clientdata), srv,
                 (params == C_NULL ? "" : unsafe_string(params)),
                 ReceiveBuffer(buf, len))
end

_recv(cb::ReceiveCallback, srv::Server, params::String, buf::ReceiveBuffer) =
    cb.recv(cb.data, srv, params, buf)

# Addresses of callbacks cannot be precompiled so we set them at run-time in
# the __init__() method of the module.
const _SEND_REF = Ref{Ptr{Cvoid}}(0)
const _RECV_REF = Ref{Ptr{Cvoid}}(0)
function __init__()
    global _SEND_REF, _RECV_REF
    _SEND_REF[] = @cfunction(_send, Cint,
                             (Ptr{Cvoid},     # client_data
                              Ptr{Cvoid},     # call_data
                              Ptr{Byte},      # paramlist
                              Ptr{Ptr{Byte}}, # buf
                              Ptr{Csize_t}))  # len
    _RECV_REF[] = @cfunction(_recv, Cint,
                             (Ptr{Cvoid},     # client_data
                              Ptr{Cvoid},     # call_data
                              Ptr{Byte},      # paramlist
                              Ptr{Byte},      # buf
                              Csize_t))       # len
end

"""
```julia
error(srv, msg) -> XPA.FAILURE
```

communicates error message `msg` to the client when serving a request by XPA
server `srv`.  This method shall only be used by the send/receive callbacks of
an XPA server.

Also see: [`XPA.Server`](@ref), [`XPA.message`](@ref),
          [`XPA.SendCallback`](@ref), [`XPA.ReceiveCallback`](@ref).

"""
function Base.error(srv::Server, msg::AbstractString)
    ccall((:XPAError, libxpa), Cint, (Server, Cstring),
          srv, msg) == SUCCESS ||
              error("XPAError failed for message \"$msg\"");
    return FAILURE
end

"""
```julia
XPA.message(srv, msg)
```

sets a specific acknowledgment message back to the client. Argument `srv` is
the XPA server serving the client and `msg` is the acknowledgment message.
This method shall only be used by the receive callback of an XPA server.

Also see: [`XPA.Server`](@ref), [`XPA.error`](@ref),
          [`XPA.ReceiveCallback`](@ref).

"""
message(srv::Server, msg::AbstractString) =
    ccall((:XPAMessage, libxpa), Cint, (Server, Cstring), srv, msg)

"""
```julia
XPA.store!(buf, data)
```

or

```julia
XPA.store!(buf, ptr, len)
```

store into the send buffer `buf` a dynamically allocated copy of the contents
of `data` or of the `len` bytes at address `ptr`.

!!! warning
    This method is meant to be used in a *send* callback to store the result of
    an [`XPA.get`](@ref) request processed by an XPA server.  Memory leaks are
    expected if used in another context.

See also [`XPA.Server`](@ref), [`XPA.SendCallback`](@ref) and
[`XPA.get`](@ref).

"""
function store!(buf::SendBuffer, ptr::Ptr{Byte}, len::Integer)
    # Before calling the send callback (see xpa.c), the buffer is empty
    # (*bufptr = NULL and *lenptr = 0).  On return of the send callback with a
    # successful status, if there are any data (*bufptr != NULL and *lenptr >
    # 0), this data is sent to the client.  Then, whatever the status and if
    # freebuf is true, the data buffer is destroy with free() or any specific
    # function set with XPASetFree().
    #
    # This function is similar to `XPASetBuf` except that it makes a dynamic
    # copy of the data to send (because option `freebuf` is always true) and
    # destroys any buffer which could have been set before.
    if (tmp = unsafe_load(buf.bufptr)) != NULL && unsafe_load(buf.lenptr) > 0
        unsafe_store!(buf.lenptr, 0)
        unsafe_store!(buf.bufptr, NULL)
        _free(tmp)
    end
    if ptr != NULL
        len > 0 || error("invalid number of bytes ($len) for non-NULL pointer")
        unsafe_store!(buf.bufptr, _memcpy(_malloc(len), ptr, len))
        unsafe_store!(buf.lenptr, len)
    else
        len == 0 || error("invalid number of bytes ($len) for NULL pointer")
    end
    return nothing
end

store!(buf::SendBuffer, ::Nothing) = store!(buf, NULL, 0)

store!(buf::SendBuffer, val::Union{Symbol,AbstractString}) =
    store!(buf, String(val))

store!(buf::SendBuffer, str::String) =
    store!(buf.bufptr, buf.lenptr,
               Base.unsafe_convert(Ptr{Byte}, str), sizeof(str))

function store!(buf::SendBuffer, arr::DenseArray{T,N}) where {T, N}
    @assert isbitstype(T)
    store!(buf.bufptr, buf.lenptr,
               convert(Ptr{Byte}, pointer(arr)), sizeof(arr))
end

function store!(buf::SendBuffer, val::T) where {T}
    @assert isbitstype(T)
    if (tmp = unsafe_load(buf.bufptr)) != NULL && unsafe_load(buf.lenptr) > 0
        unsafe_store!(buf.lenptr, 0)
        unsafe_store!(buf.bufptr, NULL)
        _free(tmp)
    end
    len = sizeof(T)
    ptr = _malloc(len)
    unsafe_store!(convert(Ptr{T}, ptr), val)
    unsafe_store!(buf.bufptr, ptr)
    unsafe_store!(buf.lenptr, len)
    return nothing
end

function Base.copyto!(dst::AbstractArray{T,N},
                      buf::ReceiveBuffer) where {T,N}
    @assert isbitstype(T)
    sizeof(T)*length(dst) ≤ sizeof(buf) ||
        error("data buffer is too small for array")
    return copyto!(dst, unsafe_wrap(Array, Ptr{T}(pointer(buf)), size(dst),
                                    own=false))
end


"""
```julia
XPA.peek(T, buf, i=1) -> val
```

yields the `i`-th binary value of type `T` stored into receive buffer `buf`.
Bounds checking is performed unless `@inbounds` is active.

Another usage of the `XPA.peek` method is to *convert* the contents of the
receive buffer into an array:

```julia
XPA.peek(Vector{T}, [len,] buf) -> vec
XPA.peek(Array{T[,N]}, (dim1, ..., dimN), buf) -> arr
```

yield a Julia vector `vec` or array `arr` whose elements are of type `T` and
dimensions are `len` or `(dim1, ..., dimN)`.  For a vector, if the length is
unspecified, the vector of maximal length that fits in the buffer is returned.

If keyword `temporary` is true, then `unsafe_wrap` is called (with option
`own=false`) to wrap the buffer contents into a Julia array whose life-time
cannot exceeds that of the callback.  Otherwise, a copy of the buffer contents
is returned.

See also [`XPA.ReceiveCallback`](@ref).

"""
@inline function peek(::Type{T},
                      buf::ReceiveBuffer,
                      i::Int=1)::T where {T}
    @assert isbitstype(T)
    @boundscheck checkbounds(T, buf, i)
    return unsafe_load(Ptr{T}(pointer(buf)), j)
end

@inline @propagate_inbounds function peek(::Type{T},
                                          buf::ReceiveBuffer,
                                          i::Integer) where {T}
    return peek(T, buf, Int(i))
end

Base.checkbounds(::Type{T}, buf::ReceiveBuffer, i::Int=1) where {T} =
    1 ≤ i && i*sizeof(T) ≤ sizeof(buf) || error("out of range index")

function peek(::Type{Vector{T}},
              buf::ReceiveBuffer;
              temporary::Bool=false)::Vector{T} where {T}
    @assert isbitstype(T)
    local vec::Vector{T}
    len = div(sizeof(buf), sizeof(T))
    if temporary
        vec = unsafe_wrap(Array, Ptr{T}(pointer(buf)), len)
    else
        vec = Vector{T}(undef, len)
        nbytes = sizeof(T)*len
        nbytes > 0 && _memcpy(pointer(vec), pointer(buf), nbytes)
    end
    return vec
end

function peek(::Type{Vector{T}},
              len::Integer,
              buf::ReceiveBuffer;
              kwds...)::Vector{T} where {T}
    return peek(Vector{T}, _dimensions(len), buf; kwds...)
end

function peek(::Type{Array{T}},
              dims::NTuple{N,Integer},
              buf::ReceiveBuffer;
              kwds...)::Array{T,N} where {T,N}
    return peek(Array{T,N}, _dimensions(dims), buf; kwds...)
end

function peek(::Type{Array{T,N}},
              dims::NTuple{N,Integer},
              buf::ReceiveBuffer;
              kwds...)::Array{T,N} where {T,N}
    return peek(Array{T,N}, _dimensions(dims), buf; kwds...)
end

function peek(::Type{Array{T,N}},
              dims::NTuple{N,Int},
              buf::ReceiveBuffer;
              temporary::Bool=false)::Array{T,N} where {T,N}
    @assert isbitstype(T)
    local arr::Array{T,N}
    len = 1
    @inbounds for d in 1:N
        (dim = dims[d]) < 0 && error("invalid Array dimension")
        len *= dim
    end
    nbytes = sizeof(T)*len
    nbytes ≤ sizeof(buf) || error("data buffer is too small for array")
    if temporary
        arr = unsafe_wrap(Array, Ptr{T}(pointer(buf)), dims)
    else
        arr = Array{T,N}(undef, dims)
        nbytes > 0 && _memcpy(pointer(arr), pointer(buf), nbytes)
    end
    return arr
end

"""
```julia
XPA.poll(sec, maxreq)
```

polls for XPA events.  This method is meant to implement a polling event loop
which checks for and processes XPA requests without blocking.

Argument `sec` specifies a timeout in seconds (rounded to millisecond
precision).  If `sec` is positive, the method blocks no longer than this amount
of time.  If `sec` is strictly negative, the routine blocks until the occurence
of an event to be processed.

Argument `maxreq` specifies how many requests will be processed.  If `maxreq <
0`, then no events are processed, but instead, the returned value indicates the
number of events that are pending.  If `maxreq == 0`, then all currently
pending requests will be processed.  Otherwise, up to `maxreq` requests will be
processed.  The most usual values for `maxreq` are `0` to process all requests
and `1` to process one request.

The following example implements a polling loop which has no noticeable impact
on the consumption of CPU when no requests are emitted to the server:

```julia
const __running = Ref{Bool}(false)

function run()
    global __running
    __running[] = true
    while __running[]
        XPA.poll(-1, 1)
    end
end
```

Here the global variable `__running` is a reference to a boolean whose value
indicates whether to continue to run the XPA server(s) created by the process.
The idea is to pass the reference to the callbacks of the server (as their
client data for instance) and let the callbacks stop the loop by setting the
contents of the reference to `false`.

Another possibility is to use [`XPA.mainloop`](@ref) (which to see).

To let Julia performs other tasks, the polling method may be repeatedly called
by a Julia timer.  The following example does this.  Calling `resume` starts
polling for XPA events immediately and then every 100ms.  Calling `suspend`
suspends the processing of XPA events.

```julia
const __timer = Ref{Timer}()

ispolling() = (isdefined(__timer, 1) && isopen(__timer[]))

resume() =
    if ! ispolling()
        __timer[] = Timer((tm) -> XPA.poll(0, 0), 0.0, interval=0.1)
    end

suspend() =
    ispolling() && close(__timer[])
```


Also see: [`XPA.Server`](@ref), [`XPA.mainloop`](@ref).

"""
poll(sec::Real, maxreq::Integer) =
    ccall((:XPAPoll, libxpa), Cint, (Cint, Cint),
          (sec < 0 ? -1 : round(Cint, 1E3*sec)), maxreq)

"""
```julia
XPA.mainloop()
```

runs XPA event loop which handles the requests sent to the server(s) created by
this process.  The loop runs until all servers created by this process have
been closed.

In the following example, the receive callback function close the server when
it receives a `"quit"` command:

```julia
function rproc(::Nothing, srv::XPA.Server, params::String,
               buf::Ptr{UInt8}, len::Integer)
    status = XPA.SUCCESS
    if params == "quit"
        close(srv)
    elseif params == ...
        ...
    end
    return status
end
```

Also see: [`XPA.Server`](@ref), [`XPA.mainloop`](@ref).

"""
mainloop() =
    ccall((:XPAMainLoop, libxpa), Cint, ())
