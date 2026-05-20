-module(math_equality_contract_test).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "test/math_equality_contract_test.gleam").
-export([main/0, numeric_contract_represents_standard_page_operators_test/0, range_contract_requires_bounds_and_inclusivity_test/0, expression_and_unit_modes_are_contract_shapes_not_evaluators_test/0, numeric_evaluation_runs_standard_operator_layer_test/0, equality_config_validation_rejects_unsupported_versions_test/0]).

-file("test/math_equality_contract_test.gleam", 6).
-spec main() -> nil.
main() ->
    gleeunit:main().

-file("test/math_equality_contract_test.gleam", 97).
-spec numeric(math@equality@types:numeric_comparison()) -> math@equality@types:numeric_spec().
numeric(Comparison) ->
    {numeric_spec, Comparison, no_tolerance, any_representation, no_precision}.

-file("test/math_equality_contract_test.gleam", 10).
-spec numeric_contract_represents_standard_page_operators_test() -> nil.
numeric_contract_represents_standard_page_operators_test() ->
    Value = math@equality@types:numeric_input(<<"2"/utf8>>),
    _assert_subject = math@equality@types:default_numeric_options(
        {equal, Value}
    ),
    _assert_subject@1 = numeric({equal, Value}),
    case _assert_subject =:= _assert_subject@1 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_equality_contract_test"/utf8>>,
                function => <<"numeric_contract_represents_standard_page_operators_test"/utf8>>,
                line => 13,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject,
                    start => 232,
                    'end' => 291
                    },
                right => #{kind => expression,
                    value => _assert_subject@1,
                    start => 299,
                    'end' => 336
                    },
                start => 225,
                'end' => 336,
                expression_start => 232})
    end,
    _assert_subject@2 = math@equality@types:default_numeric_options(
        {not_equal, Value}
    ),
    _assert_subject@3 = numeric({not_equal, Value}),
    case _assert_subject@2 =:= _assert_subject@3 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_equality_contract_test"/utf8>>,
                function => <<"numeric_contract_represents_standard_page_operators_test"/utf8>>,
                line => 15,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject@2,
                    start => 346,
                    'end' => 408
                    },
                right => #{kind => expression,
                    value => _assert_subject@3,
                    start => 416,
                    'end' => 456
                    },
                start => 339,
                'end' => 456,
                expression_start => 346})
    end,
    _assert_subject@4 = math@equality@types:default_numeric_options(
        {greater_than, Value}
    ),
    _assert_subject@5 = numeric({greater_than, Value}),
    case _assert_subject@4 =:= _assert_subject@5 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_equality_contract_test"/utf8>>,
                function => <<"numeric_contract_represents_standard_page_operators_test"/utf8>>,
                line => 17,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject@4,
                    start => 466,
                    'end' => 532
                    },
                right => #{kind => expression,
                    value => _assert_subject@5,
                    start => 540,
                    'end' => 584
                    },
                start => 459,
                'end' => 584,
                expression_start => 466})
    end,
    _assert_subject@6 = math@equality@types:default_numeric_options(
        {greater_than_or_equal, Value}
    ),
    _assert_subject@7 = numeric({greater_than_or_equal, Value}),
    case _assert_subject@6 =:= _assert_subject@7 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_equality_contract_test"/utf8>>,
                function => <<"numeric_contract_represents_standard_page_operators_test"/utf8>>,
                line => 19,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject@6,
                    start => 594,
                    'end' => 680
                    },
                right => #{kind => expression,
                    value => _assert_subject@7,
                    start => 688,
                    'end' => 739
                    },
                start => 587,
                'end' => 739,
                expression_start => 594})
    end,
    _assert_subject@8 = math@equality@types:default_numeric_options(
        {less_than, Value}
    ),
    _assert_subject@9 = numeric({less_than, Value}),
    case _assert_subject@8 =:= _assert_subject@9 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_equality_contract_test"/utf8>>,
                function => <<"numeric_contract_represents_standard_page_operators_test"/utf8>>,
                line => 23,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject@8,
                    start => 749,
                    'end' => 812
                    },
                right => #{kind => expression,
                    value => _assert_subject@9,
                    start => 820,
                    'end' => 861
                    },
                start => 742,
                'end' => 861,
                expression_start => 749})
    end,
    _assert_subject@10 = math@equality@types:default_numeric_options(
        {less_than_or_equal, Value}
    ),
    _assert_subject@11 = numeric({less_than_or_equal, Value}),
    case _assert_subject@10 =:= _assert_subject@11 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_equality_contract_test"/utf8>>,
                function => <<"numeric_contract_represents_standard_page_operators_test"/utf8>>,
                line => 25,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject@10,
                    start => 871,
                    'end' => 941
                    },
                right => #{kind => expression,
                    value => _assert_subject@11,
                    start => 949,
                    'end' => 997
                    },
                start => 864,
                'end' => 997,
                expression_start => 871})
    end.

