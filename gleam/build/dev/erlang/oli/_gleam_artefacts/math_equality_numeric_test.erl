-module(math_equality_numeric_test).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "test/math_equality_numeric_test.gleam").
-export([main/0, scalar_operators_match_standard_numeric_rules_test/0, scalar_operators_report_value_mismatch_test/0, range_operators_support_inclusive_exclusive_and_inverse_cases_test/0, range_operators_report_range_mismatch_test/0, ranges_allow_reversed_bounds_test/0, numeric_parser_accepts_number_input_scalar_notation_test/0, submitted_parse_failures_are_not_config_failures_test/0, configured_numeric_parse_failures_are_invalid_config_test/0, absolute_tolerance_supports_boundary_inside_and_outside_values_test/0, relative_tolerance_uses_larger_magnitude_and_near_zero_behavior_test/0, combined_tolerance_accepts_absolute_or_relative_success_test/0, not_equal_uses_tolerance_as_the_equality_window_test/0, representation_constraints_distinguish_value_from_submitted_form_test/0, decimal_precision_supports_exact_at_least_and_at_most_rules_test/0, legacy_significant_figures_remain_distinct_from_decimal_places_test/0, multiple_numeric_option_failures_are_reported_separately_test/0, invalid_numeric_option_values_are_config_errors_test/0]).

-file("test/math_equality_numeric_test.gleam", 5).
-spec main() -> nil.
main() ->
    gleeunit:main().

-file("test/math_equality_numeric_test.gleam", 416).
-spec matched() -> math@equality@types:equality_result().
matched() ->
    {equality_matched, [numeric_comparison_matched]}.

-file("test/math_equality_numeric_test.gleam", 403).
-spec evaluate(math@equality@types:numeric_comparison(), binary()) -> math@equality@types:equality_result().
evaluate(Comparison, Submitted) ->
    torus_math:evaluate_equality(
        {equality_spec,
            1,
            {numeric, math@equality@types:default_numeric_options(Comparison)}},
        Submitted
    ).

-file("test/math_equality_numeric_test.gleam", 9).
-spec scalar_operators_match_standard_numeric_rules_test() -> nil.
scalar_operators_match_standard_numeric_rules_test() ->
    _assert_subject = evaluate(
        {equal, math@equality@types:numeric_input(<<"2"/utf8>>)},
        <<"2"/utf8>>
    ),
    _assert_subject@1 = matched(),
    case _assert_subject =:= _assert_subject@1 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_equality_numeric_test"/utf8>>,
                function => <<"scalar_operators_match_standard_numeric_rules_test"/utf8>>,
                line => 10,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject,
                    start => 170,
                    'end' => 222
                    },
                right => #{kind => expression,
                    value => _assert_subject@1,
                    start => 226,
                    'end' => 235
                    },
                start => 163,
                'end' => 235,
                expression_start => 170})
    end,
    _assert_subject@2 = evaluate(
        {not_equal, math@equality@types:numeric_input(<<"2"/utf8>>)},
        <<"3"/utf8>>
    ),
    _assert_subject@3 = matched(),
    case _assert_subject@2 =:= _assert_subject@3 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_equality_numeric_test"/utf8>>,
                function => <<"scalar_operators_match_standard_numeric_rules_test"/utf8>>,
                line => 11,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject@2,
                    start => 245,
                    'end' => 300
                    },
                right => #{kind => expression,
                    value => _assert_subject@3,
                    start => 304,
                    'end' => 313
                    },
                start => 238,
                'end' => 313,
                expression_start => 245})
    end,
    _assert_subject@4 = evaluate(
        {greater_than, math@equality@types:numeric_input(<<"2"/utf8>>)},
        <<"3"/utf8>>
    ),
    _assert_subject@5 = matched(),
    case _assert_subject@4 =:= _assert_subject@5 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_equality_numeric_test"/utf8>>,
                function => <<"scalar_operators_match_standard_numeric_rules_test"/utf8>>,
                line => 12,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject@4,
                    start => 323,
                    'end' => 381
                    },
                right => #{kind => expression,
                    value => _assert_subject@5,
                    start => 385,
                    'end' => 394
                    },
                start => 316,
                'end' => 394,
                expression_start => 323})
    end,
    _assert_subject@6 = evaluate(
        {greater_than_or_equal, math@equality@types:numeric_input(<<"2"/utf8>>)},
        <<"2"/utf8>>
    ),
    _assert_subject@7 = matched(),
    case _assert_subject@6 =:= _assert_subject@7 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_equality_numeric_test"/utf8>>,
                function => <<"scalar_operators_match_standard_numeric_rules_test"/utf8>>,
                line => 13,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject@6,
                    start => 404,
                    'end' => 469
                    },
                right => #{kind => expression,
                    value => _assert_subject@7,
                    start => 477,
                    'end' => 486
                    },
                start => 397,
                'end' => 486,
                expression_start => 404})
    end,
    _assert_subject@8 = evaluate(
        {less_than, math@equality@types:numeric_input(<<"2"/utf8>>)},
        <<"1"/utf8>>
    ),
    _assert_subject@9 = matched(),
    case _assert_subject@8 =:= _assert_subject@9 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_equality_numeric_test"/utf8>>,
                function => <<"scalar_operators_match_standard_numeric_rules_test"/utf8>>,
                line => 15,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject@8,
                    start => 496,
                    'end' => 551
                    },
                right => #{kind => expression,
                    value => _assert_subject@9,
                    start => 555,
                    'end' => 564
                    },
                start => 489,
                'end' => 564,
                expression_start => 496})
    end,
    _assert_subject@10 = evaluate(
        {less_than_or_equal, math@equality@types:numeric_input(<<"2"/utf8>>)},
        <<"2"/utf8>>
    ),
    _assert_subject@11 = matched(),
    case _assert_subject@10 =:= _assert_subject@11 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_equality_numeric_test"/utf8>>,
                function => <<"scalar_operators_match_standard_numeric_rules_test"/utf8>>,
                line => 16,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject@10,
                    start => 574,
                    'end' => 636
                    },
                right => #{kind => expression,
                    value => _assert_subject@11,
                    start => 644,
                    'end' => 653
                    },
                start => 567,
                'end' => 653,
                expression_start => 574})
    end.

