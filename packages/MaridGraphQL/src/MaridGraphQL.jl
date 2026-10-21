# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>

"""
    MaridGraphQL

GraphQL SDL generation from `MaridIR.ServiceDescriptor`, plus a deliberately
minimal introspection-shaped response.

Status, stated so it cannot be mistaken for protocol support: there is no
parser, no validation, no resolver runtime, and no execution. `execute_graphql_query`
answers a `__schema` request with a hand-built object and returns an empty
`data` object for everything else. That is NOT GraphQL introspection conformance
and NOT an executor (`PROJECT_BRIEF.md` §2; `docs/audits/recon-2026-10-21.adoc`,
C08).

The SDL this module emits is meant to be *valid*: it always declares a query
type (a schema without one is rejected by every GraphQL tool), it never names a
built-in scalar that GraphQL does not define, and where Marid's type system has
no GraphQL counterpart (`Void`, `Bytes`, `UInt64`) it declares the custom scalar
it uses rather than silently mapping to `String`.
"""
module MaridGraphQL

using MaridIR

export emit_graphql_sdl, execute_graphql_query

# Marid primitive -> GraphQL type, with the loss stated where there is one.
const _SCALAR_MAP = Dict{String, String}(
    "String" => "String",
    "Bool" => "Boolean",
    "Int32" => "Int",
    "Int64" => "Int",          # lossy above 2^53; documented in the SDL comment
    "Float32" => "Float",
    "Float64" => "Float",
    "UInt32" => "Int",         # fits in Int32's positive half only
    "UInt64" => "UInt64",      # custom scalar: GraphQL Int is signed 32-bit
    "Bytes" => "Bytes",        # custom scalar: base64-encoded string
    "Void" => "Void",          # custom scalar: always null
)

# Custom scalars actually referenced by a schema.
function _scalar_declarations(svc::ServiceDescriptor)::Vector{String}
    used = Set{String}()
    for t in svc.types
        for f in t.fields
            _collect_scalars!(used, f.type_ref)
        end
    end
    # Only PRIMITIVES may contribute a scalar declaration. Taking
    # `get(_SCALAR_MAP, name, name)` for a method's input/output type pushed the
    # raw name through for anything unmapped, so an object type `Entity` became
    # `scalar Entity` — a second declaration of a name also used by `type
    # Entity`, which makes the schema invalid (GraphQL has one namespace for
    # type names). An object type is never a scalar.
    for m in svc.methods
        for type_name in (m.input_type, m.output_type)
            type_name in MaridIR.PRIMITIVE_NAMES || continue
            push!(used, get(_SCALAR_MAP, type_name, "String"))
        end
    end
    # Mapped-to-builtin: GraphQL defines these, so no declaration is needed.
    for builtin in ("Int", "Float", "String", "Boolean", "ID")
        delete!(used, builtin)
    end
    declared = String[]
    for name in sort!(collect(used))
        name in ("String", "Boolean", "Int", "Float", "ID") && continue
        push!(declared, "scalar $name")
    end
    return declared
end

function _collect_scalars!(used::Set{String}, ref::TypeRef)
    if ref isa PrimitiveType
        push!(used, get(_SCALAR_MAP, ref.name, ref.name))
    elseif ref isa ListType
        _collect_scalars!(used, ref.element_type)
    elseif ref isa OptionalType
        _collect_scalars!(used, ref.inner_type)
    elseif ref isa MapType
        push!(used, "JSON")
        _collect_scalars!(used, ref.value_type)
    end
    return used
end

function _type_name(ref::TypeRef)::String
    if ref isa PrimitiveType
        return get(_SCALAR_MAP, ref.name, "String")
    elseif ref isa ObjectType
        return ref.name
    elseif ref isa ListType
        return "[" * _type_name(ref.element_type) * "]"
    elseif ref isa OptionalType
        return _type_name(ref.inner_type)
    elseif ref isa MapType
        return "JSON"
    else
        return "String"
    end
