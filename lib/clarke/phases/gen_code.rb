module Clarke
  module Phases
    class GenCode < Generic
      def run(arr)
        mod = LLVMModuleCreateWithName('root')
        env = Clarke::Env.new

        arr.each { |e| e.gen_code(mod: mod, env: env, function: nil, builder: nil) }

        LLVMVerifyModule(mod, :llvm_abort_process_action, nil)
        LLVMPrintModuleToString(mod)
      end
    end
  end
end
