# Clarke

A compiler for a simple programming language. This is a toy.

It is capable of compiling a simple program like this:

```
decl printf(string, ...): int32

def add(a: int32, b: int32): int32 =
  a + b

def sub(a: int32, b: int32): int32 =
  a - b

def mul(a: int32, b: int32): int32 = {
  a * b
}

def div(a: int32, b: int32): int32 = {
  a / b
}

printf("Add: %d\n", add(7, 3))
printf("Sub: %d\n", sub(7, 3))
printf("Mul: %d\n", mul(7, 3))
printf("Div: %d\n", div(7, 3))
```

## Usage

Initial setup:

```
bundle
```

Compiling a program to LLVM IR:

```
bundle exec bin/clarke samples/stuff.cke
```

You might want to pipe the output to `llc` to compile to an object file, and then use `cc` to generate an executable.

## Requirements

* Ruby 2.1+
* LLVM 3.6+
