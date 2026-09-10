using CapacityEquilibriaBenchmarks
using CapacityEquilibria
using Test
import TOML

# Murphy and Smeers' two open-loop models on two constructed instances, solved with PATH
# and with CCOpt, and judged against three things that depend on neither solver: a hand
# derivation of the equilibrium, an exhaustive enumeration of complementarity patterns,
# and the properties the paper itself states hold at equilibrium.
#
# Neither edition of the paper publishes a numerical example (FINDINGS.md F-0001, F-0002),
# so there is no published number to match; DECISIONS.md D-0004 says what "replicated"
# means here instead. Every published *claim* about the equilibrium that can be checked on
# a point is checked below, cited by page of the May 2002 working paper.

const DATADIR = joinpath(@__DIR__, "..", "data")
const UPSTREAM = joinpath(@__DIR__, "..", "upstream", "test_murphy_smeers_lcp.jl")
const INSTANCES = ["a", "b"]

# Four routes to a solution, not two. `:path` and `:ccopt` go through JuMP — PATH via
# `MOI.Complements`, CCOpt's relaxation method via the MathOptComplements bridges. The two
# `:ccopt_*` backends go through an `MPCCModel` the engine builds directly, which is the
# only way to reach CCOpt's penalty method (engine `FINDINGS.md` F-0004). Everything below
# is asked of all four: the agreement with the derivation, and every property the paper
# states.
const BACKENDS = (:path, :ccopt, :ccopt_relaxation, :ccopt_penalty)

instance_path(tag) = joinpath(DATADIR, "ms2002_instance_$tag.toml")
expected_path(tag) = joinpath(DATADIR, "ms2002_instance_$(tag)_expected.toml")

