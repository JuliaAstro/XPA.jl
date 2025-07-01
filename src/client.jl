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
        finalizer(disconnect, current_task())
    end
    return conn
end

function disconnect(task::Task)
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

yields the address of XPA accesspoint `apt` which can be: an instance of `XPA.AccessPoint`,
a string with a valid XPA server address or a server `class:name` identifier. In the latter
case, [`XPA.find`](@ref) is called to find a matching server which is much longer.

"""
address(apt::XPA.AccessPoint) =
    apt.addr

function address(apt::AbstractString)
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
  wich may be a list of comma separated user names or `"*"` to access all users on a given
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

function get(::Type{String}, args...; kwds...)
    return get_data(String, _get1(args...; kwds...))
end

function _get(conn::Client, apt::AbstractString, params::AbstractString,
              mode::AbstractString, nmax::Int, throwerrors::Bool,
              users::Union{Nothing,AbstractString})
    lengths = fill!(Memory{Csize_t}(undef, nmax), 0)
    buffers = fill!(Memory{Ptr{Byte}}(undef, nmax*3), Ptr{Byte}(0))
    address = pointer(buffers)
    offset = nmax*sizeof(Ptr{Byte})
    prevusers = _override_nsusers(users)
    replies = GC.@preserve lengths buffers ccall(
        (:XPAGet, libxpa), Cint,
        (Client, Cstring, Cstring, Cstring, Ptr{Ptr{Byte}},
         Ptr{Csize_t}, Ptr{Ptr{Byte}}, Ptr{Ptr{Byte}}, Cint),
        conn, apt, params, mode, address, lengths,
        address + offset, address + 2*offset, nmax)
    _restore_nsusers(prevusers)
    0 ≤ replies ≤ nmax || error("unexpected number of replies from XPAGet")
    rep = finalizer(_free, Reply(replies, lengths, buffers))
    throwerrors && verify(rep; throwerrors=true)
    return rep
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

"""
    _free(rep::Reply)
"""
function _free(rep::Reply)
    nmax = _nmax(rep)
    fill!(rep.lengths, 0)
    for i in 0:2,
        j in 1:length(rep)
        k = i*nmax + j
        if (ptr = rep.buffers[k]) != NULL
            rep.buffers[k] = NULL
            _free(ptr)
        end
    end
end

# i-th server name is at index i + nmax.
_get_srv(rep::Reply, i::Integer) = _get_srv(rep, Int(i))
_get_srv(rep::Reply, i::Int) :: Ptr{Byte} =
    (1 ≤ i ≤ length(rep) ? rep.buffers[i + _nmax(rep)] : NULL)

# i-th message is at index i + 2*nmax.
_get_msg(rep::Reply, i::Integer) = _get_msg(rep, Int(i))
_get_msg(rep::Reply, i::Int) :: Ptr{Byte} =
    (1 ≤ i ≤ length(rep) ? rep.buffers[i + _nmax(rep)*2] : NULL)

# i-th data buffer is at index i.
_get_buf(rep::Reply, i::Integer, preserve::Bool) =
    _get_buf(rep, Int(i), preserve)

function _get_buf(rep::Reply, i::Int, preserve::Bool) :: Tuple{Ptr{Byte},Int}
    local ptr::Ptr{Byte}, len::Int
    if 1 ≤ i ≤ length(rep)
        ptr, len = rep.buffers[i], rep.lengths[i]
        (ptr == NULL ? len == 0 : len ≥ 0) || error("invalid buffer length")
        if ! preserve && ptr != NULL
            rep.lengths[i] = 0
            rep.buffers[i] = NULL
        end
    else
        ptr, len = NULL, 0
    end
    return (ptr, len)
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
_nmax(rep::Reply) = length(rep.lengths)

"""
    XPA.get_server(rep, i=1)

yields the XPA identifier of the server which sent the `i`-th reply in XPA answer `rep`. An
empty string is returned if there is no `i`-th reply.

# See also

[`XPA.get`](@ref) and [`XPA.get_message`](@ref).

"""
get_server(rep::Reply, i::Integer=1) = _string(_get_srv(rep, i))

"""
    XPA.get_message(rep, i=1)

yields the message associated with the `i`-th reply in XPA answer `rep`. An empty string is
returned if there is no `i`-th reply.

# See also

[`XPA.get`](@ref), [`XPA.has_message`](@ref), [`XPA.has_error`](@ref), and
[`XPA.get_server`](@ref).

"""
get_message(rep::Reply, i::Integer=1) = _string(_get_msg(rep, i))

"""
    XPA.has_error(rep, i=1) -> Bool

yields whether `i`-th XPA answer `rep` contains an error message. The error message can be
retrieved by calling `XPA.get_message(rep, i)`.

