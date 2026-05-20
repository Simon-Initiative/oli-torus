-module(math_parser_test).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "test/math_parser_test.gleam").
-export([main/0, parser_api_boundary_is_structured_test/0, parser_acceptance_corpus_scaffold_test/0, parses_core_terms_and_grouping_test/0, rejects_phase_three_malformed_input_test/0, parses_phase_four_implicit_multiplication_test/0, parses_phase_four_functions_absolute_value_and_factorial_test/0, rejects_phase_four_malformed_input_test/0]).

-file("test/math_parser_test.gleam", 7).
-spec main() -> nil.
main() ->
    gleeunit:main().

-file("test/math_parser_test.gleam", 282).
-spec span(integer(), integer()) -> math@ast:span().
span(Start, End) ->
    {span, Start, End}.

-file("test/math_parser_test.gleam", 278).
-spec expr(math@ast:expr_kind(), integer(), integer()) -> math@ast:expr().
expr(Kind, Start, End) ->
    {expr, Kind, span(Start, End)}.

-file("test/math_parser_test.gleam", 261).
-spec int_expr(binary(), float(), integer(), integer()) -> math@ast:expr().
int_expr(Raw, Value, Start, End) ->
    expr(
        {num, {number_literal, Raw, Value, integer_notation, none}},
        Start,
        End
    ).

-file("test/math_parser_test.gleam", 11).
-spec parser_api_boundary_is_structured_test() -> nil.
parser_api_boundary_is_structured_test() ->
    _assert_subject = torus_math:parse(<<"2"/utf8>>),
    _assert_subject@1 = {ok, {expression, int_expr(<<"2"/utf8>>, 2.0, 0, 1)}},
    case _assert_subject =:= _assert_subject@1 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_parser_test"/utf8>>,
                function => <<"parser_api_boundary_is_structured_test"/utf8>>,
                line => 12,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject,
                    start => 198,
                    'end' => 219
                    },
                right => #{kind => expression,
                    value => _assert_subject@1,
                    start => 223,
                    'end' => 267
                    },
                start => 191,
                'end' => 267,
                expression_start => 198})
    end.

-file("test/math_parser_test.gleam", 15).
-spec parser_acceptance_corpus_scaffold_test() -> nil.
parser_acceptance_corpus_scaffold_test() ->
    _assert_subject = math_test@corpus:accepted_parser_inputs(),
    _assert_subject@1 = [],
    case _assert_subject /= _assert_subject@1 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_parser_test"/utf8>>,
                function => <<"parser_acceptance_corpus_scaffold_test"/utf8>>,
                line => 16,
                kind => binary_operator,
                operator => '!=',
                left => #{kind => expression,
                    value => _assert_subject,
                    start => 330,
                    'end' => 361
                    },
                right => #{kind => literal,
                    value => _assert_subject@1,
                    start => 365,
                    'end' => 367
                    },
                start => 323,
                'end' => 367,
                expression_start => 330})
    end.

-file("test/math_parser_test.gleam", 274).
-spec var_expr(binary(), integer(), integer()) -> math@ast:expr().
var_expr(Name, Start, End) ->
    expr({var, Name}, Start, End).

