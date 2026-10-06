# SPDX-License-Identifier: MPL-2.0
using HTTP
export TransportRequest, TransportResponse, serve_http, listening_port

struct TransportRequest
    method::String
    path::String
    headers::Vector{Pair{String,String}}
    body::Vector{UInt8}
end
struct TransportResponse
    status::Int
    headers::Vector{Pair{String,String}}
    body::Vector{UInt8}
end
TransportResponse(status::Int, headers, body::AbstractString) =
    TransportResponse(status, headers, Vector{UInt8}(codeunits(body)))

"Return the actual socket port, including an OS-assigned ephemeral port."
listening_port(server) = Int(Sockets.getsockname(server.listener.server)[2])

function _transport_error(status, title)
    TransportResponse(status, ["Content-Type" => "application/problem+json", "Connection" => "close"],
        "{\"type\":\"about:blank\",\"title\":\"$title\",\"status\":$status}")
end

function _read_request(stream, max_body_bytes)
    req = stream.message
    uri = HTTP.URI(req.target)
    path = String(uri.path)
    # Canonical raw paths only: do not normalize/percent-decode behind governance.
    if !startswith(req.target, "/") || startswith(path, "//") || occursin("//", path) ||
       (path != "/" && endswith(path, "/")) || occursin('%', path) || occursin('\\', path) ||
       occursin('#', req.target) || any(s -> s in (".", ".."), split(path, '/'))
        return _transport_error(400, "Non-canonical path")
    end
    body = UInt8[]
    while !eof(stream)
        # At most max_body_bytes + 1 is buffered, including for chunked bodies.
        chunk = read(stream, min(8192, max_body_bytes + 1 - length(body)))
        append!(body, chunk)
        length(body) > max_body_bytes && return _transport_error(413, "Payload Too Large")
    end
    return TransportRequest(req.method, path, copy(req.headers), body)
end

"""
    serve_http(handler; host="127.0.0.1", port=6274, max_body_bytes=1048576,
               readtimeout=5, on_shutdown=nothing)

Start an HTTP.jl HTTP/1.1 listener and return its closable server handle. `handler`
receives transport-owned values, never an HTTP.jl request. Non-canonical paths and
oversized bodies are rejected before it runs; exceptions while reading a request or
running the handler produce a generic 500 response. `on_shutdown` is passed to the
listener.

Throw `ArgumentError` unless `max_body_bytes` is positive and below `typemax(Int)`,
or when `readtimeout` is not positive. This is bounded unary HTTP, not SSE, WebSocket
or HTTP/2 support. Use `0.0.0.0` explicitly for container deployment.
"""
function serve_http(handler::Function; host="127.0.0.1", port::Integer=6274,
                    max_body_bytes::Integer=1048576, readtimeout::Integer=5, on_shutdown=nothing)
    0 < max_body_bytes < typemax(Int) || throw(ArgumentError("Invalid body limit"))
    readtimeout > 0 || throw(ArgumentError("Read timeout must be positive"))
    return HTTP.serve!(host, port; stream=true, readtimeout, on_shutdown, verbose=-1) do stream
        response = try
            request = _read_request(stream, max_body_bytes)
            request isa TransportResponse ? request : handler(request)
        catch
            _transport_error(500, "Internal Server Error")
        end
        HTTP.setstatus(stream, response.status)
        for pair in response.headers
            HTTP.setheader(stream, pair)
        end
        HTTP.setheader(stream, "Content-Length" => string(length(response.body)))
        HTTP.startwrite(stream)
        if stream.message.method != "HEAD"
            write(stream, response.body)
        end
    end
end
