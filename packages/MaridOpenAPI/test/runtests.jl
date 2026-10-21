# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>

using Test
using JSON3
using MaridIR
using MaridOpenAPI

@testset "MaridOpenAPI Tests" begin
    m = MethodDescriptor("getTaxon", "String", "Taxon", route_path="/taxon/:id",
                         http_method="GET", description="Retrieve taxon")
    svc = ServiceDescriptor("TaxonomyService", "1.0.0", TypeDescriptor[], [m])

    spec = emit_openapi_json(svc)

    @test occursin("\"openapi\": \"3.1.0\"", spec)
    @test occursin("\"title\": \"TaxonomyService\"", spec)
    @test occursin("\"operationId\": \"getTaxon\"", spec)
end

@testset "Spec is valid JSON and OpenAPI-shaped (C07)" begin
    taxon = TypeDescriptor("Taxon", [
        FieldDescriptor("id", PrimitiveType("String")),
        FieldDescriptor("name", PrimitiveType("String"), nullable=true),
        FieldDescriptor("children", ListType(ObjectType("Taxon")))
    ], description="A clade \"node\"\nsecond line — λ 🐟")
    svc = ServiceDescriptor("TaxonomyService", "1.0.0", [taxon], [
        MethodDescriptor("getTaxon", "String", "Taxon", route_path="/taxon/:id",
                         http_method="GET", description="Get \"one\" taxon\nplease"),
        MethodDescriptor("deleteTaxon", "String", "Void", route_path="/taxon/:id",
                         http_method="DELETE"),
        MethodDescriptor("createTaxon", "Taxon", "Taxon", route_path="/taxon",
                         http_method="POST")
    ])

    spec = emit_openapi_json(svc)
    # 1. It parses. Interpolation of the description above used to break this.
    doc = JSON3.read(spec)
    @test doc.openapi == "3.1.0"

    # 2. :id became an OpenAPI template, and the parameter is declared.
    get_op = doc.paths[Symbol("/taxon/{id}")]["get"]
    @test get_op.operationId == "getTaxon"
    @test get_op.parameters[1].name == "id"
    @test get_op.parameters[1].in == "path"
    @test get_op.parameters[1].required == true

    # 3. Two verbs on one path are merged into one path item, not two keys.
    @test haskey(doc.paths[Symbol("/taxon/{id}")], :delete)
    # Path order is a Dict's, so compare as a set rather than as a sequence.
    @test Set(keys(doc.paths)) == Set([Symbol("/taxon"), Symbol("/taxon/{id}")])

    # 4. Request bodies appear only where a body is expected.
    @test haskey(doc.paths[Symbol("/taxon")]["post"], :requestBody)
    @test !haskey(doc.paths[Symbol("/taxon/{id}")]["delete"], :requestBody)

    # 5. Descriptions survive escaping intact.
    @test occursin("second line", String(doc.components.schemas[:Taxon].description))

    # 6. Object types are referenced from components, not inlined as strings.
    ok = doc.paths[Symbol("/taxon/{id}")]["get"].responses[Symbol("200")].content[Symbol("application/json")].schema
    @test ok[Symbol("\$ref")] == "#/components/schemas/Taxon"
    @test doc.components.schemas[:Taxon].properties[:children].type == "array"
end
