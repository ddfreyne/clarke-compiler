module Clarke
  module Phases
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
  end
end
