-module(math@format).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/math/format.gleam").
-export([to_debug_string/1, parse_error_to_debug_string/1]).

-if(?OTP_RELEASE >= 27).
-define(MODULEDOC(Str), -moduledoc(Str)).
-define(DOC(Str), -doc(Str)).
-else.
-define(MODULEDOC(Str), -compile([])).
-define(DOC(Str), -compile([])).
-endif.

-file("src/math/format.gleam", 176).
-spec quote(binary()) -> binary().
quote(Value) ->
    <<<<"\""/utf8, Value/binary>>/binary, "\""/utf8>>.

-file("src/math/format.gleam", 108).
-spec unit_to_debug_string(math@ast:unit_expr()) -> binary().
unit_to_debug_string(Unit) ->
    case Unit of
        {unit_atom, Symbol} ->
            <<<<"UnitAtom("/utf8, (quote(Symbol))/binary>>/binary, ")"/utf8>>;

        {unit_mul, Left, Right} ->
            <<<<<<<<"UnitMul("/utf8, (unit_to_debug_string(Left))/binary>>/binary,
                        ", "/utf8>>/binary,
                    (unit_to_debug_string(Right))/binary>>/binary,
                ")"/utf8>>;

        {unit_div, Left@1, Right@1} ->
            <<<<<<<<"UnitDiv("/utf8, (unit_to_debug_string(Left@1))/binary>>/binary,
                        ", "/utf8>>/binary,
                    (unit_to_debug_string(Right@1))/binary>>/binary,
                ")"/utf8>>;

        {unit_pow, Unit@1, Exponent} ->
            <<<<<<<<"UnitPow("/utf8, (unit_to_debug_string(Unit@1))/binary>>/binary,
                        ", "/utf8>>/binary,
                    (erlang:integer_to_binary(Exponent))/binary>>/binary,
                ")"/utf8>>
    end.

-file("src/math/format.gleam", 157).
-spec function_name_to_debug_string(math@ast:function_name()) -> binary().
function_name_to_debug_string(Name) ->
    case Name of
        sin ->
            <<"Sin"/utf8>>;

        cos ->
            <<"Cos"/utf8>>;

        tan ->
            <<"Tan"/utf8>>;

        ln ->
            <<"Ln"/utf8>>;

        log ->
            <<"Log"/utf8>>;

        log10 ->
            <<"Log10"/utf8>>;

        log2 ->
            <<"Log2"/utf8>>;

        sqrt ->
            <<"Sqrt"/utf8>>;

        abs ->
            <<"Abs"/utf8>>;

        exp ->
            <<"Exp"/utf8>>
    end.

-file("src/math/format.gleam", 132).
-spec binary_op_to_debug_string(math@ast:binary_op()) -> binary().
binary_op_to_debug_string(Op) ->
    case Op of
        add ->
            <<"Add"/utf8>>;

        subtract ->
            <<"Subtract"/utf8>>;

        {multiply, explicit_multiply} ->
            <<"Mul[explicit]"/utf8>>;

        {multiply, implicit_multiply} ->
            <<"Mul[implicit]"/utf8>>;

        divide ->
            <<"Divide"/utf8>>;

        power ->
            <<"Power"/utf8>>
    end.

-file("src/math/format.gleam", 143).
-spec prefix_op_to_debug_string(math@ast:prefix_op()) -> binary().
prefix_op_to_debug_string(Op) ->
    case Op of
        negate ->
            <<"Negate"/utf8>>;

        positive ->
            <<"Positive"/utf8>>
    end.

-file("src/math/format.gleam", 150).
-spec constant_to_debug_string(math@ast:constant()) -> binary().
constant_to_debug_string(Constant) ->
    case Constant of
        pi ->
            <<"Pi"/utf8>>;

        euler ->
            <<"Euler"/utf8>>
    end.

-file("src/math/format.gleam", 76).
-spec expr_to_debug_string(math@ast:expr()) -> binary().
expr_to_debug_string(Expr) ->
    case erlang:element(2, Expr) of
        {num, Literal} ->
            <<<<"Num("/utf8, (quote(erlang:element(2, Literal)))/binary>>/binary,
                ")"/utf8>>;

        {var, Name} ->
            <<<<"Var("/utf8, (quote(Name))/binary>>/binary, ")"/utf8>>;

        {const, Constant} ->
            <<<<"Const("/utf8, (constant_to_debug_string(Constant))/binary>>/binary,
                ")"/utf8>>;

        {prefix, Op, Arg} ->
            <<<<<<<<"Prefix("/utf8, (prefix_op_to_debug_string(Op))/binary>>/binary,
                        ", "/utf8>>/binary,
                    (expr_to_debug_string(Arg))/binary>>/binary,
                ")"/utf8>>;

        {binary, Op@1, Left, Right} ->
            <<<<<<<<<<(binary_op_to_debug_string(Op@1))/binary, "("/utf8>>/binary,
                            (expr_to_debug_string(Left))/binary>>/binary,
                        ", "/utf8>>/binary,
                    (expr_to_debug_string(Right))/binary>>/binary,
                ")"/utf8>>;

        {call, Name@1, Args} ->
            <<<<<<<<"Call("/utf8,
                            (function_name_to_debug_string(Name@1))/binary>>/binary,
                        ", ["/utf8>>/binary,
                    (gleam@string:join(
                        gleam@list:map(Args, fun expr_to_debug_string/1),
                        <<", "/utf8>>
                    ))/binary>>/binary,
                "])"/utf8>>;

        {factorial, Arg@1} ->
            <<<<"Factorial("/utf8, (expr_to_debug_string(Arg@1))/binary>>/binary,
                ")"/utf8>>
    end.