-file("test/math_equality_numeric_test.gleam", 20).
-spec scalar_operators_report_value_mismatch_test() -> nil.
scalar_operators_report_value_mismatch_test() ->
    _assert_subject = evaluate(
        {equal, math@equality@types:numeric_input(<<"2"/utf8>>)},
        <<"3"/utf8>>
    ),
    _assert_subject@1 = {equality_not_matched, [numeric_value_mismatch]},
    case _assert_subject =:= _assert_subject@1 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_equality_numeric_test"/utf8>>,
                function => <<"scalar_operators_report_value_mismatch_test"/utf8>>,
                line => 21,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject,
                    start => 721,
                    'end' => 773
                    },
                right => #{kind => expression,
                    value => _assert_subject@1,
                    start => 781,
                    'end' => 848
                    },
                start => 714,
                'end' => 848,
                expression_start => 721})
    end,
    _assert_subject@2 = evaluate(
        {not_equal, math@equality@types:numeric_input(<<"2"/utf8>>)},
        <<"2"/utf8>>
    ),
    _assert_subject@3 = {equality_not_matched, [numeric_value_mismatch]},
    case _assert_subject@2 =:= _assert_subject@3 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_equality_numeric_test"/utf8>>,
                function => <<"scalar_operators_report_value_mismatch_test"/utf8>>,
                line => 23,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject@2,
                    start => 858,
                    'end' => 913
                    },
                right => #{kind => expression,
                    value => _assert_subject@3,
                    start => 921,
                    'end' => 988
                    },
                start => 851,
                'end' => 988,
                expression_start => 858})
    end,
    _assert_subject@4 = evaluate(
        {greater_than, math@equality@types:numeric_input(<<"2"/utf8>>)},
        <<"2"/utf8>>
    ),
    _assert_subject@5 = {equality_not_matched, [numeric_value_mismatch]},
    case _assert_subject@4 =:= _assert_subject@5 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_equality_numeric_test"/utf8>>,
                function => <<"scalar_operators_report_value_mismatch_test"/utf8>>,
                line => 25,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject@4,
                    start => 998,
                    'end' => 1056
                    },
                right => #{kind => expression,
                    value => _assert_subject@5,
                    start => 1064,
                    'end' => 1131
                    },
                start => 991,
                'end' => 1131,
                expression_start => 998})
    end,
    _assert_subject@6 = evaluate(
        {less_than, math@equality@types:numeric_input(<<"2"/utf8>>)},
        <<"2"/utf8>>
    ),
    _assert_subject@7 = {equality_not_matched, [numeric_value_mismatch]},
    case _assert_subject@6 =:= _assert_subject@7 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_equality_numeric_test"/utf8>>,
                function => <<"scalar_operators_report_value_mismatch_test"/utf8>>,
                line => 27,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject@6,
                    start => 1141,
                    'end' => 1196
                    },
                right => #{kind => expression,
                    value => _assert_subject@7,
                    start => 1204,
                    'end' => 1271
                    },
                start => 1134,
                'end' => 1271,
                expression_start => 1141})
    end.

-file("test/math_equality_numeric_test.gleam", 31).
-spec range_operators_support_inclusive_exclusive_and_inverse_cases_test() -> nil.
range_operators_support_inclusive_exclusive_and_inverse_cases_test() ->
    Lower = math@equality@types:numeric_input(<<"1"/utf8>>),
    Upper = math@equality@types:numeric_input(<<"3"/utf8>>),
    _assert_subject = evaluate({between, Lower, Upper, inclusive}, <<"1"/utf8>>),
    _assert_subject@1 = matched(),
    case _assert_subject =:= _assert_subject@1 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_equality_numeric_test"/utf8>>,
                function => <<"range_operators_support_inclusive_exclusive_and_inverse_cases_test"/utf8>>,
                line => 35,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject,
                    start => 1441,
                    'end' => 1500
                    },
                right => #{kind => expression,
                    value => _assert_subject@1,
                    start => 1508,
                    'end' => 1517
                    },
                start => 1434,
                'end' => 1517,
                expression_start => 1441})
    end,
    _assert_subject@2 = evaluate(
        {between, Lower, Upper, inclusive},
        <<"3"/utf8>>
    ),
    _assert_subject@3 = matched(),
    case _assert_subject@2 =:= _assert_subject@3 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_equality_numeric_test"/utf8>>,
                function => <<"range_operators_support_inclusive_exclusive_and_inverse_cases_test"/utf8>>,
                line => 37,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject@2,
                    start => 1527,
                    'end' => 1586
                    },
                right => #{kind => expression,
                    value => _assert_subject@3,
                    start => 1594,
                    'end' => 1603
                    },
                start => 1520,
                'end' => 1603,
                expression_start => 1527})
    end,
    _assert_subject@4 = evaluate(
        {between, Lower, Upper, exclusive},
        <<"2"/utf8>>
    ),
    _assert_subject@5 = matched(),
    case _assert_subject@4 =:= _assert_subject@5 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_equality_numeric_test"/utf8>>,
                function => <<"range_operators_support_inclusive_exclusive_and_inverse_cases_test"/utf8>>,
                line => 39,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject@4,
                    start => 1613,
                    'end' => 1672
                    },
                right => #{kind => expression,
                    value => _assert_subject@5,
                    start => 1680,
                    'end' => 1689
                    },
                start => 1606,
                'end' => 1689,
                expression_start => 1613})
    end,
    _assert_subject@6 = evaluate(
        {not_between, Lower, Upper, exclusive},
        <<"1"/utf8>>
    ),
    _assert_subject@7 = matched(),
    case _assert_subject@6 =:= _assert_subject@7 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_equality_numeric_test"/utf8>>,
                function => <<"range_operators_support_inclusive_exclusive_and_inverse_cases_test"/utf8>>,
                line => 41,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject@6,
                    start => 1699,
                    'end' => 1761
                    },
                right => #{kind => expression,
                    value => _assert_subject@7,
                    start => 1769,
                    'end' => 1778
                    },
                start => 1692,
                'end' => 1778,
                expression_start => 1699})
    end,
    _assert_subject@8 = evaluate(
        {not_between, Lower, Upper, inclusive},
        <<"4"/utf8>>
    ),
    _assert_subject@9 = matched(),
    case _assert_subject@8 =:= _assert_subject@9 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_equality_numeric_test"/utf8>>,
                function => <<"range_operators_support_inclusive_exclusive_and_inverse_cases_test"/utf8>>,
                line => 43,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject@8,
                    start => 1788,
                    'end' => 1850
                    },
                right => #{kind => expression,
                    value => _assert_subject@9,
                    start => 1858,
                    'end' => 1867
                    },
                start => 1781,
                'end' => 1867,
                expression_start => 1788})
    end.

