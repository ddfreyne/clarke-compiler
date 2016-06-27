def log(msg)
  $stderr.puts "[#{Time.now.strftime('%H:%M:%S.%L')}] #{msg}"
end

log('hello!')

require 'ffi/llvm'
require 'singleton'
require 'pp'

include FFI::LLVM

log('requirements loaded')

#############################################################################
# HELPER
#############################################################################

def to_llvm(array)
  FFI::MemoryPointer.new(:pointer, array.size).tap do |ptr|
    ptr.put_array_of_pointer(0, array)
  end
end

FunParam = Struct.new(:name, :type)

require_relative 'lib/clarke/env'
require_relative 'lib/clarke/types'
require_relative 'lib/clarke/nodes'
require_relative 'lib/clarke/phases'
require_relative 'lib/clarke/driver'

#############################################################################

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
