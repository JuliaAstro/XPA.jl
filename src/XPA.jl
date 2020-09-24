#
# XPA.jl --
#
# Implement XPA communication via the dynamic library.
#
#------------------------------------------------------------------------------
#
# This file is part of XPA.jl released under the MIT "expat" license.
# Copyright (C) 2016-2020, Éric Thiébaut (https://github.com/JuliaAstro/XPA.jl).
#

module XPA

using XPA_jll

using Base: ENV, @propagate_inbounds

# Access mode bits for XPA requests.
const SET    = UInt(1)
const GET    = UInt(2)
const INFO   = UInt(3)
const ACCESS = UInt(4)

# Sizes.
const SZ_LINE = 4096
const XPA_NAMELEN = 1024

# Types of fields in main XPARec structure.
const _typeof_send_mode    = Int32
const _typeof_receive_mode = Int32

# Offsets of fields in main XPARec structure.
const _offsetof_class        =  32
const _offsetof_name         =  40
const _offsetof_send_mode    =  72
const _offsetof_receive_mode =  96
const _offsetof_method       = 144
const _offsetof_sendian      = 184
const _offsetof_comm         = 192

# Field offsets in XPACommRec structure.
const _offsetof_comm_status  =   8
const _offsetof_comm_cmdfd   =  72
const _offsetof_comm_datafd  =  76
const _offsetof_comm_cendian =  80
const _offsetof_comm_ack     =  88
const _offsetof_comm_buf     =  96
const _offsetof_comm_len     = 104

# Path to the XPA dynamic library.


include("types.jl")
include("misc.jl")
include("client.jl")
include("server.jl")

end # module
