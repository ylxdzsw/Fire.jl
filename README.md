Fire.jl
=======

[![](https://github.com/ylxdzsw/Fire.jl/workflows/CI/badge.svg)](https://github.com/ylxdzsw/Fire.jl/actions)

Fire.jl is a library for creating simple CLI from julia function definitions.

### Installation

```julia
import Pkg
Pkg.add("Fire")
```

### Usage

1. put `using Fire` on the top
2. put `@main` in front of the entry function
3. (optional) add `#!/usr/bin/env julia` and `chmod +x`

```julia
using Fire

"Very Descriptive Doc String"
@main function repeat_string(message::AbstractString, times::Integer=3; color::Symbol=:normal)
    times < 0 && throw(ArgumentError("cannot repeat negative times"))
    for i in 1:times
        printstyled(message, '\n'; color)
    end
end
```

Then this function can be used at commandline (assuming the file is called "example.jl")

```
$ julia example.jl hello
hello
hello
hello

$ julia example.jl 'hello world!' 1
hello world!

$ julia example.jl 'hello world!' 1 --color red
hello world!

$ julia example.jl --help
Very Descriptive Doc String

Positional Arguments:
    str: AbstractString
    times: Integer (default: 3)

Optional Arguments:
    color: Symbol (default: :normal)
```

Multiple entries are supported.

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

This package is inspired by [python-fire](https://github.com/google/python-fire)

### Details

#### Supported Types

- String / AbstractString / Symbol
- "basic" number types like `Int32`, `AbstractFloat`, etc.
- VarArgs of above types
- Vector of above types is allowed in optional arguments
- Bool is allowed in optional arguments, and will be parsed as flag
