#
# client.jl --
#
# Implement XPA client methods.
#
#------------------------------------------------------------------------------
#
# This file is part of XPA.jl released under the MIT "expat" license.
# Copyright (C) 2016-2019, Éric Thiébaut (https://github.com/emmt/XPA.jl).
#

"""

`XPA.TEMPORARY` can be specified wherever an `XPA.Client` instance is expected
to use a non-persistent XPA connection.

"""
const TEMPORARY = Client(C_NULL)

"""
```julia
XPA.Client()
```

yields a persistent XPA client handle which can be used for calls to
[`XPA.set`](@ref) and [`XPA.get`](@ref) methods.  Persistence means that a
connection to an XPA server is not closed when one of the above calls is
completed but will be re-used on successive calls.  Using `XPA.Client()`
therefore saves the time it takes to connect to a server, which could be
significant with slow connections or if there will be a large number of
exchanges with a given access point.

See also [`XPA.set`](@ref), [`XPA.get`](@ref), [`XPA.list`](@ref) and
[`XPA.find`](@ref).

"""
function Client()
    # The argument of XPAOpen is currently ignored (it is reserved for future
    # use).
    ptr = ccall((:XPAOpen, libxpa), Ptr{Cvoid}, (Ptr{Cvoid},), C_NULL)
    ptr != C_NULL || error("failed to create a persistent XPA connection")
    return finalizer(close, Client(ptr))
end

function Base.close(xpa::Client)
    if (ptr = xpa.ptr) != C_NULL
        xpa.ptr = C_NULL # avoid closing more than once!
        ccall((:XPAClose, libxpa), Cvoid, (Ptr{Cvoid},), ptr)
    end
    return nothing
end

"""
```julia
XPA.list(xpa=XPA.TEMPORARY)
```

yields a list of available XPA access points.  Optional argument `xpa` is a
persistent XPA client connection; if omitted, a temporary client connection
will be created.  The result is a vector of [`XPA.AccessPoint`](@ref)
instances.

See also [`XPA.Client`](@ref) and [`XPA.find`](@ref).

"""
function list(xpa::Client = TEMPORARY)
    lst = AccessPoint[]
    for str in split(chomp(get(String, xpa, "xpans")), r"\n|\r\n?";
                     keepempty=false)
        arr = split(str; keepempty=false)
        if length(arr) != 5
            @warn "expecting 5 fields per access point (\"$str\")"
            continue
        end
        access = UInt(0)
        for c in arr[3]
            if c == 'g'
                access |= GET
            elseif c == 's'
                access |= SET
            elseif c == 'i'
                access |= INFO
            else
                @warn "unexpected access string (\"$(arr[3])\")"
                continue
            end
        end
        push!(lst, AccessPoint(arr[1], arr[2], arr[4], arr[5], access))
    end
    return lst
end

"""
```julia
XPA.find([xpa=XPA.TEMPORARY,] ident)
```

yields the address of the first XPA server matching `ident` or `nothing` if
none is found.  If more than one match occurs, the first match is returned.

Argument `ident` may be a regular expression or a string of the
form `CLASS:NAME` where `CLASS` and `CLASS` are matched against the server
class and name respectively (they may be `"*"` to match any).

Keyword `user` may be used to specify another name than `ENV["user"]` for the
owner of the server process.  Set `user=nothing` or `user="*"` to match any
users.

Keyword `throwerrors` may be set true (it is false by default) to automatically
throw an exception if no match is found (instead of returning `nothing`).

See also [`XPA.Client`](@ref) and [`XPA.list`](@ref).

"""
find(ident::Union{AbstractString,Regex}; kwds...)::Union{String,Nothing} =
    find(TEMPORARY, ident; kwds...)

function find(xpa::Client,
              ident::AbstractString;
              user::Union{AbstractString,Nothing} = ENV["USER"],
              throwerrors::Bool = false)::Union{String,Nothing}
    i = findfirst(isequal(':'), ident)
    class = ident[1:i-1]
    name = ident[i+1:end]
    anyuser = (user === nothing || user == "*")
    anyclass = (class == "*")
    anyname = (name == "*")
    lst = list(xpa)
    for j in eachindex(lst)
        if ((anyuser || lst[j].user == user) &&
            (anyclass || lst[j].class == class) &&
            (anyname || lst[j].name == name))
            return lst[j].addr
        end
    end
    throwerrors && error(_noserversmatch(ident))
    return nothing
