require 'd-parse'

module Clarke
  module Grammar
    extend DParse::DSL
    include Clarke::Nodes

    def self.repeat1(a)
      seq(a, repeat(a)).map { |d| [d[0]] + d[1] }
    end

    DIGIT = char_in('0'..'9')

    NUMBER =
      repeat1(DIGIT)
      .capture
      .map do |d|
        Clarke::Nodes::Const.new(d.to_i, Int32Type.instance)
      end

    STRING =
      seq(
        char('"'),
        repeat(
          char_not('"'),
        ).capture,
        char('"'),
      )
      .map do |d|
        Clarke::Nodes::Str.new(d[1])
      end

    LETTER = char_in('a'..'z')

    SPACE_OR_TAB =
      alt(
        char(' '),
        char("\t"),
      )

    WHITESPACE_CHAR =
      alt(
        char(' '),
        char("\t"),
        char("\n"),
        char("\r"),
      )

    WHITESPACE0 =
      repeat(WHITESPACE_CHAR)

    WHITESPACE1 =
      seq(WHITESPACE_CHAR, WHITESPACE0)

    RESERVED_WORD =
      describe(
        alt(
          string('else'),
          string('def'),
          string('decl'),
          string('if'),
        ),
        'reserved keyword',
      )

    IDENTIFIER =
      except(
        describe(
          repeat1(LETTER).capture,
          'identifier',
        ),
        RESERVED_WORD,
      )

    FUN_NAME = IDENTIFIER
    VAR_NAME = IDENTIFIER

    FUN_CALL =
      seq(
        FUN_NAME,
        char('(').ignore,
        opt(
          intersperse(
            seq(
              WHITESPACE0.ignore,
              lazy { EXPRESSION },
              WHITESPACE0.ignore,
            ).compact.first,
            char(',').ignore,
          ).select_even,
        ).map { |d| d || [] },
        char(')').ignore,
      ).compact.map do |data|
        Clarke::Nodes::FunCall.new(data[0], data[1])
      end

    VAR_REF =
      VAR_NAME
      .map { |d| Clarke::Nodes::VarRef.new(d) }

    INT32_TYPE =
      string('int32')
      .map { |_| Int32Type.instance }

    STRING_TYPE =
      string('string')
      .map { |_| StringType.instance }

    TYPE =
      alt(
        INT32_TYPE,
        STRING_TYPE,
      )

    VAR_DECL =
      seq(
        VAR_NAME,
        WHITESPACE0.ignore,
        string(':').ignore,
        WHITESPACE0.ignore,
        TYPE,
      ).compact.map do |d|
        FunParam.new(d[0], d[1])
      end

    IF =
      seq(
        string('if').ignore,
        WHITESPACE0.ignore,
        char('(').ignore,
        WHITESPACE0.ignore,
        lazy { EXPRESSION },
        WHITESPACE0.ignore,
        char(')').ignore,
        WHITESPACE0.ignore,
        string('{').ignore,
        repeat1(lazy { EXPRESSION }),
        string('}').ignore,
        WHITESPACE0.ignore,
        string('else').ignore,
        WHITESPACE0.ignore,
        string('{').ignore,
        repeat1(lazy { EXPRESSION }),
        string('}').ignore,
      ).compact.map do |data|
        Clarke::Nodes::If.new(data[0], data[1], data[2])
      end

    FUN_DECL =
      seq(
        string('decl').ignore,
        WHITESPACE1.ignore,
        FUN_NAME,
        WHITESPACE0.ignore,
        char('(').ignore,
        opt(
          intersperse(
            seq(
              WHITESPACE0.ignore,
              TYPE,
              WHITESPACE0.ignore,
            ).compact.first,
            char(',').ignore,
          ).select_even,
        ).map { |d| d || [] },
        # FIXME: varargs does not allow zero-arg varargs
        opt(
          seq(
            char(','),
            WHITESPACE0.ignore,
            string('...'),
          ),
        ).capture,
        char(')').ignore,
        WHITESPACE0.ignore,
        string(':').ignore,
        WHITESPACE0.ignore,
        TYPE,
      ).compact.map do |data|
        Clarke::Nodes::FunDecl.new(
          data[0], data[1], !data[2].empty?, data[3],
        )
      end

    FUN_DEF =
      seq(
        string('def').ignore,
        WHITESPACE1.ignore,
        FUN_NAME,
        WHITESPACE0.ignore,
        char('(').ignore,
        opt(
          intersperse(
            seq(
              WHITESPACE0.ignore,
              VAR_DECL,
              WHITESPACE0.ignore,
            ).compact.first,
            char(',').ignore,
          ).select_even,
        ).map { |d| d || [] },
        char(')').ignore,
        WHITESPACE0.ignore,
        string(':').ignore,
        WHITESPACE0.ignore,
        TYPE,
        WHITESPACE0.ignore,
        string('{').ignore,
        repeat1(lazy { EXPRESSION }),
        string('}').ignore,
      ).compact.map do |data|
        Clarke::Nodes::FunDef.new(data[0], data[1], data[2], data[3])
      end

    OPERATOR =
      alt(
        # char('^'),
        char('*'),
        char('/'),
        char('+'),
        char('-'),
        # string('=='),
        # string('>='),
        # string('>'),
        # string('<='),
        # string('<'),
        # string('&&'),
        # string('||'),
      ).capture.map { |d| Clarke::Nodes::Op.new(d) }

    # TRUE =
    #   string('true').map { |_| Clarke::AST::TrueLiteral }
    #
    # FALSE =
    #   string('false').map { |_| Clarke::AST::FalseLiteral }

    OPERAND =
      alt(
        # TRUE,
        # FALSE,
        FUN_CALL,
        NUMBER,
        STRING,
        IF,
        VAR_REF,
      )

    EXPRESSION =
      intersperse(
        OPERAND,
        seq(
          WHITESPACE0.ignore,
          OPERATOR,
          WHITESPACE0.ignore,
        ).compact.first,
      ).map do |data|
        Clarke::Nodes::OpSeq.new(data)
      end

    STATEMENT =
      alt(
        FUN_DEF,
        FUN_DECL,
        EXPRESSION,
      )

    LINE_BREAK =
      seq(
        repeat(SPACE_OR_TAB),
        char("\n"),
        WHITESPACE0,
      )

    STATEMENTS =
      intersperse(
        STATEMENT,
        LINE_BREAK,
      ).select_even

    PROGRAM =
      seq(
        WHITESPACE0.ignore,
        STATEMENTS,
        WHITESPACE0.ignore,
        eof.ignore,
      ).compact.first
  end
end
