require 'values'
require 'ffi/llvm'

include FFI::LLVM

# TODO: move to driver (along with other gen_code stuff)
def to_llvm(array)
  FFI::MemoryPointer.new(:pointer, array.size).tap do |ptr|
    ptr.put_array_of_pointer(0, array)
  end
end

module Clarke
  module Nodes
    module Node
      attr_accessor :env

      def gen_code(mod:, function:, builder:, env:)
      end
    end

    ### top-level

    FunParam = Struct.new(:name, :type)

    FunDecl = Struct.new(:name, :arg_types, :is_varargs, :return_type) do
      include Node

      def gen_code(mod:, function:, builder:, env:)
        arg_types_llvm = to_llvm(arg_types.map { |at| at.gen_code(mod: mod) })
        return_type_llvm = return_type.gen_code(mod: mod)
        is_varargs_llvm = is_varargs ? 1 : 0

        type = LLVMFunctionType(return_type_llvm, arg_types_llvm, arg_types.size, is_varargs_llvm)
        LLVMAddFunction(mod, name, type).tap { |f| env[name] = f }
      end
    end

    FunDef = Struct.new(:name, :params, :return_type, :body) do
      include Node

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
    end

    ### expressions

    Op = Struct.new(:name) do
    end

    OpSeq = Struct.new(:seq) do
    end

    Const = Struct.new(:value, :type) do
      include Node

      def gen_code(mod:, function:, builder:, env:)
        LLVMConstInt(type.gen_code(mod: mod), value, 0)
      end
    end

    Str = Struct.new(:value) do
      include Node

      def gen_code(mod:, function:, builder:, env:)
        LLVMBuildGlobalStringPtr(builder, value, 'str')
      end
    end

    VarRef = Struct.new(:name) do
      include Node

      def gen_code(mod:, function:, builder:, env:)
        env.fetch(name)
      end
    end

    OpAdd = Struct.new(:lhs, :rhs) do
      include Node

      def gen_code(mod:, function:, builder:, env:)
        LLVMBuildAdd(
          builder,
          lhs.gen_code(mod: mod, function: function, builder: builder, env: env),
          rhs.gen_code(mod: mod, function: function, builder: builder, env: env),
          "op_add_res",
        )
      end
    end

    OpSub = Struct.new(:lhs, :rhs) do
      include Node

      def gen_code(mod:, function:, builder:, env:)
        LLVMBuildSub(
          builder,
          lhs.gen_code(mod: mod, function: function, builder: builder, env: env),
          rhs.gen_code(mod: mod, function: function, builder: builder, env: env),
          "op_add_res",
        )
      end
    end

    OpMul = Struct.new(:lhs, :rhs) do
      include Node

      def gen_code(mod:, function:, builder:, env:)
        LLVMBuildMul(
          builder,
          lhs.gen_code(mod: mod, function: function, builder: builder, env: env),
          rhs.gen_code(mod: mod, function: function, builder: builder, env: env),
          "op_add_res",
        )
      end
    end

    OpDiv = Struct.new(:lhs, :rhs) do
      include Node

      def gen_code(mod:, function:, builder:, env:)
        LLVMBuildUDiv(
          builder,
          lhs.gen_code(mod: mod, function: function, builder: builder, env: env),
          rhs.gen_code(mod: mod, function: function, builder: builder, env: env),
          "op_add_res",
        )
      end
    end

    FunCall = Struct.new(:name, :args) do
      include Node

      def gen_code(mod:, function:, builder:, env:)
        args_ptr = to_llvm(args.map { |a| a.gen_code(mod: mod, function: function, builder: builder, env: env) })
        LLVMBuildCall(builder, env.fetch(name), args_ptr, args.size, "call_#{name}_res")
      end
    end

    If = Struct.new(:condition, :true_clause, :false_clause) do
      include Node

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
        res_false = false_clause.reduce(0) { |_, e| e.gen_code(mod: mod, function: function, builder: builder, env: env) }
        LLVMBuildBr(builder, block_end)

        LLVMPositionBuilderAtEnd(builder, block_end)
        res = LLVMBuildPhi(builder, LLVMInt32Type(), "result")

        phi_vals_ptr = to_llvm([res_true, res_false])
        phi_blocks_ptr = to_llvm([block_true, block_false])

        LLVMAddIncoming(res, phi_vals_ptr, phi_blocks_ptr, 2)
        res
      end
    end
  end
end
