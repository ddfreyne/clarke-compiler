def log(msg)
  $stderr.puts "[#{Time.now.strftime('%H:%M:%S.%L')}] #{msg}"
end

log('hello!')

require 'ffi/llvm'
require 'singleton'
require 'pp'

include FFI::LLVM

log('requirements loaded')

def to_llvm(array)
  FFI::MemoryPointer.new(:pointer, array.size).tap do |ptr|
    ptr.put_array_of_pointer(0, array)
  end
end

### helper

class Env
  def initialize(parent: nil, contents: {})
    @parent = parent
    @contents = contents
  end

  def key?(key)
    @contents.key?(key) || (@parent && @parent.key?(key))
  end

  def fetch(key, expr: nil)
    if @parent
      @contents.fetch(key) { @parent.fetch(key, expr: expr) }
    else
      @contents.fetch(key) { raise NameError.new(key, expr) }
    end
  end

  def []=(key, value)
    @contents[key] = value
  end

  def push(contents = {})
    self.class.new(parent: self, contents: contents)
  end
end

class Type
end

class Int32Type < Type
  include Singleton

  def gen_code(mod:)
    LLVMInt32Type()
  end
end

class StringType < Type
  include Singleton

  def gen_code(mod:)
    LLVMPointerType(LLVMInt8Type(), 0)
  end
end

FunParam = Struct.new(:name, :type)

module Gen
  def typecheck(mod:, env:)
  end

  def gen_code(mod:, function:, builder:, env:)
  end
end

### top-level

FunDecl = Struct.new(:name, :arg_types, :is_varargs, :return_type) do
  include Gen

  def gen_fun_decls(mod:, env:)
    env[name] = self
  end

  def gen_code(mod:, function:, builder:, env:)
    arg_types_llvm = to_llvm(arg_types.map { |at| at.gen_code(mod: mod) })
    return_type_llvm = return_type.gen_code(mod: mod)
    is_varargs_llvm = is_varargs ? 1 : 0

    type = LLVMFunctionType(return_type_llvm, arg_types_llvm, arg_types.size, is_varargs_llvm)
    LLVMAddFunction(mod, name, type).tap { |f| env[name] = f }
  end
end

FunDef = Struct.new(:name, :params, :return_type, :body) do
  include Gen

  def gen_fun_decls(mod:, env:)
    env[name] = FunDecl.new(name, params.map(&:type), false, return_type)
  end

  def gen_code(mod:, function:, builder:, env:)
    params_ptr = to_llvm(params.map { |pa| pa.type.gen_code(mod: mod) })

    function_type = LLVMFunctionType(
      return_type.gen_code(mod: mod),
      params_ptr,
      params.size,
      0,
    )

    function = env.fetch(name)

    entry = LLVMAppendBasicBlock(function, "entry")
    builder = LLVMCreateBuilder()
    LLVMPositionBuilderAtEnd(builder, entry)

    new_env = env.push
    params.each_with_index do |par, i|
      llvm_param = LLVMGetParam(function, i)
      new_env[par.name] = llvm_param
    end

    tmp = body.reduce(0) { |_, e| e.gen_code(mod: mod, function: function, builder: builder, env: new_env) }

    LLVMBuildRet(builder, tmp)
  end

  def typecheck(mod:, env:)
    new_env = env.push
    params.each do |par|
      new_env[par.name] = par
    end

    raise 'last expr of function is not int32' unless body.last.typecheck(mod: mod, env: new_env) == Int32Type.instance
  end
end

### expressions

Const = Struct.new(:value, :type) do
  include Gen

  def gen_code(mod:, function:, builder:, env:)
    LLVMConstInt(type.gen_code(mod: mod), value, 0)
  end

  def typecheck(mod:, env:)
    type
  end
end

Str = Struct.new(:value) do
  include Gen

  def gen_code(mod:, function:, builder:, env:)
    LLVMBuildGlobalStringPtr(builder, value, 'str')
  end

  def typecheck(mod:, env:)
    StringType.instance
  end
end

VarRef = Struct.new(:name) do
  include Gen

  def gen_code(mod:, function:, builder:, env:)
    env.fetch(name)
  end

  def typecheck(mod:, env:)
    env.fetch(name).type
  end
end