-file("test/math_equality_numeric_test.gleam", 47).
-spec range_operators_report_range_mismatch_test() -> nil.
range_operators_report_range_mismatch_test() ->
    Lower = math@equality@types:numeric_input(<<"1"/utf8>>),
    Upper = math@equality@types:numeric_input(<<"3"/utf8>>),
    _assert_subject = evaluate({between, Lower, Upper, exclusive}, <<"1"/utf8>>),
    _assert_subject@1 = {equality_not_matched, [numeric_range_mismatch]},
    case _assert_subject =:= _assert_subject@1 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_equality_numeric_test"/utf8>>,
                function => <<"range_operators_report_range_mismatch_test"/utf8>>,
                line => 51,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject,
                    start => 2013,
                    'end' => 2072
                    },
                right => #{kind => expression,
                    value => _assert_subject@1,
                    start => 2080,
                    'end' => 2147
                    },
                start => 2006,
                'end' => 2147,
                expression_start => 2013})
    end,
    _assert_subject@2 = evaluate(
        {not_between, Lower, Upper, inclusive},
        <<"2"/utf8>>
    ),
    _assert_subject@3 = {equality_not_matched, [numeric_range_mismatch]},
    case _assert_subject@2 =:= _assert_subject@3 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_equality_numeric_test"/utf8>>,
                function => <<"range_operators_report_range_mismatch_test"/utf8>>,
                line => 53,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject@2,
                    start => 2157,
                    'end' => 2219
                    },
                right => #{kind => expression,
                    value => _assert_subject@3,
                    start => 2227,
                    'end' => 2294
                    },
                start => 2150,
                'end' => 2294,
                expression_start => 2157})
    end.

-file("test/math_equality_numeric_test.gleam", 57).
-spec ranges_allow_reversed_bounds_test() -> nil.
ranges_allow_reversed_bounds_test() ->
    _assert_subject = evaluate(
        {between,
            math@equality@types:numeric_input(<<"3"/utf8>>),
            math@equality@types:numeric_input(<<"1"/utf8>>),
            inclusive},
        <<"2"/utf8>>
    ),
    _assert_subject@1 = matched(),
    case _assert_subject =:= _assert_subject@1 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_equality_numeric_test"/utf8>>,
                function => <<"ranges_allow_reversed_bounds_test"/utf8>>,
                line => 58,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject,
                    start => 2352,
                    'end' => 2523
                    },
                right => #{kind => expression,
                    value => _assert_subject@1,
                    start => 2531,
                    'end' => 2540
                    },
                start => 2345,
                'end' => 2540,
                expression_start => 2352})
    end.

