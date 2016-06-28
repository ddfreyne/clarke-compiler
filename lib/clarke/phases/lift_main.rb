module Clarke
  module Phases
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
  end
end
