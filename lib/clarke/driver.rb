module Clarke
  class Driver
    def run(things)
      log('compilation started')

      mod = LLVMModuleCreateWithName('root')
      env = Env.new

      log('  phase: lift_main')
      lift_main(things, mod, env)

      log('  phase: lift_fun_decls')
      lift_fun_decls(things, mod, env)

      log('  phase: typecheck')
      typecheck(things, mod, env)

      log('  phase: gen_code')
      gen_code(things, mod, env)

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
