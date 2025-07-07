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

# Lightweight structure representing a single entry of something which must implement part
# of the abstract vector API.
struct Entry{T}
    parent::T
    index::Int
    # Inner constructor ensures validity of index. Most operations on a single entry takes
    # much more time than checking the index so the extra cost is negligible.
    function Entry(A::T, i::Int) where {T}
        firstindex(A) ≤ i ≤ lastindex(A) || throw(BoundsError(A, i))
        return new{T}(A, i)
    end
end

"""
    XPA.Reply

type of structure used to store the answer(s) of [`XPA.get`](@ref) and [`XPA.set`](@ref)
requests.

Assuming `A` is an instance of `XPA.Reply`, it can be used as an abstract vector and `A[i]`
yields the `i`-th answer in `A`. The syntax `A[]` yields `A[1]` if `A` has a single answer
and throws otherwise.

A single answer `A[i]` implements the following properties:

```julia
A[i].server       # identifier of the XPA server which sent the `i`-th answer
A[i].data(...)    # data associated with `i`-th answer (see below)
A[i].has_message  # whether `i`-th answer contains a message
A[i].has_error    # whether `i`-th answer has an error
A[i].message      # message or error message associated with `i`-th answer
```

To retrieve the data associated with a reply, the `data` property can be used as follows:

```julia
A[i].data()                  # a vector of bytes
A[i].data(String)            # a single ASCII string
A[i].data(T)                 # a single value of type `T`
A[i].data(Vector{T})         # the largest possible vector with elements of type `T`
A[i].data(Array{T}, dims...) # an array of element type `T` and size `dims...`
```

If `Base.Memory` exists `Vector{T}` can be replaced by `Memory{T}`.

# See also

[`XPA.get`](@ref), [`XPA.set`](@ref), and [`XPA.has_errors`](@ref).

"""
mutable struct Reply <: AbstractVector{Entry{Reply}}
    replies::Int
    lengths::Memory{Csize_t}
    buffers::Memory{Ptr{Byte}}
    # Inner constructor allocates `lengths` vector to store data lengths, and `buffers`
    # vector to store raw data, server name, and message. These vectors must be initially
    # zero-filled.
    function Reply(nmax::Int)
        lengths = fill!(Memory{Csize_t}(undef, nmax), zero(Csize_t))
        buffers = fill!(Memory{Ptr{Byte}}(undef, nmax*3), Ptr{Byte}(0))
        return finalizer(_free, new(0, lengths, buffers))
    end
end

# Private structure to access the data associated with a single reply.
struct DataAccessor
    parent::eltype(Reply)
    DataAccessor(A::eltype(Reply)) = new(A)
end

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

struct AccessPoint
    class::String
    name::String
    address::String
    user::String
    access::UInt
    function AccessPoint(class::AbstractString,
                         name::AbstractString,
                         address::AbstractString,
                         user::AbstractString,
                         access::Union{Integer,AbstractString})
        return new(class, name, address, user, _accesspoint_type(access))
    end
end

"""

`XPA.NullBuffer` is a singleton type representing a NULL-buffer when sending data to a
server.

"""
struct NullBuffer end

# Union of types suitable for defining the shape of the expected result.
const Shape = Union{Integer, Tuple{Vararg{Integer}}}
