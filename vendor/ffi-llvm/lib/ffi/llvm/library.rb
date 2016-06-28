module FFI
  module LLVM
    extend FFI::Library

    ffi_lib 'LLVM'

    # Modules

    attach_function :"LLVMModuleCreateWithName", [:string], :llvm_module_ref
    attach_function :"LLVMPrintModuleToString", [:llvm_module_ref], :string
    attach_function :"LLVMVerifyModule", [:llvm_module_ref, :llvm_verifier_failure_action, :pointer], :llvm_bool

    # Types

    attach_function :"LLVMInt1Type", [], :llvm_type_ref
    attach_function :"LLVMInt8Type", [], :llvm_type_ref
    attach_function :"LLVMInt16Type", [], :llvm_type_ref
    attach_function :"LLVMInt32Type", [], :llvm_type_ref
    attach_function :"LLVMInt64Type", [], :llvm_type_ref

    attach_function :"LLVMFloatType", [], :llvm_type_ref
    attach_function :"LLVMDoubleType", [], :llvm_type_ref

    attach_function :"LLVMFunctionType", [:llvm_type_ref, :pointer, :uint, :int], :llvm_type_ref

    attach_function :"LLVMPointerType", [:llvm_type_ref, :uint], :llvm_type_ref
    attach_function :"LLVMVoidType", [], :llvm_type_ref
    attach_function :"LLVMLabelType", [], :llvm_type_ref

    # Constants

    attach_function :"LLVMConstInt", [:llvm_type_ref, :ulong_long, :int], :llvm_value_ref

    # Functions

    attach_function :"LLVMAddFunction", [:llvm_module_ref, :string, :llvm_type_ref], :llvm_value_ref
    attach_function :"LLVMGetParam", [:llvm_value_ref, :uint], :llvm_value_ref

    # Basic blocks

    attach_function :"LLVMAppendBasicBlock", [:llvm_value_ref, :string], :llvm_basic_block_ref
    attach_function :"LLVMAddIncoming", [:llvm_value_ref, :pointer, :pointer, :uint], :void

    # Builder

    attach_function :"LLVMCreateBuilder", [], :llvm_builder_ref
    attach_function :"LLVMPositionBuilderAtEnd", [:llvm_builder_ref, :llvm_basic_block_ref], :void

    attach_function :"LLVMBuildAdd", [:llvm_builder_ref, :llvm_value_ref, :llvm_value_ref, :string], :llvm_value_ref
    attach_function :"LLVMBuildSub", [:llvm_builder_ref, :llvm_value_ref, :llvm_value_ref, :string], :llvm_value_ref
    attach_function :"LLVMBuildMul", [:llvm_builder_ref, :llvm_value_ref, :llvm_value_ref, :string], :llvm_value_ref
    attach_function :"LLVMBuildUDiv", [:llvm_builder_ref, :llvm_value_ref, :llvm_value_ref, :string], :llvm_value_ref
    attach_function :"LLVMBuildRet", [:llvm_builder_ref, :llvm_value_ref], :llvm_value_ref
    attach_function :"LLVMBuildRetVoid", [:llvm_builder_ref], :llvm_value_ref
    attach_function :"LLVMBuildICmp", [:llvm_builder_ref, :llvm_int_predicates, :llvm_value_ref, :llvm_value_ref, :string], :llvm_value_ref
    attach_function :"LLVMBuildCondBr", [:llvm_builder_ref, :llvm_value_ref, :llvm_basic_block_ref, :llvm_basic_block_ref], :llvm_value_ref
    attach_function :"LLVMBuildBr", [:llvm_builder_ref, :llvm_basic_block_ref], :llvm_value_ref
    attach_function :"LLVMBuildPhi", [:llvm_builder_ref, :llvm_type_ref, :string], :llvm_value_ref
    attach_function :"LLVMBuildCall", [:llvm_builder_ref, :llvm_value_ref, :pointer, :uint, :string], :llvm_value_ref
    attach_function :"LLVMBuildGlobalStringPtr", [:llvm_builder_ref, :string, :string], :llvm_value_ref
  end
end
