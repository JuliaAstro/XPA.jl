#
# client.jl --
#
# Implement XPA client methods.
#
#-------------------------------------------------------------------------------------------
#
# This file is part of XPA.jl released under the MIT "expat" license.
#
# Copyright (c) 2016-2025, Éric Thiébaut (https://github.com/JuliaAstro/XPA.jl).
#

"""
    XPA.Client()

yields a persistent XPA client connection which can be used for calls to [`XPA.set`](@ref)
and [`XPA.get`](@ref) methods. Persistence means that a connection to an XPA server is not
closed when one of the above calls is completed but will be re-used on successive calls.
Using `XPA.Client()` therefore saves the time it takes to connect to a server, which could
be significant with slow connections or if there will be a large number of exchanges with a
given access point.

!!! note
    To avoid the delay for connecting to the XPA server, all XPA methods that perform XPA
    client requests automatically use a connection that is kept open for the calling task.
    Directly calling `XPA.Client()` should be unnecessary, this method is kept for backward
    compatibility.

# See also

[`XPA.set`](@ref), [`XPA.get`](@ref), [`XPA.list`](@ref), and [`XPA.find`](@ref).

"""
Client() = Client(_open())

# Private wrapper for `XPAOpen`. Used to open or re-open a client connection.
function _open()
    # The argument of `XPAOpen` is currently ignored (it is reserved for future use).
    ptr = ccall((:XPAOpen, libxpa), Ptr{CDefs.XPARec}, (Ptr{Cvoid},), Ptr{Cvoid}(0))
    isnull(ptr) && error("failed to create a persistent XPA connection")
    return ptr
end

function Base.close(conn::Client)
    if isopen(conn)
        ccall((:XPAClose, libxpa), Cvoid, (Ptr{CDefs.XPARec},), conn)
        nullify_pointer!(conn) # avoid closing more than once!
    end
    return nothing
end

# Key in the task local storage for the per-task persistent client connection.
const TLS_CLIENT = Symbol("XPA.Client")

"""
    XPA.connection()

yields a persistent XPA client connection that is kept open for the calling task (a
different connection is memorized for each Julia task).

Per-task client connections are automatically open (or even re-open) and closed as needed.

"""
function connection()
    key = TLS_CLIENT
    tls = task_local_storage()
    if haskey(tls, key)
        # Retrieve the client connection of the task and re-open it if needed.
        conn = tls[key]::Client
        isopen(conn) || setfield!(conn, :ptr, _open())
    else
        # Create a new connection for the task and manage to have it closed when the task is
        # garbage collected.
        conn = Client()
        tls[key] = conn
        finalizer(_disconnect, current_task())
    end
    return conn
end

# `_disconnect` is private because it is a bad idea to disconnect another task unless it is
# being finalized.
function _disconnect(task::Task)
    # This method must not throw as it may be called when task is finalized.
    key = TLS_CLIENT
    tls = task.storage
    if tls !== nothing && haskey(tls, key)
        conn = tls[key]
        if conn isa Client
            close(conn)
            delete!(tls, key)
        end
    end
    return nothing
end

"""
    XPA.list(f = Returns(true); kwds...)

yields a list of available XPA access-points. The result is a vector of
[`XPA.AccessPoint`](@ref) instances. Optional argument `f` is a predicate function to filter
which access-points to keep.

For example, to only keep the access-points owned by the user:

```
apts = XPA.list() do apt
    apt.user == ENV["USER"]
end
```

# Keywords

- `method` is `nothing` (the default) or one of `inet`, `unix` (or `local`), or `localhost`
  as a symbol or a string to require a specific connection method.

- `on_error` is a symbol indicating what to do in case of unexpected reply by the XPA name
  server; it can be `:throw` to throw an exception, `:warn` (the default) to print a
  warning, anything else to silently ignore the error.

- `xpaget` is to specify the method to contact the XPA name server; it can be a string with
  the path to the `xpaget` executable or a function behaving like [`XPA.get`](@ref). Using
  [`XPA.get`](@ref) has fewer possibilities so, by default, the `xpaget` executable provided
  by `XPA_jll` artifact is used.

# See also

[`XPA.find`](@ref) to select a single access-point.

[`XPA.AccessPoint`](@ref) for the properties of access-points that can be used in the
predicate function `f`.

"""
function list(f::Function = Returns(true);
              method::Union{Nothing,Symbol,AbstractString} = nothing,
              xpaget::Union{AbstractString,typeof(XPA.get)} = default_xpaget(),
              on_error::Symbol = :warn)
    # Check options.
    method === nothing || check_connection_method(method)

    # Obtain a list of running XPA servers from the XPA name server.
    lines = if xpaget isa AbstractString
        readlines(
            if method === nothing
                `$xpaget xpans`
            else

                `$xpaget -m $method xpans`
            end
        )
    else
        if method !== nothing
            global ENV
            ENV["XPA_METHOD"] = method
        end
        split(chomp(xpaget(String, "xpans")), r"\n|\r\n?"; keepempty=false)
    end

    # Parse textual descriptions of XPA servers.
    lst = AccessPoint[]
    for line in lines
        m = match(r"^ *([^ ]+) +([^ ]+) +([gsi]+) +([^ ]+) +([^ ]+) *$", line)
        if m === nothing
            if on_error in (:throw, :warn)
                mesg = "failed to parse `xpans` output line: \"$line\""
                on_error === :throw ? error(mesg) : @warn mesg
            end
        else
            class, name, acl, addr, user = m.captures
            access = zero(GET)
            for c in acl
                if c == 'g'
                    access |= GET
                elseif c == 's'
                    access |= SET
                elseif c == 'i'
                    access |= INFO
                end
            end
            apt = AccessPoint(class, name, addr, user, access)
            f(apt) && push!(lst, apt)
        end
    end
    return lst
