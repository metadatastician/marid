# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>

"""
    MaridIR

Canonical Intermediate Representation (IR) for the Marid framework.
Defines pure data models for services, methods, types, streaming semantics,
and annotations.
Zero dependencies.
"""
module MaridIR

export FieldDescriptor, TypeDescriptor, MethodDescriptor, ServiceDescriptor,
       StreamingMode, Unary, ServerStreaming, ClientStreaming, BidirectionalStreaming,
       TypeRef, PrimitiveType, ObjectType, ListType, MapType, OptionalType,
       Annotation, validate_service, to_dict, emit_proto,
       emit_capability_spec

@enum StreamingMode begin
    Unary
    ServerStreaming
    ClientStreaming
    BidirectionalStreaming
end

abstract type TypeRef end

struct PrimitiveType <: TypeRef
    name::String # Int32, Int64, UInt32, UInt64, Float32, Float64, String, Bool, Bytes, Void
end

struct ObjectType <: TypeRef
    name::String
end

struct ListType <: TypeRef
    element_type::TypeRef
end

struct MapType <: TypeRef
    key_type::TypeRef
    value_type::TypeRef
end

struct OptionalType <: TypeRef
    inner_type::TypeRef
end

struct Annotation
    name::String
    value::String
end

struct FieldDescriptor
    name::String
    type_ref::TypeRef
    nullable::Bool
    description::String
    annotations::Vector{Annotation}
end

FieldDescriptor(name::String, type_ref::TypeRef; nullable::Bool=false, description::String="", annotations::Vector{Annotation}=Annotation[]) =
    FieldDescriptor(name, type_ref, nullable, description, annotations)

# Convenience constructor from type name string
function FieldDescriptor(name::String, type_name::String; nullable::Bool=false, description::String="", annotations::Vector{Annotation}=Annotation[])
    primitives = ["String", "Int32", "Int64", "UInt32", "UInt64", "Float32", "Float64", "Bool", "Bytes", "Void"]
    ref = type_name in primitives ? PrimitiveType(type_name) : ObjectType(type_name)
    FieldDescriptor(name, ref, nullable, description, annotations)
end

struct TypeDescriptor
    name::String
    fields::Vector{FieldDescriptor}
    description::String
    annotations::Vector{Annotation}
end

TypeDescriptor(name::String, fields::Vector{FieldDescriptor}; description::String="", annotations::Vector{Annotation}=Annotation[]) =
    TypeDescriptor(name, fields, description, annotations)

struct MethodDescriptor
    name::String
    input_type::String
    output_type::String
    streaming::StreamingMode
    route_path::String
    http_method::String
    description::String
    annotations::Vector{Annotation}
end

MethodDescriptor(name::String, input_type::String, output_type::String;
                 streaming::StreamingMode=Unary, route_path::String="", http_method::String="POST",
                 description::String="", annotations::Vector{Annotation}=Annotation[]) =
    MethodDescriptor(name, input_type, output_type, streaming, route_path, http_method, description, annotations)

struct ServiceDescriptor
    name::String
    version::String
    types::Vector{TypeDescriptor}
    methods::Vector{MethodDescriptor}
    description::String
    annotations::Vector{Annotation}
end

ServiceDescriptor(name::String, version::String, types::Vector{TypeDescriptor}, methods::Vector{MethodDescriptor};
                  description::String="", annotations::Vector{Annotation}=Annotation[]) =
    ServiceDescriptor(name, version, types, methods, description, annotations)

const PRIMITIVE_NAMES = ("String", "Int32", "Int64", "UInt32", "UInt64",
                         "Float32", "Float64", "Bool", "Bytes", "Void")

"""
    _validate_type_ref(ref::TypeRef, known::Set{String}, where_::String)

Reject a field's `TypeRef` that names something the descriptor does not define.

`validate_service` previously checked method input/output types but never looked
inside a field, so `FieldDescriptor("x", ObjectType("Typo"))`, a `ListType` of an
unknown object, or a `MapType` keyed by a non-`String` all passed validation and
only failed later, in an emitter (`docs/audits/recon-2026-10-21.adoc`, C23).
Object names are checked after every type name is collected, so a recursive type
(`Node` holding `ListType(ObjectType("Node"))`) is legal.
"""
function _validate_type_ref(ref::TypeRef, known::Set{String}, where_::String)
    if ref isa PrimitiveType
        ref.name in PRIMITIVE_NAMES ||
            error("Unknown primitive type '$(ref.name)' in $where_")
    elseif ref isa ObjectType
        ref.name in known ||
            error("Unknown type '$(ref.name)' in $where_")
    elseif ref isa ListType
        _validate_type_ref(ref.element_type, known, where_)
    elseif ref isa OptionalType
        _validate_type_ref(ref.inner_type, known, where_)
    elseif ref isa MapType
        # JSON objects have string keys; a map keyed by anything else has no
        # JSON form, so reject it at the descriptor rather than at the encoder.
        (ref.key_type isa PrimitiveType && ref.key_type.name == "String") ||
            error("Map keys must be PrimitiveType(\"String\") in $where_")
        _validate_type_ref(ref.value_type, known, where_)
    else
        error("Unsupported TypeRef kind $(typeof(ref)) in $where_")
    end
    return nothing