-file("src/math/format.gleam", 9).
?DOC(
    " Debug formatting is deliberately separate from JSON serialization. These\n"
    " strings are stable golden-test and demo output, not a browser data contract\n"
    " or an evaluator interchange format.\n"
).
-spec to_debug_string(math@ast:parsed()) -> binary().
to_debug_string(Parsed) ->
    case Parsed of
        {expression, Expr} ->
            <<<<"Expression("/utf8, (expr_to_debug_string(Expr))/binary>>/binary,
                ")"/utf8>>;

        {quantity, Value, Unit} ->
            <<<<<<<<"Quantity("/utf8, (expr_to_debug_string(Value))/binary>>/binary,
                        ", "/utf8>>/binary,
                    (unit_to_debug_string(Unit))/binary>>/binary,
                ")"/utf8>>
    end.

-file("src/math/format.gleam", 172).
-spec span_to_debug_string(math@ast:span()) -> binary().
span_to_debug_string(Span) ->
    <<<<<<<<"Span("/utf8,
                    (erlang:integer_to_binary(erlang:element(2, Span)))/binary>>/binary,
                ","/utf8>>/binary,
            (erlang:integer_to_binary(erlang:element(3, Span)))/binary>>/binary,
        ")"/utf8>>.

-file("src/math/format.gleam", 21).
-spec parse_error_to_debug_string(math@ast:parse_error()) -> binary().
parse_error_to_debug_string(Error) ->
    case Error of
        {unexpected_token, Span, Expected, Found} ->
            <<<<<<<<<<<<"UnexpectedToken("/utf8,
                                    (span_to_debug_string(Span))/binary>>/binary,
                                ", expected=["/utf8>>/binary,
                            (gleam@string:join(Expected, <<","/utf8>>))/binary>>/binary,
                        "], found="/utf8>>/binary,
                    (quote(Found))/binary>>/binary,
                ")"/utf8>>;

        {unexpected_end, Expected@1} ->
            <<<<"UnexpectedEnd(expected=["/utf8,
                    (gleam@string:join(Expected@1, <<","/utf8>>))/binary>>/binary,
                "])"/utf8>>;

        {invalid_number, Span@1, Raw} ->
            <<<<<<<<"InvalidNumber("/utf8,
                            (span_to_debug_string(Span@1))/binary>>/binary,
                        ", raw="/utf8>>/binary,
                    (quote(Raw))/binary>>/binary,
                ")"/utf8>>;

        {unsupported_character, Span@2, Raw@1} ->
            <<<<<<<<"UnsupportedCharacter("/utf8,
                            (span_to_debug_string(Span@2))/binary>>/binary,
                        ", raw="/utf8>>/binary,
                    (quote(Raw@1))/binary>>/binary,
                ")"/utf8>>;

        {unsupported_function, Span@3, Name} ->
            <<<<<<<<"UnsupportedFunction("/utf8,
                            (span_to_debug_string(Span@3))/binary>>/binary,
                        ", name="/utf8>>/binary,
                    (quote(Name))/binary>>/binary,
                ")"/utf8>>;

        {function_requires_parentheses, Span@4, Name@1} ->
            <<<<<<<<"FunctionRequiresParentheses("/utf8,
                            (span_to_debug_string(Span@4))/binary>>/binary,
                        ", name="/utf8>>/binary,
                    (quote(Name@1))/binary>>/binary,
                ")"/utf8>>;

        {unclosed_parenthesis, Opened_at} ->
            <<<<"UnclosedParenthesis(opened_at="/utf8,
                    (span_to_debug_string(Opened_at))/binary>>/binary,
                ")"/utf8>>;

        {unclosed_absolute_value, Opened_at@1} ->
            <<<<"UnclosedAbsoluteValue(opened_at="/utf8,
                    (span_to_debug_string(Opened_at@1))/binary>>/binary,
                ")"/utf8>>;

        {trailing_input, Span@5} ->
            <<<<"TrailingInput("/utf8, (span_to_debug_string(Span@5))/binary>>/binary,
                ")"/utf8>>
    end.