end

@deprecate(list(conn::Client; kwds...), list(; kwds...), false)

# `xpaget` executable is taken if possible from artifact.
default_xpaget() = isdefined(XPA_jll, :xpaget_path) ? XPA_jll.xpaget_path : "xpaget"

check_connection_method(s) =
    check_connection_method(Bool, s) ? nothing : throw(ArgumentError(
        "invalid XPA connection method `$s`"))
check_connection_method(::Type{Bool}, s::AbstractString) =
    s in ("inet", "unix", "local", "localhost")
check_connection_method(::Type{Bool}, s::Symbol) =
    s in (:inet, :unix, :local, :localhost)

"""
    XPA.find(f = Returns(true); kwds...)

yields the access-point of the XPA server matching the requirements implemented by the
predicate function `f` and keywords `kwds...`. In principle, the result is either a single
instance of [`XPA.AccessPoint`](@ref) or `nothing` if no matching server is found (this type
assertion may only be invalidated by the function specified via the `select` keyword).

# Keywords

In addition to the keywords accepted by [`XPA.list`](@ref), the following keyword(s)
are available:

- `select` specifies a strategy to apply if more than one access-point is found. `select`
  can be a function (like `first` or `last` to keep the first or last entry), the symbolic
  name `:interact` to ask the user to make the selection via a REPL menu, or anything else
  to throw an exception. The default is `:throw`. If `select` is a function, it is called
  with a vector of 2 or more matching instances of [`XPA.AccessPoint`](@ref) and the result
  of `select` is returned by `XPA.find`.

# Example

``` julia
apt = XPA.find(; interact = isinteractive(), method = :local)
```

# See also

[`XPA.list`](@ref) which is called to retrieve a list of access-points with the predicate
function `f`.

[`XPA.AccessPoint`](@ref) for the properties of access-points that can be used in the predicate
function `f`.

"""
function find(f::Function = Returns(true); select = :throw, kwds...)
    apts = list(f; kwds...)
    n = length(apts)
    if n == 0
        return nothing
    elseif n == 1
        return first(apts)
    elseif select isa Function
        return select(apts)
    elseif select === :interact
        return select_interactively(apts)
    else
        error("too many ($(length(apts))) XPA servers match the constraints")
    end
end

@deprecate(find(ident::Union{AbstractString,Regex}; kwds...),
           deprecated_find(connection(), conn, ident; kwds...), false)

@deprecate(find(conn::Client, ident::Union{AbstractString,Regex}; kwds...),
           deprecated_find(conn, ident; kwds...), false)

function deprecated_find(conn::Client,
                         ident::AbstractString;
                         user::AbstractString = "*",
                         throwerrors::Bool = false)::Union{AccessPoint,Nothing}
    i = findfirst(isequal(':'), ident)
    if i === nothing
        # allow any class
        class = "*"
        name = ident
    else
        class = ident[1:i-1]
        name = ident[i+1:end]
    end
    anyuser = (user == "*")
    anyclass = (class == "*")
    anyname = (name == "*")
    lst = list(conn)
    for j in eachindex(lst)
        if ((anyuser || lst[j].user == user) &&
            (anyclass || lst[j].class == class) &&
            (anyname || lst[j].name == name))
            return lst[j]
        end
    end
    throwerrors && throw_no_servers_match(ident)
    return nothing
end

function deprecated_find(conn::Client,
                         ident::Regex;
                         user::AbstractString = "*",
                         throwerrors::Bool = false)::Union{AccessPoint,Nothing}
    anyuser = (user == "*")
    lst = list(conn)
    for j in eachindex(lst)
        if ((anyuser || lst[j].user == user) &&
            occursin(ident, lst[j].class*":"*lst[j].name))
            return lst[j]
        end
    end
    throwerrors && throw_no_servers_match(ident)
    return nothing
