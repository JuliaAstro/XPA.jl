#
# misc.jl --
#
# Implement XPA configuration methods and miscellaneous methods.
#
#-------------------------------------------------------------------------------------------
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

#-------------------------------------------------------------------------------------------
# CONFIGURATION METHODS

# The following default values are defined in "xpap.c" and can be changed by user
# environment variables.
const _DEFAULTS = Dict{String,Any}("XPA_MAXHOSTS" => 100,
                                   "XPA_SHORT_TIMEOUT" => 15,
                                   "XPA_LONG_TIMEOUT" => 180,
                                   "XPA_CONNECT_TIMEOUT" => 10,
                                   "XPA_TMPDIR" => "/tmp/.xpa",
                                   "XPA_VERBOSITY" => true,
                                   "XPA_IOCALLSXPA" => false)

"""
    XPA.getconfig(key) -> val

yields the value associated with configuration parameter `key` (a string or a symbol). The
following parameters are available (see XPA doc. for more information):

| Key Name                | Default Value                         |
|:----------------------- |:------------------------------------- |
| `"XPA_MAXHOSTS"`        | `$(_DEFAULTS["XPA_MAXHOSTS"])`        |
| `"XPA_SHORT_TIMEOUT"`   | `$(_DEFAULTS["XPA_SHORT_TIMEOUT"])`   |
| `"XPA_LONG_TIMEOUT"`    | `$(_DEFAULTS["XPA_LONG_TIMEOUT"])`    |
| `"XPA_CONNECT_TIMEOUT"` | `$(_DEFAULTS["XPA_CONNECT_TIMEOUT"])` |
| `"XPA_TMPDIR"`          | `"$(_DEFAULTS["XPA_TMPDIR"])"`        |
| `"XPA_VERBOSITY"`       | `$(_DEFAULTS["XPA_VERBOSITY"])`       |
| `"XPA_IOCALLSXPA"`      | `$(_DEFAULTS["XPA_IOCALLSXPA"])`      |

Also see [`XPA.setconfig!`](@ref).

"""
getconfig(key::Symbol) = getconfig(string(key))
function getconfig(key::AbstractString)
    haskey(_DEFAULTS, key) || error("unknown XPA parameter \"$key\"")
    def = _DEFAULTS[key]::Union{Bool,Int,String}
    haskey(ENV, key) || return def
    val = ENV[key]::String
    def isa String && return val
    ival = tryparse(Int, val)
    ival === nothing && error("value of environment variable \"$key\" cannot be converted to an integer")
    return def isa Bool ? !iszero(ival) : ival
end

"""
    XPA.setconfig!(key, val) -> oldval

set the value associated with configuration parameter `key` to be `val`. The previous value
is returned.

Also see [`XPA.getconfig`](@ref).

"""
setconfig!(key::Symbol, val) = setconfig!(string(key), val)
function setconfig!(key::AbstractString, val::Union{Integer,AbstractString})
    global _DEFAULTS, ENV
    old = getconfig(key) # also check validity of key and dictionary
    if old isa Bool
        if val isa Bool
            ENV[key] = (val ? "1" : "0")
            return old
        elseif val isa Integer && (iszero(val) || isone(val))
            ENV[key] = (isone(val) ? "1" : "0")
            return old
        end
    elseif old isa Int
        if val isa Integer
            ENV[key] = string(val)
            return old
        end
    else # `old` must be a string
        if val isa AbstractString
            ENV[key] = val
            return old
        end
    end
    error("invalid type `$typeof(val)` for XPA parameter \"$key\"")
end

#-------------------------------------------------------------------------------------------

"""
    s = XPA.preserve_state(dict, key[, val])

Yield an object that can be used to restore the state of dictionary `dict` for entry `key`
with [`XPA.restore_state`](@ref). For improved type-stability, optional argument `val` may
be specified with a substitute value of the same type as those stored in `dict` if `key` is
not in `dict`.

The call:

    XPA.preserve_state(f::Function, dict, key[, val])

is equivalent to:

    let s = XPA.preserve_state(dict, key[, val])
        try
            f()
        finally
            XPA.restore_state(s)
        end
    end

which is suitable for the `do`-block syntax.

"""
function preserve_state(dict::AbstractDict, key, val = missing_value(dict))
    flag = haskey(dict, key)
    prev = flag ? dict[key] : val
    return (dict, key, flag, prev)
end

function preserve_state(f::Function, dict::AbstractDict, key, val = missing_value(dict))
    s = preserve_state(dict, key, val)
    try
        f()
    finally
        restore_state(s)
    end
end

missing_value(dict::AbstractDict{<:Any,V}) where {V<:String} = ""
missing_value(dict::AbstractDict{<:Any,V}) where {V<:Number} = zero(V)
missing_value(dict::AbstractDict{<:Any,V}) where {V<:Any} = missing

"""
    XPA.restore_state(s)

Restore the state saved in `s` by [`XPA.preserve_state`](@ref).

"""
function restore_state((dict, key, flag, prev)::Tuple{AbstractDict,Any,Bool,Any})
    if flag
        dict[key] = prev
    else
        delete!(dict, key)
    end
    return nothing
end

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

# `_malloc(n)` returns a pointer to `n` bytes of freshly allocated memory throwing an
# `OutOfMemoryError` if the pointer is NULL.
function _malloc(n::Integer)
    ptr = Libc.malloc(n)
    isnull(ptr) && throw(OutOfMemoryError())
    return ptr
end

# `_free(ptr)` frees dynamically allocated memory at address given by `ptr` unless it is
# NULL.
_free(ptr::Ptr) = isnull(ptr) || Libc.free(ptr)

# `_memcpy!(dst, src, n)` calls C's `memcpy` to copy `n` bytes from `src` to `dst` and
# returns `dst`. The operation is *unsafe* because the validity of the arguments is not
# checked except that nothing is done if `n ≤ 0`. If `src` and/or `dst` are objects that
# implement `y = Base.cconvert(Ptr{Cvoid}, x)` and then `Base.unsafe_convert(Ptr{Cvoid},
# y)`, they are automatically preserved from being garbage collected during the call.
function _memcpy!(dst, src, n::Integer)
    if n > zero(n)
        ccall(:memcpy, Ptr{Cvoid}, (Ptr{Cvoid}, Ptr{Cvoid}, Csize_t), dst, src, n)
    end
    return dst
end
