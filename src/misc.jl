#
# misc.jl --
#
# Implement XPA configuration methods and miscellaneous methods.
#
#------------------------------------------------------------------------------
#
# This file is part of XPA.jl released under the MIT "expat" license.
#
# Copyright (c) 2016-2025, Éric Thiébaut (https://github.com/JuliaAstro/XPA.jl).
#

# Works for arrays of numbers and of pointers.
zerofill!(A::AbstractArray{T}) where {T} = fill!(A, T(0))

isnull(ptr::Ptr{T}) where {T} = ptr == Ptr{T}(0)

# Extend `Base.unsafe_convert` to automatically preserve `XPA.Client` and `XPA.Server`
# objects from being garbage collected in `ccall`s.
Base.unsafe_convert(::Type{Ptr{CDefs.XPARec}}, obj::Union{Client,Server}) = pointer(obj)

Base.isopen(obj::Union{Client,Server}) = !isnull(pointer(obj))

Base.pointer(obj::Union{Client,Server}) = getfield(obj, :ptr)

nullify_pointer!(obj::Union{Client,Server}) = setfield!(obj, :ptr, Ptr{CDefs.XPARec}(0))

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
    XPA.getconfig(key) -> val

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
    XPA.setconfig!(key, val) -> oldval

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

#-------------------------------------------------------------------------------------------

# Accessors of some members of the `XPARec` structure.
for (func, (memb, defval)) in (:get_name      => (:name,         ""),
                               :get_class     => (:xclass,       ""),
                               :get_send_mode => (:send_mode,    0),
                               :get_recv_mode => (:receive_mode, 0),
                               :get_method    => (:method,       ""),
                               :get_sendian   => (:sendian,      "?"))
    idx = Base.fieldindex(CDefs.XPARec, memb, true)
    off = fieldoffset(CDefs.XPARec, idx)
    typ = fieldtype(CDefs.XPARec, idx)
    if isa(defval, String)
        @assert typ === Ptr{UInt8}
        def = defval
        @eval function $func(obj::Union{Client,Server})
            GC.@preserve obj begin
                ptr = pointer(obj)
                if !isnull(ptr)
                    buf = unsafe_load(Ptr{$typ}(ptr + off))
                    if !isnull(buf)
                        return unsafe_string(buf)
                    end
                end
                return $def
            end
        end
    else
        def = convert(typ, defval)::typ
        @eval function $func(obj::Union{Client,Server})
            GC.@preserve obj begin
                ptr = pointer(obj)
                if !isnull(ptr)
                    return unsafe_load(Ptr{$typ}(ptr + $off))
                end
                return $def
            end
        end
    end
end

# Accessors of some member of the `XPACommRec` structure.
for (func, (memb, defval)) in (:get_comm_status  => (:status,   0),
                               :get_comm_cmdfd   => (:cmdfd,   -1),
                               :get_comm_datafd  => (:datafd,  -1),
                               :get_comm_ack     => (:ack,      1),
                               :get_comm_cendian => (:cendian, "?"),
                               :get_comm_buf     => (:buf,     NULL),
                               :get_comm_len     => (:len,      0))
    idx1 = Base.fieldindex(CDefs.XPARec, :comm, true)
    off1 = fieldoffset(CDefs.XPARec, idx1)
    typ1 = fieldtype(CDefs.XPARec, idx1)
    @assert typ1 == Ptr{CDefs.XPACommRec}
    idx2 = Base.fieldindex(CDefs.XPACommRec, memb, true)
    off2 = fieldoffset(CDefs.XPACommRec, idx2)
    typ2 = fieldtype(CDefs.XPACommRec, idx2)
    if isa(defval, String)
        @assert typ2 === Ptr{UInt8}
        def = defval
        @eval function $func(obj::Union{Client,Server})
            GC.@preserve obj begin
                ptr1 = pointer(obj)
                if !isnull(ptr1)
                    ptr2 = unsafe_load(Ptr{$typ1}(ptr1 + $off1))
                    if !isnull(ptr2)
                        ptr3 = unsafe_load(Ptr{$typ2}(ptr2 + $off2))
                        if !isnull(ptr3)
                            return unsafe_string(buf)
                        end
                    end
                end
                return $def
            end
        end
    else
        def = convert(typ2, defval)::typ2
        @eval function $func(obj::Union{Client,Server})
            GC.@preserve obj begin
                ptr1 = pointer(obj)
                if !isnull(ptr1)
                    ptr2 = unsafe_load(Ptr{$typ1}(ptr1 + $off1))
                    if !isnull(ptr2)
                        return unsafe_load(Ptr{$typ2}(ptr2 + $off2))
                    end
                end
            end
            return $def
        end
        if memb == :buf || memb == :len
            # Encode mutator.
            @eval function $(Symbol(:_set_comm_, memb))(obj::Union{Client,Server}, val)
                GC.@preserve obj begin
                    ptr1 = pointer(obj)
                    isnull(ptr1) && error("cannot set member of closed object")
                    ptr2 = unsafe_load(Ptr{$typ1}(ptr1 + $off1))
                    isnull(ptr2) && error("unexpected NULL pointer")
                    unsafe_store!(Ptr{$typ2}(ptr2 + $off2), convert($typ2, val))
                end
                return nothing
            end
        end
    end
end

"""
    _malloc(size)

Dynamically allocates `size` bytes and returns the corresponding byte pointer
(type `Ptr{UInt8}`).

!!! note
    This is just a wrapper around `Libc.malloc` that does null-checking.
"""
function _malloc(len::Integer) :: Ptr{Byte}
    ptr = Libc.malloc(len)
    ptr == NULL && throw(OutOfMemoryError())
    return ptr
end

"""
    _free(ptr)

Frees dynamically allocated memory at address given by `ptr` unless it is NULL.

!!! note
    This is just a wrapper around `Libc.free` that does avoids freeing NULL pointers.
"""
_free(ptr::Ptr{T}) where T = (ptr == C_NULL || Libc.free(ptr))

"""
    _memcpy!(dst, src, len) -> dst

Copies `len` bytes from address `src` to destination `dst`.
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