end

@noinline throw_no_servers_match(ident::AbstractString) =
    error("no XPA servers match pattern \"$(ident)\"")

@noinline throw_no_servers_match(ident::Regex) =
     error("no XPA servers match regular expression \"$(ident.pattern)\"")

menu_string(str::AbstractString) = str
menu_string(sym::Symbol) = string(sym)
menu_string(apt::AccessPoint) =
    "$(apt.class):$(apt.name) [address=\"$(apt.addr)\", user=\"$(apt.user)\"]"

function select_interactively(iter)
    options = ["(none)"]
    foreach(iter) do item
        push!(options, menu_string(item))
    end
    menu = RadioMenu(options)
    choice = request("Please select one of:", menu)
    for item in iter
        choice == 2 && return item
        choice > 2 && break
        choice -= 1
    end
    return nothing
end

"""
    XPA.address(apt) -> addr

yields the address of XPA access-point `apt` which can be: an instance of `XPA.AccessPoint`,
a string with a valid XPA server address or a server `class:name` identifier. In the latter
case, [`XPA.find`](@ref) is called to find a matching server which is much longer.

"""
address(apt::XPA.AccessPoint) =
    apt.addr

function address(apt::AbstractString) # FIXME
    i = findfirst(isequal(':'), apt)
    if (i === nothing ||
        tryparse(UInt, apt[1:i-1],  base = 16) === nothing ||
        tryparse(UInt, apt[i+1:end],  base = 10) === nothing)
        return address(XPA.find(apt; throwerrors = true))
    end
    return apt
end

"""
    XPA.get([T, [dims,]] [conn,] apt, args...; kwds...)

retrieves data from one or more XPA access-points identified by `apt` (a template name, a
`host:port` string or the name of a Unix socket file) with arguments `args...`
(automatically converted into a single string where the arguments are separated by a single
space). Optional argument `conn` is a persistent XPA client connection (created by
[`XPA.Client`](@ref)); if omitted, a per-task connection is used (see
[`XPA.connection`](@ref)). The returned value depends on the optional arguments `T` and
`dims`.

If neither `T` nor `dims` are specified, an instance of [`XPA.Reply`](@ref) is returned with
all the answer(s) from the XPA server(s). The following keywords are available:

* Keyword `nmax` specifies the maximum number of answers, `nmax=1` by default. Specify
  `nmax=-1` to use the maximum number of XPA hosts.

* Keyword `throwerrors` specifies whether to check for errors. If this keyword is set true,
  an exception is thrown for the first error message encountered in the list of answers. By
  default, `throwerrors` is false.

* Keyword `mode` specifies options in the form `"key1=value1,key2=value2"`.

* Keyword `users` specifies the list of possible users owning the access-point. This
  (temporarily) overrides the settings in environment variable `XPA_NSUSERS`. By default and
  if the environment variable `XPA_NSUSERS` is not set, the access-point must be owned the
  caller (see Section *Distinguishing Users* in XPA documentation). The value is a string
  which may be a list of comma separated user names or `"*"` to access all users on a given
  machine.

If `T` and, possibly, `dims` are specified, a single answer and no errors are expected (as
if `nmax=1` and `throwerrors=true`) and the data part of the answer is converted according
to `T` which must be a type and `dims` which is an optional list of dimensions:

* If only `T` is specified, it can be `String` to return a string interpreting the data as
  ASCII characters or a type like `Vector{S}` to return the largest vector of elements of
  type `S` that can be extracted from the returned data.

* If both `T` and `dims` are specified, `T` can be a type like `Array{S}` or `Array{S,N}`
  and `dims` a list of `N` dimensions to retrieve the data as an array of type `Array{S,N}`.

# See also

[`XPA.Client`](@ref), [`XPA.get_data`](@ref), [`XPA.set`](@ref), and
[`XPA.verify`](@ref).

"""
function get(conn::Client,
             apt::AbstractString,
             cmd::AbstractString;
             mode::AbstractString = "",
             nmax::Integer = 1,
             throwerrors::Bool = false,
             users::Union{Nothing,AbstractString} = nothing)
    return _get(conn, apt, cmd, mode, _nmax(nmax), throwerrors, users)
end

get(apt::AccessPoint, args...; kwds...) =
    get(address(apt), args...; kwds...)

get(apt::AbstractString, args...; kwds...) =
    get(connection(), apt, args...; kwds...)

get(conn::Client, apt::AccessPoint, args...; kwds...) =
    get(conn, address(apt), args...; kwds...)

get(conn::Client, apt::AbstractString, args...; kwds...) =
    get(conn, apt, join_arguments(args); kwds...)

_get1(args...; kwds...) = get(args...; nmax = 1, throwerrors = true, kwds...)

function get(::Type{Vector{T}},
             args...; kwds...) :: Vector{T} where {T}
    get_data(Vector{T}, _get1(args...; kwds...))
