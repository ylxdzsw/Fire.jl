__precompile__()

module Fire

import Base: @__doc__, doc
import Base.Meta: quot

export @main

struct FuncDef
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

const entries = FuncDef[]

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
            push!(args.args, Expr(:tuple, quot(def), String, REQUIRED))
        elseif def.head == :(::)
            push!(args.args, Expr(:tuple, quot(def.args[1]), esc(def.args[2]), REQUIRED))
        elseif def.head == :kw
            if isa(def.args[1], Symbol)
                push!(args.args, Expr(:tuple, quot(def.args[1]), String, OPTIONAL, quot(def.args[2])))
            else
                push!(args.args, Expr(:tuple, quot(def.args[1].args[1]), esc(def.args[1].args[2]), OPTIONAL, quot(def.args[2])))
            end
        elseif def.head == :(...)
            def = def.args[1]
            if isa(def, Symbol)
                push!(args.args, Expr(:tuple, quot(def), String, VARLENGTH))
            else
                push!(args.args, Expr(:tuple, quot(def.args[1]), esc(def.args[2]), VARLENGTH))
            end
        elseif def.head == :parameters
            for def in def.args
                if def.head != :kw
                    error("Fire.jl don't support var length keyword argument")
                end
                if isa(def.args[1], Symbol)
                    push!(kwargs.args, Expr(:tuple, quot(def.args[1]), String, quot(def.args[2])))
                else
                    push!(kwargs.args, Expr(:tuple, quot(def.args[1].args[1]), esc(def.args[1].args[2]), quot(def.args[2])))
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
            isempty(ARGS) && return print_help_all()
            cmd = popfirst!(ARGS)
            if cmd == "--help"
                return print_help_all()
            else
                i = findfirst(x->x.name == Symbol(replace(cmd, '-' => '_')), entries)
                i == nothing && return println(stderr, "ERROR: unknown command $cmd, see --help for available commands")
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
            x = popfirst!(ARGS)
            if startswith(x, "--")
                if x == "--help"
                    return print_help_entry(entry)
                end

                x = Symbol(x[3:end])

                arg = let ind = findfirst(y->y[1] == Symbol(replace(String(x), '-' => '_')), entry.kwargs)
                    ind != nothing ? entry.kwargs[ind] : return println(stderr, "Unknown option --$x, see --help for available options")
                end

                if arg[2] == Bool
                    oargs[arg[1]] = true
                elseif arg[2] <: Vector
                    oargs[arg[1]] = arg[2]()
                    while !isempty(ARGS)
                        x = ARGS[1]
                        startswith(x, "--") ? break : popfirst!(ARGS)
                        push!(oargs[arg[1]], parse_with_type(eltype(arg[2]), x))
                    end
                elseif arg[2] in BASIC_TYPES
                    if isempty(ARGS) || (x = popfirst!(ARGS); startswith(x, "--"))
                        return println(stderr, "Option --$(arg[1]) needs an argument")
                    end

                    oargs[arg[1]] = parse_with_type(arg[2], x)
                else
                    return println(stderr, "Argument type $(arg[2]) is not supported by Fire.jl")
                end
            else
                if i > length(entry.args)
                    return println(stderr, "Too many arguments, see --help for list of arguments")
                end

                arg = entry.args[i]

                arg[2] in BASIC_TYPES || return println(stderr, "Argument type $(arg[2]) is not supported by Fire.jl")

                push!(pargs, parse_with_type(arg[2], x))

                if arg[3] != VARLENGTH
                    i += 1
                end
            end
        end

        number_of_required_arguments = count(x->x[3]==REQUIRED, entry.args)

        if length(pargs) < number_of_required_arguments
            return println(stderr, "Need $number_of_required_arguments positional arguments, see --help for available arguments")
        end

        entry.func(pargs...; oargs...)
    end
end

function print_help_all()
    println("See --help of each command for usages")
    for entry in entries
        println("  ", replace(String(entry.name), '_' => '-'))
    end
    println()
end

function print_help_entry(entry)
    println(doc(entry.func))
    if !isempty(entry.args)
        println("Positional Arguments:")
        for i in entry.args
            print("  ", replace(String(i[1]), '_' => '-'), ": ", i[2])
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
            println("  --", replace(String(i[1]), '_' => '-'), ": ", i[2], " (default: $(i[3]))")
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
