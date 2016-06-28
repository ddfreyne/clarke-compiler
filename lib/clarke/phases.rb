module Clarke
  module Phases
    class Generic
      include Clarke::Nodes

      def run(arr, mod, env)
        raise '???'
      end
    end
  end
end

require_relative 'phases/build_env'
require_relative 'phases/lift_fun_decls'
require_relative 'phases/lift_main'
require_relative 'phases/simplify_op_seq'
require_relative 'phases/typecheck'
require_relative 'phases/gen_code'
