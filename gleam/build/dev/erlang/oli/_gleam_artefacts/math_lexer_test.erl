-module(math_lexer_test).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "test/math_lexer_test.gleam").
-export([main/0, token_contract_preserves_span_and_spacing_test/0, lexes_numbers_with_literal_metadata_test/0, lexes_words_symbols_and_leading_space_test/0, rejects_strict_number_shorthand_test/0, rejects_unsupported_characters_test/0]).

-file("test/math_lexer_test.gleam", 7).
-spec main() -> nil.
main() ->
    gleeunit:main().

-file("test/math_lexer_test.gleam", 11).
-spec token_contract_preserves_span_and_spacing_test() -> nil.
token_contract_preserves_span_and_spacing_test() ->
    Literal = {number_literal, <<"2"/utf8>>, 2.0, integer_notation, none},
    Span = {span, 1, 2},
    Number_token = {number_token, Literal, Span, true},
    _assert_subject = math@token:span(Number_token),
    case _assert_subject =:= Span of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_lexer_test"/utf8>>,
                function => <<"token_contract_preserves_span_and_spacing_test"/utf8>>,
                line => 24,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject,
                    start => 486,
                    'end' => 510
                    },
                right => #{kind => expression,
                    value => Span,
                    start => 514,
                    'end' => 518
                    },
                start => 479,
                'end' => 518,
                expression_start => 486})
    end,
    case math@token:has_leading_space(Number_token) of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_lexer_test"/utf8>>,
                function => <<"token_contract_preserves_span_and_spacing_test"/utf8>>,
                line => 25,
                kind => function_call,
                arguments => [#{kind => expression,
                        value => Number_token,
                        start => 552,
                        'end' => 564
                        }],
                start => 521,
                'end' => 565,
                expression_start => 528})
    end.

-file("test/math_lexer_test.gleam", 28).
-spec lexes_numbers_with_literal_metadata_test() -> nil.
lexes_numbers_with_literal_metadata_test() ->
    _assert_subject = math@lexer:lex(<<"2 2.0 1.23e-4 6E7"/utf8>>),
    _assert_subject@1 = {ok,
        [{number_token,
                {number_literal, <<"2"/utf8>>, 2.0, integer_notation, none},
                {span, 0, 1},
                false},
            {number_token,
                {number_literal,
                    <<"2.0"/utf8>>,
                    2.0,
                    decimal_notation,
                    {some, 1}},
                {span, 2, 5},
                true},
            {number_token,
                {number_literal,
                    <<"1.23e-4"/utf8>>,
                    0.000123,
                    scientific_notation,
                    {some, 2}},
                {span, 6, 13},
                true},
            {number_token,
                {number_literal,
                    <<"6E7"/utf8>>,
                    60000000.0,
                    scientific_notation,
                    {some, 0}},
                {span, 14, 17},
                true}]},
    case _assert_subject =:= _assert_subject@1 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_lexer_test"/utf8>>,
                function => <<"lexes_numbers_with_literal_metadata_test"/utf8>>,
                line => 29,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject,
                    start => 630,
                    'end' => 660
                    },
                right => #{kind => expression,
                    value => _assert_subject@1,
                    start => 668,
                    'end' => 1790
                    },
                start => 623,
                'end' => 1790,
                expression_start => 630})
    end.

-file("test/math_lexer_test.gleam", 74).
-spec lexes_words_symbols_and_leading_space_test() -> nil.
lexes_words_symbols_and_leading_space_test() ->
    _assert_subject = math@lexer:lex(<<"x xy log10 + - * / ^ ( ) | ! ,"/utf8>>),
    _assert_subject@1 = {ok,
        [{word_token, <<"x"/utf8>>, {span, 0, 1}, false},
            {word_token, <<"xy"/utf8>>, {span, 2, 4}, true},
            {word_token, <<"log10"/utf8>>, {span, 5, 10}, true},
            {symbol_token, plus, {span, 11, 12}, true},
            {symbol_token, minus, {span, 13, 14}, true},
            {symbol_token, star, {span, 15, 16}, true},
            {symbol_token, slash, {span, 17, 18}, true},
            {symbol_token, caret, {span, 19, 20}, true},
            {symbol_token, l_paren, {span, 21, 22}, true},
            {symbol_token, r_paren, {span, 23, 24}, true},
            {symbol_token, bar, {span, 25, 26}, true},
            {symbol_token, bang, {span, 27, 28}, true},
            {symbol_token, comma, {span, 29, 30}, true}]},
    case _assert_subject =:= _assert_subject@1 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_lexer_test"/utf8>>,
                function => <<"lexes_words_symbols_and_leading_space_test"/utf8>>,
                line => 75,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject,
                    start => 1857,
                    'end' => 1900
                    },
                right => #{kind => expression,
                    value => _assert_subject@1,
                    start => 1908,
                    'end' => 3646
                    },
                start => 1850,
                'end' => 3646,
                expression_start => 1857})
    end.

