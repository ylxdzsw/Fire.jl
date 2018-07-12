using Test

const test_file = let
    dir, cnt = mktempdir(), 0

    local function test_file(code)
        filename = joinpath(dir, "test$cnt.jl")

        open(filename, "w") do f
            println(f, "using Fire")
            println(f, code)
        end

        cnt += 1
        filename
    end
end

@testset "call" begin
    f = test_file("""
        function main()
            println("I won't get called")
        end
    """)

    @test length(read(`julia $f`)) == 0

    f = test_file("""
        @main function main()
            println("I will get called")
        end
    """)

    @test length(read(`julia $f`)) != 0
end

@testset "types" begin
    f = test_file("""
        @main function main(x::Int32)
            nothing
        end
    """)

    @test_nowarn run(`julia $f 4`)

    f = test_file("""
        @main function main(x::Symbol)
            nothing
        end
    """)

    @test_nowarn run(`julia $f 4`)

    f = test_file("""
        @main function main(x::AbstractFloat)
            nothing
        end
    """)

    @test_nowarn run(`julia $f 4e-2`)
    @test_warn r"." run(`julia $f foo`)
end

@testset "kwargs" begin
    f = test_file("""
        @main function main(x::Int32; y::Int=2, z::Int=3)
            println(x + y + z)
        end
    """)

    @test readchomp(`julia $f 4`) == "9"
    @test readchomp(`julia $f 4 --y 1`) == "8"
    @test readchomp(`julia $f 4 --y 1 --z 2`) == "7"

    f = test_file("""
        @main function main(; n::Vector{Int}=[2, 3], mult::Bool=false)
            mult ? println(*(n...)) : println(+(n...))
        end
    """)

    @test readchomp(`julia $f`) == "5"
    @test readchomp(`julia $f --mult`) == "6"
    @test readchomp(`julia $f --n 2 3 4 5`) == "14"
    @test readchomp(`julia $f --n 2 3 4 5 --mult`) == "120"
end

@testset "splat" begin
    f = test_file("""
        @main function main(x::Integer, y::Integer...)
            println(x * +(y...,))
        end
    """)

    @test readchomp(`julia $f 2 3 4`) == "14"
    @test readchomp(`julia $f 2 3 4 5`) == "24"
end

@testset "help" begin
    f = test_file("""
        "this is the doc string"
        @main function main(x::Integer=3; y::Integer=4)
            nothing
        end
    """)

    @test begin
        a = read(`julia $f --help`, String)
        all(("this is the doc string", "default: 3", "--y: Integer")) do x
            occursin(x, a)
        end
    end
end

rm(dirname(test_file("")), recursive=true)
