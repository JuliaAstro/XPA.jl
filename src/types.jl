#
# types.jl --
#
# Type definitions for XPA package.
#
#------------------------------------------------------------------------------
#
# This file is part of XPA.jl released under the MIT "expat" license.
# Copyright (C) 2016-2018, Éric Thiébaut (https://github.com/emmt/XPA.jl).
#

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
