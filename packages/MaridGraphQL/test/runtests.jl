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
    # Input objects must be declared with their own name and real fields, or the
    # SDL does not validate: `input Entity` collided with `type Entity`, and a
    # fieldless input object is invalid GraphQL.
    @test occursin("input EntityInput {", sdl)
    @test occursin("id: ID!", sdl)
    @test occursin("createEntity(input: EntityInput): Entity", sdl)
    @test !occursin("input Entity {", sdl)
    # `ID` is an ObjectType in the IR but a GraphQL built-in scalar; inside the
    # input object it must stay `ID`, never `IDInput` (which is never declared).
    @test !occursin("IDInput", sdl)

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
    # `Void` means "always null", so a non-null Void field could never be
    # satisfied by any resolver.
    @test occursin("nothing: Void\n", sdl)
    @test !occursin("Void!", sdl)
end

@testset "Declared type names are unique (C08)" begin
    # GraphQL keeps one namespace for type names. Declaring `scalar Entity`,
    # `type Entity` and `input Entity` is three collisions that every validator
    # rejects, and `occursin` assertions alone will not notice them.
    node = TypeDescriptor("Node", [
        FieldDescriptor("id", PrimitiveType("String")),
        FieldDescriptor("children", ListType(ObjectType("Node"))),
        FieldDescriptor("labels", MapType(PrimitiveType("String"), PrimitiveType("String")))
    ])
    svc = ServiceDescriptor("GraphService", "1.0.0", [node], [
        MethodDescriptor("getNode", "String", "Node", http_method="GET"),
        MethodDescriptor("createNode", "Node", "Node", http_method="POST")
    ])
    sdl = emit_graphql_sdl(svc)

    declared = String[]
    for m in eachmatch(r"^(scalar|type|input)\s+([A-Za-z_][A-Za-z0-9_]*)\b"m, sdl)
        push!(declared, String(m.captures[2]))
    end
    @test !isempty(declared)
    # Uniqueness is the property; the exact set membership is incidental.
    @test length(declared) == length(unique(declared))
    @test "Node" in declared
    @test "NodeInput" in declared
    # One capture group in this pattern, so it is `captures[1]` — indexing [2]
    # is a BoundsError, not a comparison.
    @test !("Node" in [String(m.captures[1]) for m in eachmatch(r"^scalar\s+([A-Za-z_][A-Za-z0-9_]*)"m, sdl)])

    # An output type may reference itself as an object; an input type must use
    # the input twin, because an input field cannot be an output object type.
    # Both are correct at once, so the assertions have to be scoped to the
    # respective blocks: forbidding `children: [Node]!` outright was wrong, as
    # `type Node` is supposed to contain exactly that.
    @test occursin("type Node {\n  id: String!\n  children: [Node]!", sdl)
    @test occursin("input NodeInput {\n  id: String!\n  children: [NodeInput]!", sdl)
end
