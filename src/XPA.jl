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

isdefined(Base, :__precompile__) && __precompile__(true)

module XPA

using Base: ENV

include("../deps/deps.jl")

include("constants.jl")
include("types.jl")
include("misc.jl")
include("client.jl")
include("server.jl")

end # module
