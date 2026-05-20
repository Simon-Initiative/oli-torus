-module(math_precedence_test).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "test/math_precedence_test.gleam").
-export([main/0, precedence_corpus_scaffold_test/0, explicit_operator_precedence_test/0, power_is_right_associative_test/0, unary_prefix_binds_lower_than_power_test/0, unary_prefix_binds_higher_than_multiplication_test/0, implicit_multiplication_precedence_test/0, postfix_factorial_binds_tighter_than_power_test/0]).

-file("test/math_precedence_test.gleam", 7).
-spec main() -> nil.
main() ->
    gleeunit:main().

-file("test/math_precedence_test.gleam", 11).
-spec precedence_corpus_scaffold_test() -> nil.
precedence_corpus_scaffold_test() ->
    _assert_subject = math_test@corpus:precedence_inputs(),
    _assert_subject@1 = [],
    case _assert_subject /= _assert_subject@1 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_precedence_test"/utf8>>,
                function => <<"precedence_corpus_scaffold_test"/utf8>>,
                line => 12,
                kind => binary_operator,
                operator => '!=',
                left => #{kind => expression,
                    value => _assert_subject,
                    start => 191,
                    'end' => 217
                    },
                right => #{kind => literal,
                    value => _assert_subject@1,
                    start => 221,
                    'end' => 223
                    },
                start => 184,
                'end' => 223,
                expression_start => 191})
    end.

-file("test/math_precedence_test.gleam", 188).
-spec span(integer(), integer()) -> math@ast:span().
span(Start, End) ->
    {span, Start, End}.

-file("test/math_precedence_test.gleam", 184).
-spec expr(math@ast:expr_kind(), integer(), integer()) -> math@ast:expr().
expr(Kind, Start, End) ->
    {expr, Kind, span(Start, End)}.

-file("test/math_precedence_test.gleam", 167).
-spec int_expr(binary(), float(), integer(), integer()) -> math@ast:expr().
int_expr(Raw, Value, Start, End) ->
    expr(
        {num, {number_literal, Raw, Value, integer_notation, none}},
        Start,
        End
    ).

-file("test/math_precedence_test.gleam", 157).
-spec binary(
    math@ast:binary_op(),
    math@ast:expr(),
    math@ast:expr(),
    integer(),
    integer()
) -> math@ast:expr().
binary(Op, Left, Right, Start, End) ->
    expr({binary, Op, Left, Right}, Start, End).

-file("test/math_precedence_test.gleam", 15).
-spec explicit_operator_precedence_test() -> nil.
explicit_operator_precedence_test() ->
    _assert_subject = torus_math:parse(<<"2+3*4"/utf8>>),
    _assert_subject@1 = {ok,
        {expression,
            binary(
                add,
                int_expr(<<"2"/utf8>>, 2.0, 0, 1),
                binary(
                    {multiply, explicit_multiply},
                    int_expr(<<"3"/utf8>>, 3.0, 2, 3),
                    int_expr(<<"4"/utf8>>, 4.0, 4, 5),
                    2,
                    5
                ),
                0,
                5
            )}},
    case _assert_subject =:= _assert_subject@1 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_precedence_test"/utf8>>,
                function => <<"explicit_operator_precedence_test"/utf8>>,
                line => 16,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject,
                    start => 281,
                    'end' => 306
                    },
                right => #{kind => expression,
                    value => _assert_subject@1,
                    start => 314,
                    'end' => 606
                    },
                start => 274,
                'end' => 606,
                expression_start => 281})
    end,
    _assert_subject@2 = torus_math:parse(<<"2*3+4"/utf8>>),
    _assert_subject@3 = {ok,
        {expression,
            binary(
                add,
                binary(
                    {multiply, explicit_multiply},
                    int_expr(<<"2"/utf8>>, 2.0, 0, 1),
                    int_expr(<<"3"/utf8>>, 3.0, 2, 3),
                    0,
                    3
                ),
                int_expr(<<"4"/utf8>>, 4.0, 4, 5),
                0,
                5
            )}},
    case _assert_subject@2 =:= _assert_subject@3 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_precedence_test"/utf8>>,
                function => <<"explicit_operator_precedence_test"/utf8>>,
                line => 33,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject@2,
                    start => 617,
                    'end' => 642
                    },
                right => #{kind => expression,
                    value => _assert_subject@3,
                    start => 650,
                    'end' => 942
                    },
                start => 610,
                'end' => 942,
                expression_start => 617})
    end.

