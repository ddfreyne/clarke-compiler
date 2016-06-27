require_relative 'lib/clarke'

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

run(things)