end

function get(::Type{Vector{T}}, dim::Integer,
             args...; kwds...) :: Vector{T} where {T}
    get_data(Vector{T}, dim, _get1(args...; kwds...))
end

function get(::Type{Array{T}}, dim::Integer,
             args...; kwds...) :: Array{T} where {T}
    get_data(Vector{T}, dim, _get1(args...; kwds...))
end

function get(::Type{Array{T}}, dims::NTuple{N,Integer},
             args...; kwds...) :: Array{T,N} where {T,N}
    get_data(Array{T,N}, dims, _get1(args...; kwds...))
end

function get(::Type{Array{T,N}}, dims::NTuple{N,Integer},
             args...; kwds...) :: Array{T,N} where {T,N}
    get_data(Array{T,N}, dims, _get1(args...; kwds...))
end

function get(::Type{A}, dims::Dims{N}, args...; kwds...) where {T,N,A<:AbstractArray{T,N}}
    get_data(Array{T,N}, dims, _get1(args...; kwds...))
end

function get(::Type{String}, args...; kwds...)
    return get_data(String, _get1(args...; kwds...))
end

function _get(conn::Client, apt::AbstractString, params::AbstractString,
              mode::AbstractString, nmax::Int, throwerrors::Bool,
              users::Union{Nothing,AbstractString})
    A = Reply(nmax)
    lengths = _lengths(A)
    buffers = _buffers(A)
    address = pointer(buffers)
    offset = nmax*sizeof(Ptr{Byte})
    prevusers = _override_nsusers(users)
    got = GC.@preserve A ccall(
        (:XPAGet, libxpa), Cint,
        (Client, Cstring, Cstring, Cstring, Ptr{Ptr{Byte}},
         Ptr{Csize_t}, Ptr{Ptr{Byte}}, Ptr{Ptr{Byte}}, Cint),
        conn, apt, params, mode, address, lengths,
        address + offset, address + 2*offset, nmax)
    _restore_nsusers(prevusers)
    0 ≤ got ≤ nmax || throw(AssertionError("unexpected number of replies from `XPAGet`"))
    setfield!(A, :replies, Int(got)::Int)
    throwerrors && verify(A; throwerrors=true)
    return A
end

function _set(conn::Client, apt::AbstractString, params::AbstractString,
              mode::AbstractString, data::Union{NullBuffer,DenseArray},
              nmax::Int, throwerrors::Bool,
              users::Union{Nothing,AbstractString})
    A = Reply(nmax)
    lengths = _lengths(A)
    buffers = _buffers(A)
    address = pointer(buffers)
    offset = nmax*sizeof(Ptr{Byte})
    prevusers = _override_nsusers(users)
    got = GC.@preserve A ccall(
        (:XPASet, libxpa), Cint,
        (Client, Cstring, Cstring, Cstring, Ptr{Cvoid},
         Csize_t, Ptr{Ptr{Byte}}, Ptr{Ptr{Byte}}, Cint),
        conn, apt, params, mode, data, sizeof(data),
        address + offset, address + 2*offset, nmax)
    _restore_nsusers(prevusers)
    0 ≤ got ≤ nmax || throw(AssertionError("unexpected number of replies from `XPASet`"))
    setfield!(A, :replies, Int(got)::Int)
    throwerrors && verify(A; throwerrors=true)
    return A
end

"""
    _override_nsusers(users::AbstractString) -> String
    _override_nsusers(users::Nothing) -> Nothing

Override environment variable `XPA_NSUSERS`.

"""
_override_nsusers(::Nothing) = nothing
function _override_nsusers(users::AbstractString)
    prev = Base.get(ENV, "XPA_NSUSERS", "")
    ENV["XPA_NSUSERS"] = users
    return prev
end

"""
    _restore_nsusers(users::Union{AbstractString,Nothing})

Restore environment variable `XPA_NSUSERS`.

"""
_restore_nsusers(::Nothing) = nothing
function _restore_nsusers(users::AbstractString)
    if users == ""
        delete!(ENV, "XPA_NSUSERS")
    else
        ENV["XPA_NSUSERS"] = users
    end
    nothing
end

#-------------------------------------------------------------------------------------------

# Accessors for `XPA.Entry`.
Base.parent(A::Entry) = getfield(A, :parent)
index(A::Entry) = getfield(A, :index)

# `XPA.Reply` has no property.
Base.propertynames(A::Reply) = ()
Base.getproperty(A::Reply, key::Symbol) = throw(KeyError(key))
Base.setproperty!(A::Reply, key::Symbol, x) = throw(KeyError(key))

# Private accessors for `XPA.Reply`. Object `A` must be preserved from being garbage collected.
_buffers(A::Reply) = getfield(A, :buffers)
_lengths(A::Reply) = getfield(A, :lengths)
_nbufs(A::Reply) = length(_lengths(A))

