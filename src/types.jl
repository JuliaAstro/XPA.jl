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

# Super type for client and server XPA objects.
abstract type Handle end

# XPA client, must be mutable to be finalized.
mutable struct Client <: Handle
    ptr::Ptr{Cvoid} # pointer to XPARec structure
end

# XPA server, must be mutable to be finalized.
mutable struct Server <: Handle
    ptr::Ptr{Cvoid} # pointer to XPARec structure
end

abstract type Callback end

struct SendCallback{T} <: Callback
    send::Function # function to call on `XPAGet` requests
    data::T        # client data
    acl::Bool      # enable access control
    freebuf::Bool  # free buf after callback completes
end

struct ReceiveCallback{T} <: Callback
    recv::Function # function to call on `XPASet` requests
    data::T        # client data
    acl::Bool      # enable access control
    buf::Bool      # server expects data bytes from client
    fillbuf::Bool  # read data into buffer before executing callback
    freebuf::Bool  # free buffer after callback completes
end

struct AccessPoint
    class::String # class of the access point
    name::String  # name of the access point
    addr::String  # socket access method (host:port for inet,
                  # file for local/unix)
    user::String  # user name of access point owner
    access::UInt  # allowed access
end

"""
```julia
buf = Buffer(data)
```

yields an object `buf` representing the contents of `data` which can be
[`nothing`](@ref), a dense array or a string.  If `data` is an array `buf`
holds a reference on `data`.  If `data` is a string, `buf` stores a temporary
byte buffer where the string is copied.  The object `buf` can be used to pass
some data to [`ccall`](@ref) without the risk of having the data garbage
collected.

Standard methods [`pointer`](@ref) and [`sizeof`](@ref) can be applied to `buf`
to retieve the address and the size (in bytes) of the data and
`convert(Ptr{Cvoid},buf)` can also be used.

See also [`XPA.set`](@ref).

"""
struct Buffer{T} # FIXME: should be mutable?
    data::T
    Buffer{T}(data::T) where {T} = new{T}(data)
end