-file("test/math_precedence_test.gleam", 51).
-spec power_is_right_associative_test() -> nil.
power_is_right_associative_test() ->
    _assert_subject = torus_math:parse(<<"2^3^4"/utf8>>),
    _assert_subject@1 = {ok,
        {expression,
            binary(
                power,
                int_expr(<<"2"/utf8>>, 2.0, 0, 1),
                binary(
                    power,
                    int_expr(<<"3"/utf8>>, 3.0, 2, 3),
                    int_expr(<<"4"/utf8>>, 4.0, 4, 5),
                    2,
                    5
                ),
                0,
                5
            )}},
    case _assert_subject =:= _assert_subject@1 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_precedence_test"/utf8>>,
                function => <<"power_is_right_associative_test"/utf8>>,
                line => 52,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject,
                    start => 998,
                    'end' => 1023
                    },
                right => #{kind => expression,
                    value => _assert_subject@1,
                    start => 1031,
                    'end' => 1300
                    },
                start => 991,
                'end' => 1300,
                expression_start => 998})
    end.

-file("test/math_precedence_test.gleam", 180).
-spec var_expr(binary(), integer(), integer()) -> math@ast:expr().
var_expr(Name, Start, End) ->
    expr({var, Name}, Start, End).

-file("test/math_precedence_test.gleam", 70).
-spec unary_prefix_binds_lower_than_power_test() -> nil.
unary_prefix_binds_lower_than_power_test() ->
    _assert_subject = torus_math:parse(<<"-x^2"/utf8>>),
    _assert_subject@1 = {ok,
        {expression,
            expr(
                {prefix,
                    negate,
                    binary(
                        power,
                        var_expr(<<"x"/utf8>>, 1, 2),
                        int_expr(<<"2"/utf8>>, 2.0, 3, 4),
                        1,
                        4
                    )},
                0,
                4
            )}},
    case _assert_subject =:= _assert_subject@1 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_precedence_test"/utf8>>,
                function => <<"unary_prefix_binds_lower_than_power_test"/utf8>>,
                line => 71,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject,
                    start => 1365,
                    'end' => 1389
                    },
                right => #{kind => expression,
                    value => _assert_subject@1,
                    start => 1397,
                    'end' => 1682
                    },
                start => 1358,
                'end' => 1682,
                expression_start => 1365})
    end,
    _assert_subject@2 = torus_math:parse(<<"(-x)^2"/utf8>>),
    _assert_subject@3 = {ok,
        {expression,
            binary(
                power,
                expr({prefix, negate, var_expr(<<"x"/utf8>>, 2, 3)}, 0, 4),
                int_expr(<<"2"/utf8>>, 2.0, 5, 6),
                0,
                6
            )}},
    case _assert_subject@2 =:= _assert_subject@3 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_precedence_test"/utf8>>,
                function => <<"unary_prefix_binds_lower_than_power_test"/utf8>>,
                line => 89,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject@2,
                    start => 1693,
                    'end' => 1719
                    },
                right => #{kind => expression,
                    value => _assert_subject@3,
                    start => 1727,
                    'end' => 1924
                    },
                start => 1686,
                'end' => 1924,
                expression_start => 1693})
    end.