# Abstract vector API for `XPA.Reply`.
Base.length(A::Reply) = getfield(A, :replies)
Base.firstindex(A::Reply) = 1
Base.lastindex(A::Reply) = length(A)
Base.eachindex(A::Reply) = Base.OneTo(length(A))
Base.eachindex(::IndexLinear, A::Reply) = eachindex(A)
Base.IndexStyle(::Type{<:Reply}) = IndexLinear()
Base.getindex(A::Reply, i::Int) = Entry(A, i)
Base.size(A::Reply) = (length(A),)
Base.axes(A::Reply) = (eachindex(A),)

# Finalizer for a `XPA.Reply` instance.
function _free(A::Reply)
    fill!(_lengths(A), 0)
    B = _buffers(A)
    @inbounds for i in eachindex(B)
        ptr = B[i]
        if !isnull(ptr)
            B[i] = NULL
            _free(ptr)
        end
    end
    return nothing
end

# Unsafe accessors for the reply contents. Object `A` must be preserved from being garbage
# collected and index `i` must be valid.
#
# In the `buffers` member, the storage is as follows:
#
# - i-th data buffer is at index i;
# - i-th server name is at index i + nbufs;
# - i-th message is at index i + 2*nbufs.
#
_unsafe_server( A::Reply, i::Int) = @inbounds _buffers(A)[i + _nbufs(A)]
_unsafe_message(A::Reply, i::Int) = @inbounds _buffers(A)[i + _nbufs(A)*2]
function _unsafe_data(A::Reply, i::Int)
    @inbounds begin
        ptr = _buffers(A)[i]
        len = _lengths(A)[i]
        (isnull(ptr) ? len == 0 : len ≥ 0) || throw(AssertionError("invalid buffer length"))
        return (ptr, len)
    end
end

# API for `XPA.DataAccessor`.
Base.parent(A::DataAccessor) = getfield(A, :parent)
@inline (A::DataAccessor)(args...; kwds...) = get_data(args..., parent(A); kwds...)

# API for `eltype(XPA.Reply)`. This temporary object represent a single reply entry and
# whose index has been checked by the constructor.
Base.propertynames(A::eltype(Reply)) = (:data, :has_error, :has_message, :message, :server)

Base.getproperty(A::eltype(Reply), key::Symbol) =
   key === :data        ? DataAccessor(A) :
   key === :has_error   ? has_error(   A) :
   key === :has_message ? has_message( A) :
   key === :message     ? get_message( A) :
   key === :server      ? get_server(  A) :
   throw(KeyError(key))

"""
    XPA.get_message(rep::XPA.Reply, i=1)
    XPA.get_message(rep[i])
    rep[i].message

yields the message associated with the `i`-th answer in XPA reply `rep`. An empty string is
returned if there is no message.

!!! note
    In the future `XPA.get_message` will be deprecated; `rep[i].message` is the recommended
    syntax.

# See also

[`XPA.get`](@ref), [`XPA.has_message`](@ref), [`XPA.has_error`](@ref),
[`XPA.get_data`](@ref) and [`XPA.get_server`](@ref).

"""
function get_message(A::eltype(Reply))
    B, i = parent(A), index(A)
    return GC.@preserve B _string(_unsafe_message(B, i))
end

"""
    XPA.get_server(rep::XPA.Reply, i=1)
    XPA.get_server(rep[i])
    rep[i].server

yields a string identifying the server who provided the `i`-th answer in XPA reply `rep`.

!!! note
    In the future `XPA.get_server` will be deprecated; `rep[i].server` is the recommended
    syntax.

# See also

[`XPA.get`](@ref), [`XPA.has_message`](@ref), [`XPA.has_error`](@ref),
[`XPA.get_data`](@ref) and [`XPA.get_message`](@ref).

"""
function get_server(A::eltype(Reply))
    B, i = parent(A), index(A)
    return GC.@preserve B _string(_unsafe_server(B, i))
end

# `_string(ptr)` copies bytes at address `ptr` as a string, returning an empty
# string if `ptr` is `NULL`.
_string(ptr::Ptr{Byte}) = isnull(ptr) ? EMPTY_STRING : unsafe_string(ptr)

"""
    XPA.has_error(rep::XPA.Reply, i=1)
    XPA.has_error(rep[i])
    rep[i].has_error

yields whether `i`-th answer in XPA reply `rep` has an error whose message is given by
`rep[i].message`.

!!! note
    In the future `XPA.has_error` will be deprecated; `rep[i].has_error` is the recommended
    syntax.

# See also

[`XPA.get`](@ref), [`XPA.get_message`](@ref), [`XPA.has_message`](@ref),
[`XPA.get_data`](@ref), and [`XPA.get_server`](@ref),

"""
function has_error(A::eltype(Reply))
    B, i = parent(A), index(A)
    return GC.@preserve B _starts_with(_unsafe_message(B, i), _XPA_ERROR)
