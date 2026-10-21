# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>

using Test
using MaridIR
using MaridGraphQL

@testset "MaridGraphQL Tests" begin
    field = FieldDescriptor("id", "ID", nullable=false)
    entity_type = TypeDescriptor("Entity", [field])
    m_get = MethodDescriptor("getEntity", "ID", "Entity", http_method="GET")
    m_create = MethodDescriptor("createEntity", "Entity", "Entity", http_method="POST")

    svc = ServiceDescriptor("EntityService", "1.0.0", [entity_type], [m_get, m_create])

    sdl = emit_graphql_sdl(svc)
    @test occursin("type Entity {", sdl)
    @test occursin("id: ID!", sdl)
    @test occursin("type Query {", sdl)
    @test occursin("type Mutation {", sdl)
    # Input objects must be declared, or the SDL does not validate.
    @test occursin("input Entity", sdl)
    @test occursin("createEntity(input: Entity): Entity", sdl)

    res = execute_graphql_query("{ __schema { queryType { name } } }", svc)
    @test haskey(res, "data")
    @test haskey(res["data"], "__schema")
    @test res["data"]["__schema"]["types"][1]["kind"] == "OBJECT"
end

@testset "SDL is valid for a mutation-only service (C08)" begin
    entity = TypeDescriptor("Entity", [FieldDescriptor("id", "String")])
    svc = ServiceDescriptor("WriteOnly", "1.0.0", [entity], [
        MethodDescriptor("createEntity", "Entity", "Entity", http_method="POST")])
    sdl = emit_graphql_sdl(svc)
    # A schema with only a Mutation type is invalid; Query is always emitted.
    @test occursin("type Query {", sdl)
    @test occursin("_empty: Boolean", sdl)
    @test !occursin("type Query {\n}", sdl)
end

@testset "No undefined built-in scalars are emitted (C08)" begin
    weird = TypeDescriptor("Blob", [
        FieldDescriptor("raw", PrimitiveType("Bytes")),
        FieldDescriptor("big", PrimitiveType("UInt64")),
        FieldDescriptor("nothing", PrimitiveType("Void")),
        FieldDescriptor("labels", MapType(PrimitiveType("String"), PrimitiveType("String")))
    ])
    svc = ServiceDescriptor("BlobService", "1.0.0", [weird], [
        MethodDescriptor("put", "Blob", "Void", http_method="POST")])
    sdl = emit_graphql_sdl(svc)
    # Custom scalars are declared where they are used, rather than mapped to a
    # built-in type with a different meaning.
    @test occursin("scalar Bytes", sdl)
    @test occursin("scalar UInt64", sdl)
    @test occursin("scalar Void", sdl)
    @test occursin("scalar JSON", sdl)
    @test occursin("raw: Bytes!", sdl)
    @test occursin("nothing: Void!", sdl)
end
