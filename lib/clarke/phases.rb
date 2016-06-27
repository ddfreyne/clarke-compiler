def lift_fun_decls(arr, mod, env)
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
  (fun_decls + fun_defs).each { |e| arr << e.lift_fun_decls(mod: mod, env: env) }
  arr.concat(fun_defs)
  arr.concat(others)
end

def lift_main(arr, mod, env)
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
