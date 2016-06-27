require 'd-parse'

module Clarke
  module Grammar
    extend DParse::DSL

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

    STR =
      seq(
        char('"'),
        repeat(
          except(
            succeed,
            char('"'),
          ),
        ),
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
          string('false'),
          string('fun'),
          string('if'),
          string('in'),
          string('let'),
          string('true'),
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
        Clarke::Nodes::FunctionCall.new(data[0], data[1])
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

    FUN_DEF =
      seq(
        string('fun').ignore,
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

    EXPRESSION =
      alt(
        FUN_CALL,
        NUMBER,
        IF,
        VAR_REF,
      )

    STATEMENT =
      alt(
        FUN_DEF,
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
