if !isdefined(Base, :Returns)
    struct Returns{T}
        value::T
    end
    (f::Returns)(args...; kwds...) = f.value
end