-file("test/math_parser_test.gleam", 19).
-spec parses_core_terms_and_grouping_test() -> nil.
parses_core_terms_and_grouping_test() ->
    _assert_subject = torus_math:parse(<<"x"/utf8>>),
    _assert_subject@1 = {ok, {expression, var_expr(<<"x"/utf8>>, 0, 1)}},
    case _assert_subject =:= _assert_subject@1 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_parser_test"/utf8>>,
                function => <<"parses_core_terms_and_grouping_test"/utf8>>,
                line => 20,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject,
                    start => 427,
                    'end' => 448
                    },
                right => #{kind => expression,
                    value => _assert_subject@1,
                    start => 452,
                    'end' => 491
                    },
                start => 420,
                'end' => 491,
                expression_start => 427})
    end,
    _assert_subject@2 = torus_math:parse(<<"pi"/utf8>>),
    _assert_subject@3 = {ok, {expression, expr({const, pi}, 0, 2)}},
    case _assert_subject@2 =:= _assert_subject@3 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_parser_test"/utf8>>,
                function => <<"parses_core_terms_and_grouping_test"/utf8>>,
                line => 21,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject@2,
                    start => 501,
                    'end' => 523
                    },
                right => #{kind => expression,
                    value => _assert_subject@3,
                    start => 531,
                    'end' => 580
                    },
                start => 494,
                'end' => 580,
                expression_start => 501})
    end,
    _assert_subject@4 = torus_math:parse(<<"e"/utf8>>),
    _assert_subject@5 = {ok, {expression, expr({const, euler}, 0, 1)}},
    case _assert_subject@4 =:= _assert_subject@5 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_parser_test"/utf8>>,
                function => <<"parses_core_terms_and_grouping_test"/utf8>>,
                line => 23,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject@4,
                    start => 590,
                    'end' => 611
                    },
                right => #{kind => expression,
                    value => _assert_subject@5,
                    start => 619,
                    'end' => 671
                    },
                start => 583,
                'end' => 671,
                expression_start => 590})
    end,
    _assert_subject@6 = torus_math:parse(<<"(x+1)"/utf8>>),
    _assert_subject@7 = {ok,
        {expression,
            expr(
                {binary,
                    add,
                    var_expr(<<"x"/utf8>>, 1, 2),
                    int_expr(<<"1"/utf8>>, 1.0, 3, 4)},
                0,
                5
            )}},
    case _assert_subject@6 =:= _assert_subject@7 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_parser_test"/utf8>>,
                function => <<"parses_core_terms_and_grouping_test"/utf8>>,
                line => 26,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject@6,
                    start => 682,
                    'end' => 707
                    },
                right => #{kind => expression,
                    value => _assert_subject@7,
                    start => 715,
                    'end' => 917
                    },
                start => 675,
                'end' => 917,
                expression_start => 682})
    end.

-file("test/math_parser_test.gleam", 40).
-spec rejects_phase_three_malformed_input_test() -> nil.
rejects_phase_three_malformed_input_test() ->
    _assert_subject = torus_math:parse(<<"2^^3"/utf8>>),
    _assert_subject@1 = {error,
        {unexpected_token, span(2, 3), [<<"expression"/utf8>>], <<"^"/utf8>>}},
    case _assert_subject =:= _assert_subject@1 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_parser_test"/utf8>>,
                function => <<"rejects_phase_three_malformed_input_test"/utf8>>,
                line => 41,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject,
                    start => 982,
                    'end' => 1006
                    },
                right => #{kind => expression,
                    value => _assert_subject@1,
                    start => 1014,
                    'end' => 1121
                    },
                start => 975,
                'end' => 1121,
                expression_start => 982})
    end,
    _assert_subject@2 = torus_math:parse(<<"(x+1"/utf8>>),
    _assert_subject@3 = {error, {unclosed_parenthesis, span(0, 1)}},
    case _assert_subject@2 =:= _assert_subject@3 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_parser_test"/utf8>>,
                function => <<"rejects_phase_three_malformed_input_test"/utf8>>,
                line => 48,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject@2,
                    start => 1132,
                    'end' => 1156
                    },
                right => #{kind => expression,
                    value => _assert_subject@3,
                    start => 1164,
                    'end' => 1217
                    },
                start => 1125,
                'end' => 1217,
                expression_start => 1132})
    end,
    _assert_subject@4 = torus_math:parse(<<"2+"/utf8>>),
    _assert_subject@5 = {error,
        {unexpected_end, [<<"expression after `+`"/utf8>>]}},
    case _assert_subject@4 =:= _assert_subject@5 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_parser_test"/utf8>>,
                function => <<"rejects_phase_three_malformed_input_test"/utf8>>,
                line => 51,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject@4,
                    start => 1228,
                    'end' => 1250
                    },
                right => #{kind => literal,
                    value => _assert_subject@5,
                    start => 1258,
                    'end' => 1318
                    },
                start => 1221,
                'end' => 1318,
                expression_start => 1228})
    end.

