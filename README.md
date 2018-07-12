Fire.jl
=======

[![](http://pkg.julialang.org/badges/Fire_0.5.svg)](http://pkg.julialang.org/?pkg=Fire)
[![](http://pkg.julialang.org/badges/Fire_0.6.svg)](http://pkg.julialang.org/?pkg=Fire)
[![](http://pkg.julialang.org/badges/Fire_0.7.svg)](http://pkg.julialang.org/?pkg=Fire)

Fire.jl is a library for creating simple CLI from julia function definitions.

### Installation

```julia
Pkg.add("Fire")
```

### Basic Usage

1. put `using Fire` into your file
2. put `@main` in front of your entry functions
3. (optional) add shebang and chmod to save a word in commandline
4. enjoy

```julia
using Fire

"Your Doc String"
@main function repeat_string(message::AbstractString, times::Integer=3; color::Symbol=:normal)
    times < 0 && throw(ArgumentError("cannot repeat negative times"))
    for i in 1:times
        print_with_color(color, message)
    end
end
```

Then you can call `repeat_string` at commandline (assume the file is called "example.jl")

```
$ julia example.jl hello
hello
hello
hello

$ julia example.jl "hello world!" 1
hello world!

$ julia example.jl "hello world!" 1 --color red
hello world!

$ julia example.jl "hello world!" badguy
Error parsing positional argument `times`: require `Integer`, but got "badguy"
`--help` for usages

$ julia example.jl --help
Your Doc String

Positional Arguments:
    str: AbstractString
    times: Integer (default: 3)

Optional Arguments:
    color: Symbol (default: normal)
```

Multiple entries are supported. You can call each function by name.

```julia
using Fire

@main function is_odd(x::Integer)
    x == 0 ? println("false") : is_even(x-sign(x))
end

@main function is_even(x::Integer)
    x == 0 ? println("true") : is_odd(x-sign(x))
end
```

```
$ julia example.jl is_odd 3
true

$ julia example.jl is_even 3
false
```

### Why is it called Fire?

This package is highly inspired by [python-fire](https://github.com/google/python-fire)

### Details

#### Supported Types

- String / AbstractString / Symbol
- "basic" number types like `Int32`, `AbstractFloat`, etc.
- VarArgs of above types
- Vector of above types is allowed in optional arguments
- Bool is allowed in optional arguments, and will be parsed as flag
