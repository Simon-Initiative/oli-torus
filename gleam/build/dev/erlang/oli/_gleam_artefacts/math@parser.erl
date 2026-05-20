-module(math@parser).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/math/parser.gleam").
-export([parse_tokens/1, parse/1]).

-if(?OTP_RELEASE >= 27).
-define(MODULEDOC(Str), -moduledoc(Str)).
-define(DOC(Str), -doc(Str)).
-else.
-define(MODULEDOC(Str), -compile([])).
-define(DOC(Str), -compile([])).
-endif.

-file("src/math/parser.gleam", 555).
-spec binary_op_to_source(math@ast:binary_op()) -> binary().
binary_op_to_source(Op) ->
    case Op of
        add ->
            <<"+"/utf8>>;

        subtract ->
            <<"-"/utf8>>;

        {multiply, _} ->
            <<"*"/utf8>>;

        divide ->
            <<"/"/utf8>>;

        power ->
            <<"^"/utf8>>
    end.

-file("src/math/parser.gleam", 524).
-spec expr_span(math@ast:expr()) -> math@ast:span().
expr_span(Expr) ->
    erlang:element(3, Expr).

-file("src/math/parser.gleam", 528).
-spec combine_spans(math@ast:span(), math@ast:span()) -> math@ast:span().
combine_spans(Left, Right) ->
    {span, erlang:element(2, Left), erlang:element(3, Right)}.

-file("src/math/parser.gleam", 471).
-spec multiply_binding_power() -> {integer(), integer()}.
multiply_binding_power() ->
    {3, 4}.

-file("src/math/parser.gleam", 483).
-spec implicit_multiplication_start(math@token:token()) -> boolean().
implicit_multiplication_start(Token) ->
    case Token of
        {number_token, _, _, _} ->
            true;

        {word_token, _, _, _} ->
            true;

        {symbol_token, l_paren, _, _} ->
            true;

        {symbol_token, bar, _, _} ->
            true;

        _ ->
            false
    end.

-file("src/math/parser.gleam", 448).
-spec infix_binding_power(math@token:symbol()) -> {ok,
        {integer(), integer(), math@ast:binary_op()}} |
    {error, nil}.
infix_binding_power(Symbol) ->
    case Symbol of
        plus ->
            {ok, {1, 2, add}};

        minus ->
            {ok, {1, 2, subtract}};

        star ->
            {Left_binding_power, Right_binding_power} = multiply_binding_power(),
            {ok,
                {Left_binding_power,
                    Right_binding_power,
                    {multiply, explicit_multiply}}};

        slash ->
            {Left_binding_power@1, Right_binding_power@1} = multiply_binding_power(
                
            ),
            {ok, {Left_binding_power@1, Right_binding_power@1, divide}};

        caret ->
            {ok, {7, 6, power}};

        _ ->
            {error, nil}
    end.

-file("src/math/parser.gleam", 479).
-spec postfix_binding_power() -> integer().
postfix_binding_power() ->
    9.

-file("src/math/parser.gleam", 540).
-spec symbol_to_source(math@token:symbol()) -> binary().
symbol_to_source(Symbol) ->
    case Symbol of
        plus ->
            <<"+"/utf8>>;

        minus ->
            <<"-"/utf8>>;

        star ->
            <<"*"/utf8>>;

        slash ->
            <<"/"/utf8>>;

        caret ->
            <<"^"/utf8>>;

        l_paren ->
            <<"("/utf8>>;

        r_paren ->
            <<")"/utf8>>;

        bar ->
            <<"|"/utf8>>;

        bang ->
            <<"!"/utf8>>;

        comma ->
            <<","/utf8>>
    end.

-file("src/math/parser.gleam", 532).
-spec token_to_source(math@token:token()) -> binary().
token_to_source(Token) ->
    case Token of
        {number_token, Literal, _, _} ->
            erlang:element(2, Literal);

        {word_token, Raw, _, _} ->
            Raw;

        {symbol_token, Symbol, _, _} ->
            symbol_to_source(Symbol)
    end.