-file("test/math_parser_test.gleam", 252).
-spec call_expr(
    math@ast:function_name(),
    list(math@ast:expr()),
    integer(),
    integer()
) -> math@ast:expr().
call_expr(Name, Args, Start, End) ->
    expr({call, Name, Args}, Start, End).

-file("test/math_parser_test.gleam", 242).
-spec binary(
    math@ast:binary_op(),
    math@ast:expr(),
    math@ast:expr(),
    integer(),
    integer()
) -> math@ast:expr().
binary(Op, Left, Right, Start, End) ->
    expr({binary, Op, Left, Right}, Start, End).

-file("test/math_parser_test.gleam", 55).
-spec parses_phase_four_implicit_multiplication_test() -> nil.
parses_phase_four_implicit_multiplication_test() ->
    _assert_subject = torus_math:parse(<<"2x"/utf8>>),
    _assert_subject@1 = {ok,
        {expression,
            binary(
                {multiply, implicit_multiply},
                int_expr(<<"2"/utf8>>, 2.0, 0, 1),
                var_expr(<<"x"/utf8>>, 1, 2),
                0,
                2
            )}},
    case _assert_subject =:= _assert_subject@1 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_parser_test"/utf8>>,
                function => <<"parses_phase_four_implicit_multiplication_test"/utf8>>,
                line => 56,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject,
                    start => 1389,
                    'end' => 1411
                    },
                right => #{kind => expression,
                    value => _assert_subject@1,
                    start => 1419,
                    'end' => 1596
                    },
                start => 1382,
                'end' => 1596,
                expression_start => 1389})
    end,
    _assert_subject@2 = torus_math:parse(<<"xy"/utf8>>),
    _assert_subject@3 = {ok,
        {expression,
            binary(
                {multiply, implicit_multiply},
                var_expr(<<"x"/utf8>>, 0, 1),
                var_expr(<<"y"/utf8>>, 1, 2),
                0,
                2
            )}},
    case _assert_subject@2 =:= _assert_subject@3 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_parser_test"/utf8>>,
                function => <<"parses_phase_four_implicit_multiplication_test"/utf8>>,
                line => 67,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject@2,
                    start => 1607,
                    'end' => 1629
                    },
                right => #{kind => expression,
                    value => _assert_subject@3,
                    start => 1637,
                    'end' => 1809
                    },
                start => 1600,
                'end' => 1809,
                expression_start => 1607})
    end,
    _assert_subject@4 = torus_math:parse(<<"2(x+3)"/utf8>>),
    _assert_subject@5 = {ok,
        {expression,
            binary(
                {multiply, implicit_multiply},
                int_expr(<<"2"/utf8>>, 2.0, 0, 1),
                expr(
                    {binary,
                        add,
                        var_expr(<<"x"/utf8>>, 2, 3),
                        int_expr(<<"3"/utf8>>, 3.0, 4, 5)},
                    1,
                    6
                ),
                0,
                6
            )}},
    case _assert_subject@4 =:= _assert_subject@5 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_parser_test"/utf8>>,
                function => <<"parses_phase_four_implicit_multiplication_test"/utf8>>,
                line => 78,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject@4,
                    start => 1820,
                    'end' => 1846
                    },
                right => #{kind => expression,
                    value => _assert_subject@5,
                    start => 1854,
                    'end' => 2197
                    },
                start => 1813,
                'end' => 2197,
                expression_start => 1820})
    end,
    _assert_subject@6 = torus_math:parse(<<"(x+1)(x-1)"/utf8>>),
    _assert_subject@7 = {ok,
        {expression,
            binary(
                {multiply, implicit_multiply},
                expr(
                    {binary,
                        add,
                        var_expr(<<"x"/utf8>>, 1, 2),
                        int_expr(<<"1"/utf8>>, 1.0, 3, 4)},
                    0,
                    5
                ),
                expr(
                    {binary,
                        subtract,
                        var_expr(<<"x"/utf8>>, 6, 7),
                        int_expr(<<"1"/utf8>>, 1.0, 8, 9)},
                    5,
                    10
                ),
                0,
                10
            )}},
    case _assert_subject@6 =:= _assert_subject@7 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_parser_test"/utf8>>,
                function => <<"parses_phase_four_implicit_multiplication_test"/utf8>>,
                line => 97,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject@6,
                    start => 2208,
                    'end' => 2238
                    },
                right => #{kind => expression,
                    value => _assert_subject@7,
                    start => 2246,
                    'end' => 2757
                    },
                start => 2201,
                'end' => 2757,
                expression_start => 2208})
    end,
    _assert_subject@8 = torus_math:parse(<<"2x + 6"/utf8>>),
    _assert_subject@9 = {ok,
        {expression,
            binary(
                add,
                binary(
                    {multiply, implicit_multiply},
                    int_expr(<<"2"/utf8>>, 2.0, 0, 1),
                    var_expr(<<"x"/utf8>>, 1, 2),
                    0,
                    2
                ),
                int_expr(<<"6"/utf8>>, 6.0, 5, 6),
                0,
                6
            )}},
    case _assert_subject@8 =:= _assert_subject@9 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_parser_test"/utf8>>,
                function => <<"parses_phase_four_implicit_multiplication_test"/utf8>>,
                line => 124,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject@8,
                    start => 2768,
                    'end' => 2794
                    },
                right => #{kind => expression,
                    value => _assert_subject@9,
                    start => 2802,
                    'end' => 3089
                    },
                start => 2761,
                'end' => 3089,
                expression_start => 2768})
    end,
    _assert_subject@10 = torus_math:parse(<<"2sqrt(2)"/utf8>>),
    _assert_subject@11 = {ok,
        {expression,
            binary(
                {multiply, implicit_multiply},
                int_expr(<<"2"/utf8>>, 2.0, 0, 1),
                call_expr(sqrt, [int_expr(<<"2"/utf8>>, 2.0, 6, 7)], 1, 8),
                0,
                8
            )}},
    case _assert_subject@10 =:= _assert_subject@11 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_parser_test"/utf8>>,
                function => <<"parses_phase_four_implicit_multiplication_test"/utf8>>,
                line => 141,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject@10,
                    start => 3100,
                    'end' => 3128
                    },
                right => #{kind => expression,
                    value => _assert_subject@11,
                    start => 3136,
                    'end' => 3347
                    },
                start => 3093,
                'end' => 3347,
                expression_start => 3100})
    end,
    _assert_subject@12 = torus_math:parse(<<"2|x|"/utf8>>),
    _assert_subject@13 = {ok,
        {expression,
            binary(
                {multiply, implicit_multiply},
                int_expr(<<"2"/utf8>>, 2.0, 0, 1),
                call_expr(abs, [var_expr(<<"x"/utf8>>, 2, 3)], 1, 4),
                0,
                4
            )}},
    case _assert_subject@12 =:= _assert_subject@13 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_parser_test"/utf8>>,
                function => <<"parses_phase_four_implicit_multiplication_test"/utf8>>,
                line => 152,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject@12,
                    start => 3358,
                    'end' => 3382
                    },
                right => #{kind => expression,
                    value => _assert_subject@13,
                    start => 3390,
                    'end' => 3595
                    },
                start => 3351,
                'end' => 3595,
                expression_start => 3358})
    end.

