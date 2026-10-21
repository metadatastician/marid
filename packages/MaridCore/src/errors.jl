# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>

"""
    MaridCore.Errors

RFC 9457 Problem Details and stable domain error hierarchy for Marid.
"""

export MaridError, NotFoundError, ValidationError, UnauthorizedError,
       ConflictError, TimeoutError, InternalError,
       status_code, problem_details, error_slug

abstract type MaridError <: Exception end

struct NotFoundError <: MaridError
    message::String
    resource::String
    identifier::String
end

NotFoundError(resource::String, id::String) =
    NotFoundError("Resource '$resource' with identifier '$id' not found.", resource, id)

struct ValidationError <: MaridError
    message::String
    field::String
    reason::String
end

struct UnauthorizedError <: MaridError
    message::String
    realm::String
end

UnauthorizedError(msg::String="Unauthorized access.") = UnauthorizedError(msg, "default")

struct ConflictError <: MaridError
    message::String
    resource::String
    revision::String
end

struct TimeoutError <: MaridError
    message::String
    elapsed_ms::Float64
end

struct InternalError <: MaridError
    message::String
    cause::Union{Nothing, Exception}
end

InternalError(msg::String) = InternalError(msg, nothing)

# Status code mappings
status_code(::NotFoundError) = 404
status_code(::ValidationError) = 400
status_code(::UnauthorizedError) = 401
status_code(::ConflictError) = 409
status_code(::TimeoutError) = 504
status_code(::InternalError) = 500
status_code(::MaridError) = 500

# A stable slug per error kind. RFC 9457 `type` identifies the PROBLEM KIND; a
# URI built from `typeof(err)` produced
# "https://marid.hyperpolymath.org/errors/MaridCore.NotFoundError", which is not
# stable (a module rename changes the URI) and is not a human-readable title
# (recon-2026-10-21, C10).
error_slug(::NotFoundError) = "not-found"
error_slug(::ValidationError) = "validation"
error_slug(::UnauthorizedError) = "unauthorized"
error_slug(::ConflictError) = "conflict"
error_slug(::TimeoutError) = "timeout"
error_slug(::InternalError) = "internal"
error_slug(::MaridError) = "error"

const _ERROR_TITLES = Dict{String, String}(
    "not-found" => "Not Found",
    "validation" => "Validation Failed",
    "unauthorized" => "Unauthorized",
    "conflict" => "Conflict",
    "timeout" => "Gateway Timeout",
    "internal" => "Internal Server Error",
    "error" => "Error",
)

"""
    problem_details(err::MaridError; instance::String="", trace_id=nothing) -> Dict{String,Any}

Map a domain error to an RFC 9457 problem detail object.

`type` is `https://marid.hyperpolymath.org/problems/<slug>` where `<slug>` is
stable across renames, `title` is the HTTP reason phrase for the kind, `detail`
is the message, and `trace_id` (when given) is carried as an extension member so
a client can quote a request id in a bug report without exposing internals.
"""
function problem_details(err::MaridError; instance::String="",
                         trace_id::Union{Nothing, String}=nothing)::Dict{String, Any}
    slug = error_slug(err)
    document = Dict{String, Any}(
        "type" => "https://marid.hyperpolymath.org/problems/$slug",
        "title" => get(_ERROR_TITLES, slug, "Error"),
        "status" => status_code(err),
        "detail" => err.message,
        "instance" => isempty(instance) ? "/problems/$slug" : instance
    )
    trace_id === nothing || (document["trace_id"] = trace_id)
    return document
end
