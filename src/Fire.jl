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
const BASIC_TYPES         = (BASIC_NUMBER_TYPE..., BASIC_STRING_TYPE..., BASIC_ABSTRACT_TYPE...)

const REQUIRED  = 0x01
const OPTIONAL  = 0x02
const VARLENGTH = 0x03

const entries   = FuncDef[]
const typecache = Dict(1=>String)
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
            push!(args.args, Expr(:tuple, quot(def), :($typecache[1]), REQUIRED))
        elseif def.head == :(::)
            x = typecount()
            def.args[2] = :( $typecache[$x] = $(def.args[2]) )
            push!(args.args, Expr(:tuple, quot(def.args[1]), :($typecache[$x]), REQUIRED))
        elseif def.head == :kw
            if isa(def.args[1], Symbol)
                push!(args.args, Expr(:tuple, quot(def.args[1]), :($typecache[1]), OPTIONAL, quot(def.args[2])))
            else
                x = typecount()
                def.args[1].args[2] = :( $typecache[$x] = $(def.args[1].args[2]) )
                push!(args.args, Expr(:tuple, quot(def.args[1].args[1]), :($typecache[$x]), OPTIONAL, quot(def.args[2])))
            end
        elseif def.head == :(...)
            def = def.args[1]
            if isa(def, Symbol)
                push!(args.args, Expr(:tuple, quot(def), :($typecache[1]), VARLENGTH))
            else
                x = typecount()
                def.args[2] = :( $typecache[$x] = $(def.args[2]) )
                push!(args.args, Expr(:tuple, quot(def.args[1]), :($typecache[$x]), VARLENGTH))
            end
        elseif def.head == :parameters
            for def in def.args
                if def.head != :kw
                    error("Fire.jl don't support var length keyword argument")
                end
                if isa(def.args[1], Symbol)
                    push!(kwargs.args, Expr(:tuple, quot(def.args[1]), :($typecache[1]), quot(def.args[2])))
                else
                    x = typecount()
                    def.args[1].args[2] = :( $typecache[$x] = $(def.args[1].args[2]) )
                    push!(kwargs.args, Expr(:tuple, quot(def.args[1].args[1]), :($typecache[$x]), quot(def.args[2])))
                end
            end
        else
            error("your function is too complex for Fire.jl")
        end
    end

    quot(name), args, kwargs, esc(name)
end

function parse_with_type(t, x)
    t in BASIC_NUMBER_TYPE             ? parse(t, x) :
    t in BASIC_STRING_TYPE             ? t(x) :
    t in (Signed, Integer)             ? parse(Int, x) :
    t == Unsigned                      ? parse(UInt, x) :
    t in (AbstractFloat, Real, Number) ? parse(Float64, x) :
    t == AbstractString                ? x :
    error("BUG")
end

function parse_command_line()
    isempty(entries) && return

    let ARGS = copy(ARGS)
        pargs, oargs = [], Dict{Symbol, Any}()
        entry = if length(entries) > 1
            cmd = shift!(ARGS)
            if cmd == "--help"
                return print_help_all()
            else
                i = findfirst(x->x.name == Symbol(cmd), entries)
                i == 0 && return println(STDERR, "ERROR: unknown command $cmd, see --help for more avaliable commands")
                entries[i]
            end
        else
            entries[]
        end

        for kwarg in entry.kwargs
            if kwarg[2] == Bool
                oargs[kwarg[1]] = false
            end
        end

        i = 1

        while !isempty(ARGS)
            x = shift!(ARGS)
            if startswith(x, "--")
                if x == "--help"
                    return print_help_entry(entry)
                end

                x = Symbol(x[3:end])

                arg = let ind = findfirst(y->y[1] == x, entry.kwargs)
                    ind != 0 ? entry.kwargs[ind] : return println(STDERR, "Unknown option --$x, see --help for avaliable options")
                end

                if arg[2] == Bool
                    oargs[arg[1]] = true
                elseif arg[2] <: Vector
                    oargs[arg[1]] = arg[2]()
                    while !isempty(ARGS)
                        x = ARGS[1]
                        startswith(x, "--") ? break : shift!(ARGS)
                        push!(oargs[arg[1]], parse_with_type(eltype(arg[2]), x))
                    end
                elseif arg[2] in BASIC_TYPES
                    if isempty(ARGS) || (x = shift!(ARGS); startswith(x, "--"))
                        return println(STDERR, "Option --$(arg[1]) need an argument")
                    end

                    oargs[arg[1]] = parse_with_type(arg[2], x)
                else
                    return println(STDERR, "Argument type $(arg[2]) is not supported by Fire.jl")
                end
            else
                if i > length(entry.args)
                    return println(STDERR, "Too many arguments, see --help for list of arguments")
                end

                arg = entry.args[i]

                arg[2] in BASIC_TYPES || return println(STDERR, "Argument type $(arg[2]) is not supported by Fire.jl")

                push!(pargs, parse_with_type(arg[2], x))

                if arg[3] != VARLENGTH
                    i += 1
                end
            end
        end

        number_of_required_arguments = count(x->x[3]==REQUIRED, entry.args)

        if length(pargs) < number_of_required_arguments
            return println(STDERR, "Need $number_of_required_arguments positional arguments, see --help for what are them")
        end

        entry.func(pargs...; oargs...)
    end
end

function print_help_all()
    println("See --help of each command for usages")
    for entry in entries
        println("  ", entry.name)
    end
    println()
end

function print_help_entry(entry)
    println(doc(entry.func))
    if !isempty(entry.args)
        println("Positional Arguments:")
        for i in entry.args
            print("  ", i[1], ": ", i[2])
            i[3] == REQUIRED  ? println() :
            i[3] == OPTIONAL  ? println(" (default: $(i[4]))") :
            i[3] == VARLENGTH ? println("...") :
            error("BUG")
        end
        println()
    end
    if !isempty(entry.kwargs)
        println("Optional Arguments:")
        for i in entry.kwargs
            println("  --", i[1], ": ", i[2], " (default: $(i[3]))")
        end
        println()
    end
end

macro main(f::Expr)
    x = parse_function_definition(f)
    quote
        @__doc__ $(esc(f))
        push!(entries, FuncDef($(x...)))
    end
end

end # module Fire