-file("test/math_lexer_test.gleam", 145).
-spec rejects_strict_number_shorthand_test() -> nil.
rejects_strict_number_shorthand_test() ->
    _assert_subject = math@lexer:lex(<<".5"/utf8>>),
    _assert_subject@1 = {error, {invalid_number, {span, 0, 2}, <<".5"/utf8>>}},
    case _assert_subject =:= _assert_subject@1 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_lexer_test"/utf8>>,
                function => <<"rejects_strict_number_shorthand_test"/utf8>>,
                line => 146,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject,
                    start => 3707,
                    'end' => 3722
                    },
                right => #{kind => literal,
                    value => _assert_subject@1,
                    start => 3730,
                    'end' => 3799
                    },
                start => 3700,
                'end' => 3799,
                expression_start => 3707})
    end,
    _assert_subject@2 = math@lexer:lex(<<"1."/utf8>>),
    _assert_subject@3 = {error, {invalid_number, {span, 0, 2}, <<"1."/utf8>>}},
    case _assert_subject@2 =:= _assert_subject@3 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_lexer_test"/utf8>>,
                function => <<"rejects_strict_number_shorthand_test"/utf8>>,
                line => 149,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject@2,
                    start => 3810,
                    'end' => 3825
                    },
                right => #{kind => literal,
                    value => _assert_subject@3,
                    start => 3833,
                    'end' => 3902
                    },
                start => 3803,
                'end' => 3902,
                expression_start => 3810})
    end,
    _assert_subject@4 = math@lexer:lex(<<"1e"/utf8>>),
    _assert_subject@5 = {error, {invalid_number, {span, 0, 2}, <<"1e"/utf8>>}},
    case _assert_subject@4 =:= _assert_subject@5 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_lexer_test"/utf8>>,
                function => <<"rejects_strict_number_shorthand_test"/utf8>>,
                line => 152,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject@4,
                    start => 3913,
                    'end' => 3928
                    },
                right => #{kind => literal,
                    value => _assert_subject@5,
                    start => 3936,
                    'end' => 4005
                    },
                start => 3906,
                'end' => 4005,
                expression_start => 3913})
    end,
    _assert_subject@6 = math@lexer:lex(<<"1e+"/utf8>>),
    _assert_subject@7 = {error, {invalid_number, {span, 0, 3}, <<"1e+"/utf8>>}},
    case _assert_subject@6 =:= _assert_subject@7 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_lexer_test"/utf8>>,
                function => <<"rejects_strict_number_shorthand_test"/utf8>>,
                line => 155,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject@6,
                    start => 4016,
                    'end' => 4032
                    },
                right => #{kind => literal,
                    value => _assert_subject@7,
                    start => 4040,
                    'end' => 4110
                    },
                start => 4009,
                'end' => 4110,
                expression_start => 4016})
    end.

-file("test/math_lexer_test.gleam", 159).
-spec rejects_unsupported_characters_test() -> nil.
rejects_unsupported_characters_test() ->
    _assert_subject = math@lexer:lex(<<"1,000"/utf8>>),
    _assert_subject@1 = {error,
        {unsupported_character, {span, 1, 2}, <<","/utf8>>}},
    case _assert_subject =:= _assert_subject@1 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_lexer_test"/utf8>>,
                function => <<"rejects_unsupported_characters_test"/utf8>>,
                line => 160,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject,
                    start => 4170,
                    'end' => 4188
                    },
                right => #{kind => literal,
                    value => _assert_subject@1,
                    start => 4196,
                    'end' => 4290
                    },
                start => 4163,
                'end' => 4290,
                expression_start => 4170})
    end,
    _assert_subject@2 = math@lexer:lex(<<"x²"/utf8>>),
    _assert_subject@3 = {error,
        {unsupported_character, {span, 1, 2}, <<"²"/utf8>>}},
    case _assert_subject@2 =:= _assert_subject@3 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_lexer_test"/utf8>>,
                function => <<"rejects_unsupported_characters_test"/utf8>>,
                line => 166,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject@2,
                    start => 4301,
                    'end' => 4317
                    },
                right => #{kind => literal,
                    value => _assert_subject@3,
                    start => 4325,
                    'end' => 4420
                    },
                start => 4294,
                'end' => 4420,
                expression_start => 4301})
    end.