end

function find(xpa::Client,
              ident::Regex;
              user::Union{AbstractString,Nothing} = ENV["USER"],
              throwerrors::Bool = false)::Union{String,Nothing}
    anyuser = (user === nothing || user == "*")
    lst = list(xpa)
    for j in eachindex(lst)
        if ((anyuser || lst[j].user == user) &&
            occursin(ident, lst[j].class*":"*lst[j].name))
            return lst[j].addr
        end
    end
    throwerrors && error(_noserversmatch(ident))
    return nothing
end

@noinline _noserversmatch(ident::AbstractString) =
    "no XPA servers match pattern \"$(ident)\""

@noinline _noserversmatch(ident::Regex) =
    "no XPA servers match regular expression \"$(ident.pattern)\""

"""
```julia
XPA.get([T, [dims,]] [xpa,] apt, args...)
```

retrieves data from one or more XPA access points identified by `apt` (a
template name, a `host:port` string or the name of a Unix socket file) with
arguments `args...` (automatically converted into a single string where the
arguments are separated by a single space).  Optional argument `xpa` specifies
an XPA handle (created by [`XPA.Client`](@ref)) for faster connections.  The
returned value depends on the optional arguments `T` and `dims`.

If neither `T` nor `dims` are specified, an instance of [`XPA.Reply`](@ref) is
returned with all the answer(s) from the XPA server(s).  The following keywords
are available:

* Keyword `nmax` specifies the maximum number of answers, `nmax=1` by default.
  Specify `nmax=-1` to use the maximum number of XPA hosts.

* Keyword `throwerrors` specifies whether to check for errors.  If this keyword
  is set true, an exception is thrown for the first error message encountered
  in the list of answers.  By default, `throwerrors` is false.

* Keyword `mode` specifies options in the form `"key1=value1,key2=value2"`.

If `T` and, possibly, `dims` are specified, a single answer and no errors are
expected (as if `nmax=1` and `throwerrors=true`) and the data part of the
answer is converted according to `T` which must be a type and `dims` which is
an optional list of dimensions:

* If only `T` is specified, it can be `String` to return a string interpreting
  the data as ASCII characters or a type like `Vector{S}` to return the largest
  vector of elements of type `S` that can be extracted from the returned data.

* If both `T` and `dims` are specified, `T` can be a type like `Array{S}` or
  `Array{S,N}` and `dims` a list of `N` dimensions to retrieve the data as an
  array of type `Array{S,N}`.

See also [`XPA.Client`](@ref), [`XPA.get_data`](@ref), [`XPA.set`](@ref) and
[`XPA.verify`](@ref).

"""
function get(xpa::Client,
             apt::AbstractString,
             cmd::AbstractString;
             mode::AbstractString = "",
             nmax::Integer = 1,
             throwerrors::Bool = false)
    return _get(xpa, apt, cmd, mode, _nmax(nmax), throwerrors)
end

function get(xpa::Client,
             apt::AbstractString,
             args::Union{AbstractString,Real}...;
             kwds...)
    return get(xpa, apt, _join(args); kwds...)
end

get(apt::AbstractString, args::Union{AbstractString,Real}...; kwds...) =
    get(TEMPORARY, apt, _join(args); kwds...)

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
             args...; kwds...) :: Array{T,N} where {T,N}
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

function _get(xpa::Client, apt::AbstractString, params::AbstractString,
              mode::AbstractString, nmax::Int, throwerrors::Bool)
    lengths = fill!(Vector{Csize_t}(undef, nmax), 0)
    buffers = fill!(Vector{Ptr{Byte}}(undef, nmax*3), Ptr{Byte}(0))
    address = pointer(buffers)
    offset = nmax*sizeof(Ptr{Byte})
    replies = ccall((:XPAGet, libxpa), Cint,
                    (Client, Cstring, Cstring, Cstring, Ptr{Ptr{Byte}},
                     Ptr{Csize_t}, Ptr{Ptr{Byte}}, Ptr{Ptr{Byte}}, Cint),
                    xpa, apt, params, mode, address, lengths,
                    address + offset, address + 2*offset, nmax)
    0 ≤ replies ≤ nmax || error("unexpected number of replies from XPAGet")
    rep = finalizer(_free, Reply(replies, lengths, buffers))
    throwerrors && verify(rep; throwerrors=true)
    return rep