OpAdd = Struct.new(:lhs, :rhs) do
  include Gen

  def gen_code(mod:, function:, builder:, env:)
    LLVMBuildAdd(
      builder,
      lhs.gen_code(mod: mod, function: function, builder: builder, env: env),
      rhs.gen_code(mod: mod, function: function, builder: builder, env: env),
      "op_add_res",
    )
  end

  def typecheck(mod:, env:)
    raise "type error: lhs is not int32" unless lhs.typecheck(mod: mod, env: env) == Int32Type.instance
    raise "type error: rhs is not int32" unless rhs.typecheck(mod: mod, env: env) == Int32Type.instance
    Int32Type.instance
  end
end

FunCall = Struct.new(:name, :args) do
  include Gen

  def gen_code(mod:, function:, builder:, env:)
    args_ptr = to_llvm(args.map { |a| a.gen_code(mod: mod, function: function, builder: builder, env: env) })
    LLVMBuildCall(builder, env.fetch(name), args_ptr, args.size, "call_#{name}_res")
  end

  def typecheck(mod:, env:)
    env.fetch(name).return_type
  end
end

If = Struct.new(:condition, :true_clause, :false_clause) do
  include Gen

  def gen_code(mod:, function:, builder:, env:)
    var_condition = condition.gen_code(mod: mod, function: function, builder: builder, env: env)

    block_true = LLVMAppendBasicBlock(function, "if_true")
    block_false = LLVMAppendBasicBlock(function, "if_false")
    block_end = LLVMAppendBasicBlock(function, "if_end")

    # FIXME: wrong condition
    constant_zero = LLVMConstInt(LLVMInt32Type(), 0, 0)
    cond = LLVMBuildICmp(builder, :llvm_int_eq, var_condition, constant_zero, "cond")
    LLVMBuildCondBr(builder, cond, block_true, block_false)

    LLVMPositionBuilderAtEnd(builder, block_true)
    res_true = true_clause.reduce(0) { |_, e| e.gen_code(mod: mod, function: function, builder: builder, env: env) }
    LLVMBuildBr(builder, block_end)

    LLVMPositionBuilderAtEnd(builder, block_false)
    res_false = true_clause.reduce(0) { |_, e| e.gen_code(mod: mod, function: function, builder: builder, env: env) }
    LLVMBuildBr(builder, block_end)

    LLVMPositionBuilderAtEnd(builder, block_end)
    res = LLVMBuildPhi(builder, LLVMInt32Type(), "result")

    phi_vals_ptr = to_llvm([res_true, res_false])
    phi_blocks_ptr = to_llvm([block_true, block_false])

    LLVMAddIncoming(res, phi_vals_ptr, phi_blocks_ptr, 2)
    res
  end

  def typecheck(mod:, env:)
    raise "type error: true clause is not int32" unless true_clause.last.typecheck(mod: mod, env: env) == Int32Type.instance
    raise "type error: false clause is not int32" unless false_clause.last.typecheck(mod: mod, env: env) == Int32Type.instance
    Int32Type.instance
  end
end

#############################################################################

def gen_fun_decls(arr, mod, env)
  fun_decls = []
  fun_defs = []
  others = []
  arr.each do |e|
    case e
    when FunDecl
      fun_decls << e
    when FunDef
      fun_defs << e
    else
      others << e
    end
  end

  arr.replace([])
  (fun_decls + fun_defs).each { |e| arr << e.gen_fun_decls(mod: mod, env: env) }
  arr.concat(fun_defs)
  arr.concat(others)
end

def gen_main(arr, mod, env)
  if env.key?('main')
    raise "Function `main` already defined"
  end

  stmts, exprs = arr.partition do |e|
    [FunDecl, FunDef].include?(e.class)
  end

  arr.replace(stmts)

  arr << FunDef.new('main', [], Int32Type.instance, exprs)
end

def typecheck(arr, mod, env)
  arr.each { |e| e.typecheck(mod: mod, env: env) }
end

def gen_code(arr, mod, env)
  arr.each { |e| e.gen_code(mod: mod, env: env, function: nil, builder: nil) }
end

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

#############################################################################

log('compilation started')

mod = LLVMModuleCreateWithName('giraffe')
env = Env.new
log('  phase: gen_main')
gen_main(things, mod, env)
log('  phase: gen_fun_decls')
gen_fun_decls(things, mod, env)
log('  phase: typecheck')
typecheck(things, mod, env)
log('  phase: gen_code')
gen_code(things, mod, env)

log('compilation ended')

LLVMVerifyModule(mod, :llvm_abort_process_action, nil)
puts LLVMPrintModuleToString(mod)