-file("test/math_equality_numeric_test.gleam", 69).
-spec numeric_parser_accepts_number_input_scalar_notation_test() -> nil.
numeric_parser_accepts_number_input_scalar_notation_test() ->
    _assert_subject = evaluate(
        {equal, math@equality@types:numeric_input(<<"42"/utf8>>)},
        <<"42"/utf8>>
    ),
    _assert_subject@1 = matched(),
    case _assert_subject =:= _assert_subject@1 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_equality_numeric_test"/utf8>>,
                function => <<"numeric_parser_accepts_number_input_scalar_notation_test"/utf8>>,
                line => 70,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject,
                    start => 2621,
                    'end' => 2675
                    },
                right => #{kind => expression,
                    value => _assert_subject@1,
                    start => 2679,
                    'end' => 2688
                    },
                start => 2614,
                'end' => 2688,
                expression_start => 2621})
    end,
    _assert_subject@2 = evaluate(
        {equal, math@equality@types:numeric_input(<<"42"/utf8>>)},
        <<"+42"/utf8>>
    ),
    _assert_subject@3 = matched(),
    case _assert_subject@2 =:= _assert_subject@3 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_equality_numeric_test"/utf8>>,
                function => <<"numeric_parser_accepts_number_input_scalar_notation_test"/utf8>>,
                line => 71,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject@2,
                    start => 2698,
                    'end' => 2753
                    },
                right => #{kind => expression,
                    value => _assert_subject@3,
                    start => 2757,
                    'end' => 2766
                    },
                start => 2691,
                'end' => 2766,
                expression_start => 2698})
    end,
    _assert_subject@4 = evaluate(
        {equal, math@equality@types:numeric_input(<<"2.5"/utf8>>)},
        <<"2.5"/utf8>>
    ),
    _assert_subject@5 = matched(),
    case _assert_subject@4 =:= _assert_subject@5 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_equality_numeric_test"/utf8>>,
                function => <<"numeric_parser_accepts_number_input_scalar_notation_test"/utf8>>,
                line => 72,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject@4,
                    start => 2776,
                    'end' => 2832
                    },
                right => #{kind => expression,
                    value => _assert_subject@5,
                    start => 2836,
                    'end' => 2845
                    },
                start => 2769,
                'end' => 2845,
                expression_start => 2776})
    end,
    _assert_subject@6 = evaluate(
        {equal, math@equality@types:numeric_input(<<".5"/utf8>>)},
        <<".5"/utf8>>
    ),
    _assert_subject@7 = matched(),
    case _assert_subject@6 =:= _assert_subject@7 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_equality_numeric_test"/utf8>>,
                function => <<"numeric_parser_accepts_number_input_scalar_notation_test"/utf8>>,
                line => 73,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject@6,
                    start => 2855,
                    'end' => 2909
                    },
                right => #{kind => expression,
                    value => _assert_subject@7,
                    start => 2913,
                    'end' => 2922
                    },
                start => 2848,
                'end' => 2922,
                expression_start => 2855})
    end,
    _assert_subject@8 = evaluate(
        {equal, math@equality@types:numeric_input(<<"0.5"/utf8>>)},
        <<"+.5"/utf8>>
    ),
    _assert_subject@9 = matched(),
    case _assert_subject@8 =:= _assert_subject@9 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_equality_numeric_test"/utf8>>,
                function => <<"numeric_parser_accepts_number_input_scalar_notation_test"/utf8>>,
                line => 74,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject@8,
                    start => 2932,
                    'end' => 2988
                    },
                right => #{kind => expression,
                    value => _assert_subject@9,
                    start => 2992,
                    'end' => 3001
                    },
                start => 2925,
                'end' => 3001,
                expression_start => 2932})
    end,
    _assert_subject@10 = evaluate(
        {equal, math@equality@types:numeric_input(<<"-0.5"/utf8>>)},
        <<"-.5"/utf8>>
    ),
    _assert_subject@11 = matched(),
    case _assert_subject@10 =:= _assert_subject@11 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_equality_numeric_test"/utf8>>,
                function => <<"numeric_parser_accepts_number_input_scalar_notation_test"/utf8>>,
                line => 75,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject@10,
                    start => 3011,
                    'end' => 3068
                    },
                right => #{kind => expression,
                    value => _assert_subject@11,
                    start => 3072,
                    'end' => 3081
                    },
                start => 3004,
                'end' => 3081,
                expression_start => 3011})
    end,
    _assert_subject@12 = evaluate(
        {equal, math@equality@types:numeric_input(<<"1000"/utf8>>)},
        <<"1e3"/utf8>>
    ),
    _assert_subject@13 = matched(),
    case _assert_subject@12 =:= _assert_subject@13 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_equality_numeric_test"/utf8>>,
                function => <<"numeric_parser_accepts_number_input_scalar_notation_test"/utf8>>,
                line => 76,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject@12,
                    start => 3091,
                    'end' => 3148
                    },
                right => #{kind => expression,
                    value => _assert_subject@13,
                    start => 3152,
                    'end' => 3161
                    },
                start => 3084,
                'end' => 3161,
                expression_start => 3091})
    end,
    _assert_subject@14 = evaluate(
        {equal, math@equality@types:numeric_input(<<"1000"/utf8>>)},
        <<"1E3"/utf8>>
    ),
    _assert_subject@15 = matched(),
    case _assert_subject@14 =:= _assert_subject@15 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_equality_numeric_test"/utf8>>,
                function => <<"numeric_parser_accepts_number_input_scalar_notation_test"/utf8>>,
                line => 77,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject@14,
                    start => 3171,
                    'end' => 3228
                    },
                right => #{kind => expression,
                    value => _assert_subject@15,
                    start => 3232,
                    'end' => 3241
                    },
                start => 3164,
                'end' => 3241,
                expression_start => 3171})
    end,
    _assert_subject@16 = evaluate(
        {equal, math@equality@types:numeric_input(<<"-1000"/utf8>>)},
        <<"-1e3"/utf8>>
    ),
    _assert_subject@17 = matched(),
    case _assert_subject@16 =:= _assert_subject@17 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_equality_numeric_test"/utf8>>,
                function => <<"numeric_parser_accepts_number_input_scalar_notation_test"/utf8>>,
                line => 78,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject@16,
                    start => 3251,
                    'end' => 3310
                    },
                right => #{kind => expression,
                    value => _assert_subject@17,
                    start => 3318,
                    'end' => 3327
                    },
                start => 3244,
                'end' => 3327,
                expression_start => 3251})
    end.

-file("test/math_equality_numeric_test.gleam", 82).
-spec submitted_parse_failures_are_not_config_failures_test() -> nil.
submitted_parse_failures_are_not_config_failures_test() ->
    _assert_subject = evaluate(
        {equal, math@equality@types:numeric_input(<<"2"/utf8>>)},
        <<"two"/utf8>>
    ),
    _assert_subject@1 = {invalid_submitted_answer, [numeric_parse_failure]},
    case _assert_subject =:= _assert_subject@1 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_equality_numeric_test"/utf8>>,
                function => <<"submitted_parse_failures_are_not_config_failures_test"/utf8>>,
                line => 83,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject,
                    start => 3405,
                    'end' => 3459
                    },
                right => #{kind => expression,
                    value => _assert_subject@1,
                    start => 3467,
                    'end' => 3537
                    },
                start => 3398,
                'end' => 3537,
                expression_start => 3405})
    end.

-file("test/math_equality_numeric_test.gleam", 87).
-spec configured_numeric_parse_failures_are_invalid_config_test() -> nil.
configured_numeric_parse_failures_are_invalid_config_test() ->
    _assert_subject = evaluate(
        {equal, math@equality@types:numeric_input(<<"two"/utf8>>)},
        <<"2"/utf8>>
    ),
    _assert_subject@1 = {invalid_config,
        {invalid_field,
            <<"comparison.expected"/utf8>>,
            <<"expected numeric string"/utf8>>}},
    case _assert_subject =:= _assert_subject@1 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_equality_numeric_test"/utf8>>,
                function => <<"configured_numeric_parse_failures_are_invalid_config_test"/utf8>>,
                line => 88,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject,
                    start => 3619,
                    'end' => 3673
                    },
                right => #{kind => literal,
                    value => _assert_subject@1,
                    start => 3681,
                    'end' => 3811
                    },
                start => 3612,
                'end' => 3811,
                expression_start => 3619})
    end,
    _assert_subject@2 = evaluate(
        {between,
            math@equality@types:numeric_input(<<"1"/utf8>>),
            math@equality@types:numeric_input(<<"three"/utf8>>),
            inclusive},
        <<"2"/utf8>>
    ),
    _assert_subject@3 = {invalid_config,
        {invalid_field,
            <<"comparison.upper"/utf8>>,
            <<"expected numeric string"/utf8>>}},
    case _assert_subject@2 =:= _assert_subject@3 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_equality_numeric_test"/utf8>>,
                function => <<"configured_numeric_parse_failures_are_invalid_config_test"/utf8>>,
                line => 94,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject@2,
                    start => 3822,
                    'end' => 3997
                    },
                right => #{kind => literal,
                    value => _assert_subject@3,
                    start => 4005,
                    'end' => 4132
                    },
                start => 3815,
                'end' => 4132,
                expression_start => 3822})
    end.

