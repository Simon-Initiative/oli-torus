-module(math_format_test).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "test/math_format_test.gleam").
-export([main/0, rejected_corpus_scaffold_test/0, formats_representative_ast_debug_strings_test/0, formats_functions_absolute_and_factorial_debug_strings_test/0, formats_parse_errors_debug_strings_test/0]).

-file("test/math_format_test.gleam", 7).
-spec main() -> nil.
main() ->
    gleeunit:main().

-file("test/math_format_test.gleam", 11).
-spec rejected_corpus_scaffold_test() -> nil.
rejected_corpus_scaffold_test() ->
    _assert_subject = erlang:length(math_test@corpus:rejected_parser_inputs()),
    _assert_subject@1 = 7,
    case _assert_subject =:= _assert_subject@1 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_format_test"/utf8>>,
                function => <<"rejected_corpus_scaffold_test"/utf8>>,
                line => 12,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject,
                    start => 180,
                    'end' => 224
                    },
                right => #{kind => literal,
                    value => _assert_subject@1,
                    start => 228,
                    'end' => 229
                    },
                start => 173,
                'end' => 229,
                expression_start => 180})
    end.

-file("test/math_format_test.gleam", 15).
-spec formats_representative_ast_debug_strings_test() -> nil.
formats_representative_ast_debug_strings_test() ->
    Parsed@1 = case torus_math:parse(<<"2(x+3)"/utf8>>) of
        {ok, Parsed} -> Parsed;
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"math_format_test"/utf8>>,
                        function => <<"formats_representative_ast_debug_strings_test"/utf8>>,
                        line => 16,
                        value => _assert_fail,
                        start => 292,
                        'end' => 342,
                        pattern_start => 303,
                        pattern_end => 313})
    end,
    _assert_subject = torus_math:to_debug_string(Parsed@1),
    _assert_subject@1 = <<"Expression(Mul[implicit](Num(\"2\"), Add(Var(\"x\"), Num(\"3\"))))"/utf8>>,
    case _assert_subject =:= _assert_subject@1 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_format_test"/utf8>>,
                function => <<"formats_representative_ast_debug_strings_test"/utf8>>,
                line => 18,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject,
                    start => 353,
                    'end' => 387
                    },
                right => #{kind => literal,
                    value => _assert_subject@1,
                    start => 395,
                    'end' => 463
                    },
                start => 346,
                'end' => 463,
                expression_start => 353})
    end.

