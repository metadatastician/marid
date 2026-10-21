# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>

using Test
using MaridRPC

@testset "MaridRPC Tests" begin
    registry = Dict{String, Function}(
        "ping" => params -> Dict{String, Any}("pong" => true)
    )

    # 1. Success
    req = RpcRequest("2.0", "ping", Dict{String, Any}(), 1)
    res = dispatch_rpc(req, registry)
    @test res.id == 1
    @test res.error === nothing
    @test res.result["pong"] == true

    # 2. Method not found
    bad_req = RpcRequest("2.0", "unknownMethod", Dict{String, Any}(), 2)
    bad_res = dispatch_rpc(bad_req, registry)
    @test bad_res.id == 2
    @test bad_res.error["code"] == -32601

    # 3. Invalid request (wrong jsonrpc version) keeps the id for correlation
    wrong_version = dispatch_rpc(RpcRequest("1.0", "ping", Dict{String, Any}(), 3), registry)
    @test wrong_version.error["code"] == -32600
    @test wrong_version.id == 3
    @test wrong_version.result === nothing
end

@testset "Internal errors are redacted (C06)" begin
    # A marker that reads as sensitive without looking like a real credential:
    # a literal connection string in a fixture tends to trip secret scanners and
    # teaches the wrong lesson about what the test is checking.
    registry = Dict{String, Function}(
        "boom" => params -> error("SECRET-MARKER-DO-NOT-LEAK db-host-internal")
    )
    # The contract has two halves: the client gets a fixed message, and the
    # detail goes to the log. Assert both, and keep the log record out of the
    # test output while doing it.
    local res
    @test_logs (:error, r"MaridRPC handler failed") begin
        res = dispatch_rpc(RpcRequest("2.0", "boom", Dict{String, Any}(), 4), registry)
    end
    @test res.error["code"] == -32603
    @test res.error["message"] == "Internal error"
    # The whole point: nothing about the failure crosses the wire.
    @test !occursin("SECRET-MARKER", res.error["message"])
    @test !occursin("db-host-internal", res.error["message"])
    @test res.id == 4
end

@testset "Results are any JSON value, not only objects (C06)" begin
    registry = Dict{String, Function}(
        "number" => params -> 7,
        "list" => params -> [1, 2, 3],
        "text" => params -> "ok",
        "null" => params -> nothing
    )
    @test dispatch_rpc(RpcRequest("2.0", "number", Dict{String, Any}(), 5), registry).result == 7
    @test dispatch_rpc(RpcRequest("2.0", "list", Dict{String, Any}(), 6), registry).result == [1, 2, 3]
    @test dispatch_rpc(RpcRequest("2.0", "text", Dict{String, Any}(), 7), registry).result == "ok"
    res = dispatch_rpc(RpcRequest("2.0", "null", Dict{String, Any}(), 8), registry)
    @test res.result === nothing
    @test res.error === nothing
end
