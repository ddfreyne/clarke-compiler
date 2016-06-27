module Clarke
  module Phases
    class Generic
      def run(arr, mod, env)
        raise '???'
      end
    end

    class BuildEnv < Generic
      def run(arr)
        Clarke::Env.new.tap do |env|
          arr.each { |obj| run_single(obj, env) }
        end
      end

      def run_single(obj, parent_env)
        case obj
        when Clarke::Nodes::FunDecl
          parent_env[obj.name] = obj
          obj.tenv = parent_env

        when Clarke::Nodes::FunDef
          parent_env[obj.name] =
            FunDecl.new(obj.name, obj.params.map(&:type), false, obj.return_type)
          obj.tenv =
            parent_env.push.tap do |new_env|
              obj.params.each do |param|
                new_env[param.name] = param
              end
            end

        when Clarke::Nodes::Const
          obj.tenv = parent_env

        when Clarke::Nodes::Str
          obj.tenv = parent_env

        when Clarke::Nodes::VarRef
          obj.tenv = parent_env

        when Clarke::Nodes::OpAdd
          obj.tenv = parent_env

        when Clarke::Nodes::FunCall
          obj.tenv = parent_env

        when Clarke::Nodes::If
          obj.tenv = parent_env

        end
      end
    end

    class LiftMain < Generic
      def run(arr, env)
        if env.key?('main')
          raise "Function `main` already defined"
        end

        stmts, exprs = arr.partition do |e|
          [FunDecl, FunDef].include?(e.class)
        end

        arr.replace(stmts)

        arr << FunDef.new('main', [], Int32Type.instance, exprs)
      end
    end

    class LiftFunDecls < Generic
      def run(arr, mod, env)
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

        new_fun_decls =
          (fun_decls + fun_defs).map do |e|
            case e
            when Clarke::Nodes::FunDecl
              e
            when Clarke::Nodes::FunDef
              FunDecl.new(e.name, e.params.map(&:type), false, e.return_type)
            else
              raise '???'
            end
          end

        arr.replace(new_fun_decls + fun_defs + others)
      end
    end

    class Typecheck < Generic
      def run(arr, mod, env)
        arr.each { |e| e.typecheck(mod: mod, env: env) }
      end
    end

    class GenCode < Generic
      def run(arr, mod, env)
        arr.each { |e| e.gen_code(mod: mod, env: env, function: nil, builder: nil) }
      end
    end
  end
end
