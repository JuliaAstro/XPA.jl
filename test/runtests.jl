#
# runtests.jl --
#
# Exercises XPA communication in Julia.
#
#------------------------------------------------------------------------------
#
# This file is part of XPA.jl released under the MIT "expat" license.
# Copyright (C) 2016-2017, Éric Thiébaut (https://github.com/emmt/XPA.jl).
#
module XPATests

using XPA
import Base: RefValue

const VERBOSE = false

function sproc(running::RefValue{Bool}, srv::XPA.Server, params::String,
               bufptr::Ptr{Ptr{UInt8}}, lenptr::Ptr{Csize_t})
    if running[]
        VERBOSE && println("send: $params")
    end
    result = 42
    try
        XPA.setbuf!(bufptr, lenptr, result)
        return XPA.SUCCESS
    catch err
        error(srv, err)
        return XPA.FAILURE
    end
end

function rproc(running::RefValue{Bool}, xpa::XPA.Server, params::String,
               buf::Ptr{UInt8}, len::Integer)

    status =  XPA.SUCCESS
    if running[]
        VERBOSE && println("receive: $params [$len byte(s)]")
        #arr = unsafe_wrap(buf, len, false)
        if params == "quit"
            running[] = false
        elseif params == "greetings"
            status = XPA.setmessage(xpa, "hello folks!")
        end
    end
    return status
end

function main()
    running = Ref(true)
    server = XPA.Server("TEST", "test1", "help me!",
                        XPA.SendCallback(sproc, running),
                        XPA.ReceiveCallback(rproc, running))
    while running[]
        XPA.poll(10, 0)
    end
    close(server)
end


end
