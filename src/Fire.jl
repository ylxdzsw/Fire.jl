__precompile__()

module Fire

import Base: @__doc__, doc
import Base.Meta: quot

export @main

type FuncDef
    name::Symbol
    args::Vector
    kwargs::Vector
    func::Function
end

const BASIC_NUMBER_TYPE   = Int8, UInt8, Int16, UInt16, Int32, UInt32, Int64, UInt64, Int128, UInt128, Float16, Float32, Float64, BigInt, BigFloat
const BASIC_STRING_TYPE   = String, Symbol
const BASIC_ABSTRACT_TYPE = Signed, Unsigned, Integer, AbstractFloat, Real, Number, AbstractString

const REQUIRED  = 0x01
const OPTIONAL  = 0x02
const VARLENGTH = 0x03

const entries   = FuncDef[]
const typecache = Type[String]
const typecount = ((c) -> () -> c += 1)(1)

function __init__()
    atexit(parse_command_line)
end

function parse_function_definition(f)
    if f.head != Symbol("function")
        throw(ArgumentError("@main can only be used on function definitions"))
    end
    name = f.args[1].args[1]
    defs = f.args[1].args[2:end]
    args, kwargs = Expr(:vect), Expr(:vect)

    for def in defs
        if isa(def, Symbol)
            push!(args.args, Expr(:tuple, quot(def), 1, REQUIRED))
        elseif def.head == :(::)
            i, x = typecount(), gensym()
            def.args[2] = :( let $x = $(def.args[2]); push!($typecache, $x); $x end )
            push!(args.args, Expr(:tuple, quot(def.args[1]), i, REQUIRED))
        elseif def.head == :kw
            if isa(def.args[1], Symbol)
                push!(args.args, Expr(:tuple, quot(def.args[1]), 1, OPTIONAL))
            else
                def = def.args[1]
                i, x = typecount(), gensym()
                def.args[2] = :( let $x = $(def.args[2]); push!($typecache, $x); $x end )
                push!(args.args, Expr(:tuple, quot(def.args[1]), i, OPTIONAL))
            end
        elseif def.head == :(...)
            def = def.args[1]
            if isa(def, Symbol)
                push!(args.args, Expr(:tuple, quot(def), 1, VARLENGTH))
            else
                i, x = typecount(), gensym()
                def.args[2] = :( let $x = $(def.args[2]); push!($typecache, $x); $x end )
                push!(args.args, Expr(:tuple, quot(def.args[1]), i, VARLENGTH))
            end
        elseif def.head == :parameters
            for def in def.args
                if def.head != :kw
                    error("Fire.jl don't support var length keyword argument")
                end
                if isa(def.args[1], Symbol)
                    push!(kwargs.args, Expr(:tuple, quot(def.args[1]), 1))
                else
                    def = def.args[1]
                    i, x = typecount(), gensym()
                    def.args[2] = :( let $x = $(def.args[2]); push!($typecache, $x); $x end )
                    push!(kwargs.args, Expr(:tuple, quot(def.args[1]), i))
                end
            end
        else
            error("your function is too complex for Fire.jl")
        end
    end

    quot(name), args, kwargs, esc(name)
end

function parse_command_line()
    println(entries)
end

macro main(f::Expr)
    dump(f.args[1].args)
    x = parse_function_definition(f)
    quote
        @__doc__ $(esc(f))
        push!(entries, FuncDef($(x...)))
    end
end

end # module Fire