end
const _XPA_ERROR   = "XPA\$ERROR "

"""
    XPA.has_message(rep::XPA.Reply, i=1)
    XPA.has_message(rep[i])
    rep[i].has_message

yields whether `i`-th answer in XPA reply `rep` has an associated message that is given by
`rep[i].message`.

!!! note
    In the future `XPA.has_message` will be deprecated; `rep[i].has_message` is the
    recommended syntax.

# See also

[`XPA.get`](@ref), [`XPA.get_message`](@ref), [`XPA.has_error`](@ref),
[`XPA.get_data`](@ref), and [`XPA.get_server`](@ref),

"""
function has_message(A::eltype(Reply))
    B, i = parent(A), index(A)
    return GC.@preserve B _starts_with(_unsafe_message(B, i), _XPA_MESSAGE)
end
const _XPA_MESSAGE = "XPA\$MESSAGE "

function _starts_with(ptr::Ptr{UInt8}, str::String)
    if isnull(ptr)
        return false
    end
    @inbounds for i in 1:ncodeunits(str)
        if unsafe_load(ptr, i) != codeunit(str, i)
            return false
        end
    end
    return true
end

for func in (:get_message, :get_server, :has_message, :has_error)
    @eval $func(A::Reply, i::Integer=1) = $func(A[i])
end

"""
    XPA.has_errors(rep::Reply) -> Bool

yields whether answer `rep` contains any error messages.

# See also

[`XPA.get`](@ref), [`XPA.has_error`](@ref), and [`XPA.get_message`](@ref).

"""
function has_errors(A::Reply)
    @inbounds for Aᵢ in A
        if Aᵢ.has_error
            return true
        end
    end
    return false
end

"""
    XPA.join_arguments(args) -> str::String

joins a tuple of arguments into a single string where arguments are separated by a single
space. It is implemented so as to be faster than `join(args, " ")` when `args` has less than
2 arguments. It is intended to build XPA command string from arguments.

"""
join_arguments(args::Tuple) = join(args, " ")
join_arguments(args::Tuple{String}) = args[1]
join_arguments(args::Tuple{Any}) = string(args[1])
join_arguments(::Tuple{}) = ""

"""
    _nmax(n::Integer)

Private method. Yields the maximum number of expected answers to a get/set
request.  The result is `n` if `n ≥ 1` or `getconfig("XPA_MAXHOSTS")`
otherwise. The call `_nmax(rep::Reply)` yields the maximum number of
answers that can be stored in `rep`.
"""
_nmax(n::Integer) = (n == -1 ? Int(getconfig("XPA_MAXHOSTS")) : Int(n))

function Base.show(io::IO, A::eltype(Reply))
    print(io, "XPA answer: ")
    _show(io, A)
    return nothing
end

function _show(io::IO, A::eltype(Reply))
    B, i = parent(A), index(A)
    GC.@preserve B begin
        print(io, "server = ", repr(A.server; context=io),
              ", message = ", repr(A.message; context=io),
              ", data = ")
        ptr, len = _unsafe_data(B, i)
        if isnull(ptr)
            print(io, "NULL")
        elseif len == 0
            print(io, repr("";  context=io))
        else
            # Check whether all bytes in the data buffer are printable ASCII characters.
            cstring = true
            for j in 1:len
                b = unsafe_load(ptr, j)
                if !iszero(b & 0x80)
                    # Not ASCII.
                    cstring = false
                    break
                end
                c = Char(b)
                if !(isprint(c) || c == '\n' || c == '\r' || c == '\t')
                    # Not Printable.
                    cstring = false
                    break
                end
            end
            if cstring
                print(io, repr(unsafe_string(ptr, len); context=io))
            else
                print(io, len, (len > 1 ? " bytes" : " byte"))
            end
        end
    end
    return nothing
end

Base.show(io::IO, ::MIME"text/plain", A::Reply) = show(io, A)

function Base.show(io::IO, A::Reply)
    print(io, "XPA.Reply")
    n = length(A)
    if n == 0
        print(io, " (no replies)")
    else
        print(io, " (", n, " repl", (n > 1 ? "ies" : "y"), "):\n")
        for i in 1:n
            print(io, "  ", i, ": ")
            _show(io, A[i])
            i < n && print(io, "\n")
        end
    end
    return nothing
end

"""
    XPA.verify(rep::Reply [, i]; throwerrors::Bool=false) -> Bool

verifies whether answer(s) in the result `rep` from an [`XPA.get`](@ref) or
[`XPA.set`](@ref) request has no errors. If index `i` is specified only that specific answer
is considered; otherwise, all answers are verified. If keyword `throwerrors` is true, an
exception is thrown for the first error found if any.

"""
function verify(rep::Reply; kwds...)
    for i in 1:length(rep)
        verify(rep, i; kwds...) || return false
    end
    return true
