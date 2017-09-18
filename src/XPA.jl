#
# XPA.jl --
#
# Implement XPA communication via the dynamic library.
#
#------------------------------------------------------------------------------
#
# This file is part of DS9.jl released under the MIT "expat" license.
# Copyright (C) 2016, Éric Thiébaut (https://github.com/emmt).
#
module XPA

export xpa_list,
       xpa_open,
       xpa_get,
       xpa_get_bytes,
       xpa_get_text,
       xpa_get_lines,
       xpa_get_words,
       xpa_set,
       xpa_config

const libxpa = "libxpa."*Libdl.dlext

const GET = UInt(1)
const SET = UInt(2)
const INFO = UInt(4)

struct AccessPoint
    class::String # class of the access point
    name::String  # name of the access point
    addr::String  # socket access method (host:port for inet,
                  # file for local/unix)
    user::String  # user name of access point owner
    access::UInt  # allowed access
end

# Must be mutable to be finalized.
mutable struct Handle
    _ptr::Ptr{Void}
end

const NullHandle = Handle(C_NULL)

function xpa_open()
    # The argument of XPAOpen is currently ignored (it is reserved for future
    # use).
    ptr = ccall((:XPAOpen, libxpa), Ptr{Void}, (Ptr{Void},), C_NULL)
    if ptr == C_NULL
        error("failed to allocate a persistent XPA connection")
    end
    obj = Handle(ptr)
    finalizer(obj, xpa_close)
    return obj
end

function xpa_close(xpa::Handle)
    if xpa._ptr != C_NULL
        temp = xpa._ptr
        xpa._ptr = C_NULL
        ccall((:XPAClose, libxpa), Void, (Ptr{Void},), temp)
    end
end

function xpa_list(xpa::Handle = NullHandle)
    lst = Array{AccessPoint}(0)
    for str in xpa_get_lines(xpa, "xpans")
        arr = split(str)
        if length(arr) != 5
            warn("expecting 5 fields per access point (\"$str\")")
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
                warn("unexpected access string (\"$(arr[3])\")")
                continue
            end
        end
        push!(lst, AccessPoint(arr[1], arr[2], arr[4], arr[5], access))
    end
    return lst
end

"""

Private method `_fetch(...)` converts a pointer into a Julia vector or a
string and let Julia manage the memory.

"""
_fetch(ptr::Ptr{T}, nbytes::Integer) where T =
    ptr == C_NULL ? Array{T}(0) :
    unsafe_wrap(Array, ptr, div(nbytes, sizeof(T)), true)

_fetch(::Type{T}, ptr::Ptr, nbytes::Integer) where T =
    _fetch(convert(Ptr{T}, ptr), nbytes)

_fetch(ptr::Ptr{Void}, nbytes::Integer) = _fetch(UInt8, ptr, nbytes)

function _fetch(::Type{String}, ptr::Ptr{UInt8})
    if ptr == C_NULL
        str = ""
    else
        str = unsafe_string(ptr)
        _free(ptr)
    end
    return str
end

_free(ptr::Ptr) = (ptr != C_NULL && ccall(:free, Void, (Ptr{Void},), ptr))

doc"""
    xpa_get([xpa,] apt [, params...]) -> tup

retrieves data from one or more XPA access points identified by `apt` (a
template name, a `host:port` string or the name of a Unix socket file) with
parameters `params` (automatically converted into a single string where the
parameters are separated by a single space).  The result is a tuple of tuples
`(data,name,mesg)` where `data` is a vector of bytes (`UInt8`), `name` is a
string identifying the server which answered the request and `mesg` is an error
message (a zero-length string `""` if there are no errors).  Argument `xpa`
specifies an XPA handle (created by `xpa_open`) for faster connections.

The following keywords are available:

* `nmax` specifies the maximum number of answers, `nmax=1` by default.
  Specify `nmax=-1` to use the maximum number of XPA hosts.

* `mode` specifies options in the form `"key1=value1,key2=value2"`.

See also: [@ref](`xpa_open`), [@ref](`xpa_set`).
"""
function xpa_get(xpa::Handle, apt::AbstractString, params::AbstractString...;
                 mode::AbstractString = "", nmax::Integer = 1)
    if nmax == -1
        nmax = xpa_config("XPA_MAXHOSTS")
    end
    bufs = Array{Ptr{UInt8}}(nmax)
    lens = Array{Csize_t}(nmax)
    names = Array{Ptr{UInt8}}(nmax)
    errs = Array{Ptr{UInt8}}(nmax)
    n = ccall((:XPAGet, libxpa), Cint,
              (Ptr{Void}, Cstring, Cstring, Cstring, Ptr{Ptr{UInt8}},
               Ptr{Csize_t}, Ptr{Ptr{UInt8}}, Ptr{Ptr{UInt8}}, Cint),
              xpa._ptr, apt, join(params, " "), mode,
              bufs, lens, names, errs, nmax)
    n ≥ 0 || error("unexpected result from XPAGet")
    return ntuple(i -> (_fetch(bufs[i], lens[i]),
                        _fetch(String, names[i]),
                        _fetch(String, errs[i])), n)
end

xpa_get(args::AbstractString...; kwds...) =
    xpa_get(NullHandle, args...; kwds...)

doc"""
    xpa_get_bytes([xpa,] apt [, params...]; mode=...) -> buf

yields the `data` part of the answers received by an `xpa_get` request as a
vector of bytes.  Arguments `xpa`, `apt` and `params...` and keyword `mode` are
passed to `xpa_get` limiting the number of answers to be at most one.  An error
is thrown if `xpa_get` returns a non-empty error message.

See also: [@ref](`xpa_get`).
"""
function xpa_get_bytes(args...; kwds...)
    tup = xpa_get(args...; nmax=1, kwds...)
    local data::Vector{UInt8}
    if length(tup) ≥ 1
        (data, name, mesg) = tup[1]
        length(mesg) > 0 && error(mesg)
    else
        data = Array{UInt8}(0)
    end
    return data
