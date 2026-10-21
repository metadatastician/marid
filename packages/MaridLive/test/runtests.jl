# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>

using Test
using JSON3
using MaridLive

@testset "MaridLive Complete Suite" begin
    # 1. HTMX Integration Helpers
    @testset "HTMX Helpers" begin
        # Out of band swap
        oob = hx_swap_oob("<span>Updated Node</span>", "node-42")
        @test occursin("id=\"node-42\"", oob)
        @test occursin("hx-swap-oob=\"outerHTML\"", oob)
        @test occursin("<span>Updated Node</span>", oob)

        # Headers
        h1 = hx_trigger_header("entityCreated")
        @test h1.first == "HX-Trigger"
        @test h1.second == "entityCreated"

        h2 = hx_trigger_header("scoreUpdated", data=Dict("score" => "42"))
        @test h2.first == "HX-Trigger"
        parsed = JSON3.read(h2.second)
        @test parsed[:scoreUpdated][:score] == "42"

        push_h = hx_push_url_header("/taxa/hominini")
        @test push_h.first == "HX-Push-Url"
        @test push_h.second == "/taxa/hominini"

        # SSE Wire Event for HTMX
        sse = format_htmx_sse("nodeChanged", "<div id=\"node\">Homo</div>")
        @test startswith(sse, "event: nodeChanged\n")
        @test occursin("data: <div id=\"node\">Homo</div>", sse)
        @test endswith(sse, "\n\n")
    end

    # 1b. Values cannot break out of their context (C09)
    @testset "Escaping and header hygiene" begin
        # JSON is escaped, not concatenated: a quote in a value used to produce
        # a malformed HX-Trigger document.
        h = hx_trigger_header("updated", data=Dict("label" => "He said \"hi\""))
        @test JSON3.read(h.second)[:updated][:label] == "He said \"hi\""

        # HTML attributes are escaped.
        oob = hx_swap_oob("<p>x</p>", "a\" onload=\"alert(1)")
        @test occursin("&quot;", oob)
        @test !occursin("onload=\"alert(1)\"", oob)

        turbo = turbo_replace("t\" onclick=\"x", "<p>x</p>")
        @test occursin("&quot;", turbo)
        @test !occursin("onclick=\"x", turbo)

        # Unknown actions and swap modes are rejected instead of emitted.
        @test_throws ArgumentError turbo_stream("explode", "t", "<p>x</p>")
        @test_throws ArgumentError hx_swap_oob("<p>x</p>", "t"; swap_mode="drop table")

        # CR/LF in a header value is refused: that is response splitting.
        @test_throws ArgumentError hx_trigger_header("ok\r\nX-Evil: 1")
        @test_throws ArgumentError hx_push_url_header("/a\nb")
    end

    # 2. Hotwire Turbo Streams
    @testset "Turbo Streams" begin
        app = turbo_append("taxa-list", "<li>Pan troglodytes</li>")
        @test occursin("<turbo-stream action=\"append\" target=\"taxa-list\">", app)
        @test occursin("<template><li>Pan troglodytes</li></template>", app)

        rep = turbo_replace("status-box", "<div>Ready</div>")
        @test occursin("action=\"replace\"", rep)

        rem = turbo_remove("modal-1")
        @test rem == "<turbo-stream action=\"remove\" target=\"modal-1\"></turbo-stream>"
    end

    # 3. Datastar Reactive SSE Helpers
    @testset "Datastar Signals & Fragments" begin
        # Fragment merge
        frag = datastar_merge_fragments("<p id=\"msg\">Calculated</p>", selector="#msg", merge_mode="upsertAttributes")
        @test occursin("event: datastar-merge-fragments", frag)
        @test occursin("data: selector #msg", frag)
        @test occursin("data: mergeMode upsertAttributes", frag)
        @test occursin("data: fragments <p id=\"msg\">Calculated</p>", frag)
        # Exactly one trailing blank line, i.e. the block ends "\n\n".
        @test endswith(frag, "\n\n")
        @test !endswith(frag, "\n\n\n")

        # Signals merge: numbers and booleans must be JSON, not Julia syntax.
        sig = datastar_merge_signals(Dict{String, Any}("parsimony_score" => 3.5, "running" => true))
        @test occursin("event: datastar-merge-signals", sig)
        signals_line = first(filter(l -> startswith(l, "data: signals "), split(sig, '\n')))
        signals = JSON3.read(replace(signals_line, "data: signals " => ""))
        @test signals[:parsimony_score] == 3.5
        @test signals[:running] === true
        @test endswith(sig, "\n\n")

        # Nested structures are valid JSON too (the old interpolation was not).
        nested = datastar_merge_signals(Dict{String, Any}("peers" => ["a", "b"], "meta" => Dict("n" => 2)))
        nested_line = first(filter(l -> startswith(l, "data: signals "), split(nested, '\n')))
        @test JSON3.read(replace(nested_line, "data: signals " => ""))[:peers] == ["a", "b"]

        # Remove fragment
        rem_frag = datastar_remove_fragments("#stale-node")
        @test occursin("event: datastar-remove-fragments", rem_frag)
        @test occursin("data: selector #stale-node", rem_frag)
    end
end