end

function verify(rep::Reply, i::Integer; throwerrors::Bool=false)
    if has_error(rep, i)
        if throwerrors
            # Strip error message prefix (which we know that it is present).
            msg = get_message(rep, i)
            j = length(_XPA_ERROR_PREFIX) + 1
            while j ≤ length(msg) && isspace(msg[j])
                j += 1
            end
            error(msg[j:end])
        else
            return false
        end
    end
    return true
end

"""
    XPA.get_data([T, [dims,]] rep::XPA.Reply, i=1; preserve=false)
    XPA.get_data([T, [dims,]] rep[i]; preserve=false)
    rep[i].data([T, [dims,]]; preserve=false)

yields the data associated with the `i`-th answer in XPA reply `rep`. The returned value
depends on the optional leading arguments `T` and `dims`:

* If neither `T` nor `dims` are specified, a vector of bytes (`$Byte`) is returned.

* If only `T` is specified, it can be `String` to return a string interpreting the data as
  ASCII characters or a type like `Vector{S}` to return the largest vector of elements of
  type `S` that can be extracted from the data.

* If both `T` and `dims` are specified, `T` can be an array type like `Array{S}` or
  `Array{S,N}` and `dims` a list of `N` dimensions to retrieve the data as an array of type
  `Array{S,N}`.

Keyword `preserve` specifies whether or not to preserve the internal data buffer in `rep`
for another call to `XPA.get_data`. This keyword is ignored if the result cannot directly
use the internal buffer. By default, `preserve=true`.

In any cases, the type of the result is predictable, so there should be no type instability
issue.

!!! note
    In the future `XPA.get_data` will be deprecated; `rep[i].data(...)` is the recommended
    syntax.

# See also

[`XPA.get`](@ref), [`XPA.get_message`](@ref), and [`XPA.get_server`](@ref).

"""
function get_data(A::Reply, i::Integer=1; kwds...)
    return get_data(A[i]; kwds...)
end

function get_data(::Type{T}, A::Reply, i::Integer=1; kwds...) where {T}
    return get_data(T, A[i]; kwds...)
end

function get_data(::Type{T}, shape::ArrayShape, A::Reply, i::Integer=1;
                  kwds...) where {T<:AbstractArray}
    return get_data(T, shape, A[i]; kwds...)
end

# By default returns content as a vector of bytes.
function get_data(A::eltype(Reply); kwds...)
    return get_data(Memory{Byte}, A; kwds...)
end

# Convert content to a single ASCII string. `preserve` keyword is ignored because a copy is
# made anyway.
function get_data(::Type{String}, A::eltype(Reply); preserve::Bool = true)
    B, i = parent(A), index(A)
    GC.@preserve B begin
        ptr, len = _unsafe_data(B, i)
        return iszero(len) ? EMPTY_STRING : unsafe_string(ptr, len)
    end
end

# Returns content as a single value. `preserve` keyword is ignored because a copy is made
# anyway.
function get_data(::Type{T}, A::eltype(Reply); preserve::Bool = true) where {T}
    isbitstype(T) || throw(ArgumentError("value type `$T` is not plain data type"))
    B, i = parent(A), index(A)
    GC.@preserve B begin
        ptr, nbytes = _unsafe_data(B, i)
        sizeof(T) ≤ nbytes || throw_buffer_too_small(sizeof(T), nbytes)
        return unsafe_load(Ptr{T}(ptr))
    end
end

# Returns content as a vector as long as possible.
function get_data(::Type{R}, A::eltype(Reply); kwds...) where {T,R<:AbstractVector{T}}
    (isbitstype(T) && sizeof(T) > 0) || throw(ArgumentError(
        "unable to infer number of elements of type `$T`"))
    nbytes = @inbounds _lengths(parent(A))[index(A)]
    nelem = div(nbytes, sizeof(T))
    return get_data(R, as_array_size(nelem), A; kwds...)
end

# Convert array shape to `Dims`.
function get_data(::Type{T}, shape::ArrayShape, A::eltype(Reply);
                  kwds...) where {T<:AbstractArray}
    return get_data(T, as_array_size(shape), A; kwds...)
end