-file("test/math_equality_contract_test.gleam", 29).
-spec range_contract_requires_bounds_and_inclusivity_test() -> nil.
range_contract_requires_bounds_and_inclusivity_test() ->
    Lower = math@equality@types:numeric_input(<<"1"/utf8>>),
    Upper = math@equality@types:numeric_input(<<"3"/utf8>>),
    _assert_subject = math@equality@types:default_numeric_options(
        {between, Lower, Upper, inclusive}
    ),
    _assert_subject@1 = numeric({between, Lower, Upper, inclusive}),
    case _assert_subject =:= _assert_subject@1 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_equality_contract_test"/utf8>>,
                function => <<"range_contract_requires_bounds_and_inclusivity_test"/utf8>>,
                line => 33,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject,
                    start => 1152,
                    'end' => 1274
                    },
                right => #{kind => expression,
                    value => _assert_subject@1,
                    start => 1282,
                    'end' => 1382
                    },
                start => 1145,
                'end' => 1382,
                expression_start => 1152})
    end,
    _assert_subject@2 = math@equality@types:default_numeric_options(
        {not_between, Lower, Upper, exclusive}
    ),
    _assert_subject@3 = numeric({not_between, Lower, Upper, exclusive}),
    case _assert_subject@2 =:= _assert_subject@3 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_equality_contract_test"/utf8>>,
                function => <<"range_contract_requires_bounds_and_inclusivity_test"/utf8>>,
                line => 44,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject@2,
                    start => 1393,
                    'end' => 1518
                    },
                right => #{kind => expression,
                    value => _assert_subject@3,
                    start => 1526,
                    'end' => 1629
                    },
                start => 1386,
                'end' => 1629,
                expression_start => 1393})
    end.

-file("test/math_equality_contract_test.gleam", 120).
-spec unit_spec() -> math@equality@types:unit_spec().
unit_spec() ->
    {unit_spec,
        {unit_numeric,
            math@equality@types:numeric_input(<<"9.8"/utf8>>),
            <<"m/s^2"/utf8>>},
        {convertible_units, [<<"m/s^2"/utf8>>, <<"cm/s^2"/utf8>>]}}.

-file("test/math_equality_contract_test.gleam", 106).
-spec expression_spec() -> math@equality@types:expression_spec().
expression_spec() ->
    {expression_spec,
        {algebraic_equivalence, <<"x + 1"/utf8>>, {sampling_config, 7, 5}},
        {expression_validation,
            [<<"x"/utf8>>],
            [sin, sqrt],
            [{variable_domain, <<"x"/utf8>>, -10.0, 10.0}]}}.

