module Clarke
  module Phases
    class SimplifyOpSeq < Generic
      PRECEDENCES = {
        # '^' => 3,
        '*' => 2,
        '/' => 2,
        '+' => 1,
        '-' => 1,
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
        '*' => :left,
        '/' => :left,
        '+' => :left,
        '-' => :left,
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
              when '-'
                stack << Clarke::Nodes::OpSub.new(*es)
              when '*'
                stack << Clarke::Nodes::OpMul.new(*es)
              when '/'
                stack << Clarke::Nodes::OpDiv.new(*es)
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
  end
end