# See also

[`XPA.get`](@ref), [`XPA.has_message`](@ref), [`XPA.get_message`](@ref).

"""
has_error(rep::Reply, i::Integer=1) =
    _startswith(_get_msg(rep, i), _XPA_ERROR)

const _XPA_ERROR_PREFIX = "XPA\$ERROR "
const _XPA_ERROR = Tuple(map(Byte, collect(_XPA_ERROR_PREFIX)))

function Base.show(io::IO, rep::Reply)
    print(io, "XPA.Reply")
    n = length(rep)
    if n == 0
        print(io, " (no replies)")
    else
        print(io, " (", n, " repl", (n > 1 ? "ies" : "y"), "):\n")
        for i in 1:n
            # Check whether all bytes in the data buffer are printable ASCII
            # characters.
            print(io, "  ", i, ": server = ",
                  repr(get_server(rep, i); context=io), ", message = ",
                  repr(get_message(rep, i); context=io), ", data = ")
            ptr, len = _get_buf(rep, i, true)
            if ptr == C_NULL
                print(io, "NULL")
            elseif len == 0
                print(io, repr("";  context=io))
            else
                cstring = true
                for j in 1:len
                    b = unsafe_load(ptr, j)
                    if (b & 0x80) != 0
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
                    print(io, repr(unsafe_string(ptr, len);  context=io))
                else
                    print(io, len, (len > 1 ? " bytes" : " byte"))
                end
            end
            i < n && print(io, "\n")
        end
    end
end

"""
    XPA.has_errors(rep::Reply) -> Bool

yields whether answer `rep` contains any error messages.

# See also

[`XPA.get`](@ref), [`XPA.has_error`](@ref), and [`XPA.get_message`](@ref).

"""
function has_errors(rep::Reply) :: Bool
    for i in 1:length(rep)
        if has_error(rep, i)
            return true
        end
    end
    return false
end

"""
    XPA.has_message(rep::Reply, i=1) -> Bool

yields whether `i`-th XPA answer `rep` contains an error message.

# See also

[`XPA.get`](@ref) and [`XPA.has_message`](@ref).

"""
has_message(rep::Reply, i::Integer=1) =
    _startswith(_get_msg(rep, i), _XPA_MESSAGE)

const _XPA_MESSAGE_PREFIX = "XPA\$MESSAGE "
const _XPA_MESSAGE = Tuple(map(Byte, collect(_XPA_MESSAGE_PREFIX)))

function _startswith(ptr::Ptr{Byte}, tup::NTuple{N,Byte}) where {N}
    if ptr == NULL
        return false
    end
    for i in 1:N
        if unsafe_load(ptr, i) != tup[i]
            return false
        end
    end
    return true
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
    XPA.get_data([T, [dims,]] rep, i=1; preserve=false)

yields the data associated with the `i`-th reply in XPA answer `rep`. The returned value
depends on the optional leading arguments `T` and `dims`:

* If neither `T` nor `dims` are specified, a vector of bytes (`UInt8`) is returned.

* If only `T` is specified, it can be `String` to return a string interpreting the data as
  ASCII characters or a type like `Vector{S}` to return the largest vector of elements of
  type `S` that can be extracted from the data.

* If both `T` and `dims` are specified, `T` can be an array type like `Array{S}` or
  `Array{S,N}` and `dims` a list of `N` dimensions to retrieve the data as an array of type
  `Array{S,N}`.

Keyword `preserve` can be used to specify whether or not to preserve the internal data
buffer in `rep` for another call to `XPA.get_data`. By default, `preserve=true` when `T =
String` is specified and `preserve=false` otherwise.

In any cases, the type of the result is predictable, so there should be no type instability
issue.

# See also

[`XPA.get`](@ref), [`XPA.get_message`](@ref), and [`XPA.get_server`](@ref).

"""
get_data(rep::Reply, args...; kwds...) =
    get_data(Vector{Byte}, rep, args...; kwds...)

function get_data(::Type{String}, rep::Reply, i::Integer=1;
                  preserve::Bool = true) :: String
    ptr, len = _get_buf(rep, i, preserve)
    ptr == NULL && return ""
    str = unsafe_string(ptr, len)
    preserve || _free(ptr)
    return str
end

function get_data(::Type{Vector{T}}, rep::Reply, i::Integer=1;
                  preserve::Bool = false) :: Vector{T} where {T}
    isbitstype(T) || error("invalid Array element type")
    ptr, len = _get_buf(rep, i, preserve)
    cnt = div(len, sizeof(T))
    if ptr == NULL || cnt ≤ 0
        # Empty vector.
        return T[]
    elseif preserve
        # Make a copy of the buffer in the form of a Julia vector.
        return _memcpy!(Vector{T}(undef, cnt), ptr, cnt*sizeof(T))
    else
        # Transfer ownership of buffer to Julia.
        return unsafe_wrap(Array, Ptr{T}(ptr), cnt, own=true)
    end
