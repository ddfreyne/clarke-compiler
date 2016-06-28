module Clarke
  module Phases
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

        when OpAdd, OpSub, OpDiv, OpMul
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
  end
end
