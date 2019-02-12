#
# constants.jl --
#
# Constant definitions.
#
# *IMPORTANT* This file has been automatically generated, do not edit it
#             directly but rather modify the source in `../deps/gencode.c`.
#
#------------------------------------------------------------------------------
#
# This file is part of IPC.jl released under the MIT "expat" license.
# Copyright (C) 2016-2019, Éric Thiébaut (https://github.com/emmt/IPC.jl).
#

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