-file("test/math_equality_numeric_test.gleam", 420).
-spec evaluate_with_options(
    math@equality@types:numeric_comparison(),
    math@equality@types:numeric_tolerance(),
    math@equality@types:numeric_representation(),
    math@equality@types:numeric_precision(),
    binary()
) -> math@equality@types:equality_result().
evaluate_with_options(
    Comparison,
    Tolerance,
    Representation,
    Precision,
    Submitted
) ->
    torus_math:evaluate_equality(
        {equality_spec,
            1,
            {numeric,
                {numeric_spec, Comparison, Tolerance, Representation, Precision}}},
        Submitted
    ).

-file("test/math_equality_numeric_test.gleam", 108).
-spec absolute_tolerance_supports_boundary_inside_and_outside_values_test() -> nil.
absolute_tolerance_supports_boundary_inside_and_outside_values_test() ->
    Tolerance = {absolute_tolerance, 0.125},
    _assert_subject = evaluate_with_options(
        {equal, math@equality@types:numeric_input(<<"10"/utf8>>)},
        Tolerance,
        any_representation,
        no_precision,
        <<"10.125"/utf8>>
    ),
    _assert_subject@1 = matched(),
    case _assert_subject =:= _assert_subject@1 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_equality_numeric_test"/utf8>>,
                function => <<"absolute_tolerance_supports_boundary_inside_and_outside_values_test"/utf8>>,
                line => 111,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject,
                    start => 4281,
                    'end' => 4444
                    },
                right => #{kind => expression,
                    value => _assert_subject@1,
                    start => 4452,
                    'end' => 4461
                    },
                start => 4274,
                'end' => 4461,
                expression_start => 4281})
    end,
    _assert_subject@2 = evaluate_with_options(
        {equal, math@equality@types:numeric_input(<<"10"/utf8>>)},
        Tolerance,
        any_representation,
        no_precision,
        <<"10.0625"/utf8>>
    ),
    _assert_subject@3 = matched(),
    case _assert_subject@2 =:= _assert_subject@3 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_equality_numeric_test"/utf8>>,
                function => <<"absolute_tolerance_supports_boundary_inside_and_outside_values_test"/utf8>>,
                line => 120,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject@2,
                    start => 4472,
                    'end' => 4636
                    },
                right => #{kind => expression,
                    value => _assert_subject@3,
                    start => 4644,
                    'end' => 4653
                    },
                start => 4465,
                'end' => 4653,
                expression_start => 4472})
    end,
    _assert_subject@4 = evaluate_with_options(
        {equal, math@equality@types:numeric_input(<<"10"/utf8>>)},
        Tolerance,
        any_representation,
        no_precision,
        <<"10.126"/utf8>>
    ),
    _assert_subject@5 = {equality_not_matched, [numeric_tolerance_mismatch]},
    case _assert_subject@4 =:= _assert_subject@5 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_equality_numeric_test"/utf8>>,
                function => <<"absolute_tolerance_supports_boundary_inside_and_outside_values_test"/utf8>>,
                line => 129,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject@4,
                    start => 4664,
                    'end' => 4827
                    },
                right => #{kind => expression,
                    value => _assert_subject@5,
                    start => 4835,
                    'end' => 4919
                    },
                start => 4657,
                'end' => 4919,
                expression_start => 4664})
    end.

-file("test/math_equality_numeric_test.gleam", 141).
-spec relative_tolerance_uses_larger_magnitude_and_near_zero_behavior_test() -> nil.
relative_tolerance_uses_larger_magnitude_and_near_zero_behavior_test() ->
    Tolerance = {relative_tolerance, 0.1},
    _assert_subject = evaluate_with_options(
        {equal, math@equality@types:numeric_input(<<"100"/utf8>>)},
        Tolerance,
        any_representation,
        no_precision,
        <<"90"/utf8>>
    ),
    _assert_subject@1 = matched(),
    case _assert_subject =:= _assert_subject@1 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_equality_numeric_test"/utf8>>,
                function => <<"relative_tolerance_uses_larger_magnitude_and_near_zero_behavior_test"/utf8>>,
                line => 144,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject,
                    start => 5067,
                    'end' => 5227
                    },
                right => #{kind => expression,
                    value => _assert_subject@1,
                    start => 5235,
                    'end' => 5244
                    },
                start => 5060,
                'end' => 5244,
                expression_start => 5067})
    end,
    _assert_subject@2 = evaluate_with_options(
        {equal, math@equality@types:numeric_input(<<"100"/utf8>>)},
        Tolerance,
        any_representation,
        no_precision,
        <<"89"/utf8>>
    ),
    _assert_subject@3 = {equality_not_matched, [numeric_tolerance_mismatch]},
    case _assert_subject@2 =:= _assert_subject@3 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_equality_numeric_test"/utf8>>,
                function => <<"relative_tolerance_uses_larger_magnitude_and_near_zero_behavior_test"/utf8>>,
                line => 153,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject@2,
                    start => 5255,
                    'end' => 5415
                    },
                right => #{kind => expression,
                    value => _assert_subject@3,
                    start => 5423,
                    'end' => 5507
                    },
                start => 5248,
                'end' => 5507,
                expression_start => 5255})
    end,
    _assert_subject@4 = evaluate_with_options(
        {equal, math@equality@types:numeric_input(<<"0"/utf8>>)},
        Tolerance,
        any_representation,
        no_precision,
        <<"0.001"/utf8>>
    ),
    _assert_subject@5 = {equality_not_matched, [numeric_tolerance_mismatch]},
    case _assert_subject@4 =:= _assert_subject@5 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_equality_numeric_test"/utf8>>,
                function => <<"relative_tolerance_uses_larger_magnitude_and_near_zero_behavior_test"/utf8>>,
                line => 164,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject@4,
                    start => 5518,
                    'end' => 5679
                    },
                right => #{kind => expression,
                    value => _assert_subject@5,
                    start => 5687,
                    'end' => 5771
                    },
                start => 5511,
                'end' => 5771,
                expression_start => 5518})
    end.

