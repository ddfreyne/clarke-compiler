require_relative 'lib/clarke'

program =
<<-EOS
decl printf(string, ...): int32
def sum(a: int32, b: int32): int32 {if(0) {222}else{333}}
printf("hello there!!! -> %d\n", 3 + sum(2, 1)) + 4
EOS

Clarke::Driver.new.run(
  Clarke::Grammar::PROGRAM.apply(program).data,
)
