#
# misc.jl --
#
# Implement XPA configuration methods and miscellaneous methods.
#
#------------------------------------------------------------------------------
#
# This file is part of XPA.jl released under the MIT "expat" license.
# Copyright (C) 2016-2020, Éric Thiébaut (https://github.com/JuliaAstro/XPA.jl).
#

#------------------------------------------------------------------------------
# CONFIGURATION METHODS

# The following default values are defined in "xpap.c" and can be changed by
# user environment variables.
const _DEFAULTS = Dict{String,Any}("XPA_MAXHOSTS" => 100,
                                   "XPA_SHORT_TIMEOUT" => 15,
                                   "XPA_LONG_TIMEOUT" => 180,
                                   "XPA_CONNECT_TIMEOUT" => 10,
                                   "XPA_TMPDIR" => "/tmp/.xpa",
                                   "XPA_VERBOSITY" => true,
                                   "XPA_IOCALLSXPA" => false)

"""
```julia
XPA.getconfig(key) -> val
```

yields the value associated with configuration parameter `key` (a string or a
symbol).  The following parameters are available (see XPA doc. for more
information):

| Key Name                | Default Value |
|:----------------------- |:------------- |
| `"XPA_MAXHOSTS"`        | `100`         |
| `"XPA_SHORT_TIMEOUT"`   | `15`          |
| `"XPA_LONG_TIMEOUT"`    | `180`         |
| `"XPA_CONNECT_TIMEOUT"` | `10`          |
| `"XPA_TMPDIR"`          | `"/tmp/.xpa"` |
| `"XPA_VERBOSITY"`       | `true`        |
| `"XPA_IOCALLSXPA"`      | `false`       |

Also see [`XPA.setconfig!`](@ref).

"""
function getconfig(key::AbstractString)
    haskey(_DEFAULTS, key) || error("unknown XPA parameter \"$key\"")
    def = _DEFAULTS[key]
    if haskey(ENV, key)
        val = haskey(ENV, key)
        return (isa(def, Bool) ? (parse(Int, val) != 0) :
                isa(def, Integer) ? parse(Int, val) :
                isa(def, AbstractString) ? val :
                error("unexpected type $(typeof(def)) for default value of \"$key\""))
    else
        return def
    end
end

"""
```julia
XPA.setconfig!(key, val) -> oldval
```

set the value associated with configuration parameter `key` to be `val`.  The
previous value is returned.

Also see [`XPA.getconfig`](@ref).

"""
function setconfig!(key::AbstractString,
                    val::T) where {T<:Union{Integer,Bool,AbstractString}}
    global _DEFAULTS, ENV
    old = getconfig(key) # also check validity of key
    def = _DEFAULTS[key]
    if isa(def, Integer) && isa(val, Integer)
        ENV[key] = string(val)
    elseif isa(def, Bool) && isa(val, Bool)
        ENV[key] = (val ? "1" : "0")
    elseif isa(def, AbstractString) && isa(val, AbstractString)
        ENV[key] = val
    else
        error("invalid type for XPA parameter \"$key\"")
    end
    return old
end

getconfig(key::Symbol) = getconfig(string(key))
setconfig!(key::Symbol, val) = setconfig!(string(key), val)

#------------------------------------------------------------------------------
# PRIVATE METHODS

"""
Private methods:

```julia
_get_field(T, ptr, off, def)
```

and

```julia
_get_field(T, ptr, off1, off2, def)
```

retrieve a field of type `T` at offset `off` (in bytes) with respect to address
`ptr`.  If two offsets are given, the first one refers to a pointer with
respect to which the second is applied.  If `ptr` is NULL, `def` is returned.

"""
_get_field(::Type{T}, ptr::Ptr{Cvoid}, off::UInt, def::T) where {T} =
    (ptr == C_NULL ? def : unsafe_load(convert(Ptr{T}, ptr + off)))

_get_field(::Type{String}, ptr::Ptr{Cvoid}, off::UInt, def::String) = begin
    ptr == C_NULL && return def
    buf = unsafe_load(convert(Ptr{Ptr{Byte}}, ptr + off))
    buf == C_NULL && return def
    return unsafe_string(buf)
