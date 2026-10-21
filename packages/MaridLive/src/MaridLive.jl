# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>

"""
    MaridLive

HTML-first live helpers for HTMX, Hotwire Turbo Streams, and Datastar over SSE.

These functions build wire fragments: an attribute, an HTML element, a response
header, an SSE block. Two rules apply to every one of them:

* Anything that becomes JSON is written by JSON3, never by string interpolation.
  The previous `"\"$k\": \"$v\""` form produced invalid JSON for any value
  containing a quote, and non-JSON Julia syntax for non-strings
  (`docs/audits/recon-2026-10-21.adoc`, C09).
* Anything that becomes an HTML attribute is escaped, and anything that becomes
  a header value is rejected if it contains CR or LF, so a value cannot break out
  of its context.

There is no browser evidence for these helpers: they are string builders with
unit tests (`PROJECT_BRIEF.md` §2 requires real-browser acceptance for Phase 5).
"""
module MaridLive

using JSON3

export hx_swap_oob, hx_trigger_header, hx_push_url_header, format_htmx_sse,
       turbo_stream, turbo_append, turbo_replace, turbo_update, turbo_remove,
       datastar_merge_fragments, datastar_merge_signals, datastar_remove_fragments

const _TURBO_ACTIONS = ("append", "prepend", "replace", "update", "remove", "before", "after")
const _HX_SWAP_MODES = ("outerHTML", "innerHTML", "beforebegin", "afterbegin",
                        "beforeend", "afterend", "delete", "none")

"Reject CR/LF in a header value rather than emit a response-splitting vector."
function _header_value(value::AbstractString, field::AbstractString)::String
    (occursin('\r', value) || occursin('\n', value)) &&
        throw(ArgumentError("$field must not contain CR or LF"))
    return String(value)
end

"Escape a value for use inside a double-quoted HTML attribute."
function _attr(value::AbstractString)::String
    return replace(String(value),
        '&' => "&amp;", '<' => "&lt;", '>' => "&gt;",
        '"' => "&quot;", '\'' => "&#39;")
end

# 1. HTMX Helpers
"""
    hx_swap_oob(html::String, target_id::String; swap_mode::String="outerHTML") -> String

Wrap an HTML fragment for an out-of-band swap. `target_id` is escaped and
`swap_mode` must be one of HTMX's swap styles.
"""
function hx_swap_oob(html::String, target_id::String; swap_mode::String="outerHTML")::String
    swap_mode in _HX_SWAP_MODES ||
        throw(ArgumentError("Unknown hx-swap-oob mode: $swap_mode"))
    return "<div id=\"$(_attr(target_id))\" hx-swap-oob=\"$swap_mode\">$html</div>"
end

"""
    hx_trigger_header(event_name::String; data=nothing) -> Pair{String,String}

Build the `HX-Trigger` response header. With `data`, the value is
`{"<event_name>": {<data>}}` encoded by JSON3.
"""
function hx_trigger_header(event_name::String; data::Union{Nothing, AbstractDict}=nothing)::Pair{String, String}
    _header_value(event_name, "HX-Trigger event name")
    data === nothing && return "HX-Trigger" => event_name
    payload = Dict{String, Any}(String(k) => v for (k, v) in data)
    return "HX-Trigger" => _header_value(JSON3.write(Dict{String, Any}(event_name => payload)), "HX-Trigger")
end

function hx_push_url_header(url::String)::Pair{String, String}
    return "HX-Push-Url" => _header_value(url, "HX-Push-Url")
end

"""
    format_htmx_sse(event_name::String, html::String) -> String

Format an SSE message for HTMX's `hx-ext="sse"`. CRLF is normalised to LF and
each line of the fragment gets its own `data:` prefix.
"""
function format_htmx_sse(event_name::String, html::String)::String
    normalised = replace(html, "\r\n" => "\n", '\r' => "")
    data_lines = join(["data: $line" for line in split(normalised, '\n')], "\n")
    return "event: $event_name\n$data_lines\n\n"
end

# 2. Hotwire Turbo Streams
"""
    turbo_stream(action::String, target::String, html::String="") -> String

Format a `<turbo-stream>` element. `action` must be one of Turbo's seven stream
actions and `target` is escaped.
"""
function turbo_stream(action::String, target::String, html::String="")::String
    action in _TURBO_ACTIONS || throw(ArgumentError("Unknown Turbo Stream action: $action"))
    escaped = _attr(target)
    action == "remove" &&
        return "<turbo-stream action=\"remove\" target=\"$escaped\"></turbo-stream>"
    return "<turbo-stream action=\"$action\" target=\"$escaped\"><template>$html</template></turbo-stream>"
end

turbo_append(target::String, html::String) = turbo_stream("append", target, html)
turbo_replace(target::String, html::String) = turbo_stream("replace", target, html)
turbo_update(target::String, html::String) = turbo_stream("update", target, html)
turbo_remove(target::String) = turbo_stream("remove", target, "")

# 3. Datastar Helpers
"""
    datastar_merge_fragments(html::String; selector::String="", merge_mode::String="morph") -> String

Format a Datastar `datastar-merge-fragments` SSE block. `morph` is the default
and is therefore omitted, which is what Datastar expects.
"""
function datastar_merge_fragments(html::String; selector::String="", merge_mode::String="morph")::String
    buf = IOBuffer()
    println(buf, "event: datastar-merge-fragments")
    isempty(selector) || println(buf, "data: selector $selector")
    merge_mode == "morph" || println(buf, "data: mergeMode $merge_mode")
    for line in split(replace(html, "\r\n" => "\n", '\r' => ""), '\n')
        println(buf, "data: fragments $line")
    end
    println(buf)
    return String(take!(buf))
end

"""
    datastar_merge_signals(signals::AbstractDict; only_if_missing::Bool=false) -> String

Format a Datastar `datastar-merge-signals` SSE block. The signal document is
JSON3-encoded, so nested objects, arrays, booleans, numbers and strings are all
valid JSON (the previous implementation emitted Julia syntax for non-strings).
"""
function datastar_merge_signals(signals::AbstractDict; only_if_missing::Bool=false)::String
    buf = IOBuffer()
    println(buf, "event: datastar-merge-signals")
    only_if_missing && println(buf, "data: onlyIfMissing true")
    payload = Dict{String, Any}(String(k) => v for (k, v) in signals)
    for line in split(JSON3.write(payload), '\n')
        println(buf, "data: signals $line")
    end
    println(buf)
    return String(take!(buf))
end

function datastar_remove_fragments(selector::String)::String
    return "event: datastar-remove-fragments\ndata: selector $selector\n\n"
end

end # module MaridLive
