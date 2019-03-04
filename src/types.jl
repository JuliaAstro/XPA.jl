#
# types.jl --
#
# Type definitions for XPA package.
#
#------------------------------------------------------------------------------
#
# This file is part of XPA.jl released under the MIT "expat" license.
# Copyright (C) 2016-2019, Éric Thiébaut (https://github.com/emmt/XPA.jl).
#

const Byte = UInt8
const NULL = Ptr{Byte}(0)

"""

`XPA.SUCCESS` and `XPA.FAILURE` are the possible values returned by the
callbacks of an XPA server.

"""
const SUCCESS = convert(Cint,  0)
const FAILURE = convert(Cint, -1)
@doc @doc(SUCCESS) FAILURE

# Server mode flags for receive, send, info.
const MODE_BUF     = convert(Cint, 1)
const MODE_FILLBUF = convert(Cint, 2)
const MODE_FREEBUF = convert(Cint, 4)
const MODE_ACL     = convert(Cint, 8)

"""

Abstract type `XPA.Handle` is the super type of client ([`XPA.Client`](@ref))
and server ([`XPA.Server`](@ref)) connections in the XPA Messaging System.

"""
abstract type Handle end

"""

An instance of the mutable structure `XPA.Client` represents a client
connection in the XPA Messaging System.

"""
mutable struct Client <: Handle # must be mutable to be finalized
    ptr::Ptr{Cvoid} # pointer to XPARec structure
end

"""

`XPA.TupleOf{T}` represents a tuple of any number of elements of type `T`, it
is an alias for `Tuple{Vararg{T}}`

"""
const TupleOf{T} = Tuple{Vararg{T}}

"""

`XPA.Reply` is used to store the answer(s) of [`XPA.get`](@ref) and
[`XPA.set`](@ref) requests.  Method `length` applied to an object of type
`Reply` yields the number of replies.  Methods [`XPA.get_data`](@ref),
[`XPA.get_server`](@ref) and [`XPA.get_message`](@ref) can be used to retrieve
the contents of an object of type `XPA.Reply`.

"""
mutable struct Reply
    replies::Int
    lengths::Vector{Csize_t}
    buffers::Vector{Ptr{Byte}}
end

Base.length(rep::Reply) = rep.replies

"""

An instance of the mutable structure `XPA.Server` represents a server
connection in the XPA Messaging System.

"""
mutable struct Server <: Handle # must be mutable to be finalized
    ptr::Ptr{Cvoid} # pointer to XPARec structure
end

abstract type Callback end

"""

An instance of the `XPA.SendCallback` structure represents a callback called to
serve an [`XPA.get`](@ref) request.

"""
mutable struct SendCallback{T,F<:Function} <: Callback
    # must be mutable because pointer_from_objref is used to recover it
    send::F        # function to call on `XPA.get` requests
    data::T        # client data
    acl::Bool      # enable access control
    freebuf::Bool  # free buf after callback completes
end

"""

An instance of the `XPA.SendBuffer` structure is provided to send callbacks to
record the addresses where to store the address and size of the data associated
to the answer of an [`XPA.get`](@ref) request.

See also [`XPA.set_buffer!`](@ref), [`XPA.get`](@ref), [`XPA.Server`](@ref)
and [`XPA.SendCallback`](@ref).

"""
struct SendBuffer
    bufptr::Ptr{Ptr{Byte}}
    lenptr::Ptr{Csize_t}
end

"""

An instance of the `XPA.ReceiveCallback` structure represents a callback called
to serve an [`XPA.set`](@ref) request.

"""
mutable struct ReceiveCallback{T,F<:Function} <: Callback
    # must be mutable because pointer_from_objref is used to recover it
    recv::F        # function to call on `XPA.set` requests
    data::T        # client data
    acl::Bool      # enable access control
    buf::Bool      # server expects data bytes from client
    fillbuf::Bool  # read data into buffer before executing callback
    freebuf::Bool  # free buffer after callback completes
end

"""

An instance of the `XPA.ReceiveBuffer` structure is provided to receive
callbacks to record the address and the size of the data sent by an
[`XPA.set`](@ref) request.  Methods `pointer(buf)` and `sizeof(buf)` can be
used to query the address and the number of bytes of the buffer `buf`.

See also [`XPA.get`](@ref), [`XPA.Server`](@ref) and
[`XPA.ReceiveCallback`](@ref).

"""
struct ReceiveBuffer
    buf::Ptr{Byte}
    len::Csize_t
end
Base.sizeof(buf::ReceiveBuffer)::Int = (buf.ptr != NULL ? Int(buf.len) : 0)
Base.pointer(buf::ReceiveBuffer) = buf.ptr

"""

An instance of the `XPA.AccessPoint` structure represents an available XPA
server.  A vector of such instances is returned by the [`XPA.list`](@ref)
utility.

"""
struct AccessPoint
    class::String # class of the access point
    name::String  # name of the access point
    addr::String  # socket access method (host:port for inet,
                  # file for local/unix)
    user::String  # user name of access point owner
    access::UInt  # allowed access
end

"""

`XPA.NullBuffer` is a singleton type representing a NULL-buffer when sending
data to a server.

"""
struct NullBuffer end
