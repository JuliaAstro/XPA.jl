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

yields a persistent XPA client handle which can be used for calls to `XPA.set`
and XPA.get` methods.  Persistence means that a connection to an XPA server is
not closed when one of the above calls is completed but will be re-used on
successive calls.  Using `XPA.Client()` therefore saves the time it takes to
connect to a server, which could be significant with slow connections or if
there will be a large number of exchanges with a given access point.

See also: [`XPA.set`](@ref), [`XPA.get`](@ref)

"""
function Client()
    # The argument of XPAOpen is currently ignored (it is reserved for future
    # use).
    ptr = ccall((:XPAOpen, libxpa), Ptr{Cvoid}, (Ptr{Cvoid},), C_NULL)
    ptr != C_NULL || error("failed to create a persistent XPA connection")
    return finalizer(close, Client(ptr))
end

Base.isopen(xpa::Handle) = xpa.ptr != C_NULL

function Base.close(xpa::Client)
    if (ptr = xpa.ptr) != C_NULL
        xpa.ptr = C_NULL
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
will be created.  The result is a vector of `XPA.AccessPoint` instances.

Also see: [`XPA.Client`](@ref).

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
XPA.get([T, [dims,]] [xpa,] apt, params...) -> rep
```


FIXME: fix doc.

retrieves data from one or more XPA access points identified by `apt` (a
template name, a `host:port` string or the name of a Unix socket file) with
parameters `params` (automatically converted into a single string where the
parameters are separated by a single space).  The result is a tuple of tuples
`(data,name,mesg)` where `data` is a vector of bytes (`UInt8`), `name` is a
string identifying the server which answered the request and `mesg` is a
textual message (a zero-length string `""` if there are no messages).  Optional
argument `xpa` specifies an XPA handle (created by [`XPA.Client`](@ref)) for
faster connections.

The following keywords are available:

* `nmax` specifies the maximum number of answers, `nmax=1` by default.
  Specify `nmax=-1` to use the maximum number of XPA hosts.

* `check` specifies whether to check for errors.  If this keyword is set true,
  an error is thrown for the first error message encountered in the list of
  answers.  By default, `check` is false.

* `mode` specifies options in the form `"key1=value1,key2=value2"`.

See also: [`XPA.Client`](@ref), [`XPA.set`](@ref).

"""
function get(xpa::Client, apt::AbstractString, params::AbstractString...;
             # FIXME: params can have values not just strings, the only
             #        constraint could be to start with a string.
             mode::AbstractString = "",
             nmax::Integer = 1,
             check::Bool = false)
    return _get(xpa, apt, _join(params), mode, _nmax(nmax), check)
end

get(args::AbstractString...; kwds...) =
    get(TEMPORARY, args...; kwds...)

function get(::Type{Vector{T}},
             args...; kwds...) :: Vector{T} where {T}
    get_data(Vector{T}, get(args...; nmax = 1, check = true, kwds...))
end

function get(::Type{Vector{T}}, dim::Integer,
             args...; kwds...) :: Vector{T} where {T}
    get_data(Vector{T}, dim, get(args...; nmax = 1, check = true, kwds...))
end

function get(::Type{Array{T}}, dims::NTuple{N,Integer},
             args...; kwds...) :: Array{T,N} where {T,N}
    get_data(Array{T,N}, dims, get(args...; nmax = 1, check = true, kwds...))
end

function get(::Type{Array{T,N}}, dims::NTuple{N,Integer},
             args...; kwds...) :: Array{T,N} where {T,N}
    get_data(Array{T,N}, dims, get(args...; nmax = 1, check = true, kwds...))
end

function get(::Type{String}, args...; kwds...)
    return get_data(String, get(args...; nmax = 1, kwds...))
end

function _get(xpa::Client, apt::AbstractString, params::AbstractString,
              mode::AbstractString, nmax::Int, check::Bool)
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
    if check
        for i in 1:replies
            if has_error(rep, i)
                error(get_message(rep, i))
            end
        end
    end
    return rep
end

function _free(rep::Reply)
    nmax = _nmax(rep)
    for i in 0:2, j in 1:rep.replies
        k = i*nmax + j
        if i == 0
            rep.lengths[k] = 0
        end
        if (ptr = rep.buffers[k]) != NULL
            rep.buffers[k] = NULL
            _free(ptr)
        end
    end
end

_checked_index(rep::Reply, i::Integer) = _checked_index(rep, Int(i))
_checked_index(rep::Reply, i::Int) =
    (1 ≤ i ≤ rep.replies ? i : error("out of range reply index"))

_buf_index(rep::Reply, i::Integer) = _checked_index(rep, i)
_srv_index(rep::Reply, i::Integer) = _checked_index(rep, i) + _nmax(rep)
_msg_index(rep::Reply, i::Integer) = _checked_index(rep, i) + _nmax(rep)*2

"""

