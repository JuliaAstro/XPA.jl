#
# types.jl --
#
# Type definitions for XPA package.
#
#-------------------------------------------------------------------------------------------
#
# This file is part of XPA.jl released under the MIT "expat" license.
#
# Copyright (c) 2016-2025, Éric Thiébaut (https://github.com/JuliaAstro/XPA.jl).
#

const Byte = UInt8
const NULL = Ptr{Byte}(0)

"""

`XPA.SUCCESS` and `XPA.FAILURE` are the possible values returned by the callbacks of an XPA
server.

"""
const SUCCESS = convert(Cint,  0)
const FAILURE = convert(Cint, -1)
@doc @doc(SUCCESS) FAILURE

# Server mode flags for receive, send, info.  These constants are defined
# in the *private* header file `xpap.h`.
const MODE_BUF     = 1 # XPA_MODE_BUF in `xpap.h`
const MODE_FILLBUF = 2 # XPA_MODE_FILLBUF in `xpap.h`
const MODE_FREEBUF = 4 # XPA_MODE_FREEBUF in `xpap.h`
const MODE_ACL     = 8 # XPA_MODE_ACL in `xpap.h`

"""
    XPA.Client

An instance of the mutable structure `XPA.Client` represents a client connection in the XPA
Messaging System.

"""
mutable struct Client # must be mutable to be finalized
    ptr::Ptr{CDefs.XPARec}
    function Client(ptr::Ptr{CDefs.XPARec})
        obj = new(ptr)
        finalizer(close, obj)
        return obj
    end
end

"""
    XPA.Server

An instance of the mutable structure `XPA.Server` represents a server connection in the XPA
Messaging System.

"""
mutable struct Server # must be mutable to be finalized
    ptr::Ptr{CDefs.XPARec}
    function Server(ptr::Ptr{CDefs.XPARec})
        obj = new(ptr)
        finalizer(close, obj)
        return obj
    end
end

"""

`XPA.TupleOf{T}` represents a tuple of any number of elements of type `T`, it
is an alias for `Tuple{Vararg{T}}`

"""
const TupleOf{T} = Tuple{Vararg{T}}

"""
    XPA.Reply

type of structure used to store the answer(s) of [`XPA.get`](@ref) and [`XPA.set`](@ref)
requests. Method `length` applied to an object of type `Reply` yields the number of replies.
Methods [`XPA.get_data`](@ref), [`XPA.get_server`](@ref) and [`XPA.get_message`](@ref) can
be used to retrieve the contents of an object of type `XPA.Reply`.

"""
mutable struct Reply
    replies::Int
    lengths::Memory{Csize_t}
    buffers::Memory{Ptr{Byte}}
end

Base.length(rep::Reply) = rep.replies

abstract type Callback end

"""
    XPA.SendCallback <: XPA.Callback

An instance of the `XPA.SendCallback` structure represents a callback called to serve an
[`XPA.get`](@ref) request.

"""
mutable struct SendCallback{T,F<:Function} <: Callback
    # must be mutable because pointer_from_objref is used to recover it
    send::F        # function to call on `XPA.get` requests
    data::T        # client data
    acl::Bool      # enable access control
end

"""
    XPA.SendBuffer

An instance of the `XPA.SendBuffer` structure is provided to send callbacks to record the
addresses where to store the address and size of the data associated to the answer of an
[`XPA.get`](@ref) request. A send callback shall use [`XPA.store!`](@ref) to set the buffer
contents.

# See also

[`XPA.store!`](@ref), [`XPA.get`](@ref), [`XPA.Server`](@ref) and
[`XPA.SendCallback`](@ref).

"""
struct SendBuffer
    bufptr::Ptr{Ptr{Byte}}
    lenptr::Ptr{Csize_t}
end

"""
    XPA.ReceiveCallback <: XPA.Callback

An instance of the `XPA.ReceiveCallback` structure represents a callback called to serve an
[`XPA.set`](@ref) request.

"""
mutable struct ReceiveCallback{T,F<:Function} <: Callback
    # must be mutable because pointer_from_objref is used to recover it
    recv::F        # function to call on `XPA.set` requests
    data::T        # client data
    acl::Bool      # enable access control
end

"""

An instance of the `XPA.ReceiveBuffer` structure is provided to receive callbacks to record
the address and the size of the data sent by an [`XPA.set`](@ref) request. Methods
`pointer(buf)` and `sizeof(buf)` can be used to query the address and the number of bytes of
the buffer `buf`.

# See also

[`XPA.get`](@ref), [`XPA.Server`](@ref), and [`XPA.ReceiveCallback`](@ref).

"""
struct ReceiveBuffer
    ptr::Ptr{Byte}
    len::Int
    # Inner constructor that checks parameters at construction time.
    function ReceiveBuffer(ptr::Ptr{Byte}, len::Integer)
        if ptr == NULL
            if len != 0
                error("Non-zero `len` (= $len) passed with NULL `ptr`.")
            end
        else
            if len < 0
                error("Negative `len` (= $len) passed.")
            end
        end
        return new(ptr, len)
    end
end
Base.sizeof(buf::ReceiveBuffer) = buf.len
Base.pointer(buf::ReceiveBuffer) = buf.ptr

# Access mode bits in AccessPoint.
const SET    = UInt(1)
const GET    = SET << 1
const INFO   = SET << 2

"""
    apt = XPA.AccessPoint(class, name, addr, user, access)

builds a structure representing an XPA server for a client. The arguments reflect the
properties of the object:

    apt.class   # access-point class
    apt.name    # access-point name
    apt.addr    # server address (host:port for inet socket, path for unix socket)
    apt.user    # access-point owner
    apt.access  # allowed access

All properties are strings except `access` which is an unsigned integer whose bits are set
as follows:

     !iszero(apt.access & $(Int(SET))) # holds if `set` command allowed
     !iszero(apt.access & $(Int(GET))) # holds if `get` command allowed
     !iszero(apt.access & $(Int(INFO))) # holds if `info` command allowed

# See also

[`XPA.list`](@ref) to retrieve a vector of existing XPA servers possibly filtered by some
provided function.

[`XPA.find`](@ref) to obtain the access-point of a single XPA server.

"""
struct AccessPoint
    class::String
    name::String
    addr::String
    user::String
    access::UInt
end

"""

`XPA.NullBuffer` is a singleton type representing a NULL-buffer when sending data to a
server.

"""
struct NullBuffer end
