module Clarke
  class Driver
    def run(things)
      log('compilation started')

      log('  phase: build_env')
      env = Clarke::Phases::BuildEnv.new.run(things)

      log('  phase: lift_main')
      Clarke::Phases::LiftMain.new.run(things, env)

      log('  phase: lift_fun_decls')
      Clarke::Phases::LiftFunDecls.new.run(things, env)

      log('  phase: typecheck')
      Clarke::Phases::Typecheck.new.run(things)

      log('  phase: gen_code')
      ir = Clarke::Phases::GenCode.new.run(things)

      log('compilation ended')

      puts ir
    end

    private

    def log(msg)
      $stderr.puts "[#{Time.now.strftime('%H:%M:%S.%L')}] #{msg}"
    end
  end
end
