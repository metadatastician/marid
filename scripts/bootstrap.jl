# SPDX-License-Identifier: MPL-2.0
# Instantiate an independent project and its transitive local Marid dependencies.
using Pkg, TOML
length(ARGS) == 1 || error("Usage: julia scripts/bootstrap.jl <project-directory>")
root = dirname(@__DIR__)
environment = abspath(ARGS[1])
projects = Dict{String,String}()
for directory in readdir(joinpath(root, "packages"); join=true)
    file = joinpath(directory, "Project.toml")
    isfile(file) || continue
    projects[TOML.parsefile(file)["name"]] = directory
end
selected = Set{String}()
function visit(directory)
    config = TOML.parsefile(joinpath(directory, "Project.toml"))
    for name in keys(get(config, "deps", Dict()))
        if haskey(projects, name) && !(name in selected)
            push!(selected, name)
            visit(projects[name])
        end
    end
end
visit(environment)
cd(environment) do
    Pkg.activate(".")
    specs = [Pkg.PackageSpec(path=relpath(projects[name], environment)) for name in sort!(collect(selected))]
    isempty(specs) || Pkg.develop(specs)
    # Instantiate FIRST: a committed Manifest.toml is a complete, source-pinned
    # resolution, and `Pkg.resolve()` on top of it demands a usable General
    # registry just to re-derive what the manifest already states. In an
    # environment without one (a fresh CI depot) that turns into
    # `expected package `Parsers [69de0a69]` to be registered` - a red matrix
    # cell for every package that tracks a manifest, for no reason. Resolve is
    # kept as the fallback, which is what a missing or stale manifest needs.
    # Only applications (examples/*) commit a manifest; the libraries under
    # packages/ never do (they are registered by subdir, D67/D117), so a
    # package environment always takes the resolve path.
    try
        Pkg.instantiate()
    catch err
        @warn "instantiate failed, resolving from the registry" exception = (err, catch_backtrace())
        Pkg.resolve()
        Pkg.instantiate()
    end
end
