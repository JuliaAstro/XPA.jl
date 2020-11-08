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

include("cdefs.jl")
include("types.jl")
include("misc.jl")
include("client.jl")
include("server.jl")

end # module
