#!/usr/bin/env julia
# SPDX-License-Identifier: MPL-2.0
#
# check-packages-precompile.jl — assert that every package under packages/
# precompiles and loads, each in its own Julia process.
#
# Acceptance criterion: metadatastician/marid#40 (re-homed from #37 item 4).
#
# Why a separate gate: MaridCore failed to precompile on `main` (#37, a
# docstring followed by another docstring) and the only signal was three red
# matrix cells, one of which did not name MaridCore at all. Julia General
# AutoMerge runs a package's tests, so a package that will not precompile
# cannot be registered, and D55 submits all 13 as one set. This is the
# precompile analogue of scripts/check-julia-compat.jl and sits beside it in
# the `cli-and-emitters` job (single-shot, never the 26-cell matrix).
#
# Exit codes: 0 every package precompiles and loads; 1 at least one does not
# (each named, with its first error line); 2 the gate found nothing to check
# or failed its own self-test. A gate that discovers nothing has failed.

import TOML
import UUIDs

const ROOT = dirname(@__DIR__)
const BOOTSTRAP = joinpath(ROOT, "scripts", "bootstrap.jl")

# The program each package runs in isolation. `include(bootstrap.jl)` reads the
# package directory from ARGS, develops its intra-family deps by path and
# instantiates; `Pkg.activate` inside it leaves the package as the active
# project, so `Pkg.precompile(strict=true)` then covers the package and every
# dependency in its manifest, and `using` proves the result actually loads.
const PROGRAM = """
const _dir, _boot, _name = ARGS[1], ARGS[2], ARGS[3]
empty!(ARGS); push!(ARGS, _dir)   # bootstrap.jl insists on exactly one argument
include(_boot)
import Pkg
Pkg.precompile(; strict=true)
@eval using \$(Symbol(_name))
println("PRECOMPILE-OK ", _name)
"""

"Return the sorted (name, directory) pairs of every packages/*/Project.toml."
function package_dirs(pkgroot::AbstractString)
    out = Tuple{String,String}[]
    isdir(pkgroot) || return out
    for entry in sort(readdir(pkgroot))
        dir = joinpath(pkgroot, entry)
        file = joinpath(dir, "Project.toml")
        isfile(file) || continue
        name = get(TOML.parsefile(file), "name", entry)
        push!(out, (String(name), dir))
    end
    return out
end

"""
Pick the one line of a failed run worth showing: the innermost LoadError if
there is one, else the first `ERROR:` line, else the last non-empty line.
"""
function first_error_line(output::AbstractString)
    lines = filter(!isempty, strip.(split(output, '\n')))
    isempty(lines) && return "(no output)"
    i = findfirst(l -> occursin("LoadError", l), lines)
    i === nothing && (i = findfirst(l -> startswith(l, "ERROR"), lines))
    return String(lines[i === nothing ? end : i])
end

"""
Precompile and load one package in a fresh Julia process. Returns
`(ok, first_error_line)`. `bootstrap` is the bootstrap script to include; the
self-test passes the real one against a fixture package.
"""
function precompile_one(name::AbstractString, dir::AbstractString;
                        bootstrap::AbstractString=BOOTSTRAP)
    julia = Base.julia_cmd()
    cmd = `$julia --startup-file=no -e $PROGRAM $dir $bootstrap $name`
    io = IOBuffer()
    proc = run(pipeline(ignorestatus(cmd); stdout=io, stderr=io))
    out = String(take!(io))
    ok = success(proc) && occursin("PRECOMPILE-OK $name", out)
    return ok, ok ? "" : first_error_line(out)
end

# ── Self-test ────────────────────────────────────────────────────────────────
# A passing check proves nothing until a mutant dies. The seeded defect is the
# real #37 shape, a docstring followed by another docstring, which makes Julia
# try to document a string literal; the clean fixture guards against a gate
# that reports everything as broken. Exit 2 if either control misbehaves.
"Write a minimal package `name` under `parent` with the given module body."
function write_fixture(parent::AbstractString, name::AbstractString, body::AbstractString)
    dir = joinpath(parent, name)
    mkpath(joinpath(dir, "src"))
    open(joinpath(dir, "Project.toml"), "w") do io
        println(io, "name = \"$name\"")
        println(io, "uuid = \"$(UUIDs.uuid4())\"")
        println(io, "version = \"0.0.1\"")
        println(io, "\n[compat]\njulia = \"1.10\"")
    end
    open(joinpath(dir, "src", "$name.jl"), "w") do io
        println(io, "module $name\n$body\nend")
    end
    return dir
end

"Run both controls; return true only if the mutant dies and the clean one passes."
function self_test()::Bool
    ok = true
    mktempdir() do tmp
        bad = write_fixture(tmp, "PrecompileMutant",
            "\"\"\"docstring for f\"\"\"\n\"\"\"a second docstring: the #37 defect\"\"\"\nf() = 1")
        good = write_fixture(tmp, "PrecompileControl", "f() = 1")
        bad_ok, bad_err = precompile_one("PrecompileMutant", bad)
        if bad_ok
            println("  self-test: MISSED seeded defect (double docstring precompiled)")
            ok = false
        elseif !occursin("document", bad_err)
            println("  self-test: mutant died for the wrong reason: $bad_err")
            ok = false
        end
        good_ok, good_err = precompile_one("PrecompileControl", good)
        if !good_ok
            println("  self-test: FALSE POSITIVE on clean control: $good_err")
            ok = false
        end
    end
    println(ok ? "  self-test: 2/2 OK (mutant died, control passed)" : "  self-test: FAILED")
    return ok
end

# ── Main ─────────────────────────────────────────────────────────────────────
function main()
    pkgroot = joinpath(ROOT, "packages")
    println("check-packages-precompile: every packages/* must precompile and load")
    self_test() || (println("ABORT: the gate cannot detect its own fixtures."); exit(2))

    pkgs = package_dirs(pkgroot)
    # A gate that finds nothing to check has failed, not passed.
    if isempty(pkgs)
        println("ABORT: found no packages/*/Project.toml to check.")
        exit(2)
    end

    failed = Tuple{String,String}[]
    for (name, dir) in pkgs
        ok, err = precompile_one(name, dir)
        if ok
            println("ok   $name")
        else
            push!(failed, (name, err))
            println("FAIL $name")
            println("       - $err")
        end
    end

    println("\nchecked $(length(pkgs)) package(s); $(length(failed)) failing")
    if !isempty(failed)
        println("failing: $(join(first.(failed), ", "))")
        exit(1)
    end
    println("All packages precompile and load.")
    return nothing
end

main()