-file("test/math_precedence_test.gleam", 101).
-spec unary_prefix_binds_higher_than_multiplication_test() -> nil.
unary_prefix_binds_higher_than_multiplication_test() ->
    _assert_subject = torus_math:parse(<<"-x*2"/utf8>>),
    _assert_subject@1 = {ok,
        {expression,
            binary(
                {multiply, explicit_multiply},
                expr({prefix, negate, var_expr(<<"x"/utf8>>, 1, 2)}, 0, 2),
                int_expr(<<"2"/utf8>>, 2.0, 3, 4),
                0,
                4
            )}},
    case _assert_subject =:= _assert_subject@1 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_precedence_test"/utf8>>,
                function => <<"unary_prefix_binds_higher_than_multiplication_test"/utf8>>,
                line => 102,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject,
                    start => 1999,
                    'end' => 2023
                    },
                right => #{kind => expression,
                    value => _assert_subject@1,
                    start => 2031,
                    'end' => 2253
                    },
                start => 1992,
                'end' => 2253,
                expression_start => 1999})
    end.

-file("test/math_precedence_test.gleam", 114).
-spec implicit_multiplication_precedence_test() -> nil.
implicit_multiplication_precedence_test() ->
    _assert_subject = torus_math:parse(<<"2x^2"/utf8>>),
    _assert_subject@1 = {ok,
        {expression,
            binary(
                {multiply, implicit_multiply},
                int_expr(<<"2"/utf8>>, 2.0, 0, 1),
                binary(
                    power,
                    var_expr(<<"x"/utf8>>, 1, 2),
                    int_expr(<<"2"/utf8>>, 2.0, 3, 4),
                    1,
                    4
                ),
                0,
                4
            )}},
    case _assert_subject =:= _assert_subject@1 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_precedence_test"/utf8>>,
                function => <<"implicit_multiplication_precedence_test"/utf8>>,
                line => 115,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject,
                    start => 2317,
                    'end' => 2341
                    },
                right => #{kind => expression,
                    value => _assert_subject@1,
                    start => 2349,
                    'end' => 2577
                    },
                start => 2310,
                'end' => 2577,
                expression_start => 2317})
    end,
    _assert_subject@2 = torus_math:parse(<<"1/2x"/utf8>>),
    _assert_subject@3 = {ok,
        {expression,
            binary(
                {multiply, implicit_multiply},
                binary(
                    divide,
                    int_expr(<<"1"/utf8>>, 1.0, 0, 1),
                    int_expr(<<"2"/utf8>>, 2.0, 2, 3),
                    0,
                    3
                ),
                var_expr(<<"x"/utf8>>, 3, 4),
                0,
                4
            )}},
    case _assert_subject@2 =:= _assert_subject@3 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_precedence_test"/utf8>>,
                function => <<"implicit_multiplication_precedence_test"/utf8>>,
                line => 126,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject@2,
                    start => 2588,
                    'end' => 2612
                    },
                right => #{kind => expression,
                    value => _assert_subject@3,
                    start => 2620,
                    'end' => 2910
                    },
                start => 2581,
                'end' => 2910,
                expression_start => 2588})
    end.

-file("test/math_precedence_test.gleam", 144).
-spec postfix_factorial_binds_tighter_than_power_test() -> nil.
postfix_factorial_binds_tighter_than_power_test() ->
    _assert_subject = torus_math:parse(<<"n!^2"/utf8>>),
    _assert_subject@1 = {ok,
        {expression,
            binary(
                power,
                expr({factorial, var_expr(<<"n"/utf8>>, 0, 1)}, 0, 2),
                int_expr(<<"2"/utf8>>, 2.0, 3, 4),
                0,
                4
            )}},
    case _assert_subject =:= _assert_subject@1 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_precedence_test"/utf8>>,
                function => <<"postfix_factorial_binds_tighter_than_power_test"/utf8>>,
                line => 145,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject,
                    start => 2982,
                    'end' => 3006
                    },
                right => #{kind => expression,
                    value => _assert_subject@1,
                    start => 3014,
                    'end' => 3198
                    },
                start => 2975,
                'end' => 3198,
                expression_start => 2982})
    end.
