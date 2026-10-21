# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>

"""
    MaridRPC

JSON-RPC 2.0 bindings for Marid.

Scope and limits, stated up front so they cannot be mistaken for protocol
support: this is in-process request/response dispatch. It implements the single
request form (success, method-not-found, invalid-request, internal-error) and
NOTIFICATION bodies are not handled; batching is not implemented; there is no
transport, no MCP lifecycle and no independent client interoperating with it.
`PROJECT_BRIEF.md` §2 and `docs/audits/recon-2026-10-21.adoc` (C06) record that
gap; do not describe this module as JSON-RPC conformance.
"""
module MaridRPC

using MaridIR
using MaridCodec

export RpcRequest, RpcResponse, dispatch_rpc

struct RpcRequest
    jsonrpc::String
    method::String
    params::Dict{String, Any}
    id::Union{Int, String, Nothing}
end

struct RpcResponse
    jsonrpc::String
    # `Any`: JSON-RPC results are any JSON value (object, array, string, number,
    # boolean, null). The previous `Union{Dict{String,Any}, Nothing}` could not
    # carry a scalar or an array at all, so a conforming handler's result was a
    # MethodError rather than a response.
    result::Any
    error::Union{Dict{String, Any}, Nothing}
    id::Union{Int, String, Nothing}
end

"""
    dispatch_rpc(req::RpcRequest, registry::Dict{String,<:Function}) -> RpcResponse

Dispatch one JSON-RPC 2.0 request against `registry`.

Internal failures return the fixed message `"Internal error"` and code `-32603`;
the exception is logged server-side with the request id but is NEVER serialised
into the response. The HTTP transport in `MaridCore.ext.MaridHTTPJSONExt`
redacts 500s for the same reason, and leaking handler internals through the RPC
path would undo that.
"""
function dispatch_rpc(req::RpcRequest, registry::Dict{String, <:Function})::RpcResponse
    req.jsonrpc != "2.0" && return RpcResponse(
        "2.0", nothing,
        Dict{String, Any}("code" => -32600, "message" => "Invalid Request"), req.id)

    if haskey(registry, req.method)
        handler = registry[req.method]
        try
            return RpcResponse("2.0", handler(req.params), nothing, req.id)
        catch err
            # Detail goes to the log, keyed by the request id; the client gets a
            # fixed string. See C06 in docs/audits/recon-2026-10-21.adoc.
            @error "MaridRPC handler failed" rpc_method = req.method rpc_id = req.id exception = (err, catch_backtrace())
            return RpcResponse("2.0", nothing,
                Dict{String, Any}("code" => -32603, "message" => "Internal error"), req.id)
        end
    end

    return RpcResponse("2.0", nothing,
        Dict{String, Any}("code" => -32601, "message" => "Method not found"), req.id)
end

end # module MaridRPC
