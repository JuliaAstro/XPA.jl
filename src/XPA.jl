#
# XPA.jl --
#
# Implement XPA communication via the dynamic library.
#
#------------------------------------------------------------------------------
#
# This file is part of XPA.jl released under the MIT "expat" license.
# Copyright (C) 2016-2019, Éric Thiébaut (https://github.com/emmt/XPA.jl).
#

module XPA

export
    XPA_VERSION

using Base: ENV, @propagate_inbounds

isfile(joinpath(@__DIR__, "..", "deps", "deps.jl")) ||
    error("XPA not properly installed.  Please run Pkg.build(\"XPA\")")
include(joinpath("..", "deps", "deps.jl"))
include("types.jl")
include("misc.jl")
include("client.jl")
include("server.jl")

end # module