-file("test/math_format_test.gleam", 22).
-spec formats_functions_absolute_and_factorial_debug_strings_test() -> nil.
formats_functions_absolute_and_factorial_debug_strings_test() ->
    Function_parsed@1 = case torus_math:parse(<<"sqrt(2)/2"/utf8>>) of
        {ok, Function_parsed} -> Function_parsed;
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"math_format_test"/utf8>>,
                        function => <<"formats_functions_absolute_and_factorial_debug_strings_test"/utf8>>,
                        line => 23,
                        value => _assert_fail,
                        start => 540,
                        'end' => 602,
                        pattern_start => 551,
                        pattern_end => 570})
    end,
    Abs_parsed@1 = case torus_math:parse(<<"|x-2|"/utf8>>) of
        {ok, Abs_parsed} -> Abs_parsed;
        _assert_fail@1 ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"math_format_test"/utf8>>,
                        function => <<"formats_functions_absolute_and_factorial_debug_strings_test"/utf8>>,
                        line => 24,
                        value => _assert_fail@1,
                        start => 605,
                        'end' => 658,
                        pattern_start => 616,
                        pattern_end => 630})
    end,
    Factorial_parsed@1 = case torus_math:parse(<<"n!"/utf8>>) of
        {ok, Factorial_parsed} -> Factorial_parsed;
        _assert_fail@2 ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"math_format_test"/utf8>>,
                        function => <<"formats_functions_absolute_and_factorial_debug_strings_test"/utf8>>,
                        line => 25,
                        value => _assert_fail@2,
                        start => 661,
                        'end' => 717,
                        pattern_start => 672,
                        pattern_end => 692})
    end,
    _assert_subject = torus_math:to_debug_string(Function_parsed@1),
    _assert_subject@1 = <<"Expression(Divide(Call(Sqrt, [Num(\"2\")]), Num(\"2\")))"/utf8>>,
    case _assert_subject =:= _assert_subject@1 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_format_test"/utf8>>,
                function => <<"formats_functions_absolute_and_factorial_debug_strings_test"/utf8>>,
                line => 27,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject,
                    start => 728,
                    'end' => 771
                    },
                right => #{kind => literal,
                    value => _assert_subject@1,
                    start => 779,
                    'end' => 837
                    },
                start => 721,
                'end' => 837,
                expression_start => 728})
    end,
    _assert_subject@2 = torus_math:to_debug_string(Abs_parsed@1),
    _assert_subject@3 = <<"Expression(Call(Abs, [Subtract(Var(\"x\"), Num(\"2\"))]))"/utf8>>,
    case _assert_subject@2 =:= _assert_subject@3 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_format_test"/utf8>>,
                function => <<"formats_functions_absolute_and_factorial_debug_strings_test"/utf8>>,
                line => 30,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject@2,
                    start => 848,
                    'end' => 886
                    },
                right => #{kind => literal,
                    value => _assert_subject@3,
                    start => 894,
                    'end' => 953
                    },
                start => 841,
                'end' => 953,
                expression_start => 848})
    end,
    _assert_subject@4 = torus_math:to_debug_string(Factorial_parsed@1),
    _assert_subject@5 = <<"Expression(Factorial(Var(\"n\")))"/utf8>>,
    case _assert_subject@4 =:= _assert_subject@5 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_format_test"/utf8>>,
                function => <<"formats_functions_absolute_and_factorial_debug_strings_test"/utf8>>,
                line => 33,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject@4,
                    start => 964,
                    'end' => 1008
                    },
                right => #{kind => literal,
                    value => _assert_subject@5,
                    start => 1016,
                    'end' => 1051
                    },
                start => 957,
                'end' => 1051,
                expression_start => 964})
    end.

-file("test/math_format_test.gleam", 37).
-spec formats_parse_errors_debug_strings_test() -> nil.
formats_parse_errors_debug_strings_test() ->
    _assert_subject = torus_math:parse_error_to_debug_string(
        {unclosed_parenthesis, {span, 0, 1}}
    ),
    _assert_subject@1 = <<"UnclosedParenthesis(opened_at=Span(0,1))"/utf8>>,
    case _assert_subject =:= _assert_subject@1 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_format_test"/utf8>>,
                function => <<"formats_parse_errors_debug_strings_test"/utf8>>,
                line => 38,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject,
                    start => 1115,
                    'end' => 1230
                    },
                right => #{kind => literal,
                    value => _assert_subject@1,
                    start => 1238,
                    'end' => 1280
                    },
                start => 1108,
                'end' => 1280,
                expression_start => 1115})
    end,
    _assert_subject@2 = torus_math:parse_error_to_debug_string(
        {function_requires_parentheses, {span, 0, 3}, <<"tan"/utf8>>}
    ),
    _assert_subject@3 = <<"FunctionRequiresParentheses(Span(0,3), name=\"tan\")"/utf8>>,
    case _assert_subject@2 =:= _assert_subject@3 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_format_test"/utf8>>,
                function => <<"formats_parse_errors_debug_strings_test"/utf8>>,
                line => 43,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject@2,
                    start => 1291,
                    'end' => 1428
                    },
                right => #{kind => literal,
                    value => _assert_subject@3,
                    start => 1436,
                    'end' => 1490
                    },
                start => 1284,
                'end' => 1490,
                expression_start => 1291})
    end.
