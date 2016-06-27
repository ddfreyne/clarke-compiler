require_relative 'lib/clarke'

include Clarke::Nodes

Clarke::Driver.new.run(
  Clarke::Grammar::PROGRAM.apply(
    'fun abc(a: int32): int32 {16}',
  ).data,
)

Clarke::Driver.new.run(
  Clarke::Grammar::PROGRAM.apply(
    'fun abc(a: int32): int32 {if(0) {222}else{333}}',
  ).data,
)

things = [
  FunDecl.new(
    "printf",
    [StringType.instance],
    true,
    Int32Type.instance,
  ),
  FunCall.new(
    "printf",
    [
      Str.new("It’s %u!\n"),
      FunCall.new(
        "sum",
        [
          Const.new(100, Int32Type.instance),
          Const.new(20, Int32Type.instance),
          Const.new(3, Int32Type.instance),
        ],
      ),
    ],
  ),
  FunDef.new(
    "sum",
    [
      FunParam.new("a", Int32Type.instance),
      FunParam.new("b", Int32Type.instance),
      FunParam.new("c", Int32Type.instance),
    ],
    Int32Type.instance,
    [
      If.new(
        VarRef.new("a"),
        [
          OpAdd.new(
            VarRef.new("a"),
            OpAdd.new(
              VarRef.new("b"),
              VarRef.new("c"),
            ),
          ),
        ],
        [
          OpAdd.new(
            VarRef.new("a"),
            VarRef.new("b"),
          ),
        ],
      ),
    ],
  ),
]

Clarke::Driver.new.run(things)
