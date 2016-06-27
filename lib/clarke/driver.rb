module Clarke
  class Driver
    def run(things)
      log('compilation started')

      mod = LLVMModuleCreateWithName('root')
      env = Clarke::Env.new

      log('  phase: lift_main')
      Clarke::Phases::LiftMain.new.run(things, mod, env)

      log('  phase: lift_fun_decls')
      Clarke::Phases::LiftFunDecls.new.run(things, mod, env)

      log('  phase: typecheck')
      Clarke::Phases::Typecheck.new.run(things, mod, env)

      log('  phase: gen_code')
      Clarke::Phases::GenCode.new.run(things, mod, env)

      log('compilation ended')

      LLVMVerifyModule(mod, :llvm_abort_process_action, nil)
      puts LLVMPrintModuleToString(mod)
    end

    private

    def log(msg)
      $stderr.puts "[#{Time.now.strftime('%H:%M:%S.%L')}] #{msg}"
    end
  end
end