-file("src/math/parser.gleam", 520).
-spec with_span(math@ast:expr(), math@ast:span()) -> math@ast:expr().
with_span(Expr, Span) ->
    {expr, erlang:element(2, Expr), Span}.

-file("src/math/parser.gleam", 475).
-spec prefix_binding_power() -> integer().
prefix_binding_power() ->
    5.

-file("src/math/parser.gleam", 509).
-spec is_single_ascii_letter(binary()) -> boolean().
is_single_ascii_letter(Raw) ->
    case gleam@string:to_utf_codepoints(Raw) of
        [Codepoint] ->
            Code = gleam_stdlib:identity(Codepoint),
            ((Code >= 65) andalso (Code =< 90)) orelse ((Code >= 97) andalso (Code
            =< 122));

        _ ->
            false
    end.

-file("src/math/parser.gleam", 170).
-spec word_part_expr(binary(), math@ast:span()) -> {ok, math@ast:expr()} |
    {error, math@ast:parse_error()}.
word_part_expr(Raw, Span) ->
    case is_single_ascii_letter(Raw) of
        true ->
            {ok, {expr, {var, Raw}, Span}};

        false ->
            {error,
                {unexpected_token,
                    Span,
                    [<<"single-letter variable"/utf8>>],
                    Raw}}
    end.

-file("src/math/parser.gleam", 138).
-spec combine_variable_run(
    math@ast:expr(),
    list(binary()),
    integer(),
    list(math@token:token())
) -> {ok, {math@ast:expr(), list(math@token:token())}} |
    {error, math@ast:parse_error()}.
combine_variable_run(Left, Remaining, Offset, Rest) ->
    case Remaining of
        [] ->
            {ok, {Left, Rest}};

        [Next | Tail] ->
            Part_span = {span, Offset, Offset + 1},
            case word_part_expr(Next, Part_span) of
                {ok, Right} ->
                    Combined = {expr,
                        {binary, {multiply, implicit_multiply}, Left, Right},
                        combine_spans(expr_span(Left), expr_span(Right))},
                    combine_variable_run(Combined, Tail, Offset + 1, Rest);

                {error, Error} ->
                    {error, Error}
            end
    end.

-file("src/math/parser.gleam", 110).
-spec parse_variable_run(binary(), math@ast:span(), list(math@token:token())) -> {ok,
        {math@ast:expr(), list(math@token:token())}} |
    {error, math@ast:parse_error()}.
parse_variable_run(Raw, Span, Rest) ->
    case gleam@string:to_graphemes(Raw) of
        [] ->
            {error,
                {unexpected_token,
                    Span,
                    [<<"single-letter variable"/utf8>>],
                    Raw}};

        [First | Remaining] ->
            First_span = {span,
                erlang:element(2, Span),
                erlang:element(2, Span) + 1},
            case word_part_expr(First, First_span) of
                {ok, Left} ->
                    combine_variable_run(
                        Left,
                        Remaining,
                        erlang:element(2, Span) + 1,
                        Rest
                    );

                {error, Error} ->
                    {error, Error}
            end
    end.

-file("src/math/parser.gleam", 493).
-spec function_name(binary()) -> {ok, math@ast:function_name()} | {error, nil}.
function_name(Raw) ->
    case Raw of
        <<"sin"/utf8>> ->
            {ok, sin};

        <<"cos"/utf8>> ->
            {ok, cos};

        <<"tan"/utf8>> ->
            {ok, tan};

        <<"ln"/utf8>> ->
            {ok, ln};

        <<"log"/utf8>> ->
            {ok, log};

        <<"log10"/utf8>> ->
            {ok, log10};

        <<"log2"/utf8>> ->
            {ok, log2};

        <<"sqrt"/utf8>> ->
            {ok, sqrt};

        <<"abs"/utf8>> ->
            {ok, abs};

        <<"exp"/utf8>> ->
            {ok, exp};

        _ ->
            {error, nil}
    end.