@testset "CapacityEquilibriaBenchmarks" begin

    @testset "Phase 0: the engine is reachable and drives both backends" begin
        M, q = [2.0 1.0; 1.0 2.0], [-4.0, 1.0]
        build() = lcp_model(M, q)
        path = solve_complementarity(build, :path)
        ccopt = solve_complementarity(build, :ccopt)
        @test lcp_residual(M, q, path.x).worst < 1e-6
        @test lcp_residual(M, q, ccopt.x).worst < 1e-6
        @test path.x ≈ ccopt.x atol = 1e-6
    end

    @testset "data/ carries provenance for whatever it holds" begin
        # Every .toml in data/ must be named in PROVENANCE.md. The document cannot make
        # the numbers right, but it can make an unexplained file impossible.
        @test isfile(joinpath(DATADIR, "PROVENANCE.md"))
        transcriptions = filter(f -> endswith(f, ".toml"), readdir(DATADIR))
        @test !isempty(transcriptions)
        provenance = read(joinpath(DATADIR, "PROVENANCE.md"), String)
        for file in transcriptions
            @test occursin(file, provenance)
        end
    end

    @testset "the loader refuses an instance the paper's results do not cover" begin
        ok = MSData("ok", 3, 1.0, [20.0, 15.0, 10.0], [2.0, 7.0], [3.0, 1.0])
        @test check_assumptions(ok) === ok
        @test_throws ArgumentError check_assumptions(
            MSData("bad", 3, 1.0, [20.0, 15.0, 10.0], [2.0, 7.0], [1.0, 3.0]))  # peaker not cheaper on peak
        @test_throws ArgumentError check_assumptions(
            MSData("bad", 3, 1.0, [10.0, 15.0, 20.0], [2.0, 7.0], [3.0, 1.0]))  # α increasing
        @test_throws ArgumentError check_assumptions(
            MSData("bad", 3, -1.0, [20.0, 15.0, 10.0], [2.0, 7.0], [3.0, 1.0])) # β < 0
        @test_throws ArgumentError check_assumptions(
            MSData("bad", 3, 1.0, [20.0, 15.0], [2.0, 7.0], [3.0, 1.0]))        # length(α) ≠ S
        @test_throws ArgumentError ms_lcp(ok, :closed_loop)
    end

    for tag in INSTANCES
        data = load_ms_instance(instance_path(tag))
        expected = TOML.parsefile(expected_path(tag))
        # The tolerance at which a solver's point is declared to be the derived equilibrium.
        # A claim about the replication, so it lives with the instance rather than in the
        # engine (engine docs/BOUNDARY.md).
        tol = Float64(expected["tolerance"])
        Sp = peak_segments(data)
        types(variant) = Symbol.(expected[String(variant)]["segment_types"])

        @testset "instance $(uppercase(tag)) satisfies the paper's stated assumptions" begin
            # load_ms_instance already threw if not; this makes each one visible.
            @test data.beta > 0                                             # p.12
            @test issorted(data.alpha; rev = true) && allunique(data.alpha) # p.12
            Kp, Kb = data.K[PLAYER_P], data.K[PLAYER_B]
            νp, νb = data.nu[PLAYER_P], data.nu[PLAYER_B]
            @test Kp + νp < Kb + νb                                         # p.11
            @test Kb + data.S * νb < Kp + data.S * νp                       # p.11
            @test 1 <= Sp < data.S                                          # p.14: a genuine two-technology mix
        end

        @testset "instance $(uppercase(tag)): the LCP assembly agrees with a direct transcription" begin
            # ms_lcp builds M and q; ms_conditions writes F row by row from the paper's
            # equations without M. An index error in either shows up as disagreement on a
            # point with all-distinct coordinates.
            for variant in MS_VARIANTS
                M, q, ix = ms_lcp(data, variant)
                n = length(ix)
                @test size(M) == (n, n) && n == 2 + 4 * data.S
                for z in ([mod(7k, 5) + 0.5 for k in 1:n], [k / 3 for k in 1:n], ones(n))
                    @test M * z .+ q ≈ ms_conditions(data, variant, z) atol = 1e-12
                end
                @test is_monotone(M)   # Lemma 1, p.18, and its competitive counterpart
            end
        end

        solutions = Dict{Symbol, Dict{Symbol, MSPoint}}()

        for variant in MS_VARIANTS
            @testset "instance $(uppercase(tag)), $variant: derivation, enumeration, PATH and CCOpt agree" begin
                M, q, _ = ms_lcp(data, variant)
                z_hand = load_ms_expected(data, expected_path(tag), variant)

                # 1. The derived point solves the system, by substitution. If this fails,
                #    nothing below means anything.
                @test lcp_residual(M, q, z_hand).worst < 1e-10

                # 2. Exhaustive enumeration, no solver involved, finds that point and
                #    nothing else in any nondegenerate pattern.
                en = enumerate_lcp_solutions(M, q)
                @test length(en.solutions) == 1
                @test en.solutions[1] ≈ z_hand atol = 1e-8

                # 3. The solution is unique outright: monotone map (above), strictly
                #    complementary point, nonsingular basis. See enumerate_lcp.jl.
                @test strictly_complementary(M, q, z_hand)
                @test basis_nonsingular(M, z_hand)

                # 4. Each backend reaches it, judged on a residual recomputed from its
                #    point and on distance from the derived point — never on its status.
                sols = Dict(b => solve_complementarity(M, q, b) for b in BACKENDS)
                for b in BACKENDS
                    @test lcp_residual(M, q, sols[b].x).worst < tol
                    @test sols[b].x ≈ z_hand atol = tol
                    b === :path || @test sols[b].x ≈ sols[:path].x atol = tol
                end
                # The two relaxation runs are one method on one problem, reached with and
                # without the bridges. They agree *exactly*, because the bridges build the
                # same lifted NLP the engine builds by hand, in the same variable order.
                # Equality is the honest assertion; a tolerance here would be a threshold
                # with nothing to threshold (engine `FINDINGS.md` F-0006).
                @test sols[:ccopt].x == sols[:ccopt_relaxation].x

                # 5. The regime is the one the derivation was done on — checked on every
                #    backend's point, not just PATH's. This is the check that separates a
                #    solver which is merely *near* the equilibrium from one that is on the
                #    right side of every complementarity boundary, so inheriting it from
                #    PATH would have defeated its purpose. It is applied at the case
                #    tolerance rather than `segment_type`'s stricter default: the point is
                #    declared to be the equilibrium at `tol`, so it should be classified at
                #    `tol` too, and the nearest genuine regime boundary is O(0.1) away,
                #    four orders clear of either.
                solutions[variant] = Dict(b => ms_unpack(data, sols[b].x) for b in BACKENDS)
                for b in BACKENDS
                    pt = solutions[variant][b]
                    @test [segment_type(data, pt, s; tol = tol) for s in 1:data.S] ==
                          types(variant)
                end
            end
        end

        for backend in BACKENDS
            pc = solutions[:competitive][backend]
            ol = solutions[:open_loop_cournot][backend]

            @testset "instance $(uppercase(tag)), competitive ($backend): the paper's stated properties hold" begin
                # Production efficiency, p.14: peakers only in s ≤ S_p, base everywhere.
                @test production_efficiency_holds(data, pc)
                # Pricing efficiency, p.15: price = short-run marginal cost + scarcity rent.
                @test pricing_efficiency_gap(data, pc) < tol
                # Investment criterion, p.15: K_i = Σ_s max(p^s − ν_i, 0) for an investing
                # player. Both invest on both instances, asserted so the criterion is not
                # passing vacuously.
                @test all(pc.x .> tol)
                gap = investment_criterion_gap(data, :competitive, pc)
                @test gap.p < tol && gap.b < tol
            end

            @testset "instance $(uppercase(tag)), open-loop Cournot ($backend): the paper's stated properties hold" begin
                # Theorem 1, p.19: the base player always invests a positive amount.
                @test ol.x[PLAYER_B] > tol
                # Investment criterion, p.16: K_i = Σ_s max(p^s − β x_i − ν_i, 0).
                @test all(ol.x .> tol)
                gap = investment_criterion_gap(data, :open_loop_cournot, ol)
                @test gap.p < tol && gap.b < tol
                # Lemma 5, p.21: y_p^s < y_b^s wherever base capacity is not binding.
                slack = [s for s in 1:data.S if ol.x[PLAYER_B] - ol.y[PLAYER_B, s] > tol]
                @test !isempty(slack)   # the lemma is exercised, not vacuous
                for s in slack
                    @test ol.y[PLAYER_P, s] < ol.y[PLAYER_B, s]
                end
                # Lemma 11, p.27: peaker at capacity in s ⇒ base at capacity in s.
                for s in 1:data.S
                    if abs(ol.x[PLAYER_P] - ol.y[PLAYER_P, s]) < tol
                        @test abs(ol.x[PLAYER_B] - ol.y[PLAYER_B, s]) < tol
                    end
                end
                # Corollary 1, p.20: at capacity in s ⇒ at capacity in every s' < s.
                for i in (PLAYER_P, PLAYER_B), s in 2:data.S
                    if abs(ol.x[i] - ol.y[i, s]) < tol
                        @test all(abs(ol.x[i] - ol.y[i, s′]) < tol for s′ in 1:s-1)
                    end
                end
                # Lemma 12, p.29: the peak capacity's marginal values λ_p^s coincide between
                # the competitive and open-loop equilibria when the peaker invests in both.
                @test pc.x[PLAYER_P] > tol && ol.x[PLAYER_P] > tol
                @test ol.λ[PLAYER_P, :] ≈ pc.λ[PLAYER_P, :] atol = tol
                # Cournot withholding (Theorem 7, p.29, read for the two equilibria built
                # here): less total capacity and a higher price in every segment.
                @test sum(ol.x) < sum(pc.x)
                @test all(ol.price .> pc.price)
                # p.16: in the open-loop model peakers may operate in s > S_p, where they
                # are not the efficient technology. On both instances they do, while
                # competition shuts them off there (production efficiency, above).
                @test any(ol.y[PLAYER_P, s] > tol for s in Sp+1:data.S)
            end
        end
    end

    @testset "Phase 3, closed-loop: the second stage, Lemma 7, and equation (16)" begin
        # The closed-loop model of the paper's section 6 shares its entire second stage
        # with the open-loop Cournot model and differs only in the condition paired with
        # capacity. Nothing here searches for a closed-loop equilibrium; these are the
        # pieces such a search needs, each checked on its own.
        for tag in INSTANCES
            data = load_ms_instance(instance_path(tag))
            tol = Float64(TOML.parsefile(expected_path(tag))["tolerance"])
            ol = ms_unpack(data, load_ms_expected(data, expected_path(tag),
                                                  :open_loop_cournot))

            @testset "instance $(uppercase(tag)): the second stage is the open-loop model's" begin
                # At the open-loop capacities the short-run equilibrium must be the
                # open-loop equilibrium's own outputs and duals. If this fails, the claim
                # that the two models share a second stage is wrong and everything below
                # is meaningless.
                M2, q2, ix2 = ms_second_stage_lcp(data, ol.x)
                @test size(M2) == (4 * data.S, 4 * data.S)
                @test length(ix2) == 4 * data.S
                @test is_monotone(M2)
                pt = ms_second_stage(data, ol.x)
                w = vcat(pt.y[PLAYER_P, :], pt.y[PLAYER_B, :],
                         pt.λ[PLAYER_P, :], pt.λ[PLAYER_B, :])
                @test lcp_residual(M2, q2, w).worst < tol
                @test pt.y ≈ ol.y atol = tol
                @test pt.λ ≈ ol.λ atol = tol
                @test pt.price ≈ ol.price atol = tol
                @test_throws DimensionMismatch ms_second_stage_lcp(data, [1.0, 2.0, 3.0])
            end

            @testset "instance $(uppercase(tag)): Lemma 7 against numerical differentiation" begin
                # The derivative table (14), p.22 is the one piece of the closed-loop model
                # that is asserted rather than solved for, so it is checked against a
                # forward difference of the second-stage solve itself. y(x) is piecewise
                # affine (Lemma 8, p.23), so away from a kink the two agree to solver
                # accuracy rather than to O(h).
                pt = ms_second_stage(data, ol.x)
                h = 1e-6
                perturbed = [ms_second_stage(data, ol.x .+ h .* (1:2 .== i)) for i in 1:2]
                for s in 1:data.S
                    B = second_stage_jacobian(data, pt, s)
                    @test size(B) == (2, 2)
                    for i in 1:2
                        numeric = (perturbed[i].y[:, s] .- pt.y[:, s]) ./ h
                        @test B[i, :] ≈ numeric atol = 1e-6
                    end
                end
                # The role is consistent with the type, and the type is the derived one.
                for s in 1:data.S
                    t, who = segment_role(data, pt, s)
                    @test t == segment_type(data, pt, s)
                    @test (t in (:a, :b)) == (who == 0)
                    t === :c && @test abs(pt.x[who] - pt.y[who, s]) < 1e-7   # i is at capacity
                    t in (:d, :e) && @test pt.y[who, s] < 1e-7               # i is idle
                end
            end

            @testset "instance $(uppercase(tag)): the closed-loop equilibrium, and the points that are not" begin
                # `enumerate_closed_loop` finds every point satisfying (16) at a
                # differentiable point, without a solver in the search. On both instances
                # three do, and exactly one of them is an equilibrium: the other two are
                # corners where one player invests nothing, and the other player would
                # strictly gain by deviating. That is the piecewise convexity of Lemma 13,
                # p.31 showing up as a stationary point that is not a minimum, and it is why
                # D-0006 will not call a root of (16) an equilibrium without this check.
                en = enumerate_closed_loop(data)
                @test length(en.solutions) == 3

                gaps = [best_response_gap(data, x).gap for x in en.solutions]
                equilibria = findall(g -> g == 0.0, gaps)
                @test length(equilibria) == 1
                @test all(gaps[k] > 1.0 for k in eachindex(gaps) if k ∉ equilibria)

                x_cl = en.solutions[only(equilibria)]
                z_expected = load_ms_expected(data, expected_path(tag), :closed_loop_cournot)
                @test x_cl ≈ z_expected[1:2] atol = tol

                pt = ms_second_stage(data, x_cl)
                expected_cl = TOML.parsefile(expected_path(tag))["closed_loop_cournot"]
                @test pt.y[PLAYER_P, :] ≈ Float64.(expected_cl["y_p"]) atol = tol
                @test pt.y[PLAYER_B, :] ≈ Float64.(expected_cl["y_b"]) atol = tol
                @test pt.λ[PLAYER_P, :] ≈ Float64.(expected_cl["lambda_p"]) atol = tol
                @test pt.λ[PLAYER_B, :] ≈ Float64.(expected_cl["lambda_b"]) atol = tol
                @test pt.price ≈ Float64.(expected_cl["price"]) atol = tol
                @test [String(segment_type(data, pt, s; tol = tol)) for s in 1:data.S] ==
                      String.(expected_cl["segment_types"])
                @test ms_closed_loop_residual(data, x_cl).worst < tol

                # The paper's comparative results, checked against the competitive and
                # open-loop equilibria already validated at the `validated` tier. These are
                # the closest thing Phase 3 has to the enumeration oracle Phase 1 had.
                cm = ms_unpack(data, load_ms_expected(data, expected_path(tag), :competitive))
                @test sum(x_cl) >= sum(ol.x) - tol                       # Theorem 4, p.28
                @test x_cl[PLAYER_B] >= ol.x[PLAYER_B] - tol             # Theorem 5, p.28
                @test all(pt.price .<= ol.price .+ tol)                  # Theorem 6, p.28
                @test sum(ol.x) - tol <= sum(x_cl) <= sum(cm.x) + tol    # Theorem 7, p.29
                @test pt.λ[PLAYER_P, :] ≈ ol.λ[PLAYER_P, :] atol = tol   # Lemma 12, p.29
                # Corollary 3 (18), p.28: with a type-(c) segment present, the base player
                # has K_b > Σ λ_b while the peak player keeps equality.
                dec = ms_closed_loop_conditions_decomposed(data, pt)
                @test dec.valid
                @test :c in [segment_type(data, pt, s; tol = tol) for s in 1:data.S]
                @test dec.open_loop[PLAYER_P] ≈ 0.0 atol = tol
                @test dec.open_loop[PLAYER_B] > tol
                # Theorem 3, p.26: the closed-loop and open-loop equilibria differ.
                @test !isapprox(x_cl, ol.x; atol = 1e-3)

                # The two non-equilibria are corners, and the decomposition knows it cannot
                # speak about them: a player investing nothing is at capacity trivially and
                # can carry a positive λ, which breaks the identity.
                for k in eachindex(en.solutions)
                    k in equilibria && continue
                    bad = ms_second_stage(data, en.solutions[k])
                    @test any(en.solutions[k] .<= tol)
                    @test !ms_closed_loop_conditions_decomposed(data, bad).valid
                end
            end

            @testset "instance $(uppercase(tag)): equation (16) and its decomposition agree" begin
                # ms_closed_loop_conditions builds (16) term by term from Lemma 7's table;
                # ms_closed_loop_conditions_decomposed writes the same quantity as the
                # open-loop condition plus a type-(c) correction. Two transcriptions of one
                # equation, in the D-0005 pattern, so an error in either shows as a gap.
                pt = ms_second_stage(data, ol.x)
                ξ = ms_closed_loop_conditions(data, pt)
                dec = ms_closed_loop_conditions_decomposed(data, pt)
                @test dec.valid          # both players invest here, so the identity applies
                @test ξ ≈ dec.xi atol = 1e-9

                # At the open-loop capacities the open-loop condition holds by construction,
                # so the decomposition's first term vanishes and ξ is the correction alone.
                @test dec.open_loop ≈ [0.0, 0.0] atol = tol
                @test ξ ≈ dec.manipulation atol = tol

                # Both instances have a type-(c) segment with the base player at capacity,
                # so the paper predicts the signs: Corollary 3 (18), p.28 gives K_p = Σλ_p
                # and K_b > Σλ_b at a closed-loop equilibrium, and Theorem 5, p.28 says the
                # closed-loop base capacity is the larger. A negative ξ_b here is that
                # pressure to invest, and it is why the open-loop point is not a
                # closed-loop equilibrium (Theorem 3, p.26).
                types = [segment_type(data, pt, s) for s in 1:data.S]
                @test :c in types
                @test ξ[PLAYER_P] ≈ 0.0 atol = tol
                @test ξ[PLAYER_B] < -tol
                # The correction is exactly -(β/2) times the base player's output in the
                # type-(c) segments where it is at capacity. Checked against a sum written
                # here rather than by the function under test.
                expected_corr = -0.5 * data.beta * sum(
                    pt.y[PLAYER_B, s] for s in 1:data.S
                    if segment_role(data, pt, s) == (:c, PLAYER_B); init = 0.0)
                @test ξ[PLAYER_B] ≈ expected_corr atol = tol

                # And the residual view of the same thing: the open-loop capacities fail to
                # be a closed-loop equilibrium, while the second stage under them is solved.
                r = ms_closed_loop_residual(data, ol.x)
                @test r.second_stage < tol
                @test r.ξ ≈ ξ atol = 1e-9
                @test r.worst > tol          # not a closed-loop equilibrium
                @test r.primal == 0.0        # the capacities themselves are feasible
            end
        end
    end

    @testset "the emitted upstream file is the same model, and still solves it" begin
        # DECISIONS.md D-0001: what CCOpt.jl's maintainers would hold is generated from
        # `data/` and from the model sources, never hand-written. This is the round trip
        # the plan asks for — the emitted copy re-run and required to reproduce the same
        # numbers as the in-repo model — and it is what stops the copy drifting once the
        # model behind it is corrected. Staleness of the *file* is a separate question,
        # answered by `ci/gates/check_stale_generated.py` against `generated.toml`.
        @test isfile(UPSTREAM)

        # Including it runs its own testsets against CCOpt, both methods, all four cases,
        # inside this suite; the module it returns is then interrogated below.
        emitted = include(UPSTREAM)

        # The emitted set is exactly the in-repo set: every case here is matched by its
        # parameters, not by its label, and every case there is accounted for. A case
        # silently dropped from the emitter, or one carrying parameters that belong to no
        # instance in `data/`, fails this rather than passing quietly.
        @test length(emitted.CASES) == length(INSTANCES) * length(MS_VARIANTS)

        for tag in INSTANCES, variant in MS_VARIANTS
            data = load_ms_instance(instance_path(tag))
            matching = [c for c in emitted.CASES
                        if c.variant === variant && c.S == data.S && c.beta == data.beta &&
                           c.alpha == data.alpha && c.K == data.K && c.nu == data.nu]
            @test length(matching) == 1
            case = only(matching)

            M, q, _ = ms_lcp(data, variant)
            z_hand = load_ms_expected(data, expected_path(tag), variant)

            # The emitted file's own assembly, on its own inlined parameters, rebuilds the
            # in-repo matrices exactly — not approximately. It can, because the assembly is
            # this repository's assembly, spliced rather than retyped (F-0009).
            Me, qe = emitted.ms_lcp_arrays(case.S, case.beta, case.alpha, case.K,
                                           case.nu, case.variant)
            @test Me == M
            @test qe == q
            # The inlined equilibrium is the derived one, and the inlined tolerance is the
            # instance's own — a looser tolerance travelling upstream than the one used
            # here would be exactly the drift this check exists to catch.
            @test case.z == z_hand
            @test case.tol == Float64(TOML.parsefile(expected_path(tag))["tolerance"])
            # And the oracle that travels with the file agrees with the engine's.
            @test emitted.lcp_residual(M, q, z_hand).worst ==
                  lcp_residual(M, q, z_hand).worst
        end
    end
end