-file("test/math_parser_test.gleam", 164).
-spec parses_phase_four_functions_absolute_value_and_factorial_test() -> nil.
parses_phase_four_functions_absolute_value_and_factorial_test() ->
    _assert_subject = torus_math:parse(<<"sqrt(2)/2"/utf8>>),
    _assert_subject@1 = {ok,
        {expression,
            binary(
                divide,
                call_expr(sqrt, [int_expr(<<"2"/utf8>>, 2.0, 5, 6)], 0, 7),
                int_expr(<<"2"/utf8>>, 2.0, 8, 9),
                0,
                9
            )}},
    case _assert_subject =:= _assert_subject@1 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_parser_test"/utf8>>,
                function => <<"parses_phase_four_functions_absolute_value_and_factorial_test"/utf8>>,
                line => 165,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject,
                    start => 3681,
                    'end' => 3710
                    },
                right => #{kind => expression,
                    value => _assert_subject@1,
                    start => 3718,
                    'end' => 3905
                    },
                start => 3674,
                'end' => 3905,
                expression_start => 3681})
    end,
    _assert_subject@2 = torus_math:parse(<<"sin(x)"/utf8>>),
    _assert_subject@3 = {ok,
        {expression, call_expr(sin, [var_expr(<<"x"/utf8>>, 4, 5)], 0, 6)}},
    case _assert_subject@2 =:= _assert_subject@3 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_parser_test"/utf8>>,
                function => <<"parses_phase_four_functions_absolute_value_and_factorial_test"/utf8>>,
                line => 176,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject@2,
                    start => 3916,
                    'end' => 3942
                    },
                right => #{kind => expression,
                    value => _assert_subject@3,
                    start => 3950,
                    'end' => 4017
                    },
                start => 3909,
                'end' => 4017,
                expression_start => 3916})
    end,
    _assert_subject@4 = torus_math:parse(<<"cos(x)"/utf8>>),
    _assert_subject@5 = {ok,
        {expression, call_expr(cos, [var_expr(<<"x"/utf8>>, 4, 5)], 0, 6)}},
    case _assert_subject@4 =:= _assert_subject@5 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_parser_test"/utf8>>,
                function => <<"parses_phase_four_functions_absolute_value_and_factorial_test"/utf8>>,
                line => 178,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject@4,
                    start => 4027,
                    'end' => 4053
                    },
                right => #{kind => expression,
                    value => _assert_subject@5,
                    start => 4061,
                    'end' => 4128
                    },
                start => 4020,
                'end' => 4128,
                expression_start => 4027})
    end,
    _assert_subject@6 = torus_math:parse(<<"tan(x)"/utf8>>),
    _assert_subject@7 = {ok,
        {expression, call_expr(tan, [var_expr(<<"x"/utf8>>, 4, 5)], 0, 6)}},
    case _assert_subject@6 =:= _assert_subject@7 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_parser_test"/utf8>>,
                function => <<"parses_phase_four_functions_absolute_value_and_factorial_test"/utf8>>,
                line => 180,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject@6,
                    start => 4138,
                    'end' => 4164
                    },
                right => #{kind => expression,
                    value => _assert_subject@7,
                    start => 4172,
                    'end' => 4239
                    },
                start => 4131,
                'end' => 4239,
                expression_start => 4138})
    end,
    _assert_subject@8 = torus_math:parse(<<"ln(x)"/utf8>>),
    _assert_subject@9 = {ok,
        {expression, call_expr(ln, [var_expr(<<"x"/utf8>>, 3, 4)], 0, 5)}},
    case _assert_subject@8 =:= _assert_subject@9 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_parser_test"/utf8>>,
                function => <<"parses_phase_four_functions_absolute_value_and_factorial_test"/utf8>>,
                line => 182,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject@8,
                    start => 4249,
                    'end' => 4274
                    },
                right => #{kind => expression,
                    value => _assert_subject@9,
                    start => 4282,
                    'end' => 4348
                    },
                start => 4242,
                'end' => 4348,
                expression_start => 4249})
    end,
    _assert_subject@10 = torus_math:parse(<<"log(x)"/utf8>>),
    _assert_subject@11 = {ok,
        {expression, call_expr(log, [var_expr(<<"x"/utf8>>, 4, 5)], 0, 6)}},
    case _assert_subject@10 =:= _assert_subject@11 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_parser_test"/utf8>>,
                function => <<"parses_phase_four_functions_absolute_value_and_factorial_test"/utf8>>,
                line => 184,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject@10,
                    start => 4358,
                    'end' => 4384
                    },
                right => #{kind => expression,
                    value => _assert_subject@11,
                    start => 4392,
                    'end' => 4459
                    },
                start => 4351,
                'end' => 4459,
                expression_start => 4358})
    end,
    _assert_subject@12 = torus_math:parse(<<"log10(x)"/utf8>>),
    _assert_subject@13 = {ok,
        {expression, call_expr(log10, [var_expr(<<"x"/utf8>>, 6, 7)], 0, 8)}},
    case _assert_subject@12 =:= _assert_subject@13 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_parser_test"/utf8>>,
                function => <<"parses_phase_four_functions_absolute_value_and_factorial_test"/utf8>>,
                line => 186,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject@12,
                    start => 4469,
                    'end' => 4497
                    },
                right => #{kind => expression,
                    value => _assert_subject@13,
                    start => 4505,
                    'end' => 4574
                    },
                start => 4462,
                'end' => 4574,
                expression_start => 4469})
    end,
    _assert_subject@14 = torus_math:parse(<<"log2(x)"/utf8>>),
    _assert_subject@15 = {ok,
        {expression, call_expr(log2, [var_expr(<<"x"/utf8>>, 5, 6)], 0, 7)}},
    case _assert_subject@14 =:= _assert_subject@15 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_parser_test"/utf8>>,
                function => <<"parses_phase_four_functions_absolute_value_and_factorial_test"/utf8>>,
                line => 188,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject@14,
                    start => 4584,
                    'end' => 4611
                    },
                right => #{kind => expression,
                    value => _assert_subject@15,
                    start => 4619,
                    'end' => 4687
                    },
                start => 4577,
                'end' => 4687,
                expression_start => 4584})
    end,
    _assert_subject@16 = torus_math:parse(<<"abs(x)"/utf8>>),
    _assert_subject@17 = {ok,
        {expression, call_expr(abs, [var_expr(<<"x"/utf8>>, 4, 5)], 0, 6)}},
    case _assert_subject@16 =:= _assert_subject@17 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_parser_test"/utf8>>,
                function => <<"parses_phase_four_functions_absolute_value_and_factorial_test"/utf8>>,
                line => 190,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject@16,
                    start => 4697,
                    'end' => 4723
                    },
                right => #{kind => expression,
                    value => _assert_subject@17,
                    start => 4731,
                    'end' => 4798
                    },
                start => 4690,
                'end' => 4798,
                expression_start => 4697})
    end,
    _assert_subject@18 = torus_math:parse(<<"exp(x)"/utf8>>),
    _assert_subject@19 = {ok,
        {expression, call_expr(exp, [var_expr(<<"x"/utf8>>, 4, 5)], 0, 6)}},
    case _assert_subject@18 =:= _assert_subject@19 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_parser_test"/utf8>>,
                function => <<"parses_phase_four_functions_absolute_value_and_factorial_test"/utf8>>,
                line => 192,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject@18,
                    start => 4808,
                    'end' => 4834
                    },
                right => #{kind => expression,
                    value => _assert_subject@19,
                    start => 4842,
                    'end' => 4909
                    },
                start => 4801,
                'end' => 4909,
                expression_start => 4808})
    end,
    _assert_subject@20 = torus_math:parse(<<"|x-2|"/utf8>>),
    _assert_subject@21 = {ok,
        {expression,
            call_expr(
                abs,
                [binary(
                        subtract,
                        var_expr(<<"x"/utf8>>, 1, 2),
                        int_expr(<<"2"/utf8>>, 2.0, 3, 4),
                        1,
                        4
                    )],
                0,
                5
            )}},
    case _assert_subject@20 =:= _assert_subject@21 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_parser_test"/utf8>>,
                function => <<"parses_phase_four_functions_absolute_value_and_factorial_test"/utf8>>,
                line => 195,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject@20,
                    start => 4920,
                    'end' => 4945
                    },
                right => #{kind => expression,
                    value => _assert_subject@21,
                    start => 4953,
                    'end' => 5222
                    },
                start => 4913,
                'end' => 5222,
                expression_start => 4920})
    end,
    _assert_subject@22 = torus_math:parse(<<"n!"/utf8>>),
    _assert_subject@23 = {ok,
        {expression, expr({factorial, var_expr(<<"n"/utf8>>, 0, 1)}, 0, 2)}},
    case _assert_subject@22 =:= _assert_subject@23 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_parser_test"/utf8>>,
                function => <<"parses_phase_four_functions_absolute_value_and_factorial_test"/utf8>>,
                line => 213,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject@22,
                    start => 5233,
                    'end' => 5255
                    },
                right => #{kind => expression,
                    value => _assert_subject@23,
                    start => 5263,
                    'end' => 5334
                    },
                start => 5226,
                'end' => 5334,
                expression_start => 5233})
    end.