-file("test/math_equality_numeric_test.gleam", 176).
-spec combined_tolerance_accepts_absolute_or_relative_success_test() -> nil.
combined_tolerance_accepts_absolute_or_relative_success_test() ->
    Tolerance = {absolute_or_relative_tolerance, 0.01, 0.1},
    _assert_subject = evaluate_with_options(
        {equal, math@equality@types:numeric_input(<<"0"/utf8>>)},
        Tolerance,
        any_representation,
        no_precision,
        <<"0.005"/utf8>>
    ),
    _assert_subject@1 = matched(),
    case _assert_subject =:= _assert_subject@1 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_equality_numeric_test"/utf8>>,
                function => <<"combined_tolerance_accepts_absolute_or_relative_success_test"/utf8>>,
                line => 180,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject,
                    start => 5944,
                    'end' => 6105
                    },
                right => #{kind => expression,
                    value => _assert_subject@1,
                    start => 6113,
                    'end' => 6122
                    },
                start => 5937,
                'end' => 6122,
                expression_start => 5944})
    end,
    _assert_subject@2 = evaluate_with_options(
        {equal, math@equality@types:numeric_input(<<"100"/utf8>>)},
        Tolerance,
        any_representation,
        no_precision,
        <<"90"/utf8>>
    ),
    _assert_subject@3 = matched(),
    case _assert_subject@2 =:= _assert_subject@3 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_equality_numeric_test"/utf8>>,
                function => <<"combined_tolerance_accepts_absolute_or_relative_success_test"/utf8>>,
                line => 189,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject@2,
                    start => 6133,
                    'end' => 6293
                    },
                right => #{kind => expression,
                    value => _assert_subject@3,
                    start => 6301,
                    'end' => 6310
                    },
                start => 6126,
                'end' => 6310,
                expression_start => 6133})
    end,
    _assert_subject@4 = evaluate_with_options(
        {equal, math@equality@types:numeric_input(<<"0"/utf8>>)},
        Tolerance,
        any_representation,
        no_precision,
        <<"0.02"/utf8>>
    ),
    _assert_subject@5 = {equality_not_matched, [numeric_tolerance_mismatch]},
    case _assert_subject@4 =:= _assert_subject@5 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_equality_numeric_test"/utf8>>,
                function => <<"combined_tolerance_accepts_absolute_or_relative_success_test"/utf8>>,
                line => 198,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject@4,
                    start => 6321,
                    'end' => 6481
                    },
                right => #{kind => expression,
                    value => _assert_subject@5,
                    start => 6489,
                    'end' => 6573
                    },
                start => 6314,
                'end' => 6573,
                expression_start => 6321})
    end.

-file("test/math_equality_numeric_test.gleam", 210).
-spec not_equal_uses_tolerance_as_the_equality_window_test() -> nil.
not_equal_uses_tolerance_as_the_equality_window_test() ->
    _assert_subject = evaluate_with_options(
        {not_equal, math@equality@types:numeric_input(<<"10"/utf8>>)},
        {absolute_tolerance, 0.1},
        any_representation,
        no_precision,
        <<"10.05"/utf8>>
    ),
    _assert_subject@1 = {equality_not_matched, [numeric_tolerance_mismatch]},
    case _assert_subject =:= _assert_subject@1 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_equality_numeric_test"/utf8>>,
                function => <<"not_equal_uses_tolerance_as_the_equality_window_test"/utf8>>,
                line => 211,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject,
                    start => 6650,
                    'end' => 6841
                    },
                right => #{kind => expression,
                    value => _assert_subject@1,
                    start => 6849,
                    'end' => 6933
                    },
                start => 6643,
                'end' => 6933,
                expression_start => 6650})
    end,
    _assert_subject@2 = evaluate_with_options(
        {not_equal, math@equality@types:numeric_input(<<"10"/utf8>>)},
        {absolute_tolerance, 0.1},
        any_representation,
        no_precision,
        <<"10.2"/utf8>>
    ),
    _assert_subject@3 = matched(),
    case _assert_subject@2 =:= _assert_subject@3 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_equality_numeric_test"/utf8>>,
                function => <<"not_equal_uses_tolerance_as_the_equality_window_test"/utf8>>,
                line => 222,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject@2,
                    start => 6944,
                    'end' => 7134
                    },
                right => #{kind => expression,
                    value => _assert_subject@3,
                    start => 7142,
                    'end' => 7151
                    },
                start => 6937,
                'end' => 7151,
                expression_start => 6944})
    end.

-file("test/math_equality_numeric_test.gleam", 232).
-spec representation_constraints_distinguish_value_from_submitted_form_test() -> nil.
representation_constraints_distinguish_value_from_submitted_form_test() ->
    _assert_subject = evaluate_with_options(
        {equal, math@equality@types:numeric_input(<<"42"/utf8>>)},
        no_tolerance,
        integer_representation,
        no_precision,
        <<"42"/utf8>>
    ),
    _assert_subject@1 = matched(),
    case _assert_subject =:= _assert_subject@1 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_equality_numeric_test"/utf8>>,
                function => <<"representation_constraints_distinguish_value_from_submitted_form_test"/utf8>>,
                line => 233,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject,
                    start => 7245,
                    'end' => 7416
                    },
                right => #{kind => expression,
                    value => _assert_subject@1,
                    start => 7424,
                    'end' => 7433
                    },
                start => 7238,
                'end' => 7433,
                expression_start => 7245})
    end,
    _assert_subject@2 = evaluate_with_options(
        {equal, math@equality@types:numeric_input(<<"42"/utf8>>)},
        no_tolerance,
        integer_representation,
        no_precision,
        <<"42.0"/utf8>>
    ),
    _assert_subject@3 = {equality_not_matched,
        [numeric_representation_mismatch]},
    case _assert_subject@2 =:= _assert_subject@3 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_equality_numeric_test"/utf8>>,
                function => <<"representation_constraints_distinguish_value_from_submitted_form_test"/utf8>>,
                line => 242,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject@2,
                    start => 7444,
                    'end' => 7617
                    },
                right => #{kind => expression,
                    value => _assert_subject@3,
                    start => 7625,
                    'end' => 7714
                    },
                start => 7437,
                'end' => 7714,
                expression_start => 7444})
    end,
    _assert_subject@4 = evaluate_with_options(
        {equal, math@equality@types:numeric_input(<<"42"/utf8>>)},
        no_tolerance,
        decimal_representation,
        no_precision,
        <<"42.0"/utf8>>
    ),
    _assert_subject@5 = matched(),
    case _assert_subject@4 =:= _assert_subject@5 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_equality_numeric_test"/utf8>>,
                function => <<"representation_constraints_distinguish_value_from_submitted_form_test"/utf8>>,
                line => 253,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject@4,
                    start => 7725,
                    'end' => 7898
                    },
                right => #{kind => expression,
                    value => _assert_subject@5,
                    start => 7906,
                    'end' => 7915
                    },
                start => 7718,
                'end' => 7915,
                expression_start => 7725})
    end,
    _assert_subject@6 = evaluate_with_options(
        {equal, math@equality@types:numeric_input(<<"42"/utf8>>)},
        no_tolerance,
        scientific_representation,
        no_precision,
        <<"4.2e1"/utf8>>
    ),
    _assert_subject@7 = matched(),
    case _assert_subject@6 =:= _assert_subject@7 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_equality_numeric_test"/utf8>>,
                function => <<"representation_constraints_distinguish_value_from_submitted_form_test"/utf8>>,
                line => 262,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject@6,
                    start => 7926,
                    'end' => 8103
                    },
                right => #{kind => expression,
                    value => _assert_subject@7,
                    start => 8111,
                    'end' => 8120
                    },
                start => 7919,
                'end' => 8120,
                expression_start => 7926})
    end.