# Returns content as an array of given size and element type.
function get_data(::Type{R}, dims::Dims{N}, A::eltype(Reply);
                  preserve::Bool = true) where {T,N,R<:AbstractArray{T}}
    R <: Union{Array,Memory} || throw(ArgumentError("unsupported array type `$R`"))
    isbitstype(T) || throw(ArgumentError("array element type `$T` is not plain data type"))
    !has_ndims(R) || ndims(R) == N || throw(DimensionMismatch(
        "result type `$R` incompatible with $N-dimensional shape"))
    B, i = parent(A), index(A)
    ptr, nbytes = _unsafe_data(B, i)
    nelem = 1
    for dim in dims
        dim ≥ 0 || throw(ArgumentError("invalid dimension(s)"))
        nelem *= dim
    end
    nelem*sizeof(T) ≤ nbytes || throw_buffer_too_small(nelem*sizeof(T), nbytes)
    GC.@preserve B begin
        if R <: Array{T} && !preserve && nelem > 0
            # Transfer ownership of buffer to Julia.
            @inbounds begin
                # It is better to not free than free more than once, so forget buffer first.
                _buffers(B)[i] = NULL
                _lengths(B)[i] = 0
            end
            return unsafe_wrap(Array, Ptr{T}(ptr), dims; own=true)
        else
            # Create a new array and copy contents.
            return _memcpy!(R(undef, dims)::R, ptr, nelem*sizeof(T))
        end
    end
end

@noinline throw_buffer_too_small(req::Integer, got::Integer) = throw(DimensionMismatch(
    "$got available byte(s) in reply data, less than $req requested byte(s)"))

has_ndims(::Type{<:AbstractArray}) = false
has_ndims(::Type{<:AbstractArray{<:Any,N}}) where {N} = true

"""
    XPA.set([conn,] apt, args...; data=nothing, kwds...) -> rep

sends `data` to one or more XPA access-points identified by `apt` with arguments `args...`
(automatically converted into a single string where the arguments are separated by a single
space). The result is an instance of [`XPA.Reply`](@ref). Optional argument `conn` is a
persistent XPA client connection (created by [`XPA.Client`](@ref)); if omitted, a per-task
connection is used (see [`XPA.connection`](@ref)).

The following keywords are available:

* Keyword `data` specifies the data to send, may be `nothing`, an array or a string. If it
  is an array, it must have contiguous elements (as a for a *dense* array) and must
  implement the `pointer` method.

* Keyword `nmax` specifies the maximum number of recipients, `nmax=1` by default. Specify
  `nmax=-1` to use the maximum possible number of XPA hosts.

* Keyword `mode` specifies options in the form `"key1=value1,key2=value2"`.

* Keyword `throwerrors` specifies whether to check for errors. If this keyword is set
  `true`, an exception is thrown for the first error message encountered in the list of
  answers. By default, `throwerrors` is false.

* Keyword `users` specifies the list of possible users owning the access-point. This
  (temporarily) overrides the settings in environment variable `XPA_NSUSERS`. By default and
  if the environment variable `XPA_NSUSERS` is not set, the access-point must be owned the
  caller (see Section *Distinguishing Users* in XPA documentation). The value is a string
  which may be a list of comma separated user names or `"*"` to access all users on a given
  machine.

# See also

[`XPA.Client`](@ref), [`XPA.get`](@ref) and [`XPA.verify`](@ref).

"""
function set(conn::Client,
             apt::AbstractString,
             cmd::AbstractString;
             data = nothing,
             mode::AbstractString = "",
             nmax::Integer = 1,
             throwerrors::Bool = false,
             users::Union{Nothing,AbstractString} = nothing)
    return _set(conn, apt, cmd, mode, buffer(data), _nmax(nmax),
                throwerrors, users)
end

function set(conn::Client,
             apt::AbstractString,
             args::Union{AbstractString,Real}...;
             kwds...)
    return _set(conn, apt, join_arguments(args); kwds...)
end

set(apt::AbstractString, args::Union{AbstractString,Real}...; kwds...) =
    set(connection(), apt, join_arguments(args); kwds...)

"""
    buf = XPA.buffer(data)

yields an object `buf` representing the contents of `data` and which can be used as an
argument to `ccall` without the risk of having the data garbage collected. Argument `data`
can be `nothing`, a dense array or a string. If `data` is an array `buf` is just an alias
for `data`. If `data` is a string, `buf` is a temporary byte buffer where the string has
been copied.

Standard methods `pointer` and `sizeof` can be applied to `buf` to retieve the address and
the size (in bytes) of the data and `convert(Ptr{Cvoid},buf)` can also be used.

# See also

[`XPA.set`](@ref).

"""
function buffer(arr::A) :: A where {T,N,A<:DenseArray{T,N}}
    @assert isbitstype(T)
    return arr
end

function buffer(str::AbstractString)
    @assert isascii(str)
    len = length(str)
    buf = Vector{Cchar}(undef, len)
    @inbounds for i in 1:len
        buf[i] = str[i]
    end
    return buf
end

buffer(::Nothing) = NullBuffer()

Base.unsafe_convert(::Type{Ptr{T}}, ::NullBuffer) where {T} = Ptr{T}(0)
Base.pointer(::NullBuffer) = C_NULL
Base.sizeof(::NullBuffer) = 0
