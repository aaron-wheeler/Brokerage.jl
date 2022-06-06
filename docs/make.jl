using Brokerage
using Documenter

DocMeta.setdocmeta!(Brokerage, :DocTestSetup, :(using Brokerage); recursive=true)

makedocs(;
    modules=[Brokerage],
    authors="aaron-wheeler",
    repo="https://github.com/aaron-wheeler/Brokerage.jl/blob/{commit}{path}#{line}",
    sitename="Brokerage.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://aaron-wheeler.github.io/Brokerage.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/aaron-wheeler/Brokerage.jl",
    devbranch="main",
)
