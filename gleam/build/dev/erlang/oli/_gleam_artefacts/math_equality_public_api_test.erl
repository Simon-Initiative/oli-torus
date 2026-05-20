-module(math_equality_public_api_test).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "test/math_equality_public_api_test.gleam").
-export([main/0, public_api_evaluates_decoded_json_config_test/0, public_api_reports_not_equal_diagnostics_without_feedback_test/0, public_api_reports_invalid_submitted_answers_test/0, public_api_rejects_invalid_config_before_evaluation_test/0, public_api_keeps_future_modes_unsupported_test/0]).

-file("test/math_equality_public_api_test.gleam", 6).
-spec main() -> nil.
main() ->
    gleeunit:main().

-file("test/math_equality_public_api_test.gleam", 10).
-spec public_api_evaluates_decoded_json_config_test() -> nil.
public_api_evaluates_decoded_json_config_test() ->
    Source = <<"{\"version\":1,\"mode\":\"numeric\",\"comparison\":{\"type\":\"equal\",\"expected\":\"2\"},\"tolerance\":{\"type\":\"none\"},\"representation\":{\"type\":\"any\"},\"precision\":{\"type\":\"none\"}}"/utf8>>,
    Spec@1 = case torus_math:decode_equality_config(Source) of
        {ok, Spec} -> Spec;
        _assert_fail ->
            erlang:error(#{gleam_error => let_assert,
                        message => <<"Pattern match failed, no pattern matched the value."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"math_equality_public_api_test"/utf8>>,
                        function => <<"public_api_evaluates_decoded_json_config_test"/utf8>>,
                        line => 14,
                        value => _assert_fail,
                        start => 394,
                        'end' => 457,
                        pattern_start => 405,
                        pattern_end => 413})
    end,
    _assert_subject = torus_math:evaluate_equality(Spec@1, <<"2"/utf8>>),
    _assert_subject@1 = {equality_matched, [numeric_comparison_matched]},
    case _assert_subject =:= _assert_subject@1 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_equality_public_api_test"/utf8>>,
                function => <<"public_api_evaluates_decoded_json_config_test"/utf8>>,
                line => 16,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject,
                    start => 468,
                    'end' => 507
                    },
                right => #{kind => expression,
                    value => _assert_subject@1,
                    start => 515,
                    'end' => 583
                    },
                start => 461,
                'end' => 583,
                expression_start => 468})
    end.

-file("test/math_equality_public_api_test.gleam", 81).
-spec numeric_spec(math@equality@types:numeric_comparison()) -> math@equality@types:equality_spec().
numeric_spec(Comparison) ->
    {equality_spec,
        1,
        {numeric, math@equality@types:default_numeric_options(Comparison)}}.

-file("test/math_equality_public_api_test.gleam", 20).
-spec public_api_reports_not_equal_diagnostics_without_feedback_test() -> nil.
public_api_reports_not_equal_diagnostics_without_feedback_test() ->
    Spec = numeric_spec(
        {not_equal, math@equality@types:numeric_input(<<"2"/utf8>>)}
    ),
    _assert_subject = torus_math:evaluate_equality(Spec, <<"2"/utf8>>),
    _assert_subject@1 = {equality_not_matched, [numeric_value_mismatch]},
    case _assert_subject =:= _assert_subject@1 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_equality_public_api_test"/utf8>>,
                function => <<"public_api_reports_not_equal_diagnostics_without_feedback_test"/utf8>>,
                line => 23,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject,
                    start => 749,
                    'end' => 788
                    },
                right => #{kind => expression,
                    value => _assert_subject@1,
                    start => 796,
                    'end' => 863
                    },
                start => 742,
                'end' => 863,
                expression_start => 749})
    end.

