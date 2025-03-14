using XPA
using Documenter
using Documenter.Remotes: GitHub

include("pages.jl")

makedocs(;
    modules = [XPA],
    sitename = "XPA.jl",
    repo = GitHub("JuliaAstro/XPA.jl"),
    format = Documenter.HTML(),
    authors = "Éric Thiébaut and contributors",
    pages,
    doctest = true,
)

deploydocs(
    repo = "github.com/JuliaAstro/XPA.jl.git",
    push_preview = true,
)
