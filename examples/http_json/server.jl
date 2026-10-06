# SPDX-License-Identifier: MPL-2.0
include("app.jl")
app, _ = build_example()
server = serve_json(app; host=get(ENV, "MARID_HOST", "127.0.0.1"),
    port=parse(Int, get(ENV, "MARID_PORT", "6274")))
println("Unary HTTP/JSON example ready (experimental, no persistence/authentication)")
try
    wait(server)
finally
    app.is_draining = true
    app.is_ready = false
    close(server)
end