Private method `_join(tup)` joins a tuple of string into a single string.
It is implemented so as to be faster than `join(tup, " ")` when `tup` has
less than 2 arguments.  It is intended to build XPA command string from
arguments.

"""
_join(args::TupleOf{Union{AbstractString,Real}}) = join(args, " ")
_join(args::Tuple{Union{AbstractString,Real}}) = args[1]
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
answer `rep`.

See also [`XPA.get](@ref), [`XPA.get_message](@ref).

"""
get_server(rep::Reply, i::Integer=1) :: String =
    _copy(String, rep.buffers[_srv_index(rep, i)])

"""
```julia
get_message(rep, i=1)
```

yields the message associated with the `i`-th reply in XPA answer `rep`.

See also [`XPA.get](@ref), [`XPA.has_message](@ref), [`XPA.has_error](@ref),
[`XPA.get_server](@ref).

"""
get_message(rep::Reply, i::Integer=1) :: String =
    _copy(String, rep.buffers[_msg_index(rep, i)])

"""
```julia
XPA.has_error(rep, i=1) -> boolean
```

yields whether `i`-th XPA answer `rep` contains an error message.  The error
message can be retrieved by calling `XPA.get_message(rep, i)`.

See also [`XPA.get](@ref), [`XPA.has_message](@ref), [`XPA.get_message](@ref).

"""
has_error(rep::Reply, i::Integer=1) :: Bool =
    _is_same(rep.buffers[_msg_index(rep, i)], _XPA_ERROR)

const _XPA_ERROR = map(Byte, Tuple(collect("XPA\$ERROR")))
# Note: Tuple(map(UInt8, collect(s))) is ~7 times faster than
#       map(UInt8, Tuple(collect(s)))

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

See also [`XPA.get](@ref), [`XPA.has_message](@ref).

"""
has_message(rep::Reply, i::Integer=1) :: Bool =
    _is_same(rep.buffers[_msg_index(rep, i)], _XPA_MESSAGE)

const _XPA_MESSAGE = map(Byte, Tuple(collect("XPA\$MESSAGE")))

function _is_same(ptr::Ptr{Byte}, tup::NTuple{N,Byte}) where {N}
    if ptr == NULL
        return false
    end
    for i in 1:N
        if unsafe_load(ptr, i) != tup[i]
            return false
        end
    end
    return unsafe_load(ptr, N + 1) == zero(Byte)
end

"""
```julia
get_data([T, [dims,]] rep, i=1; preserve=false)
```

yields the data associated with the `i`-th reply in XPA answer `rep`.  The
returned value depends on the optional leading arguments `T` and `dims`:

* If neither `T` nor `dims` are specified, a vector of bytes (`UInt8`) is
  returned.

* If only `T` is specified, it can be `String` to return a string or
  a bits type to return a vector `Vector{T}`.

* If both `T` and `dims` are specified, `T` can be an array type like
  `Array{S}` or `Array{S,N}` and `dims` a list of `N` dimensions
  to retrieve the data as an array of type `Array{S,N}`.

Keyword `preserve` can be used to specifiy whether or not to preserve the
internal data buffer in `rep` for another call to `XPA.get_data`.  By default,
`preserve=true` when `T = String` is specified and `preserve=false` otherwise.

In any cases, the type of the result is predictible, so there should be no type
instability issue.

