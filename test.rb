require 'ffi/llvm'
require 'singleton'

include FFI::LLVM

def to_llvm(array)
  FFI::MemoryPointer.new(:pointer, array.size).tap do |ptr|
    ptr.put_array_of_pointer(0, array)
  end
end

### helper

class Type
end

class Int32Type < Type
  include Singleton

  def codegen(mod:)
    LLVMInt32Type()
  end
end

class StringType < Type
  include Singleton

  def codegen(mod:)
    LLVMPointerType(LLVMInt8Type(), 0)
  end
end

FunParam = Struct.new(:name, :type)

$functions = {}

### top-level

FunDecl = Struct.new(:name, :arg_types, :is_varargs, :return_type) do
  def codegen(mod:)
    arg_types_llvm = to_llvm(arg_types.map { |at| at.codegen(mod: mod) })
    return_type_llvm = return_type.codegen(mod: mod)
    is_varargs_llvm = is_varargs ? 1 : 0

    type = LLVMFunctionType(return_type_llvm, arg_types_llvm, arg_types.size, is_varargs_llvm)
    function = LLVMAddFunction(mod, name, type)
    # FIXME: eeeewwww
    $functions[name] = function
    function
  end
end

FunDef = Struct.new(:name, :params, :ret_type, :body) do
  def codegen(mod:)
    params_ptr = to_llvm(params.map { |pa| pa.type.codegen(mod: mod) })

    function_type = LLVMFunctionType(
      ret_type.codegen(mod: mod),
      params_ptr,
      params.size,
      0,
    )

    if $functions.key?(name)
      raise "Function already defined: #{name}"
    end
    function = LLVMAddFunction(mod, name, function_type)
    # FIXME: eeeewwww
    $functions[name] = function

    env = {}
    params.each_with_index do |par, i|
      llvm_param = LLVMGetParam(function, i)
      LLVMSetValueName(llvm_param, par.name)
      env[par.name] = llvm_param
    end

    entry = LLVMAppendBasicBlock(function, "entry")
    builder = LLVMCreateBuilder()
    LLVMPositionBuilderAtEnd(builder, entry)

    tmp = body.codegen(mod: mod, function: function, builder: builder, env: env)

    LLVMBuildRet(builder, tmp)
  end
end

### expressions

Const = Struct.new(:value, :type) do
  def codegen(mod:, function:, builder:, env:)
    LLVMConstInt(type.codegen(mod: mod), value, 0)
  end
end

Str = Struct.new(:value) do
  def codegen(mod:, function:, builder:, env:)
    LLVMBuildGlobalStringPtr(builder, value, 'str')
  end
end

VarRef = Struct.new(:name) do
  def codegen(mod:, function:, builder:, env:)
    env.fetch(name)
  end
end

OpAdd = Struct.new(:lhs, :rhs) do
  def codegen(mod:, function:, builder:, env:)
    LLVMBuildAdd(
      builder,
      lhs.codegen(mod: mod, function: function, builder: builder, env: env),
      rhs.codegen(mod: mod, function: function, builder: builder, env: env),
      "op_add_res",
    )
  end
end

FunCall = Struct.new(:name, :args) do
  def codegen(mod:, function:, builder:, env:)
    args_ptr = to_llvm(args.map { |a| a.codegen(mod: mod, function: function, builder: builder, env: env) })

    LLVMBuildCall(builder, $functions.fetch(name), args_ptr, args.size, "call_#{name}_res")
  end
end

If = Struct.new(:condition, :true_clause, :false_clause) do
  def codegen(mod:, function:, builder:, env:)
    var_condition = condition.codegen(mod: mod, function: function, builder: builder, env: env)

    block_true = LLVMAppendBasicBlock(function, "if_true")
    block_false = LLVMAppendBasicBlock(function, "if_false")
    block_end = LLVMAppendBasicBlock(function, "if_end")

    # FIXME: wrong condition
    constant_zero = LLVMConstInt(LLVMInt32Type(), 0, 0)
    cond = LLVMBuildICmp(builder, :llvm_int_eq, var_condition, constant_zero, "cond")
    LLVMBuildCondBr(builder, cond, block_true, block_false)

    LLVMPositionBuilderAtEnd(builder, block_true)
    res_true = true_clause.codegen(mod: mod, function: function, builder: builder, env: env)
    LLVMBuildBr(builder, block_end)

    LLVMPositionBuilderAtEnd(builder, block_false)
    res_false = true_clause.codegen(mod: mod, function: function, builder: builder, env: env)
    LLVMBuildBr(builder, block_end)

    LLVMPositionBuilderAtEnd(builder, block_end)
    res = LLVMBuildPhi(builder, LLVMInt32Type(), "result")

    phi_vals_ptr = to_llvm([res_true, res_false])
    phi_blocks_ptr = to_llvm([block_true, block_false])

    LLVMAddIncoming(res, phi_vals_ptr, phi_blocks_ptr, 2)
    res
  end
end

#############################################################################

things = [
  FunDecl.new(
    "printf",
    [StringType.instance],
    true,
    Int32Type.instance,
  ),
  FunDef.new(
    "sum",
    [
      FunParam.new("a", Int32Type.instance),
      FunParam.new("b", Int32Type.instance),
      FunParam.new("c", Int32Type.instance),
    ],
    Int32Type.instance,
    If.new(
      VarRef.new("a"),
      OpAdd.new(
        VarRef.new("a"),
        OpAdd.new(
          VarRef.new("b"),
          VarRef.new("c"),
        ),
      ),
      OpAdd.new(
        VarRef.new("a"),
        VarRef.new("b"),
      ),
    )
  ),
  FunDef.new(
    "main",
    [],
    Int32Type.instance,
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
  ),
]

#############################################################################

mod = LLVMModuleCreateWithName("giraffe")
things.each { |t| t.codegen(mod: mod) }

LLVMVerifyModule(mod, :llvm_abort_process_action, nil)
puts LLVMPrintModuleToString(mod)