end

"""
`TypeRef` field with `!` where the field is non-nullable.

`Void` is never non-null: it is declared as "always null", so `Void!` would be a
field no resolver could ever satisfy.
"""
function _field_type(f::FieldDescriptor)::String
    name = _type_name(f.type_ref)
    nullable = f.nullable || f.type_ref isa OptionalType || _is_void(f.type_ref)
    return nullable ? name : name * "!"
end

_is_void(ref::TypeRef) = ref isa PrimitiveType && ref.name == "Void"

"""
    emit_graphql_sdl(svc::ServiceDescriptor) -> String

Emit GraphQL SDL from a service descriptor.

Methods with `GET` become `Query` fields, everything else `Mutation` fields.
A `Query` type is always emitted (with a placeholder field when no method maps
to it), because a schema without a query type is invalid. Argument types are
declared as input objects with distinct `<Name>Input` names and real fields, so
the output validates rather than merely rendering: GraphQL forbids two types
sharing a name and forbids an input object with no fields.
"""
function emit_graphql_sdl(svc::ServiceDescriptor)::String
    lines = String[]
    push!(lines, "# Generated by MaridIR/MaridGraphQL from $(svc.name) v$(svc.version); do not edit.")
    push!(lines, "# Int64/UInt32 are emitted as Int (GraphQL Int is signed 32-bit);")
    push!(lines, "# UInt64, Bytes and Void are custom scalars declared below.")
    push!(lines, "")

    scalars = _scalar_declarations(svc)
    if !isempty(scalars)
        append!(lines, scalars)
        push!(lines, "")
    end

    for t in svc.types
        push!(lines, "type $(t.name) {")
        for f in t.fields
            push!(lines, "  $(f.name): $(_field_type(f))")
        end
        push!(lines, "}")
        push!(lines, "")
    end

    queries = filter(m -> uppercase(m.http_method) == "GET", svc.methods)
    mutations = filter(m -> uppercase(m.http_method) != "GET", svc.methods)

    # Input objects, so arguments have declared types.
    #
    # A GraphQL input object needs its own name and at least one field. Emitting
    # `input Entity` for a descriptor that also emits `type Entity` declared one
    # name twice, and the bare declaration had no fields at all — invalid on both
    # counts. Inputs are therefore named `<Name>Input`, carry the type's fields,
    # and object references inside them point at the matching input type.
    by_name = Dict{String, TypeDescriptor}(t.name => t for t in svc.types)
    input_types = _input_object_names(svc, by_name)
    for name in sort!(collect(input_types))
        push!(lines, "input $(_input_name(name)) {")
        t = by_name[name]
        if isempty(t.fields)
            # GraphQL forbids an input object with no fields. An empty message
            # type is still reachable, so declare one inert field rather than
            # emit an invalid block.
            push!(lines, "  _empty: Boolean")
        else
            for f in t.fields
                push!(lines, "  $(f.name): $(_input_field_type(f.type_ref, f.nullable))")
            end
        end
        push!(lines, "}")
        push!(lines, "")
    end

    push!(lines, "type Query {")
    if isempty(queries)
        # A valid schema always has a query type with at least one field.
        push!(lines, "  _empty: Boolean")
    else
        for q in queries
            push!(lines, "  $(q.name)$(_argument_list(q)): $(_body_type(q.output_type))")
        end
    end
    push!(lines, "}")
    push!(lines, "")

    if !isempty(mutations)
        push!(lines, "type Mutation {")
        for m in mutations
            push!(lines, "  $(m.name)$(_argument_list(m)): $(_body_type(m.output_type))")
        end
        push!(lines, "}")
        push!(lines, "")
    end

    return join(lines, "\n")
end

"Name of the input-object twin of an object type, kept distinct from `type X`."
_input_name(type_name::String)::String = type_name * "Input"

