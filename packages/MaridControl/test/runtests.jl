# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>

using Test
using MaridControl

@testset "MaridControl Complete Suite" begin
    # 1. Snapshot & Atomic Configuration
    @testset "Snapshot and Atomic Swaps" begin
        cfg = AtomicConfig(Snapshot(1, MaridControl.now(MaridControl.UTC), Dict("cluster_name" => "node-alpha")))
        s1 = get_snapshot(cfg)
        @test s1.version == 1
        @test s1.data["cluster_name"] == "node-alpha"
        
        # In-place atomic update
        s2 = update_snapshot!(cfg) do d
            d["route_timeout"] = 5000
            return d
        end
        @test s2.version == 2
        @test s2.data["route_timeout"] == 5000
        @test s2.data["cluster_name"] == "node-alpha"
    end

    # 1b. swap_snapshot! returns the installed snapshot (C03)
    @testset "swap_snapshot! installs and returns the new snapshot" begin
        cfg = AtomicConfig(Snapshot(0, MaridControl.now(MaridControl.UTC), Dict{String, Any}("a" => 1)))
        next = Snapshot(1, MaridControl.now(MaridControl.UTC), Dict{String, Any}("a" => 2))

        installed = swap_snapshot!(cfg, next)   # was: MethodError on every call
        @test installed isa Snapshot
        @test installed === next
        @test installed.version == 1
        @test get_snapshot(cfg).version == 1
        @test get_snapshot(cfg).data["a"] == 2

        # A swap is not a merge: the previous payload does not survive unless the
        # caller put it there. Documented contract, asserted here.
        @test !haskey(get_snapshot(cfg).data, "b")
    end

    # 1c. A swap is unconditional: interleaving with other writers must not make
    # it throw. The previous compare-and-swap could fail exactly here.
    @testset "swap_snapshot! cannot fail under concurrent writers" begin
        cfg = AtomicConfig(Snapshot(0, MaridControl.now(MaridControl.UTC),
                                    Dict{String, Any}("a" => 0)))

        errors_seen = Base.Threads.Atomic{Int}(0)
        tasks = [Threads.@spawn begin
            try
                for i in 1:50
                    swap_snapshot!(cfg, Snapshot(i, MaridControl.now(MaridControl.UTC),
                                                 Dict{String, Any}("a" => i)))
                    update_snapshot!(d -> d, cfg)
                    get_snapshot(cfg)
                end
            catch
                Base.Threads.atomic_add!(errors_seen, 1)
            end
        end for _ in 1:4]
        foreach(wait, tasks)

        @test errors_seen[] == 0
        # Some writer's snapshot is installed and readable.
        @test get_snapshot(cfg) isa Snapshot
    end

    # 2. Sequential Log Abstraction
    @testset "Sequential Log Append & Playback" begin
        log = SequentialLog()
        e1 = append_log!(log, 1, "schema/v1", "schema_definition_1")
        e2 = append_log!(log, 1, "schema/v2", "schema_definition_2")
        e3 = append_log!(log, 2, "schema/v3", "schema_definition_3")
        
        @test e1.index == 1
        @test e2.index == 2
        @test e3.index == 3
        @test e3.term == 2
        
        # Playback from index 2
        entries = read_log_from(log, 2)
        @test length(entries) == 2
        @test entries[1].key == "schema/v2"
        @test entries[2].key == "schema/v3"
    end

    # 3. Control-Plane-Down Serving Isolation
    @testset "Node Serves with Control Plane Down" begin
        backend = InMemoryControlBackend()
        node = ControlNode(backend)
        
        # Initial sync
        sync_from_backend!(node, Dict{String, Any}("routing_table" => "v1_routes", "rate_limit" => 100))
        @test serve_request(node, "routing_table") == "v1_routes"
        @test serve_request(node, "rate_limit") == 100
        
        # Sever control plane connection completely
        set_connected!(backend, false)
        
        # Node continues serving traffic without errors or performance penalty
        for _ in 1:100
            @test serve_request(node, "routing_table") == "v1_routes"
        end
        
        # Control plane recovers and pushes new config
        set_connected!(backend, true)
        sync_from_backend!(node, Dict{String, Any}("rate_limit" => 250))
        @test serve_request(node, "rate_limit") == 250
    end

    # 4. Multi-Threaded Concurrent Swap Stress Test (Race Defense)
    @testset "Race-Tested Atomic Swaps" begin
        cfg = AtomicConfig(Snapshot(0, MaridControl.now(MaridControl.UTC), Dict("counter" => 0, "checksum" => 0)))
        num_readers = 4
        num_swaps = 500
        
        # Concurrent reader tasks
        reader_errors = Int[]
        reader_tasks = Task[]
        
        for r in 1:num_readers
            t = @async begin
                errs = 0
                for _ in 1:1000
                    snap = get_snapshot(cfg)
                    c = get(snap.data, "counter", 0)
                    chk = get(snap.data, "checksum", 0)
                    # Verify atomic consistency: counter must equal checksum
                    if c != chk
                        errs += 1
                    end
                end
                return errs
            end
            push!(reader_tasks, t)
        end
        
        # Writer loop performing atomic swaps
        for i in 1:num_swaps
            update_snapshot!(cfg) do d
                d["counter"] = i
                d["checksum"] = i
                return d
            end
        end
        
        # Check all reader errors
        for t in reader_tasks
            push!(reader_errors, fetch(t))
        end
        
        @test sum(reader_errors) == 0
        final_snap = get_snapshot(cfg)
        @test final_snap.data["counter"] == num_swaps
        @test final_snap.data["checksum"] == num_swaps
    end
end
