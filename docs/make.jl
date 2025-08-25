DEPLOYDOCS = (get(ENV, "CI", nothing) == "true")
push!(LOAD_PATH, "../src/")
using XPA
using Documenter
using Documenter.Remotes: GitHub

include("pages.jl")

makedocs(;
    modules = [XPA],
    sitename = "XPA.jl",
    repo = GitHub("JuliaAstro/XPA.jl"),
    format = Documenter.HTML(;
        canonical = "https://juliaastro.org/XPA/stable/",
        edit_link = "main",
        prettyurls = DEPLOYDOCS,
    ),
    authors = "Éric Thiébaut and contributors",
    pages = pages,
    doctest = true,
)

if DEPLOYDOCS
    deploydocs(
        repo = "github.com/JuliaAstro/XPA.jl.git",
        push_preview = true,
        versions = ["stable" => "v^", "v#.#"], # Restrict to minor releases
    )
end
