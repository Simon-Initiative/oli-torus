-module(expression_test).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "test/expression_test.gleam").
-export([main/0, hello_test/0, parse_test/0]).

-file("test/expression_test.gleam", 4).
-spec main() -> nil.
main() ->
    gleeunit:main().

-file("test/expression_test.gleam", 8).
-spec hello_test() -> nil.
hello_test() ->
    _assert_subject = expression:hello(<<"Torus"/utf8>>),
    _assert_subject@1 = <<"Hello from Gleam, Torus!"/utf8>>,
    case _assert_subject =:= _assert_subject@1 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"expression_test"/utf8>>,
                function => <<"hello_test"/utf8>>,
                line => 9,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject,
                    start => 103,
                    'end' => 128
                    },
                right => #{kind => literal,
                    value => _assert_subject@1,
                    start => 132,
                    'end' => 158
                    },
                start => 96,
                'end' => 158,
                expression_start => 103})
    end.

-file("test/expression_test.gleam", 12).
-spec parse_test() -> nil.
parse_test() ->
    _assert_subject = expression:parse(<<"1 + 2"/utf8>>),
    _assert_subject@1 = {ok, <<"parsed: 1 + 2"/utf8>>},
    case _assert_subject =:= _assert_subject@1 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"expression_test"/utf8>>,
                function => <<"parse_test"/utf8>>,
                line => 13,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject,
                    start => 193,
                    'end' => 218
                    },
                right => #{kind => literal,
                    value => _assert_subject@1,
                    start => 222,
                    'end' => 241
                    },
                start => 186,
                'end' => 241,
                expression_start => 193})
    end.