end

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

Private method `_join(tup)` joins a tuple of strings or reals into a single
string.  It is implemented so as to be faster than `join(tup, " ")` when `tup`
has less than 2 arguments.  It is intended to build XPA command string from
arguments.

"""
_join(args::TupleOf{Union{AbstractString,Real}}) = join(args, " ")
_join(args::Tuple{AbstractString}) = args[1]
_join(args::Tuple{Real}) = string(args[1])
_join(::Tuple{}) = ""

"""

Private method `_nmax(n::Integer)` yields the maximum number of expected
answers to a get/set request.  The result is `n` if `n ≥ 1` or
`getconfig("XPA_MAXHOSTS")` otherwise.  The call `_nmax(rep::Reply)` yields
the maximum number of answer that can be stored in `rep`.

"""
_nmax(n::Integer) = (n == -1 ? Int(getconfig("XPA_MAXHOSTS")) : Int(n))
_nmax(rep::Reply) = length(rep.lengths)


"""
```julia
get_server(rep, i=1)
```

yields the XPA identifier of the server which sent the `i`-th reply in XPA
answer `rep`.  An empty string is returned if there is no `i`-th reply.

See also [`XPA.get`](@ref), [`XPA.get_message`](@ref).

"""
get_server(rep::Reply, i::Integer=1) = _string(_get_srv(rep, i))

"""
```julia
get_message(rep, i=1)
```

yields the message associated with the `i`-th reply in XPA answer `rep`.  An
empty string is returned if there is no `i`-th reply.

See also [`XPA.get`](@ref), [`XPA.has_message`](@ref), [`XPA.has_error`](@ref),
[`XPA.get_server`](@ref).

"""
get_message(rep::Reply, i::Integer=1) = _string(_get_msg(rep, i))

"""
```julia
XPA.has_error(rep, i=1) -> boolean
```

yields whether `i`-th XPA answer `rep` contains an error message.  The error
message can be retrieved by calling `XPA.get_message(rep, i)`.

See also [`XPA.get`](@ref), [`XPA.has_message`](@ref),
[`XPA.get_message`](@ref).

"""
has_error(rep::Reply, i::Integer=1) =
    _startswith(_get_msg(rep, i), _XPA_ERROR)

const _XPA_ERROR_PREFIX = "XPA\$ERROR "
const _XPA_ERROR = Tuple(map(Byte, collect(_XPA_ERROR_PREFIX)))

"""
```julia
XPA.has_errors(rep) -> boolean
```

yields whether answer `rep` contains any error messages.

See also [`XPA.get`](@ref), [`XPA.has_error`](@ref), [`XPA.get_message`](@ref).

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
```julia
XPA.has_message(rep, i=1) -> boolean
```

yields whether `i`-th XPA answer `rep` contains an error message.

See also [`XPA.get`](@ref), [`XPA.has_message`](@ref).

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

```julia
verify(rep [, i]; throwerrors::Bool=false) -> boolean
```

verifies whether answer(s) in the result `rep` from an [`XPA.get`](@ref) or
[`XPA.set`](@ref) request has no errors.  If index `i` is specified only that
specific answer is considered; otherwise, all answers are verified.  If keyword
`throwerrors` is true, an exception is thrown for the first error found if any.

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
```julia
get_data([T, [dims,]] rep, i=1; preserve=false)
```

yields the data associated with the `i`-th reply in XPA answer `rep`.  The
returned value depends on the optional leading arguments `T` and `dims`:

* If neither `T` nor `dims` are specified, a vector of bytes (`UInt8`) is
  returned.

* If only `T` is specified, it can be `String` to return a string interpreting
  the data as ASCII characters or a type like `Vector{S}` to return the largest
  vector of elements of type `S` that can be extracted from the data.

* If both `T` and `dims` are specified, `T` can be an array type like
  `Array{S}` or `Array{S,N}` and `dims` a list of `N` dimensions to retrieve
  the data as an array of type `Array{S,N}`.

Keyword `preserve` can be used to specifiy whether or not to preserve the
internal data buffer in `rep` for another call to `XPA.get_data`.  By default,
`preserve=true` when `T = String` is specified and `preserve=false` otherwise.