See also [`XPA.get](@ref), [`XPA.get_message](@ref), [`XPA.get_server](@ref).

"""
get_data(rep::Reply, args...; kwds...) =
    get_data(Vector{Byte}, rep, args...; kwds...)

# FIXME: implement
#   get_data(Vector{AbstractString}, rep, ...) to split in words

function get_data(::Type{String}, rep::Reply, i::Integer=1;
                  preserve::Bool = true) :: String
    ptr, len = _get_data(rep, i, preserve)
    ptr == NULL && return ""
    str = unsafe_string(ptr, len)
    preserve || _free(ptr)
    return str
end

function get_data(::Type{Vector{T}}, rep::Reply, i::Integer=1;
                  preserve::Bool = false) :: Vector{T} where {T}
    isbitstype(T) || error("invalid Array element type")
    ptr, len = _get_data(rep, i, preserve)
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

function get_data(::Type{Array{T}}, dims::Integer,
                  rep::Reply, i::Integer = 1;
                  preserve::Bool = false) :: Vector{T} where {T}
    return _get_data(Vector{T}, _dimensions(dims), rep, i, preserve)
end

function get_data(::Type{Vector{T}}, dims::Integer,
                  rep::Reply, i::Integer = 1;
                  preserve::Bool = false) :: Vector{T} where {T}
    return _get_data(Vector{T}, _dimensions(dims), rep, i, preserve)
end

function get_data(::Type{Array{T}}, dims::NTuple{N,Integer},
                  rep::Reply, i::Integer = 1;
                  preserve::Bool = false) :: Array{T,N} where {T,N}
    return _get_data(Array{T,N}, _dimensions(dims), rep, i, preserve)
end

function get_data(::Type{Array{T,N}}, dims::NTuple{N,Integer},
                  rep::Reply, i::Integer = 1;
                  preserve::Bool = false) :: Array{T,N} where {T,N}
    return _get_data(Array{T,N}, _dimensions(dims), rep, i, preserve)
end

"""

Private method `_get_data(rep,i,preserve)` yields `(ptr,len)` the address and
length (in bytes) of internal buffer corresponding to the data for the `i`-th
reply in `rep`.  If `preserve` is false, then the internal buffer is set to
NULL and the caller is reponsible to free it.

The call:

```julia
_get_data(::Type{Array{T,N}}, dims::NTuple{N,Int},
          rep::Reply, i::Integer, preserve::Bool)
```

yields the contents of the internal data buffer as a Julia array.

"""
function _get_data(rep::Reply, i::Integer, preserve::Bool)
    j = _buf_index(rep, i)
    ptr, len = rep.buffers[j], rep.lengths[j]
    (ptr == NULL ? len == 0 : len ≥ 0) || error("invalid buffer length")
    if ! preserve && ptr != NULL
        rep.lengths[j] = 0
        rep.buffers[j] = NULL
    end
    return (ptr, len)
end

function _get_data(::Type{Array{T,N}}, dims::NTuple{N,Int},
                  rep::Reply, i::Int, preserve::Bool) :: Array{T,N} where {T,N}
    isbitstype(T) || error("invalid Array element type")
    minimum(dims) ≥ 0 || error("invalid Array dimensions")
    ptr, len = _get_data(rep, i, preserve)
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

# _copy(what, ptr [, nbytes]) copies data at address ptr in the form
# specified by what: String, Vector{T}, or, Array{N,T}, dims.
#
# Compared to _pop, the buffer at address ptr is not managed by Julia and left
# untouched.

_copy(::Type{String}, ptr::Ptr{Byte}) =
    (ptr == NULL ? "" : unsafe_string(ptr))

_copy(::Type{String}, ptr::Ptr{Byte}, nbytes::Integer) =
    (ptr == NULL ? "" : unsafe_string(ptr, nbytes))

"""
```julia
XPA.set([xpa,] apt, params...; data=nothing) -> rep
```

# FIXME: fix doc.

sends `data` to one or more XPA access points identified by `apt` with
parameters `params` (automatically converted into a single string where the
parameters are separated by a single space).  The result is a tuple of tuples
`(name,mesg)` where `name` is a string identifying the server which received
the request and `mesg` is an error message (a zero-length string `""` if there
are no errors).  Optional argument `xpa` specifies an XPA handle (created by
[`XPA.Client`](@ref)) for faster connections.

The following keywords are available:

* `data` specifies the data to send, may be `nothing`, an array or a string.
  If it is an array, it must be an instance of a sub-type of `DenseArray` which
  implements the `pointer` and `sizeof` methods.

* `nmax` specifies the maximum number of recipients, `nmax=1` by default.
  Specify `nmax=-1` to use the maximum possible number of XPA hosts.

* `mode` specifies options in the form `"key1=value1,key2=value2"`.

* `check` specifies whether to check for errors.  If this keyword is set true,
  an error is thrown for the first error message encountered in the list of
  answers.  By default, `check` is false.

See also: [`XPA.Client`](@ref), [`XPA.get`](@ref).

"""
function set(xpa::Client, apt::AbstractString, params::AbstractString...;
             data = nothing,
             mode::AbstractString = "",
             nmax::Integer = 1,
             check::Bool = false)
    return _set(xpa, apt, _join(params), mode, buffer(data), _nmax(nmax), check)
end

set(args::AbstractString...; kwds...) =
    set(TEMPORARY, args...; kwds...)

function _set(xpa::Client, apt::AbstractString, params::AbstractString,
              mode::AbstractString, data::Union{NullBuffer,DenseArray},
              nmax::Int, check::Bool)

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
    if check
        for i in 1:replies
            if has_error(rep, i)
                error(get_message(rep, i))
            end
        end
    end
    return rep
end

"""
```julia
buf = buffer(data)
```

yields an object `buf` representing the contents of `data` and which can be
used as an argument to [`ccall`](@ref) without the risk of having the data
garbage collected.  Argument `data` can be [`nothing`](@ref), a dense array or
a string.  If `data` is an array `buf` is just an alias for `data`.  If `data`
is a string, `buf` is a temporary byte buffer where the string has been copied.

Standard methods [`pointer`](@ref) and [`sizeof`](@ref) can be applied to `buf`
to retieve the address and the size (in bytes) of the data and
`convert(Ptr{Cvoid},buf)` can also be used.

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
