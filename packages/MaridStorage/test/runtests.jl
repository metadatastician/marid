# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>

using Test
using MaridStorage

@testset "MaridStorage Suite" begin
    # 1. In-Memory Engine
    @testset "InMemoryEngine Operations" begin
        storage = InMemoryEngine()
        data = Dict{String, Any}("name" => "Clade A", "support" => 0.98)
        put_entity!(storage, "nodes", "1", data)

        retrieved = get_entity(storage, "nodes", "1")
        @test retrieved !== nothing
        @test retrieved["name"] == "Clade A"
        @test retrieved["_id"] == "nodes/1"

        # Querying
        put_entity!(storage, "nodes", "2", Dict{String, Any}("name" => "Clade B", "support" => 0.85))
        all_nodes = query_entities(storage, "nodes")
        @test length(all_nodes) == 2

        high_support = query_entities(storage, "nodes", filter_fn = n -> n["support"] > 0.9)
        @test length(high_support) == 1
        @test high_support[1]["name"] == "Clade A"

        delete_entity!(storage, "nodes", "1")
        @test get_entity(storage, "nodes", "1") === nothing
    end

    # 1b. Reads return copies, so a caller cannot corrupt the store (P14)
    @testset "InMemoryEngine copies on read" begin
        storage = InMemoryEngine()
        put_entity!(storage, "nodes", "1", Dict{String, Any}("name" => "Original"))
        got = get_entity(storage, "nodes", "1")
        got["name"] = "Mutated"
        @test get_entity(storage, "nodes", "1")["name"] == "Original"

        listed = query_entities(storage, "nodes")[1]
        listed["name"] = "Mutated too"
        @test get_entity(storage, "nodes", "1")["name"] == "Original"
    end

    # 2. The Arango seam refuses to pretend (C05)
    @testset "ArangoStorageEngine is not silently in-memory" begin
        # Default construction is NOT a working backend: every operation throws
        # rather than writing to a process-local dictionary and reporting success.
        arango_storage = ArangoStorageEngine("http://127.0.0.1:8529", "biomodel_test")
        @test !is_mock(arango_storage)
        @test_throws ArgumentError put_entity!(arango_storage, "edges", "e1",
            Dict{String, Any}("weight" => 0.99))
        @test_throws ArgumentError get_entity(arango_storage, "edges", "e1")
        @test_throws ArgumentError delete_entity!(arango_storage, "edges", "e1")
        @test_throws ArgumentError query_entities(arango_storage, "edges")

        # The error names the operation and the reason.
        err = try
            get_entity(arango_storage, "edges", "e1")
            nothing
        catch e
            e
        end
        @test err isa ArgumentError
        @test occursin("mock=true", sprint(showerror, err))

        # The explicit test double still works, and says so.
        double = ArangoStorageEngine("http://127.0.0.1:8529", "biomodel_test"; mock=true)
        @test is_mock(double)
        put_entity!(double, "edges", "e1",
            Dict{String, Any}("_from" => "nodes/1", "_to" => "nodes/2", "weight" => 0.99))
        e = get_entity(double, "edges", "e1")
        @test e !== nothing
        @test e["weight"] == 0.99
    end
end