"""
Object types reachable as *inputs*, transitively.

An input field cannot reference an output object type, so every object a method
consumes — including ones nested inside a field — needs an `input` twin
declaration or the reference dangles.
"""
function _input_object_names(svc::ServiceDescriptor, by_name::Dict{String, TypeDescriptor})::Set{String}
    found = Set{String}()
    pending = String[]
    for m in svc.methods
        m.input_type in keys(by_name) && push!(pending, m.input_type)
    end
    while !isempty(pending)
        name = pop!(pending)
        name in found && continue
        push!(found, name)
        for f in by_name[name].fields
            _collect_object_names!(pending, f.type_ref, by_name)
        end
    end
    return found
end

function _collect_object_names!(pending::Vector{String}, ref::TypeRef, by_name::Dict{String, TypeDescriptor})
    if ref isa ObjectType
        ref.name in keys(by_name) && push!(pending, ref.name)
    elseif ref isa ListType
        _collect_object_names!(pending, ref.element_type, by_name)
    elseif ref isa OptionalType
        _collect_object_names!(pending, ref.inner_type, by_name)
    elseif ref isa MapType
        _collect_object_names!(pending, ref.value_type, by_name)
    end
    return pending
end

"Input-field type: primitives map to scalars, objects to their input twins."
function _input_field_type(ref::TypeRef, nullable::Bool)::String
    name = _input_type_name(ref)
    optional = nullable || ref isa OptionalType || _is_void(ref)
    return optional ? name : name * "!"
end

function _input_type_name(ref::TypeRef)::String
    if ref isa PrimitiveType
        return get(_SCALAR_MAP, ref.name, "String")
    elseif ref isa ObjectType
        # `ID` is a GraphQL built-in scalar, but it is not a primitive in the
        # IR, so a descriptor writes it as `ObjectType("ID")`. It must stay
        # `ID` in an input field: `IDInput` would reference a type that is
        # never declared.
        ref.name == "ID" && return "ID"
        return _input_name(ref.name)
    elseif ref isa ListType
        return "[" * _input_type_name(ref.element_type) * "]"
    elseif ref isa OptionalType
        return _input_type_name(ref.inner_type)
    elseif ref isa MapType
        return "JSON"
    end
    return "String"
end

function _body_type(type_name::String)::String
    type_name in MaridIR.PRIMITIVE_NAMES && return get(_SCALAR_MAP, type_name, "String")
    return type_name
end

function _argument_list(m::MethodDescriptor)::String
    m.input_type == "Void" && return ""
    if m.input_type in MaridIR.PRIMITIVE_NAMES
        return "(input: " * get(_SCALAR_MAP, m.input_type, "String") * ")"
    end
    # `ID` reads as an ObjectType here (it is not an IR primitive) but is a
    # GraphQL built-in scalar. Without this it becomes `IDInput`, which no
    # declaration ever introduces.
    m.input_type == "ID" && return "(input: ID)"
    return "(input: $(_input_name(m.input_type)))"
end

"""
    execute_graphql_query(query_str::String, svc::ServiceDescriptor) -> Dict{String,Any}

Answer a `__schema` query with a minimal, introspection-*shaped* object; every
other query returns an empty `data` object.

This is a placeholder, not an executor: it does not parse the query, does not
honour field selection, and does not implement the `__Type` shape or
`__typename`. Callers must not describe it as GraphQL support.
"""
function execute_graphql_query(query_str::String, svc::ServiceDescriptor)::Dict{String, Any}
    if occursin("__schema", query_str)
        types = Any[]
        for t in svc.types
            push!(types, Dict{String, Any}("kind" => "OBJECT", "name" => t.name))
        end
        push!(types, Dict{String, Any}("kind" => "OBJECT", "name" => "Query"))
        return Dict{String, Any}("data" => Dict{String, Any}(
            "__schema" => Dict{String, Any}(
                "queryType" => Dict{String, Any}("name" => "Query"),
                "types" => types)))
    end
    return Dict{String, Any}("data" => Dict{String, Any}())
end

end # module MaridGraphQL