-file("test/math_equality_public_api_test.gleam", 27).
-spec public_api_reports_invalid_submitted_answers_test() -> nil.
public_api_reports_invalid_submitted_answers_test() ->
    Spec = numeric_spec(
        {equal, math@equality@types:numeric_input(<<"2"/utf8>>)}
    ),
    _assert_subject = torus_math:evaluate_equality(Spec, <<"two"/utf8>>),
    _assert_subject@1 = {invalid_submitted_answer, [numeric_parse_failure]},
    case _assert_subject =:= _assert_subject@1 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_equality_public_api_test"/utf8>>,
                function => <<"public_api_reports_invalid_submitted_answers_test"/utf8>>,
                line => 30,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject,
                    start => 1013,
                    'end' => 1054
                    },
                right => #{kind => expression,
                    value => _assert_subject@1,
                    start => 1062,
                    'end' => 1132
                    },
                start => 1006,
                'end' => 1132,
                expression_start => 1013})
    end.

-file("test/math_equality_public_api_test.gleam", 34).
-spec public_api_rejects_invalid_config_before_evaluation_test() -> nil.
public_api_rejects_invalid_config_before_evaluation_test() ->
    Spec = {equality_spec,
        2,
        {numeric,
            math@equality@types:default_numeric_options(
                {equal, math@equality@types:numeric_input(<<"2"/utf8>>)}
            )}},
    _assert_subject = torus_math:evaluate_equality(Spec, <<"2"/utf8>>),
    _assert_subject@1 = {invalid_config, {unsupported_version, 2}},
    case _assert_subject =:= _assert_subject@1 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_equality_public_api_test"/utf8>>,
                function => <<"public_api_rejects_invalid_config_before_evaluation_test"/utf8>>,
                line => 45,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject,
                    start => 1420,
                    'end' => 1459
                    },
                right => #{kind => literal,
                    value => _assert_subject@1,
                    start => 1467,
                    'end' => 1531
                    },
                start => 1413,
                'end' => 1531,
                expression_start => 1420})
    end.

-file("test/math_equality_public_api_test.gleam", 49).
-spec public_api_keeps_future_modes_unsupported_test() -> nil.
public_api_keeps_future_modes_unsupported_test() ->
    Expression = {equality_spec,
        1,
        {expression,
            {expression_spec,
                {exact_expression, <<"x + 1"/utf8>>},
                {expression_validation, [<<"x"/utf8>>], [sin], []}}}},
    Unit = {equality_spec,
        1,
        {unit_aware,
            {unit_spec,
                {unit_numeric,
                    math@equality@types:numeric_input(<<"9.8"/utf8>>),
                    <<"m/s^2"/utf8>>},
                {strict_unit, <<"m/s^2"/utf8>>}}}},
    _assert_subject = torus_math:evaluate_equality(Expression, <<"x + 1"/utf8>>),
    _assert_subject@1 = {unsupported_mode, expression_evaluation},
    case _assert_subject =:= _assert_subject@1 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_equality_public_api_test"/utf8>>,
                function => <<"public_api_keeps_future_modes_unsupported_test"/utf8>>,
                line => 75,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject,
                    start => 2254,
                    'end' => 2303
                    },
                right => #{kind => expression,
                    value => _assert_subject@1,
                    start => 2311,
                    'end' => 2366
                    },
                start => 2247,
                'end' => 2366,
                expression_start => 2254})
    end,
    _assert_subject@2 = torus_math:evaluate_equality(Unit, <<"9.8 m/s^2"/utf8>>),
    _assert_subject@3 = {unsupported_mode, unit_aware_evaluation},
    case _assert_subject@2 =:= _assert_subject@3 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_equality_public_api_test"/utf8>>,
                function => <<"public_api_keeps_future_modes_unsupported_test"/utf8>>,
                line => 77,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject@2,
                    start => 2376,
                    'end' => 2423
                    },
                right => #{kind => expression,
                    value => _assert_subject@3,
                    start => 2431,
                    'end' => 2485
                    },
                start => 2369,
                'end' => 2485,
                expression_start => 2376})
    end.
