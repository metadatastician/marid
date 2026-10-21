# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>

using Test
using MaridCore

# Declared at top level: `struct` is not allowed inside a `@testset`. This type
# exists only to exercise the `::MaridError` fallbacks, which no shipped error
# kind reaches because each one has its own method.
struct UnmappedTestError <: MaridError
    message::String
end

@testset "MaridCore Complete Suite" begin
    # 1. Error Mapping & Problem Details
    @testset "RFC 9457 Domain Errors" begin
        not_found = NotFoundError("Taxon", "42")
        @test status_code(not_found) == 404
        pd = problem_details(not_found, instance="/taxa/42")
        @test pd["status"] == 404
        @test occursin("42", pd["detail"])
        @test pd["instance"] == "/taxa/42"
        
        val_err = ValidationError("Field missing", "email", "required")
        @test status_code(val_err) == 400
        
        conflict = ConflictError("Document conflict", "entities/1", "rev-abc")
        @test status_code(conflict) == 409
        
        timeout = TimeoutError("Deadline reached", 150.0)
        @test status_code(timeout) == 504
    end

    # 1b. Stable problem-detail identifiers (C10)
    @testset "Problem details identify the kind, stably" begin
        pd = problem_details(NotFoundError("Taxon", "42"))
        # Not "…/errors/MaridCore.NotFoundError": the type is a stable slug.
        @test pd["type"] == "https://marid.hyperpolymath.org/problems/not-found"
        @test pd["title"] == "Not Found"
        @test pd["instance"] == "/problems/not-found"
        @test pd["status"] == 404
        @test occursin("42", pd["detail"])

        @test error_slug(ValidationError("bad", "email", "required")) == "validation"
        @test problem_details(UnauthorizedError())["title"] == "Unauthorized"
        @test problem_details(ConflictError("c", "r", "v"))["status"] == 409
        @test problem_details(TimeoutError("t", 1.0))["status"] == 504

        # Unknown subclasses still map to a sane slug rather than throwing.
        # `InternalError` has its own method, so it cannot test the fallback;
        # this uses a subtype the module does not know about.
        @test error_slug(UnmappedTestError("boom")) == "error"
        @test status_code(UnmappedTestError("boom")) == 500
        fallback = problem_details(UnmappedTestError("boom"))
        @test fallback["type"] == "https://marid.hyperpolymath.org/problems/error"
        @test fallback["title"] == "Error"
        @test fallback["status"] == 500
        # The shipped kinds still resolve to their own slugs.
        @test error_slug(InternalError("boom")) == "internal"

        # A trace id travels with the problem, as an extension member.
        traced = problem_details(InternalError("safe"), trace_id="abc-123")
        @test traced["trace_id"] == "abc-123"
        @test occursin("safe", traced["detail"])
    end

    # 2. CallContext Lifecycle & Cancellation
    @testset "CallContext Semantics" begin
        ctx = create_context(principal="user:dr_smith", tenant="biology_dept", timeout_ms=500)
        @test ctx.principal == "user:dr_smith"
        @test ctx.tenant_scope == "biology_dept"
        @test !is_cancelled(ctx)
        @test !is_expired(ctx)
        @test check_deadline(ctx) > 0.0
        
        cancel!(ctx)
        @test is_cancelled(ctx) == true
        
        expired_ctx = create_context(timeout_ms=-10)
        @test is_expired(expired_ctx) == true
        @test_throws TimeoutError check_deadline(expired_ctx)
    end

    # 3. Bounded Streaming Seam & Backpressure
    @testset "Streaming Flow Control" begin
        ctx = create_context(timeout_ms=5000)
        stream = Stream{Int}(4, ctx)
        
        @async begin
            for i in 1:5
                push_item!(stream, i)
            end
            close_stream!(stream)
        end
        
        items = collect_stream(stream)
        @test items == [1, 2, 3, 4, 5]
        @test is_closed(stream) == true
    end

    # 4. Stream Cancellation Interruption
    @testset "Stream Cancellation Defense" begin
        ctx = create_context(timeout_ms=5000)
        stream = Stream{String}(2, ctx)
        push_item!(stream, "item1")
        cancel!(ctx)
        @test_throws ErrorException push_item!(stream, "item2")
    end

    # 5. Radix Trie Router Matching
    @testset "Trie Router" begin
        table = RouteTable{String}()
        table = add_route(table, "GET", "/api/v1/taxa", "list_taxa")
        table = add_route(table, "GET", "/api/v1/taxa/:id", "get_taxon")
        table = add_route(table, "POST", "/api/v1/taxa", "create_taxon")
        table = add_route(table, "GET", "/static/*", "serve_static")
        
        # Exact match
        m1 = match_route(table, "GET", "/api/v1/taxa")
        @test m1 !== nothing
        @test m1.handler == "list_taxa"
        @test isempty(m1.params)
        
        # Parameterized match
        m2 = match_route(table, "GET", "/api/v1/taxa/hominini")
        @test m2 !== nothing
        @test m2.handler == "get_taxon"
        @test m2.params["id"] == "hominini"
        
        # Wildcard match
        m3 = match_route(table, "GET", "/static/css/theme.css")
        @test m3 !== nothing
        @test m3.handler == "serve_static"
        @test m3.params["*"] == "css/theme.css"
        
        # Unmatched route
        @test match_route(table, "GET", "/not/found") === nothing
        @test match_route(table, "DELETE", "/api/v1/taxa") === nothing
    end

    # 6. Middleware and App Dispatch
    @testset "Application Assembly" begin
        app = MaridApp()
        
        # Handler returns stream of results
        register_route!(app, "GET", "/greet/:name", (ctx, req) -> begin
            out = Stream{String}(ctx)
            push_item!(out, "Hello, $(req.params["name"])!")
            close_stream!(out)
            return out
        end)
        
        # Add tracing middleware
        push!(app.middlewares, FunctionMiddleware((ctx, call, next) -> begin
            # Append audit attribute
            ctx.attributes[:audited] = true
            return next(ctx, call)
        end))
        
        ctx = create_context()
        in_stream = Stream{String}(ctx)
        out_stream = dispatch_call(app, ctx, "GET", "/greet/Jonathan", in_stream)
        
        results = collect_stream(out_stream)
        @test results == ["Hello, Jonathan!"]
        @test ctx.attributes[:audited] == true
        
        # Route not found exception
        @test_throws NotFoundError dispatch_call(app, ctx, "GET", "/unknown", in_stream)
    end
end
