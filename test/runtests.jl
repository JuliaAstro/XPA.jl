#
# runtests.jl --
#
# Exercises XPA communication in Julia.
#
#-------------------------------------------------------------------------------------------
#
# This file is part of XPA.jl released under the MIT "expat" license.
#
# Copyright (c) 2016-2025, Éric Thiébaut (https://github.com/JuliaAstro/XPA.jl).
#
module XPATests

using XPA
using Test
import Base: RefValue

@testset "XPA Messaging System" begin
    @testset "XPA Configuration" begin
        val = XPA.getconfig(:XPA_MAXHOSTS)
        @test val isa Int
        @test_throws Exception XPA.setconfig!(:XPA_MAXHOSTS, 2//3)
        @test XPA.setconfig!(:XPA_MAXHOSTS, val - 1) === val
        @test XPA.getconfig(:XPA_MAXHOSTS) === val - 1

        val = XPA.getconfig(:XPA_SHORT_TIMEOUT)
        @test val isa Int
        @test_throws Exception XPA.setconfig!(:XPA_SHORT_TIMEOUT, 2//3)
        @test XPA.setconfig!(:XPA_SHORT_TIMEOUT, val - 1) === val
        @test XPA.getconfig(:XPA_SHORT_TIMEOUT) === val - 1

        val = XPA.getconfig(:XPA_LONG_TIMEOUT)
        @test val isa Int
        @test_throws Exception XPA.setconfig!(:XPA_LONG_TIMEOUT, 2//3)
        @test XPA.setconfig!(:XPA_LONG_TIMEOUT, val - 1) === val
        @test XPA.getconfig(:XPA_LONG_TIMEOUT) === val - 1

        val = XPA.getconfig(:XPA_CONNECT_TIMEOUT)
        @test val isa Int
        @test_throws Exception XPA.setconfig!(:XPA_CONNECT_TIMEOUT, 2//3)
        @test XPA.setconfig!(:XPA_CONNECT_TIMEOUT, val - 1) === val
        @test XPA.getconfig(:XPA_CONNECT_TIMEOUT) === val - 1

        val = XPA.getconfig(:XPA_TMPDIR)
        @test val isa String
        @test_throws Exception XPA.setconfig!(:XPA_TMPDIR, 2//3)
        @test XPA.setconfig!(:XPA_TMPDIR, "/some_other_dir") == val
        @test XPA.getconfig(:XPA_TMPDIR) == "/some_other_dir"

        val = XPA.getconfig(:XPA_VERBOSITY)
        @test val isa Bool
        @test_throws Exception XPA.setconfig!(:XPA_VERBOSITY, 2//3)
        @test XPA.setconfig!(:XPA_VERBOSITY, !val) == val
        @test XPA.getconfig(:XPA_VERBOSITY) == !val

        val = XPA.getconfig(:XPA_IOCALLSXPA)
        @test val isa Bool
        @test_throws Exception XPA.setconfig!(:XPA_IOCALLSXPA, 2//3)
        @test XPA.setconfig!(:XPA_IOCALLSXPA, !val) == val
        @test XPA.getconfig(:XPA_IOCALLSXPA) == !val
    end
    @testset "XPA Utilities" begin
        A = Dict(:a => 1, :b => 2, :c => 3)
        s = @inferred XPA.preserve_state(A, :b)
        delete!(A, :b)
        @test !haskey(A, :b)
        XPA.restore_state(s)
        @test haskey(A, :b) && A[:b] === 2
        A[:b] = -1
        XPA.restore_state(s)
        @test haskey(A, :b) && A[:b] === 2
        s = @inferred XPA.preserve_state(A, :x)
        @test !haskey(A, :x)
        A[:x] = 0
        @test haskey(A, :x) && A[:x] === 0
        XPA.restore_state(s)
        @test !haskey(A, :x)
        XPA.preserve_state(A, :x) do
            A[:x] = 0
        end
        @test !haskey(A, :x)
        XPA.preserve_state(A, :b) do
            A[:b] = 0
        end
        @test haskey(A, :b) && A[:b] === 2
        XPA.preserve_state(A, :b) do
            delete!(A, :b)
        end
        @test haskey(A, :b) && A[:b] === 2
    end
    @testset "XPA Client Connection" begin
        A = @inferred XPA.connection()
        @test A isa XPA.Client
        @test isopen(A)
        close(A)
        @test !isopen(A)
        B = @inferred XPA.connection()
        @test B === A # should be the very same object
        @test isopen(A) # connection should have been automatically re-open
        task = Threads.@spawn begin
            return XPA.connection()
        end
        GC.@preserve task begin
            C = fetch(task)
            @test C isa XPA.Client
            @test C != A # different tasks have different connections
            @test isopen(C)
        end
        finalize(task)
        GC.gc()
        @test !isopen(C) # connection shall have been closed
    end
    @testset "XPA Access Point" begin
        apt = XPA.AccessPoint()
        @test apt isa XPA.AccessPoint
        @test apt.class == ""
        @test apt.name == ""
        @test apt.address == ""
        @test apt.user == ""
        @test apt.access == 0
        @test !isopen(apt)
        apt = XPA.AccessPoint("class", "name", "addr", "user", 5)
        @test apt isa XPA.AccessPoint
        @test apt.class == "class"
        @test apt.name == "name"
        @test apt.address == "addr"
        @test apt.user == "user"
        @test apt.access == 5
        @test isopen(apt)
        @test isopen(XPA.AccessPoint(address="foo"))
        str = "DS9 ds9-8.7b1 gs 7f000001:37143 eric"
        A = tryparse(XPA.AccessPoint, str)
        @test A isa XPA.AccessPoint
        @test A.class == "DS9"
        @test A.name == "ds9-8.7b1"
        @test A.address == "7f000001:37143"
        @test A.user == "eric"
        @test A.access == 3
        @test string(A) == str
        B = tryparse(XPA.AccessPoint, str*"\n")
        @test B == A
        @test tryparse(XPA.AccessPoint, "a b c d e ") === nothing
        @test tryparse(XPA.AccessPoint, "a b c d") === nothing
        B = XPA.AccessPoint(A.class, A.name, A.address, A.user, A.access)
        @test B == A
        B = XPA.AccessPoint(A.class, A.name, A.address, A.user, "gs")
        @test B == A
        B = XPA.AccessPoint(class=A.class, name=A.name, address=A.address, user=A.user, access=A.access)
        @test B == A
        B = XPA.AccessPoint(class=A.class, name=A.name, address=A.address, user=A.user, access="gs")
        @test B == A
    end
end

const VERBOSE = true

function sproc1(running::RefValue{Bool}, srv::XPA.Server, params::String,
                buf::XPA.SendBuffer)
    if running[]
        VERBOSE && println("send: $params")
        result = 42
        try
            XPA.store!(buf, result)
            return XPA.SUCCESS
        catch err
            error(srv, err)
            return XPA.FAILURE
        end
    end
end

function rproc1(running::RefValue{Bool}, srv::XPA.Server, params::String,
                buf::XPA.ReceiveBuffer)

    status = XPA.SUCCESS
    if running[]
        nbytes = sizeof(buf)
        VERBOSE && println("receive: $params [$nbytes byte(s)]")
        if params == "quit"
            running[] = false
        elseif params == "greetings"
            status = XPA.message(srv, "hello folks!")
        end
    end
    return status
end

function main1()
    running = Ref(true)
    server = XPA.Server("TEST", "test1", "help me!",
                        XPA.SendCallback(sproc1, running),
                        XPA.ReceiveCallback(rproc1, running))
    while running[]
        XPA.poll(-1, 1)
    end
    close(server)
end

function sproc2(::Nothing, srv::XPA.Server, params::String,
                buf::XPA.SendBuffer)
    VERBOSE && println("send: $params")
    result = 42
    try
        XPA.store!(buf, result)
        return XPA.SUCCESS
    catch err
        error(srv, err)
        return XPA.FAILURE
    end
end

function rproc2(::Nothing, srv::XPA.Server, params::String,
                buf::XPA.ReceiveBuffer)

    status = XPA.SUCCESS
    if params == "quit"
        close(srv)
    elseif params == "greetings"
        status = XPA.message(srv, "hello folks!")
    else
        nbytes = sizeof(buf)
        status = XPA.message(srv, "I received $nbytes from you, thanks!\n")
    end
    return status
end

function main2()
    server = XPA.Server("TEST", "test2", "help me!",
                        XPA.SendCallback(sproc2, nothing),
                        XPA.ReceiveCallback(rproc2, nothing))
    XPA.mainloop()
end

end