-file("src/math/parser.gleam", 415).
-spec parse_infix_right(
    math@ast:expr(),
    list(math@token:token()),
    integer(),
    integer(),
    boolean(),
    math@ast:binary_op()
) -> {ok, {math@ast:expr(), list(math@token:token())}} |
    {error, math@ast:parse_error()}.
parse_infix_right(
    Left,
    Rest,
    Right_binding_power,
    Min_binding_power,
    Stop_at_bar,
    Op
) ->
    case parse_expr_until(Rest, Right_binding_power, Stop_at_bar) of
        {ok, {Right, Next_tokens}} ->
            Expr = {expr,
                {binary, Op, Left, Right},
                combine_spans(expr_span(Left), expr_span(Right))},
            parse_infix(Expr, Next_tokens, Min_binding_power, Stop_at_bar);

        {error, {unexpected_end, _}} ->
            {error,
                {unexpected_end,
                    [<<<<"expression after `"/utf8,
                                (binary_op_to_source(Op))/binary>>/binary,
                            "`"/utf8>>]}};

        {error, Error} ->
            {error, Error}
    end.

-file("src/math/parser.gleam", 390).
-spec parse_implicit_multiplication(
    math@ast:expr(),
    list(math@token:token()),
    integer(),
    boolean()
) -> {ok, {math@ast:expr(), list(math@token:token())}} |
    {error, math@ast:parse_error()}.
parse_implicit_multiplication(Left, Tokens, Min_binding_power, Stop_at_bar) ->
    {Left_binding_power, Right_binding_power} = multiply_binding_power(),
    case Left_binding_power < Min_binding_power of
        true ->
            {ok, {Left, Tokens}};

        false ->
            parse_infix_right(
                Left,
                Tokens,
                Right_binding_power,
                Min_binding_power,
                Stop_at_bar,
                {multiply, implicit_multiply}
            )
    end.

-file("src/math/parser.gleam", 305).
-spec parse_infix(
    math@ast:expr(),
    list(math@token:token()),
    integer(),
    boolean()
) -> {ok, {math@ast:expr(), list(math@token:token())}} |
    {error, math@ast:parse_error()}.
parse_infix(Left, Tokens, Min_binding_power, Stop_at_bar) ->
    case Tokens of
        [{symbol_token, bar, _, _} | _] ->
            case Stop_at_bar of
                true ->
                    {ok, {Left, Tokens}};

                false ->
                    parse_implicit_multiplication(
                        Left,
                        Tokens,
                        Min_binding_power,
                        Stop_at_bar
                    )
            end;

        [{symbol_token, bang, Bang_span, _} | Rest] ->
            case postfix_binding_power() < Min_binding_power of
                true ->
                    {ok, {Left, Tokens}};

                false ->
                    Expr = {expr,
                        {factorial, Left},
                        combine_spans(expr_span(Left), Bang_span)},
                    parse_infix(Expr, Rest, Min_binding_power, Stop_at_bar)
            end;

        [{symbol_token, Symbol, _, _} | Rest@1] ->
            case infix_binding_power(Symbol) of
                {ok, {Left_binding_power, Right_binding_power, Op}} ->
                    case Left_binding_power < Min_binding_power of
                        true ->
                            {ok, {Left, Tokens}};

                        false ->
                            parse_infix_right(
                                Left,
                                Rest@1,
                                Right_binding_power,
                                Min_binding_power,
                                Stop_at_bar,
                                Op
                            )
                    end;

                {error, nil} ->
                    case Symbol of
                        l_paren ->
                            parse_implicit_multiplication(
                                Left,
                                Tokens,
                                Min_binding_power,
                                Stop_at_bar
                            );

                        _ ->
                            {ok, {Left, Tokens}}
                    end
            end;

        [Next | _] ->
            case implicit_multiplication_start(Next) of
                true ->
                    parse_implicit_multiplication(
                        Left,
                        Tokens,
                        Min_binding_power,
                        Stop_at_bar
                    );

                false ->
                    {ok, {Left, Tokens}}
            end;

        _ ->
            {ok, {Left, Tokens}}
    end.