end

"""
    validate_service(svc::ServiceDescriptor) -> Bool

Validates type references, detects duplicate field/type/method names,
and ensures route paths are valid.
"""
function validate_service(svc::ServiceDescriptor)::Bool
    isempty(svc.name) && error("Service name cannot be empty")
    isempty(svc.version) && error("Service version cannot be empty")
    
    # Check duplicate types
    type_names = Set{String}()
    for t in svc.types
        t.name in type_names && error("Duplicate type name: $(t.name)")
        push!(type_names, t.name)
        
        # Check duplicate fields inside type
        field_names = Set{String}()
        for f in t.fields
            f.name in field_names && error("Duplicate field '$(f.name)' in type '$(t.name)'")
            push!(field_names, f.name)
        end
    end
    
    primitives = Set{String}(PRIMITIVE_NAMES)
    all_known = union(type_names, primitives)

    # Field-level TypeRefs, now that every type name is known (a type may refer
    # to itself, so this cannot live in the loop above).
    for t in svc.types
        for f in t.fields
            _validate_type_ref(f.type_ref, type_names, "field '$(f.name)' of type '$(t.name)'")
        end
    end
    
    # Check method signatures
    method_names = Set{String}()
    route_paths = Set{Tuple{String, String}}() # (method, path)
    for m in svc.methods
        m.name in method_names && error("Duplicate method name: $(m.name)")
        push!(method_names, m.name)
        
        !(m.input_type in all_known) && error("Unknown input type '$(m.input_type)' in method '$(m.name)'")
        !(m.output_type in all_known) && error("Unknown output type '$(m.output_type)' in method '$(m.name)'")
        
        if !isempty(m.route_path)
            startswith(m.route_path, "/") || error("Route must start with /: $(m.route_path)")
            (occursin("//", m.route_path) || (m.route_path != "/" && endswith(m.route_path, "/"))) &&
                error("Use canonical routes (no repeated/trailing slash): $(m.route_path)")
            key = (uppercase(m.http_method), m.route_path)
            key in route_paths && error("Route path collision: $(m.http_method) $(m.route_path)")
            push!(route_paths, key)
        end
    end
    
    return true
end

# Composite TypeRefs used to collapse to the literal string "Complex", which
# made the "golden dictionary" lossy for three of the five TypeRef kinds and
# impossible to round-trip (`docs/audits/recon-2026-10-21.adoc`, C23). A
# composite now keeps its shape: {"list" => ...}, {"optional" => ...},
# {"map" => {"key" => ..., "value" => ...}}.
function _type_ref_to_dict(ref::TypeRef)::Any
    if ref isa PrimitiveType
        return ref.name
    elseif ref isa ObjectType
        return ref.name
    elseif ref isa ListType
        return Dict{String, Any}("list" => _type_ref_to_dict(ref.element_type))
    elseif ref isa OptionalType
        return Dict{String, Any}("optional" => _type_ref_to_dict(ref.inner_type))
    elseif ref isa MapType
        return Dict{String, Any}("map" => Dict{String, Any}(
            "key" => _type_ref_to_dict(ref.key_type),
            "value" => _type_ref_to_dict(ref.value_type)))
    end
    # Fail loudly rather than emit a placeholder. Returning a marker string here
    # would reproduce the exact defect this function replaced: a descriptor that
    # renders to something lossy and indistinguishable from real data. A
    # `TypeRef` subtype this file does not know how to serialise is a bug in the
    # type system, not a document to be published.
    error("Unsupported TypeRef kind $(typeof(ref)); cannot serialise it losslessly")
end

# Serialization to pure Dict (golden testable)
function to_dict(svc::ServiceDescriptor)::Dict{String, Any}
    Dict{String, Any}(
        "name" => svc.name,
        "version" => svc.version,
        "description" => svc.description,
        "types" => [
            Dict{String, Any}(
                "name" => t.name,
                "description" => t.description,
                "fields" => [
                    Dict{String, Any}(
                        "name" => f.name,
                        "type" => _type_ref_to_dict(f.type_ref),
                        "nullable" => f.nullable,
                        "description" => f.description
                    ) for f in t.fields
                ]
            ) for t in svc.types
        ],
        "methods" => [
            Dict{String, Any}(
                "name" => m.name,
                "input_type" => m.input_type,
                "output_type" => m.output_type,
                "streaming" => string(m.streaming),
                "route_path" => m.route_path,
                "http_method" => m.http_method,
                "description" => m.description
            ) for m in svc.methods
        ]
    )
end

include("proto.jl")
include("capability.jl")

end # module MaridIR