end

function _get_field(::Type{T}, ptr::Ptr{Cvoid}, off1::UInt, off2::UInt,
                    def::T) where {T}
    _get_field(T, _get_field(Ptr{Cvoid}, ptr, off1, C_NULL), off2, def)
end

function _set_field(::Type{T}, ptr::Ptr{Cvoid}, off::UInt, val) where {T}
    @assert ptr != C_NULL
    unsafe_store!(convert(Ptr{T}, ptr + off), val)
end

let T = CDefs.XPARec, off = fieldoffset(T, Base.fieldindex(T, :comm, true))
    @eval _get_comm(conn::Handle) =
        _get_field(Ptr{Cvoid}, conn.ptr, $off, C_NULL)
end

for (func, memb, defval) in ((:get_name,      :name,         ""),
                             (:get_class,     :xclass,       ""),
                             (:get_send_mode, :send_mode,    0),
                             (:get_recv_mode, :receive_mode, 0),
                             (:get_method,    :method,       ""),
                             (:get_sendian,   :sendian,      "?"))
    T = CDefs.XPARec
    idx = Base.fieldindex(T, memb, true)
    off = fieldoffset(T, idx)
    if isa(defval, String)
        @assert fieldtype(T, idx) === Ptr{UInt8}
        typ = String
        def = defval
    else
        typ = fieldtype(T, idx)
        def = convert(typ, defval)
    end
    @eval $func(conn::Handle) = _get_field($typ, conn.ptr, $off, $def)
end

for (func, memb, defval) in ((:get_comm_status,  :status,   0),
                             (:get_comm_cmdfd,   :cmdfd,   -1),
                             (:get_comm_datafd,  :datafd,  -1),
                             (:get_comm_ack,     :ack,      1),
                             (:get_comm_cendian, :cendian, "?"),
                             (:get_comm_buf,     :buf,     NULL),
                             (:get_comm_len,     :len,      0))
    T = CDefs.XPACommRec
    idx = Base.fieldindex(T, memb, true)
    off = fieldoffset(T, idx)
    if isa(defval, String)
        @assert fieldtype(T, idx) === Ptr{UInt8}
        typ = String
        def = defval
    else
        typ = fieldtype(T, idx)
        def = convert(typ, defval)
    end
    @eval $func(conn::Handle) = _get_field($typ, _get_comm(conn), $off, $def)
    if memb == :buf || memb == :len
        @eval $(Symbol(:_set_comm_, memb))(conn::Handle, val) =
            unsafe_store!(convert(Ptr{$typ}, _get_comm(conn) + $off), val)
    end
end

"""
```julia
_malloc(len)
```

dynamically allocates `len` bytes and returns the corresponding byte pointer
(type `Ptr{UInt8}`).

"""
function _malloc(len::Integer) :: Ptr{Byte}
    ptr = ccall(:malloc, Ptr{Byte}, (Csize_t,), len)
    ptr != NULL || throw(OutOfMemoryError())
    return ptr
end

"""
```julia
_free(ptr)
```

frees dynamically allocated memory at address givne by `ptr` unless it is NULL.

"""
_free(ptr::Ptr{T}) where T =
    (ptr == Ptr{T}(0) || ccall(:free, Cvoid, (Ptr{T},), ptr))

"""
```julia
_memcpy!(dst, src, len) -> dst
```

copies `len` bytes from address `src` to destination `dst`.

"""
function _memcpy!(dst::Ptr, src::Ptr, len::Integer)
    if len > 0
        ccall(:memcpy, Ptr{Cvoid}, (Ptr{Cvoid}, Ptr{Cvoid}, Csize_t),
              dst, src, len)
    end
    return dst
end

function _memcpy!(dst::AbstractArray, src::Ptr, len::Integer)
    len == sizeof(dst) || error("bad number of bytes to copy")
    if len > 0
        ccall(:memcpy, Ptr{Cvoid}, (Ptr{Cvoid}, Ptr{Cvoid}, Csize_t),
              dst, src, len)
    end
    return dst
end
