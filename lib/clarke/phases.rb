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

      private

      def run_single(obj, parent_env)
        case obj
        when Clarke::Nodes::FunDecl
          parent_env[obj.name] = obj
          obj.env = parent_env

        when Clarke::Nodes::FunDef
          parent_env[obj.name] =
            FunDecl.new(obj.name, obj.params.map(&:type), false, obj.return_type)
          obj.env = parent_env.push
          obj.params.each { |param| obj.env[param.name] = param }
          obj.body.each { |e| run_single(e, obj.env) }

        when Clarke::Nodes::Const
          obj.env = parent_env

        when Clarke::Nodes::Str
          obj.env = parent_env

        when Clarke::Nodes::VarRef
          obj.env = parent_env

        when Clarke::Nodes::OpAdd
          obj.env = parent_env
          run_single(obj.lhs, obj.env)
          run_single(obj.rhs, obj.env)

        when Clarke::Nodes::FunCall
          obj.env = parent_env
          obj.args.each do |arg|
            run_single(arg, obj.env)
          end

        when Clarke::Nodes::If
          obj.env = parent_env.push
          run_single(obj.condition, obj.env)
          true_env = obj.env.push
          obj.true_clause.each { |e| run_single(e, true_env) }
          false_env = obj.env.push
          obj.false_clause.each { |e| run_single(e, false_env) }

        else
          raise "Don’t know how to handle #{obj.class}"

        end
      end
    end

    class SimplifyOpSeq < Generic
      PRECEDENCES = {
        # '^' => 3,
        # '*' => 2,
        # '/' => 2,
        '+' => 1,
        # '-' => 1,
        # '&&' => 0,
        # '||' => 0,
        # '==' => 0,
        # '>'  => 0,
        # '<'  => 0,
        # '>=' => 0,
        # '<=' => 0,
      }.freeze

      ASSOCIATIVITIES = {
        # '^' => :right,
        # '*' => :left,
        # '/' => :left,
        '+' => :left,
        # '-' => :left,
        # '==' => :left,
        # '>'  => :left,
        # '<'  => :left,
        # '>=' => :left,
        # '<=' => :left,
        # '&&' => :left,
        # '||' => :left,
      }.freeze

      def run(arr)
        arr.replace(
          arr.map { |e| run_single(e) }
        )
      end

      def run_single(obj)
        case obj
        when Clarke::Nodes::FunDecl
          obj
        when Clarke::Nodes::Const
          obj
        when Clarke::Nodes::Str
          obj
        when Clarke::Nodes::VarRef
          obj
        when Clarke::Nodes::Op
          obj
        when Clarke::Nodes::FunParam
          obj
        when Clarke::Nodes::FunCall
          Clarke::Nodes::FunCall.new(
            obj.name,
            obj.args.map { |a| run_single(a) },
          )
        when Clarke::Nodes::FunDef
          Clarke::Nodes::FunDef.new(
            obj.name,
            obj.params.map { |pa| run_single(pa) },
            obj.return_type,
            obj.body.map { |e| run_single(e) },
          )
        when Clarke::Nodes::If
          Clarke::Nodes::If.new(
            run_single(obj.condition),
            obj.true_clause.map { |c| run_single(c) },
            obj.false_clause.map { |c| run_single(c) },
          )
        when Clarke::Nodes::OpSeq
          res = shunting_yard(obj.seq)
          stack = []
          res.each do |r|
            case r
            when Clarke::Nodes::Op
              es = stack.pop(2)
              case r.name
              when '+'
                stack << Clarke::Nodes::OpAdd.new(*es)
              else
                raise "Don’t know how to handle op #{r.name}"
              end
            else
              stack << run_single(r)
            end
          end
          stack.first

        else
          raise "Don’t know how to handle #{obj.class}"
        end
      end

      private

      def shunting_yard(tokens)
        output = []
        stack = []

        tokens.each do |t|
          case t
          when Clarke::Nodes::Op
            loop do
              break if stack.empty?

              stack_left_associative =
                ASSOCIATIVITIES.fetch(stack.last.name) == :left
              stack_precedence =
                PRECEDENCES.fetch(stack.last.name)
              input_precedence = PRECEDENCES.fetch(t.name)

              break if stack_left_associative &&
                input_precedence > stack_precedence
              break if !stack_left_associative &&
                input_precedence >= stack_precedence

              output << stack.pop
            end
            stack << t
          else
            output << t
          end
        end

        stack.reverse_each do |t|
          output << t
        end

        output
      end

    end

    class LiftMain < Generic
      def run(arr)
        if arr.any? { |e| e.is_a?(FunDef) && e.name == 'main' }
          raise "Function `main` is reserved"
        end

        stmts, exprs = arr.partition do |e|
          [FunDecl, FunDef].include?(e.class)
        end

        unless exprs.empty?
          arr.replace(stmts)
          arr << FunDef.new('main', [], Int32Type.instance, exprs)
        end
      end
    end

    class LiftFunDecls < Generic
      def run(arr)
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
      def run(arr)
        arr.each { |e| run_single(e) }
      end

      private

      def run_single(obj)
        case obj
        when FunDef
          unless run_single(obj.body.last) == Int32Type.instance
            raise 'last expr of function is not int32'
          end

        when Const
          obj.type

        when Str
          StringType.instance

        when VarRef
          obj.env.fetch(obj.name).type

        when OpAdd
          unless run_single(obj.lhs) == Int32Type.instance
            raise "type error: lhs is not int32"
          end
          unless run_single(obj.rhs) == Int32Type.instance
            raise "type error: rhs is not int32"
          end
          Int32Type.instance

        when FunCall
          obj.env.fetch(obj.name).return_type

        when If
          unless run_single(obj.true_clause.last) == Int32Type.instance
            raise "type error: true clause is not int32"
          end

          unless run_single(obj.false_clause.last) == Int32Type.instance
            raise "type error: false clause is not int32"
          end

          Int32Type.instance
        end
      end
    end

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