-file("test/math_equality_numeric_test.gleam", 272).
-spec decimal_precision_supports_exact_at_least_and_at_most_rules_test() -> nil.
decimal_precision_supports_exact_at_least_and_at_most_rules_test() ->
    _assert_subject = evaluate_with_options(
        {equal, math@equality@types:numeric_input(<<"1.2"/utf8>>)},
        no_tolerance,
        any_representation,
        {decimal_places, exactly, 2},
        <<"1.20"/utf8>>
    ),
    _assert_subject@1 = matched(),
    case _assert_subject =:= _assert_subject@1 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_equality_numeric_test"/utf8>>,
                function => <<"decimal_precision_supports_exact_at_least_and_at_most_rules_test"/utf8>>,
                line => 273,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject,
                    start => 8209,
                    'end' => 8412
                    },
                right => #{kind => expression,
                    value => _assert_subject@1,
                    start => 8420,
                    'end' => 8429
                    },
                start => 8202,
                'end' => 8429,
                expression_start => 8209})
    end,
    _assert_subject@2 = evaluate_with_options(
        {equal, math@equality@types:numeric_input(<<"1.2"/utf8>>)},
        no_tolerance,
        any_representation,
        {decimal_places, exactly, 2},
        <<"1.2"/utf8>>
    ),
    _assert_subject@3 = {equality_not_matched, [numeric_precision_mismatch]},
    case _assert_subject@2 =:= _assert_subject@3 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_equality_numeric_test"/utf8>>,
                function => <<"decimal_precision_supports_exact_at_least_and_at_most_rules_test"/utf8>>,
                line => 282,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject@2,
                    start => 8440,
                    'end' => 8642
                    },
                right => #{kind => expression,
                    value => _assert_subject@3,
                    start => 8650,
                    'end' => 8734
                    },
                start => 8433,
                'end' => 8734,
                expression_start => 8440})
    end,
    _assert_subject@4 = evaluate_with_options(
        {equal, math@equality@types:numeric_input(<<"1.234"/utf8>>)},
        no_tolerance,
        any_representation,
        {decimal_places, at_least, 2},
        <<"1.234"/utf8>>
    ),
    _assert_subject@5 = matched(),
    case _assert_subject@4 =:= _assert_subject@5 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_equality_numeric_test"/utf8>>,
                function => <<"decimal_precision_supports_exact_at_least_and_at_most_rules_test"/utf8>>,
                line => 293,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject@4,
                    start => 8745,
                    'end' => 8951
                    },
                right => #{kind => expression,
                    value => _assert_subject@5,
                    start => 8959,
                    'end' => 8968
                    },
                start => 8738,
                'end' => 8968,
                expression_start => 8745})
    end,
    _assert_subject@6 = evaluate_with_options(
        {equal, math@equality@types:numeric_input(<<"1.234"/utf8>>)},
        no_tolerance,
        any_representation,
        {decimal_places, at_most, 2},
        <<"1.234"/utf8>>
    ),
    _assert_subject@7 = {equality_not_matched, [numeric_precision_mismatch]},
    case _assert_subject@6 =:= _assert_subject@7 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_equality_numeric_test"/utf8>>,
                function => <<"decimal_precision_supports_exact_at_least_and_at_most_rules_test"/utf8>>,
                line => 302,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject@6,
                    start => 8979,
                    'end' => 9184
                    },
                right => #{kind => expression,
                    value => _assert_subject@7,
                    start => 9192,
                    'end' => 9276
                    },
                start => 8972,
                'end' => 9276,
                expression_start => 8979})
    end,
    _assert_subject@8 = evaluate_with_options(
        {equal, math@equality@types:numeric_input(<<"42"/utf8>>)},
        no_tolerance,
        any_representation,
        {decimal_places, exactly, 0},
        <<"42"/utf8>>
    ),
    _assert_subject@9 = matched(),
    case _assert_subject@8 =:= _assert_subject@9 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_equality_numeric_test"/utf8>>,
                function => <<"decimal_precision_supports_exact_at_least_and_at_most_rules_test"/utf8>>,
                line => 313,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject@8,
                    start => 9287,
                    'end' => 9487
                    },
                right => #{kind => expression,
                    value => _assert_subject@9,
                    start => 9495,
                    'end' => 9504
                    },
                start => 9280,
                'end' => 9504,
                expression_start => 9287})
    end.

