-module(math_validate_test).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "test/math_validate_test.gleam").
-export([main/0, symbol_config_contract_test/0, validation_accepts_configured_symbols_test/0, validation_rejects_unconfigured_variables_without_changing_parse_test/0, validation_rejects_disallowed_functions_test/0]).

-file("test/math_validate_test.gleam", 5).
-spec main() -> nil.
main() ->
    gleeunit:main().

-file("test/math_validate_test.gleam", 9).
-spec symbol_config_contract_test() -> nil.
symbol_config_contract_test() ->
    Config = {symbol_config, [<<"x"/utf8>>, <<"y"/utf8>>], [sin, sqrt]},
    _assert_subject = {symbol_config, [<<"x"/utf8>>, <<"y"/utf8>>], [sin, sqrt]},
    case Config =:= _assert_subject of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_validate_test"/utf8>>,
                function => <<"symbol_config_contract_test"/utf8>>,
                line => 16,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => Config,
                    start => 263,
                    'end' => 269
                    },
                right => #{kind => expression,
                    value => _assert_subject,
                    start => 277,
                    'end' => 383
                    },
                start => 256,
                'end' => 383,
                expression_start => 263})
    end.

-file("test/math_validate_test.gleam", 23).
-spec validation_accepts_configured_symbols_test() -> nil.
validation_accepts_configured_symbols_test() ->
    Parsed@1 = case torus_math:parse(<<"sqrt(x)+sin(y)"/utf8>>) of
        {ok, Parsed} -> Parsed;
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"math_validate_test"/utf8>>,
                        function => <<"validation_accepts_configured_symbols_test"/utf8>>,
                        line => 24,
                        value => _assert_fail,
                        start => 443,
                        'end' => 501,
                        pattern_start => 454,
                        pattern_end => 464})
    end,
    Config = {symbol_config, [<<"x"/utf8>>, <<"y"/utf8>>], [sqrt, sin]},
    _assert_subject = torus_math:validate_symbols(Parsed@1, Config),
    _assert_subject@1 = {ok, Parsed@1},
    case _assert_subject =:= _assert_subject@1 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_validate_test"/utf8>>,
                function => <<"validation_accepts_configured_symbols_test"/utf8>>,
                line => 32,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject,
                    start => 639,
                    'end' => 682
                    },
                right => #{kind => expression,
                    value => _assert_subject@1,
                    start => 686,
                    'end' => 696
                    },
                start => 632,
                'end' => 696,
                expression_start => 639})
    end.

-file("test/math_validate_test.gleam", 35).
-spec validation_rejects_unconfigured_variables_without_changing_parse_test() -> nil.
validation_rejects_unconfigured_variables_without_changing_parse_test() ->
    Parsed@1 = case torus_math:parse(<<"2z + 3"/utf8>>) of
        {ok, Parsed} -> Parsed;
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"math_validate_test"/utf8>>,
                        function => <<"validation_rejects_unconfigured_variables_without_changing_parse_test"/utf8>>,
                        line => 36,
                        value => _assert_fail,
                        start => 783,
                        'end' => 833,
                        pattern_start => 794,
                        pattern_end => 804})
    end,
    Config = {symbol_config, [<<"x"/utf8>>], [sqrt]},
    _assert_subject = torus_math:validate_symbols(Parsed@1, Config),
    _assert_subject@1 = {error,
        {unexpected_variable, {span, 1, 2}, <<"z"/utf8>>}},
    case _assert_subject =:= _assert_subject@1 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_validate_test"/utf8>>,
                function => <<"validation_rejects_unconfigured_variables_without_changing_parse_test"/utf8>>,
                line => 43,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject,
                    start => 951,
                    'end' => 994
                    },
                right => #{kind => literal,
                    value => _assert_subject@1,
                    start => 1002,
                    'end' => 1076
                    },
                start => 944,
                'end' => 1076,
                expression_start => 951})
    end.

-file("test/math_validate_test.gleam", 47).
-spec validation_rejects_disallowed_functions_test() -> nil.
validation_rejects_disallowed_functions_test() ->
    Parsed@1 = case torus_math:parse(<<"sqrt(x)"/utf8>>) of
        {ok, Parsed} -> Parsed;
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"math_validate_test"/utf8>>,
                        function => <<"validation_rejects_disallowed_functions_test"/utf8>>,
                        line => 48,
                        value => _assert_fail,
                        start => 1138,
                        'end' => 1189,
                        pattern_start => 1149,
                        pattern_end => 1159})
    end,
    Config = {symbol_config, [<<"x"/utf8>>], [sin]},
    _assert_subject = torus_math:validate_symbols(Parsed@1, Config),
    _assert_subject@1 = {error, {disallowed_function, {span, 0, 7}, sqrt}},
    case _assert_subject =:= _assert_subject@1 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_validate_test"/utf8>>,
                function => <<"validation_rejects_disallowed_functions_test"/utf8>>,
                line => 55,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject,
                    start => 1306,
                    'end' => 1349
                    },
                right => #{kind => expression,
                    value => _assert_subject@1,
                    start => 1357,
                    'end' => 1455
                    },
                start => 1299,
                'end' => 1455,
                expression_start => 1306})
    end.