end

function get_data(::Type{Array{T}}, dim::Integer,
                  rep::Reply, i::Integer = 1;
                  preserve::Bool = false) :: Vector{T} where {T}
    return _get_buf(Vector{T}, _dimensions(dim), rep, i, preserve)
end

function get_data(::Type{Vector{T}}, dim::Integer,
                  rep::Reply, i::Integer = 1;
                  preserve::Bool = false) :: Vector{T} where {T}
    return _get_buf(Vector{T}, _dimensions(dim), rep, i, preserve)
end

function get_data(::Type{Array{T}}, dims::NTuple{N,Integer},
                  rep::Reply, i::Integer = 1;
                  preserve::Bool = false) :: Array{T,N} where {T,N}
    return _get_buf(Array{T,N}, _dimensions(dims), rep, i, preserve)
end

function get_data(::Type{Array{T,N}}, dims::NTuple{N,Integer},
                  rep::Reply, i::Integer = 1;
                  preserve::Bool = false) :: Array{T,N} where {T,N}
    return _get_buf(Array{T,N}, _dimensions(dims), rep, i, preserve)
end

"""

Private method `_get_buf(rep,i,preserve)` yields `(ptr,len)` the address and length (in
bytes) of internal buffer corresponding to the data for the `i`-th reply in `rep`. If
`preserve` is false, then the internal buffer is set to NULL and the caller is responsible
to free it. If `i` is out of range or if there are no data associated with the `i`-th reply
in `rep`, `(NULL,0)` is returned.

The call:

```julia
_get_buf(::Type{Array{T,N}}, dims::NTuple{N,Int},
         rep::Reply, i::Integer, preserve::Bool)
```

yields the contents of the internal data buffer as a Julia array.

"""
function _get_buf(::Type{Array{T,N}}, dims::NTuple{N,Int},
                  rep::Reply, i::Int, preserve::Bool) :: Array{T,N} where {T,N}
    isbitstype(T) || error("invalid Array element type")
    minimum(dims) ≥ 0 || error("invalid Array dimensions")
    ptr, len = _get_buf(rep, i, preserve)
    cnt = prod(dims)
    cnt*sizeof(T) ≤ len || error("Array size too large for buffer")
    if ptr == NULL || cnt ≤ 0
        # Empty array.
        return Array{T,N}(undef, dims)
    elseif preserve
        # Make a copy of the buffer in the form of a Julia array.
        return _memcpy!(Array{T,N}(undef, dims), ptr, cnt*sizeof(T))
    else
        # Transfer ownership of buffer to Julia.
        return unsafe_wrap(Array, Ptr{T}(ptr), dims, own=true)
    end
end

_dimensions(dim::Integer) = (Int(dim),)
_dimensions(dim::Int) = (dim,)
_dimensions(dims::Tuple{}) = dims
_dimensions(dims::TupleOf{Integer}) = map(Int, dims)
_dimensions(dims::TupleOf{Int}) = dims

# _string(ptr) copies data at address ptr as a string, if ptr is NULL, an empty
# string is returned.
_string(ptr::Ptr{Byte}) = (ptr == NULL ? "" : unsafe_string(ptr))

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

function _set(conn::Client, apt::AbstractString, params::AbstractString,
              mode::AbstractString, data::Union{NullBuffer,DenseArray},
              nmax::Int, throwerrors::Bool,
              users::Union{Nothing,AbstractString})
    lengths = fill!(Memory{Csize_t}(undef, nmax), 0)
    buffers = fill!(Memory{Ptr{Byte}}(undef, nmax*3), Ptr{Byte}(0))
    address = pointer(buffers)
    offset = nmax*sizeof(Ptr{Byte})
    prevusers = _override_nsusers(users)
    replies = GC.@preserve lengths buffers ccall(
        (:XPASet, libxpa), Cint,
        (Client, Cstring, Cstring, Cstring, Ptr{Cvoid},
         Csize_t, Ptr{Ptr{Byte}}, Ptr{Ptr{Byte}}, Cint),
        conn, apt, params, mode, data, sizeof(data),
        address + offset, address + 2*offset, nmax)
    _restore_nsusers(prevusers)
    0 ≤ replies ≤ nmax || error("unexpected number of replies from XPASet")
    rep = finalizer(_free, Reply(replies, lengths, buffers))
    throwerrors && verify(rep; throwerrors=true)
    return rep
end

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