-file("test/math_equality_numeric_test.gleam", 323).
-spec legacy_significant_figures_remain_distinct_from_decimal_places_test() -> nil.
legacy_significant_figures_remain_distinct_from_decimal_places_test() ->
    _assert_subject = evaluate_with_options(
        {equal, math@equality@types:numeric_input(<<"1.23"/utf8>>)},
        no_tolerance,
        any_representation,
        {legacy_significant_figures, 3},
        <<"1.23"/utf8>>
    ),
    _assert_subject@1 = matched(),
    case _assert_subject =:= _assert_subject@1 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_equality_numeric_test"/utf8>>,
                function => <<"legacy_significant_figures_remain_distinct_from_decimal_places_test"/utf8>>,
                line => 324,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject,
                    start => 9596,
                    'end' => 9790
                    },
                right => #{kind => expression,
                    value => _assert_subject@1,
                    start => 9798,
                    'end' => 9807
                    },
                start => 9589,
                'end' => 9807,
                expression_start => 9596})
    end,
    _assert_subject@2 = evaluate_with_options(
        {equal, math@equality@types:numeric_input(<<"1.23"/utf8>>)},
        no_tolerance,
        any_representation,
        {legacy_significant_figures, 3},
        <<"1.230"/utf8>>
    ),
    _assert_subject@3 = {equality_not_matched, [numeric_precision_mismatch]},
    case _assert_subject@2 =:= _assert_subject@3 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_equality_numeric_test"/utf8>>,
                function => <<"legacy_significant_figures_remain_distinct_from_decimal_places_test"/utf8>>,
                line => 333,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject@2,
                    start => 9818,
                    'end' => 10013
                    },
                right => #{kind => expression,
                    value => _assert_subject@3,
                    start => 10021,
                    'end' => 10105
                    },
                start => 9811,
                'end' => 10105,
                expression_start => 9818})
    end,
    _assert_subject@4 = evaluate_with_options(
        {equal, math@equality@types:numeric_input(<<"1200"/utf8>>)},
        no_tolerance,
        any_representation,
        {legacy_significant_figures, 2},
        <<"1200"/utf8>>
    ),
    _assert_subject@5 = matched(),
    case _assert_subject@4 =:= _assert_subject@5 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_equality_numeric_test"/utf8>>,
                function => <<"legacy_significant_figures_remain_distinct_from_decimal_places_test"/utf8>>,
                line => 344,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject@4,
                    start => 10116,
                    'end' => 10310
                    },
                right => #{kind => expression,
                    value => _assert_subject@5,
                    start => 10318,
                    'end' => 10327
                    },
                start => 10109,
                'end' => 10327,
                expression_start => 10116})
    end,
    _assert_subject@6 = evaluate_with_options(
        {equal, math@equality@types:numeric_input(<<"1200"/utf8>>)},
        no_tolerance,
        any_representation,
        {legacy_significant_figures, 3},
        <<"1.20e3"/utf8>>
    ),
    _assert_subject@7 = matched(),
    case _assert_subject@6 =:= _assert_subject@7 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_equality_numeric_test"/utf8>>,
                function => <<"legacy_significant_figures_remain_distinct_from_decimal_places_test"/utf8>>,
                line => 353,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject@6,
                    start => 10338,
                    'end' => 10534
                    },
                right => #{kind => expression,
                    value => _assert_subject@7,
                    start => 10542,
                    'end' => 10551
                    },
                start => 10331,
                'end' => 10551,
                expression_start => 10338})
    end.

-file("test/math_equality_numeric_test.gleam", 363).
-spec multiple_numeric_option_failures_are_reported_separately_test() -> nil.
multiple_numeric_option_failures_are_reported_separately_test() ->
    _assert_subject = evaluate_with_options(
        {equal, math@equality@types:numeric_input(<<"42"/utf8>>)},
        no_tolerance,
        integer_representation,
        {decimal_places, exactly, 0},
        <<"42.0"/utf8>>
    ),
    _assert_subject@1 = {equality_not_matched,
        [numeric_representation_mismatch, numeric_precision_mismatch]},
    case _assert_subject =:= _assert_subject@1 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_equality_numeric_test"/utf8>>,
                function => <<"multiple_numeric_option_failures_are_reported_separately_test"/utf8>>,
                line => 364,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject,
                    start => 10637,
                    'end' => 10843
                    },
                right => #{kind => expression,
                    value => _assert_subject@1,
                    start => 10851,
                    'end' => 10978
                    },
                start => 10630,
                'end' => 10978,
                expression_start => 10637})
    end.

-file("test/math_equality_numeric_test.gleam", 377).
-spec invalid_numeric_option_values_are_config_errors_test() -> nil.
invalid_numeric_option_values_are_config_errors_test() ->
    _assert_subject = evaluate_with_options(
        {equal, math@equality@types:numeric_input(<<"2"/utf8>>)},
        {absolute_tolerance, -0.01},
        any_representation,
        no_precision,
        <<"2"/utf8>>
    ),
    _assert_subject@1 = {invalid_config,
        {invalid_field,
            <<"tolerance.value"/utf8>>,
            <<"expected non-negative float"/utf8>>}},
    case _assert_subject =:= _assert_subject@1 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_equality_numeric_test"/utf8>>,
                function => <<"invalid_numeric_option_values_are_config_errors_test"/utf8>>,
                line => 378,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject,
                    start => 11055,
                    'end' => 11240
                    },
                right => #{kind => literal,
                    value => _assert_subject@1,
                    start => 11248,
                    'end' => 11378
                    },
                start => 11048,
                'end' => 11378,
                expression_start => 11055})
    end,
    _assert_subject@2 = evaluate_with_options(
        {equal, math@equality@types:numeric_input(<<"2"/utf8>>)},
        no_tolerance,
        any_representation,
        {legacy_significant_figures, 0},
        <<"2"/utf8>>
    ),
    _assert_subject@3 = {invalid_config,
        {invalid_field,
            <<"precision.count"/utf8>>,
            <<"expected positive integer"/utf8>>}},
    case _assert_subject@2 =:= _assert_subject@3 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_equality_numeric_test"/utf8>>,
                function => <<"invalid_numeric_option_values_are_config_errors_test"/utf8>>,
                line => 390,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject@2,
                    start => 11389,
                    'end' => 11577
                    },
                right => #{kind => literal,
                    value => _assert_subject@3,
                    start => 11585,
                    'end' => 11713
                    },
                start => 11382,
                'end' => 11713,
                expression_start => 11389})
    end.