-file("test/math_equality_contract_test.gleam", 56).
-spec expression_and_unit_modes_are_contract_shapes_not_evaluators_test() -> nil.
expression_and_unit_modes_are_contract_shapes_not_evaluators_test() ->
    Expression_spec = {equality_spec, 1, {expression, expression_spec()}},
    Unit_spec = {equality_spec, 1, {unit_aware, unit_spec()}},
    _assert_subject = torus_math:evaluate_equality(
        Expression_spec,
        <<"x + 1"/utf8>>
    ),
    _assert_subject@1 = {unsupported_mode, expression_evaluation},
    case _assert_subject =:= _assert_subject@1 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_equality_contract_test"/utf8>>,
                function => <<"expression_and_unit_modes_are_contract_shapes_not_evaluators_test"/utf8>>,
                line => 63,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject,
                    start => 1912,
                    'end' => 1966
                    },
                right => #{kind => expression,
                    value => _assert_subject@1,
                    start => 1974,
                    'end' => 2029
                    },
                start => 1905,
                'end' => 2029,
                expression_start => 1912})
    end,
    _assert_subject@2 = torus_math:evaluate_equality(
        Unit_spec,
        <<"9.8 m/s^2"/utf8>>
    ),
    _assert_subject@3 = {unsupported_mode, unit_aware_evaluation},
    case _assert_subject@2 =:= _assert_subject@3 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_equality_contract_test"/utf8>>,
                function => <<"expression_and_unit_modes_are_contract_shapes_not_evaluators_test"/utf8>>,
                line => 65,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject@2,
                    start => 2039,
                    'end' => 2091
                    },
                right => #{kind => expression,
                    value => _assert_subject@3,
                    start => 2099,
                    'end' => 2153
                    },
                start => 2032,
                'end' => 2153,
                expression_start => 2039})
    end.

-file("test/math_equality_contract_test.gleam", 69).
-spec numeric_evaluation_runs_standard_operator_layer_test() -> nil.
numeric_evaluation_runs_standard_operator_layer_test() ->
    Spec = {equality_spec,
        1,
        {numeric,
            numeric({equal, math@equality@types:numeric_input(<<"2"/utf8>>)})}},
    _assert_subject = torus_math:evaluate_equality(Spec, <<"2"/utf8>>),
    _assert_subject@1 = {equality_matched, [numeric_comparison_matched]},
    case _assert_subject =:= _assert_subject@1 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_equality_contract_test"/utf8>>,
                function => <<"numeric_evaluation_runs_standard_operator_layer_test"/utf8>>,
                line => 78,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject,
                    start => 2394,
                    'end' => 2433
                    },
                right => #{kind => expression,
                    value => _assert_subject@1,
                    start => 2441,
                    'end' => 2509
                    },
                start => 2387,
                'end' => 2509,
                expression_start => 2394})
    end.

-file("test/math_equality_contract_test.gleam", 82).
-spec equality_config_validation_rejects_unsupported_versions_test() -> nil.
equality_config_validation_rejects_unsupported_versions_test() ->
    Spec = {equality_spec,
        2,
        {numeric,
            numeric({equal, math@equality@types:numeric_input(<<"2"/utf8>>)})}},
    _assert_subject = torus_math:validate_equality_config(Spec),
    _assert_subject@1 = {error, {unsupported_version, 2}},
    case _assert_subject =:= _assert_subject@1 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_equality_contract_test"/utf8>>,
                function => <<"equality_config_validation_rejects_unsupported_versions_test"/utf8>>,
                line => 91,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject,
                    start => 2758,
                    'end' => 2799
                    },
                right => #{kind => literal,
                    value => _assert_subject@1,
                    start => 2807,
                    'end' => 2850
                    },
                start => 2751,
                'end' => 2850,
                expression_start => 2758})
    end,
    _assert_subject@2 = torus_math:evaluate_equality(Spec, <<"2"/utf8>>),
    _assert_subject@3 = {invalid_config, {unsupported_version, 2}},
    case _assert_subject@2 =:= _assert_subject@3 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_equality_contract_test"/utf8>>,
                function => <<"equality_config_validation_rejects_unsupported_versions_test"/utf8>>,
                line => 93,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject@2,
                    start => 2860,
                    'end' => 2899
                    },
                right => #{kind => literal,
                    value => _assert_subject@3,
                    start => 2907,
                    'end' => 2971
                    },
                start => 2853,
                'end' => 2971,
                expression_start => 2860})
    end.
