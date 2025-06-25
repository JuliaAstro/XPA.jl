#
# XPA.jl --
#
# Implement XPA communication via the dynamic library.
#
#-------------------------------------------------------------------------------------------
#
# This file is part of XPA.jl released under the MIT "expat" license.
#
# Copyright (c) 2016-2025, Éric Thiébaut (https://github.com/JuliaAstro/XPA.jl).
#

module XPA

using TypeUtils
using TypeUtils: @public

# Non-exported public types.
@public Client
@public Server
@public SendBuffer
@public SendCallback
@public Reply
@public Callback
@public ReceiveCallback
@public AccessPoint
@public NullBuffer

# Non-exported public constants.
@public FAILURE
@public SUCCESS

# Non-exported public functions.
@public address
@public buffer
@public connection
@public find
@public get
@public get_data
@public get_message
@public get_server
@public getconfig
@public has_error
@public has_errors
@public has_message
@public join_arguments
@public list
@public mainloop
@public message
@public peek
@public poll
@public set
@public setconfig!
@public store!
@public verify

using XPA_jll

import REPL
using REPL.TerminalMenus

using Base: ENV, @propagate_inbounds

# XPA provides its own `get` and `set` functions.
function get end
function set end

include("compat.jl")
include("cdefs.jl")
include("types.jl")
include("misc.jl")
include("client.jl")
include("server.jl")

end # module