-file("src/math/parser.gleam", 259).
-spec parse_absolute_value(list(math@token:token()), math@ast:span()) -> {ok,
        {math@ast:expr(), list(math@token:token())}} |
    {error, math@ast:parse_error()}.
parse_absolute_value(Tokens, Opened_at) ->
    case parse_expr_until(Tokens, 0, true) of
        {ok, {Expr, [{symbol_token, bar, Closed_at, _} | Rest]}} ->
            {ok,
                {{expr,
                        {call, abs, [Expr]},
                        combine_spans(Opened_at, Closed_at)},
                    Rest}};

        {ok, {_, _}} ->
            {error, {unclosed_absolute_value, Opened_at}};

        {error, Error} ->
            {error, Error}
    end.

-file("src/math/parser.gleam", 286).
-spec parse_group(list(math@token:token()), math@ast:span()) -> {ok,
        {math@ast:expr(), list(math@token:token())}} |
    {error, math@ast:parse_error()}.
parse_group(Tokens, Opened_at) ->
    case parse_expr(Tokens, 0) of
        {ok, {Expr, [{symbol_token, r_paren, Closed_at, _} | Rest]}} ->
            {ok, {with_span(Expr, combine_spans(Opened_at, Closed_at)), Rest}};

        {ok, {_, _}} ->
            {error, {unclosed_parenthesis, Opened_at}};

        {error, Error} ->
            {error, Error}
    end.

-file("src/math/parser.gleam", 230).
-spec parse_prefix_operator(
    list(math@token:token()),
    math@ast:prefix_op(),
    math@ast:span(),
    binary(),
    boolean()
) -> {ok, {math@ast:expr(), list(math@token:token())}} |
    {error, math@ast:parse_error()}.
parse_prefix_operator(Tokens, Op, Operator_span, Raw, Stop_at_bar) ->
    case parse_expr_until(Tokens, prefix_binding_power(), Stop_at_bar) of
        {ok, {Arg, Rest}} ->
            {ok,
                {{expr,
                        {prefix, Op, Arg},
                        combine_spans(Operator_span, expr_span(Arg))},
                    Rest}};

        {error, {unexpected_end, _}} ->
            {error,
                {unexpected_end,
                    [<<<<"expression after `"/utf8, Raw/binary>>/binary,
                            "`"/utf8>>]}};

        {error, Error} ->
            {error, Error}
    end.

-file("src/math/parser.gleam", 185).
-spec parse_function_call(
    math@ast:function_name(),
    binary(),
    math@ast:span(),
    list(math@token:token())
) -> {ok, {math@ast:expr(), list(math@token:token())}} |
    {error, math@ast:parse_error()}.
parse_function_call(Name, Raw, Span, Rest) ->
    case Rest of
        [{symbol_token, l_paren, Opened_at, _} | After_open] ->
            case parse_expr(After_open, 0) of
                {ok,
                    {Arg, [{symbol_token, r_paren, Closed_at, _} | After_close]}} ->
                    {ok,
                        {{expr,
                                {call, Name, [Arg]},
                                combine_spans(Span, Closed_at)},
                            After_close}};

                {ok, {_, [Unexpected | _]}} ->
                    {error,
                        {unexpected_token,
                            math@token:span(Unexpected),
                            [<<")"/utf8>>],
                            token_to_source(Unexpected)}};

                {ok, {_, []}} ->
                    {error, {unclosed_parenthesis, Opened_at}};

                {error, Error} ->
                    {error, Error}
            end;

        _ ->
            {error, {function_requires_parentheses, Span, Raw}}
    end.

-file("src/math/parser.gleam", 93).
-spec parse_word(binary(), math@ast:span(), list(math@token:token())) -> {ok,
        {math@ast:expr(), list(math@token:token())}} |
    {error, math@ast:parse_error()}.
parse_word(Raw, Span, Rest) ->
    case Raw of
        <<"pi"/utf8>> ->
            {ok, {{expr, {const, pi}, Span}, Rest}};

        <<"e"/utf8>> ->
            {ok, {{expr, {const, euler}, Span}, Rest}};

        _ ->
            case function_name(Raw) of
                {ok, Name} ->
                    parse_function_call(Name, Raw, Span, Rest);

                {error, nil} ->
                    parse_variable_run(Raw, Span, Rest)
            end
    end.