-file("test/math_parser_test.gleam", 217).
-spec rejects_phase_four_malformed_input_test() -> nil.
rejects_phase_four_malformed_input_test() ->
    _assert_subject = torus_math:parse(<<"tan x"/utf8>>),
    _assert_subject@1 = {error,
        {function_requires_parentheses, span(0, 3), <<"tan"/utf8>>}},
    case _assert_subject =:= _assert_subject@1 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_parser_test"/utf8>>,
                function => <<"rejects_phase_four_malformed_input_test"/utf8>>,
                line => 218,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject,
                    start => 5398,
                    'end' => 5423
                    },
                right => #{kind => expression,
                    value => _assert_subject@1,
                    start => 5431,
                    'end' => 5500
                    },
                start => 5391,
                'end' => 5500,
                expression_start => 5398})
    end,
    _assert_subject@2 = torus_math:parse(<<"sqrt()"/utf8>>),
    _assert_subject@3 = {error,
        {unexpected_token, span(5, 6), [<<"expression"/utf8>>], <<")"/utf8>>}},
    case _assert_subject@2 =:= _assert_subject@3 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_parser_test"/utf8>>,
                function => <<"rejects_phase_four_malformed_input_test"/utf8>>,
                line => 221,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject@2,
                    start => 5511,
                    'end' => 5537
                    },
                right => #{kind => expression,
                    value => _assert_subject@3,
                    start => 5545,
                    'end' => 5652
                    },
                start => 5504,
                'end' => 5652,
                expression_start => 5511})
    end,
    _assert_subject@4 = torus_math:parse(<<"sqrt 2"/utf8>>),
    _assert_subject@5 = {error,
        {function_requires_parentheses, span(0, 4), <<"sqrt"/utf8>>}},
    case _assert_subject@4 =:= _assert_subject@5 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_parser_test"/utf8>>,
                function => <<"rejects_phase_four_malformed_input_test"/utf8>>,
                line => 228,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject@4,
                    start => 5663,
                    'end' => 5689
                    },
                right => #{kind => expression,
                    value => _assert_subject@5,
                    start => 5697,
                    'end' => 5767
                    },
                start => 5656,
                'end' => 5767,
                expression_start => 5663})
    end,
    _assert_subject@6 = torus_math:parse(<<"|x-2"/utf8>>),
    _assert_subject@7 = {error, {unclosed_absolute_value, span(0, 1)}},
    case _assert_subject@6 =:= _assert_subject@7 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_parser_test"/utf8>>,
                function => <<"rejects_phase_four_malformed_input_test"/utf8>>,
                line => 231,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject@6,
                    start => 5778,
                    'end' => 5802
                    },
                right => #{kind => expression,
                    value => _assert_subject@7,
                    start => 5810,
                    'end' => 5865
                    },
                start => 5771,
                'end' => 5865,
                expression_start => 5778})
    end,
    _assert_subject@8 = torus_math:parse(<<"2(*x)"/utf8>>),
    _assert_subject@9 = {error,
        {unexpected_token, span(2, 3), [<<"expression"/utf8>>], <<"*"/utf8>>}},
    case _assert_subject@8 =:= _assert_subject@9 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_parser_test"/utf8>>,
                function => <<"rejects_phase_four_malformed_input_test"/utf8>>,
                line => 234,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject@8,
                    start => 5876,
                    'end' => 5901
                    },
                right => #{kind => expression,
                    value => _assert_subject@9,
                    start => 5909,
                    'end' => 6016
                    },
                start => 5869,
                'end' => 6016,
                expression_start => 5876})
    end.
