require_relative 'lib/clarke'

program =
<<-EOS
decl printf(string, ...): int32

def add(a: int32, b: int32): int32 { a + b }
def sub(a: int32, b: int32): int32 { a - b }
def mul(a: int32, b: int32): int32 { a * b }
def div(a: int32, b: int32): int32 { a / b }

printf("Add: %d\n", add(7, 3))
printf("Sub: %d\n", sub(7, 3))
printf("Mul: %d\n", mul(7, 3))
printf("Div: %d\n", div(7, 3))
EOS

Clarke::Driver.new.run(
  Clarke::Grammar::PROGRAM.apply(program).data,
)
