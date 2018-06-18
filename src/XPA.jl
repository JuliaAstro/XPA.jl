#
# XPA.jl --
#
# Implement XPA communication via the dynamic library.
#
#------------------------------------------------------------------------------
#
# This file is part of XPA.jl released under the MIT "expat" license.
# Copyright (C) 2016-2018, Éric Thiébaut (https://github.com/emmt/XPA.jl).
#
module XPA

const libxpa = "libxpa."*Libdl.dlext

include("constants.jl")
include("types.jl")
include("misc.jl")
include("client.jl")
include("server.jl")

end # module
