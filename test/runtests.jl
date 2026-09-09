using CapacityEquilibriaBenchmarks
using CapacityEquilibria
using Test

# Phase 0 for this repository is narrower than it is for the engine. The engine has already
# shown that PATH and CCOpt solve a complementarity problem correctly (its F-0001); what is
# unproven here is that this project can reach the engine and drive it, which is the
# dependency direction D-0001 turns on.
#
# There is no Murphy and Smeers model yet, and no transcribed data. Phase 1 is where those
# arrive, and it is gated on this passing.

@testset "CapacityEquilibriaBenchmarks" begin

    @testset "the engine is reachable and drives both backends" begin
        M, q = [2.0 1.0; 1.0 2.0], [-4.0, 1.0]
        build() = lcp_model(M, q)

        path = solve_complementarity(build, :path)
        ccopt = solve_complementarity(build, :ccopt)

        @test lcp_residual(M, q, path.x).worst < 1e-6
        @test lcp_residual(M, q, ccopt.x).worst < 1e-6
        @test path.x ≈ ccopt.x atol = 1e-6
    end

    @testset "data/ carries provenance for whatever it holds" begin
        # The rule this guards is the one AGENTS.md calls the highest-risk point in the
        # plan: every value in data/ traces to a table and a page. Right now data/ holds
        # only its provenance file, so the check is vacuously true -- and it is written
        # now, before the first transcription, because a rule added after the data is a
        # rule argued against an existing pile of numbers.
        datadir = joinpath(@__DIR__, "..", "data")
        @test isfile(joinpath(datadir, "PROVENANCE.md"))
        transcriptions = filter(f -> endswith(f, ".toml"), readdir(datadir))
        provenance = read(joinpath(datadir, "PROVENANCE.md"), String)
        for file in transcriptions
            @test occursin(file, provenance)
        end
    end
end