end


doc"""
    xpa_get_text([xpa,] apt [, params...]; mode=...) -> str

converts the result of `xpa_get_bytes` into a single string.

See also: [@ref](`xpa_get_bytes`).
"""
xpa_get_text(args...; kwds...) =
    unsafe_string(pointer(xpa_get_bytes(args...; kwds...)))

doc"""
    xpa_get_lines([xpa,] apt [, params...]; keep=false, mode=...) -> arr

splits the result of `xpa_get_text` into an array of strings, one for each
line.  Keyword `keep` can be set `true` to keep empty lines.

See also: [@ref](`xpa_get_text`).
"""
xpa_get_lines(args...; keep::Bool = false, kwds...) =
    split(chomp(xpa_get_text(args...; kwds...)), r"\n|\r\n?", keep=keep)

doc"""
    xpa_get_words([xpa,] apt [, params...]; mode=...) -> arr

splits the result of `xpa_get_text` into an array of words.

See also: [@ref](`xpa_get_text`).
"""
xpa_get_words(args...; kwds...) =
    split(xpa_get_text(args...; kwds...), r"[ \t\n\r]+", keep=false)

doc"""
    xpa_set([xpa,] apt [, params...]; data=nothing) -> tup

sends `data` to one or more XPA access points identified by `apt` with
parameters `params` (automatically converted into a single string where the
parameters are separated by a single space).  The result is a tuple of tuples
`(name,mesg)` where `name` is a string identifying the server which received
the request and `mesg` is an error message (a zero-length string `""` if there
are no errors).  Argument `xpa` specifies an XPA handle (created by `xpa_open`)
for faster connections.

The following keywords are available:

* `data` the data to send, may be `nothing` or an array.  If it is an array, it
  must be an instance of a sub-type of `DenseArray` which implements the
  `pointer` method.

* `nmax` specifies the maximum number of answers, `nmax=1` by default.
  Specify `nmax=-1` to use the maximum number of XPA hosts.

* `mode` specifies options in the form `"key1=value1,key2=value2"`.

* `check` specifies whether to check for errors.  If this keyword is set true,
  an error is thrown for the first non-empty error message `mesg` encountered
  in the list of answers.

See also: [@ref](`xpa_open`), [@ref](`xpa_get`).
"""
function xpa_set(xpa::Handle, apt::AbstractString, params::AbstractString...;
                 data::Union{DenseArray,Void} = nothing,
                 mode::AbstractString = "",
                 nmax::Integer = 1,
                 check::Bool = false)
    local buf::Ptr, len::Int
    if isa(data, Void)
        buf = C_NULL
        len = 0
    else
        @assert isbits(eltype(data))
        buf = pointer(data)
        len = sizeof(data)
    end
    if nmax == -1
        nmax = xpa_config("XPA_MAXHOSTS")
    end
    names = Array{Ptr{UInt8}}(nmax)
    errs = Array{Ptr{UInt8}}(nmax)
    n = ccall((:XPASet, libxpa), Cint,
              (Ptr{Void}, Cstring, Cstring, Cstring, Ptr{Void},
               Csize_t, Ptr{Ptr{UInt8}}, Ptr{Ptr{UInt8}}, Cint),
              xpa._ptr, apt, join(params, " "), mode,
              buf, len, names, errs, nmax)
    n ≥ 0 || error("unexpected result from XPASet")
    tup = ntuple(i -> (_fetch(String, names[i]),
                       _fetch(String, errs[i])), n)
    if check
        for (name, mesg) in tup
            length(mesg) > 0 && error(mesg)
        end
    end
    return tup
end

xpa_set(args::AbstractString...; kwds...) =
    xpa_set(NullHandle, args...; kwds...)

# These default values are defined in "xpap.h" and can be changed by
# user environment variable:
const _DEFAULTS = Dict{AbstractString,Any}("XPA_MAXHOSTS" => 100,
                                           "XPA_SHORT_TIMEOUT" => 15,
                                           "XPA_LONG_TIMEOUT" => 180,
                                           "XPA_CONNECT_TIMEOUT" => 10,
                                           "XPA_TMPDIR" => "/tmp/.xpa",
                                           "XPA_VERBOSITY" => true,
                                           "XPA_IOCALLSXPA" => false)

function xpa_config(key::AbstractString)
    global _DEFAULTS, ENV
    haskey(_DEFAULTS, key) || error("unknown XPA parameter \"$key\"")
    def = _DEFAULTS[key]
    if haskey(ENV, key)
        val = haskey(ENV, key)
        return (isa(def, Bool) ? (parse(Int, val) != 0) :
                isa(def, Integer) ? parse(Int, val) : val)
    else
        return def
    end
end

function xpa_config{T<:Union{Integer,Bool,AbstractString}}(key::AbstractString,
                                                           val::T)
    global _DEFAULTS, ENV
    old = xpa_config(key) # also check validity of key
    def = _DEFAULTS[key]
    if isa(def, Integer) && isa(val, Integer)
        ENV[key] = dec(val)
    elseif isa(def, Bool) && isa(val, Bool)
        ENV[key] = (val ? "1" : "0")
    elseif isa(def, AbstractString) && isa(val, AbstractString)
        ENV[key] = val
    else
        error("invalid type for XPA parameter \"$key\"")
    end
    return old
end

xpa_config(key::Symbol) = xpa_config(string(key))
xpa_config(key::Symbol, val) = xpa_config(string(key), val)

end # module
