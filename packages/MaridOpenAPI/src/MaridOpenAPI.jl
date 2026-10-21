# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>

"""
    MaridOpenAPI

OpenAPI 3.1 and JSON Schema 2020-12 generator emitted from `MaridIR.ServiceDescriptor`.

The document is built as data and serialised once by JSON3. The previous
implementation interpolated a document as a string, so any description
containing a quote or a newline produced invalid JSON, two methods sharing a
path produced two `"path"` keys in one object, `:id` parameters appeared
literally in the path template, and no schema components were emitted at all
(`docs/audits/recon-2026-10-21.adoc`, C07).

What this emitter does NOT do yet, so it cannot be mistaken for completeness:
no `oneOf` for nullable beyond `anyOf` with `null`, no `examples`, no
`security`, and no validation against an independent OpenAPI validator in CI.
That validation is the acceptance criterion (`PROJECT_BRIEF.md` §2: "Emitted
specs validate with independent tooling") and belongs to the adapter work.
"""
module MaridOpenAPI

using JSON3
using MaridIR

export emit_openapi_json

const _VOID_SCHEMA = Dict{String, Any}("type" => "null")

"""JSON Schema for one `TypeRef` (OpenAPI 3.1 uses JSON Schema 2020-12)."""
function _json_schema(ref::TypeRef)::Dict{String, Any}
    if ref isa PrimitiveType
        name = ref.name
        name == "String" && return Dict{String, Any}("type" => "string")
        name == "Int32" && return Dict{String, Any}("type" => "integer", "format" => "int32")
        name == "Int64" && return Dict{String, Any}("type" => "integer", "format" => "int64")
        name == "UInt32" && return Dict{String, Any}("type" => "integer", "format" => "uint32", "minimum" => 0)
        name == "UInt64" && return Dict{String, Any}("type" => "integer", "format" => "uint64", "minimum" => 0)
        name == "Float32" && return Dict{String, Any}("type" => "number", "format" => "float")
        name == "Float64" && return Dict{String, Any}("type" => "number", "format" => "double")
        name == "Bool" && return Dict{String, Any}("type" => "boolean")
        name == "Bytes" && return Dict{String, Any}("type" => "string", "format" => "byte")
        name == "Void" && return copy(_VOID_SCHEMA)
        return Dict{String, Any}("type" => "string")
    elseif ref isa ObjectType
        return Dict{String, Any}("\$ref" => "#/components/schemas/$(ref.name)")
    elseif ref isa ListType
        return Dict{String, Any}("type" => "array", "items" => _json_schema(ref.element_type))
    elseif ref isa OptionalType
        # 3.1 has no `nullable`; null is a type in the type union.
        return Dict{String, Any}("anyOf" => Any[_json_schema(ref.inner_type), copy(_VOID_SCHEMA)])
    elseif ref isa MapType
        return Dict{String, Any}("type" => "object",
                                 "additionalProperties" => _json_schema(ref.value_type))
    end
    return Dict{String, Any}()
end

"""`/taxa/:id` -> ("/taxa/{id}", parameters); OpenAPI templates use braces."""
function _openapi_path(m::MethodDescriptor)
    raw = isempty(m.route_path) ? "/$(m.name)" : m.route_path
    parameters = Dict{String, Any}[]
    segments = split(raw, '/')
    for (index, segment) in enumerate(segments)
        startswith(segment, ':') || continue
        name = segment[2:end]
        segments[index] = "{$name}"
        push!(parameters, Dict{String, Any}(
            "name" => name, "in" => "path", "required" => true,
            "schema" => Dict{String, Any}("type" => "string")))
    end
    return join(segments, '/'), parameters
end

function _body_schema(type_name::String)::Dict{String, Any}
    type_name in MaridIR.PRIMITIVE_NAMES && return _json_schema(PrimitiveType(type_name))
    return _json_schema(ObjectType(type_name))
end

"""
    emit_openapi_json(svc::ServiceDescriptor) -> String

Emit an OpenAPI 3.1 specification as pretty-printed JSON.

Paths are merged per operation, `:parameter` segments become `{parameter}`
templates with matching `parameters` entries, object types become
`components.schemas` entries, and verbs that carry a body get a `requestBody`
referencing the method's input type. Every string is escaped by the JSON
serialiser, so a description containing quotes, newlines or non-BMP characters
cannot corrupt the document.
"""
function emit_openapi_json(svc::ServiceDescriptor)::String
    schemas = Dict{String, Any}()
    for t in svc.types
        properties = Dict{String, Any}()
        required = String[]
        for f in t.fields
            properties[f.name] = _json_schema(f.type_ref)
            f.nullable || push!(required, f.name)
        end
        schema = Dict{String, Any}("type" => "object", "properties" => properties)
        isempty(required) || (schema["required"] = required)
        isempty(t.description) || (schema["description"] = t.description)
        schemas[t.name] = schema
    end

    paths = Dict{String, Any}()
    for m in svc.methods
        path, parameters = _openapi_path(m)
        verb = lowercase(m.http_method)
        operation = Dict{String, Any}(
            "operationId" => m.name,
            "responses" => Dict{String, Any}(
                "200" => Dict{String, Any}(
                    "description" => "Successful operation",
                    "content" => Dict{String, Any}(
                        "application/json" => Dict{String, Any}(
                            "schema" => _body_schema(m.output_type)))),
                "default" => Dict{String, Any}(
                    "description" => "Error (RFC 9457 problem details)",
                    "content" => Dict{String, Any}(
                        "application/problem+json" => Dict{String, Any}(
                            "schema" => Dict{String, Any}("type" => "object"))))))
        isempty(m.description) || (operation["summary"] = m.description)
        isempty(parameters) || (operation["parameters"] = parameters)
        if !(uppercase(m.http_method) in ("GET", "HEAD", "DELETE", "OPTIONS")) && m.input_type != "Void"
            operation["requestBody"] = Dict{String, Any}(
                "required" => true,
                "content" => Dict{String, Any}(
                    "application/json" => Dict{String, Any}(
                        "schema" => _body_schema(m.input_type))))
        end
        # Merge per operation instead of appending a second "path" key.
        entry = get!(paths, path, Dict{String, Any}())
        entry[verb] = operation
    end

    document = Dict{String, Any}(
        "openapi" => "3.1.0",
        "info" => Dict{String, Any}(
            "title" => svc.name, "version" => svc.version,
            "description" => svc.description),
        "paths" => paths)
    isempty(schemas) || (document["components"] = Dict{String, Any}("schemas" => schemas))
    return JSON3.pretty(document)
end

end # module MaridOpenAPI