In any cases, the type of the result is predictible, so there should be no type
instability issue.

See also [`XPA.get`](@ref), [`XPA.get_message`](@ref),
[`XPA.get_server`](@ref).

"""
get_data(rep::Reply, args...; kwds...) =
    get_data(Vector{Byte}, rep, args...; kwds...)

# FIXME: implement
#   get_data(Vector{String}, rep, ...) to split in words

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

Private method `_get_buf(rep,i,preserve)` yields `(ptr,len)` the address and
length (in bytes) of internal buffer corresponding to the data for the `i`-th
reply in `rep`.  If `preserve` is false, then the internal buffer is set to
NULL and the caller is responsible to free it.  If `i` is out of range or if
there are no data associated with the `i`-th reply in `rep`, `(NULL,0)` is
returned.

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
```julia
XPA.set([xpa,] apt, args...; data=nothing) -> rep
```

sends `data` to one or more XPA access points identified by `apt` with
arguments `args...` (automatically converted into a single string where the
arguments are separated by a single space).  The result is an instance of
[`XPA.Reply`](@ref).  Optional argument `xpa` specifies an XPA handle (created
by [`XPA.Client`](@ref)) for faster connections.

The following keywords are available:

* `data` specifies the data to send, may be `nothing`, an array or a string.
  If it is an array, it must have contiguous elements (as a for a *dense*
  array) and must implement the `pointer` method.

* `nmax` specifies the maximum number of recipients, `nmax=1` by default.
  Specify `nmax=-1` to use the maximum possible number of XPA hosts.

* `mode` specifies options in the form `"key1=value1,key2=value2"`.

* `throwerrors` specifies whether to check for errors.  If this keyword is set
  `true`, an exception is thrown for the first error message encountered in the
  list of answers.  By default, `throwerrors` is false.

See also [`XPA.Client`](@ref), [`XPA.get`](@ref) and [`XPA.verify`](@ref).

"""
function set(xpa::Client,
             apt::AbstractString,
             cmd::AbstractString;
             data = nothing,
             mode::AbstractString = "",
             nmax::Integer = 1,
             throwerrors::Bool = false)
    return _set(xpa, apt, cmd, mode, buffer(data), _nmax(nmax), throwerrors)
end

function set(xpa::Client,
             apt::AbstractString,
             args::Union{AbstractString,Real}...;
             kwds...)
    return _set(xpa, apt, _join(args); kwds...)
end

set(apt::AbstractString, args::Union{AbstractString,Real}...; kwds...) =
    set(TEMPORARY, apt, _join(args); kwds...)

function _set(xpa::Client, apt::AbstractString, params::AbstractString,
              mode::AbstractString, data::Union{NullBuffer,DenseArray},
              nmax::Int, throwerrors::Bool)

    lengths = fill!(Vector{Csize_t}(undef, nmax), 0)
    buffers = fill!(Vector{Ptr{Byte}}(undef, nmax*3), Ptr{Byte}(0))
    address = pointer(buffers)
    offset = nmax*sizeof(Ptr{Byte})
    replies = ccall((:XPASet, libxpa), Cint,
              (Client, Cstring, Cstring, Cstring, Ptr{Cvoid},
               Csize_t, Ptr{Ptr{Byte}}, Ptr{Ptr{Byte}}, Cint),
              xpa, apt, params, mode, data, sizeof(data),
              address + offset, address + 2*offset, nmax)
    0 ≤ replies ≤ nmax || error("unexpected number of replies from XPASet")
    rep = finalizer(_free, Reply(replies, lengths, buffers))
    throwerrors && verify(rep; throwerrors=true)
    return rep
end

"""
```julia
buf = buffer(data)
```

yields an object `buf` representing the contents of `data` and which can be
used as an argument to `ccall` without the risk of having the data garbage
collected.  Argument `data` can be `nothing`, a dense array or a string.  If
`data` is an array `buf` is just an alias for `data`.  If `data` is a string,
`buf` is a temporary byte buffer where the string has been copied.

Standard methods `pointer` and `sizeof` can be applied to `buf` to retieve the
address and the size (in bytes) of the data and `convert(Ptr{Cvoid},buf)` can
also be used.

See also [`XPA.set`](@ref).

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