-file("src/math/parser.gleam", 47).
-spec parse_prefix(list(math@token:token()), boolean()) -> {ok,
        {math@ast:expr(), list(math@token:token())}} |
    {error, math@ast:parse_error()}.
parse_prefix(Tokens, Stop_at_bar) ->
    case Tokens of
        [] ->
            {error, {unexpected_end, [<<"expression"/utf8>>]}};

        [{number_token, Literal, Span, _} | Rest] ->
            {ok, {{expr, {num, Literal}, Span}, Rest}};

        [{word_token, Raw, Span@1, _} | Rest@1] ->
            parse_word(Raw, Span@1, Rest@1);

        [{symbol_token, plus, Span@2, _} | Rest@2] ->
            parse_prefix_operator(
                Rest@2,
                positive,
                Span@2,
                <<"+"/utf8>>,
                Stop_at_bar
            );

        [{symbol_token, minus, Span@3, _} | Rest@3] ->
            parse_prefix_operator(
                Rest@3,
                negate,
                Span@3,
                <<"-"/utf8>>,
                Stop_at_bar
            );

        [{symbol_token, l_paren, Opened_at, _} | Rest@4] ->
            parse_group(Rest@4, Opened_at);

        [{symbol_token, bar, Opened_at@1, _} | Rest@5] ->
            parse_absolute_value(Rest@5, Opened_at@1);

        [Unexpected | _] ->
            {error,
                {unexpected_token,
                    math@token:span(Unexpected),
                    [<<"expression"/utf8>>],
                    token_to_source(Unexpected)}}
    end.

-file("src/math/parser.gleam", 36).
-spec parse_expr_until(list(math@token:token()), integer(), boolean()) -> {ok,
        {math@ast:expr(), list(math@token:token())}} |
    {error, math@ast:parse_error()}.
parse_expr_until(Tokens, Min_binding_power, Stop_at_bar) ->
    case parse_prefix(Tokens, Stop_at_bar) of
        {ok, {Left, Rest}} ->
            parse_infix(Left, Rest, Min_binding_power, Stop_at_bar);

        {error, Error} ->
            {error, Error}
    end.

-file("src/math/parser.gleam", 29).
-spec parse_expr(list(math@token:token()), integer()) -> {ok,
        {math@ast:expr(), list(math@token:token())}} |
    {error, math@ast:parse_error()}.
parse_expr(Tokens, Min_binding_power) ->
    parse_expr_until(Tokens, Min_binding_power, false).

-file("src/math/parser.gleam", 19).
?DOC(
    " The parser consumes the whole token stream. A successful prefix parse is not\n"
    " enough because accepting `x y` as just `x` would hide syntax the later\n"
    " implicit-multiplication phase must handle deliberately.\n"
).
-spec parse_tokens(list(math@token:token())) -> {ok, math@ast:parsed()} |
    {error, math@ast:parse_error()}.
parse_tokens(Tokens) ->
    case parse_expr(Tokens, 0) of
        {ok, {Expr, []}} ->
            {ok, {expression, Expr}};

        {ok, {_, [Next | _]}} ->
            {error, {trailing_input, math@token:span(Next)}};

        {error, Error} ->
            {error, Error}
    end.

-file("src/math/parser.gleam", 9).
?DOC(
    " Parse source text through the lexer before entering the Pratt parser. Keeping\n"
    " this as the internal parser boundary prevents Torus callers from depending on\n"
    " token shapes while still letting lexer tests exercise tokens directly.\n"
).
-spec parse(binary()) -> {ok, math@ast:parsed()} |
    {error, math@ast:parse_error()}.
parse(Input) ->
    case math@lexer:lex(Input) of
        {ok, Tokens} ->
            parse_tokens(Tokens);

        {error, Error} ->
            {error, Error}
    end.
