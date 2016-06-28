module Clarke
  module Phases
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

        when
          Clarke::Nodes::OpAdd,
          Clarke::Nodes::OpSub,
          Clarke::Nodes::OpMul,
          Clarke::Nodes::OpDiv
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
  end
end
