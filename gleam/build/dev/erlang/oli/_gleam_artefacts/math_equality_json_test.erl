-module(math_equality_json_test).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "test/math_equality_json_test.gleam").
-export([main/0, numeric_json_fixtures_round_trip_test/0, future_mode_json_fixtures_round_trip_test/0, numeric_expected_values_are_encoded_as_strings_test/0, decoder_rejects_malformed_json_test/0, decoder_rejects_missing_required_fields_test/0, decoder_rejects_bad_version_test/0, decoder_rejects_unknown_discriminators_test/0, decoder_rejects_invalid_field_types_test/0, decoder_rejects_invalid_numeric_option_values_test/0]).

-file("test/math_equality_json_test.gleam", 7).
-spec main() -> nil.
main() ->
    gleeunit:main().

-file("test/math_equality_json_test.gleam", 147).
-spec assert_round_trip(math@equality@types:equality_spec()) -> nil.
assert_round_trip(Spec) ->
    _assert_subject = begin
        _pipe = Spec,
        _pipe@1 = torus_math:encode_equality_config(_pipe),
        torus_math:decode_equality_config(_pipe@1)
    end,
    _assert_subject@1 = {ok, Spec},
    case _assert_subject =:= _assert_subject@1 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_equality_json_test"/utf8>>,
                function => <<"assert_round_trip"/utf8>>,
                line => 148,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject,
                    start => 5619,
                    'end' => 5705
                    },
                right => #{kind => expression,
                    value => _assert_subject@1,
                    start => 5713,
                    'end' => 5721
                    },
                start => 5612,
                'end' => 5721,
                expression_start => 5619})
    end.

-file("test/math_equality_json_test.gleam", 163).
-spec numeric_with_options(
    math@equality@types:numeric_comparison(),
    math@equality@types:numeric_tolerance(),
    math@equality@types:numeric_representation(),
    math@equality@types:numeric_precision()
) -> math@equality@types:equality_spec().
numeric_with_options(Comparison, Tolerance, Representation, Precision) ->
    {equality_spec,
        1,
        {numeric,
            {numeric_spec, Comparison, Tolerance, Representation, Precision}}}.

-file("test/math_equality_json_test.gleam", 154).
-spec numeric(math@equality@types:numeric_comparison()) -> math@equality@types:equality_spec().
numeric(Comparison) ->
    numeric_with_options(
        Comparison,
        no_tolerance,
        any_representation,
        no_precision
    ).

-file("test/math_equality_json_test.gleam", 11).
-spec numeric_json_fixtures_round_trip_test() -> nil.
numeric_json_fixtures_round_trip_test() ->
    Specs = [numeric({equal, math@equality@types:numeric_input(<<"2"/utf8>>)}),
        numeric({not_equal, math@equality@types:numeric_input(<<"2"/utf8>>)}),
        numeric({greater_than, math@equality@types:numeric_input(<<"2"/utf8>>)}),
        numeric(
            {greater_than_or_equal,
                math@equality@types:numeric_input(<<"2"/utf8>>)}
        ),
        numeric({less_than, math@equality@types:numeric_input(<<"2"/utf8>>)}),
        numeric(
            {less_than_or_equal,
                math@equality@types:numeric_input(<<"2"/utf8>>)}
        ),
        numeric(
            {between,
                math@equality@types:numeric_input(<<"1"/utf8>>),
                math@equality@types:numeric_input(<<"3"/utf8>>),
                inclusive}
        ),
        numeric(
            {not_between,
                math@equality@types:numeric_input(<<"1"/utf8>>),
                math@equality@types:numeric_input(<<"3"/utf8>>),
                exclusive}
        ),
        numeric_with_options(
            {equal, math@equality@types:numeric_input(<<"2.0"/utf8>>)},
            {absolute_tolerance, 0.01},
            decimal_representation,
            {decimal_places, exactly, 2}
        ),
        numeric_with_options(
            {equal, math@equality@types:numeric_input(<<"2e3"/utf8>>)},
            {relative_tolerance, 0.001},
            scientific_representation,
            {legacy_significant_figures, 2}
        ),
        numeric_with_options(
            {equal, math@equality@types:numeric_input(<<"2"/utf8>>)},
            {absolute_or_relative_tolerance, 0.1, 0.01},
            integer_representation,
            no_precision
        )],
    gleam@list:each(Specs, fun assert_round_trip/1).

-file("test/math_equality_json_test.gleam", 194).
-spec unit_spec() -> math@equality@types:unit_spec().
unit_spec() ->
    {unit_spec,
        {unit_numeric,
            math@equality@types:numeric_input(<<"9.8"/utf8>>),
            <<"m/s^2"/utf8>>},
        {convertible_units, [<<"m/s^2"/utf8>>, <<"cm/s^2"/utf8>>]}}.

-file("test/math_equality_json_test.gleam", 180).
-spec expression_spec() -> math@equality@types:expression_spec().
expression_spec() ->
    {expression_spec,
        {algebraic_equivalence, <<"x + 1"/utf8>>, {sampling_config, 7, 5}},
        {expression_validation,
            [<<"x"/utf8>>],
            [sin, sqrt],
            [{variable_domain, <<"x"/utf8>>, -10.0, 10.0}]}}.

-file("test/math_equality_json_test.gleam", 55).
-spec future_mode_json_fixtures_round_trip_test() -> nil.
future_mode_json_fixtures_round_trip_test() ->
    assert_round_trip({equality_spec, 1, {expression, expression_spec()}}),
    assert_round_trip({equality_spec, 1, {unit_aware, unit_spec()}}).

-file("test/math_equality_json_test.gleam", 67).
-spec numeric_expected_values_are_encoded_as_strings_test() -> nil.
numeric_expected_values_are_encoded_as_strings_test() ->
    Spec = numeric_with_options(
        {equal, math@equality@types:numeric_input(<<"2.00"/utf8>>)},
        no_tolerance,
        any_representation,
        no_precision
    ),
    _assert_subject = torus_math:encode_equality_config(Spec),
    _assert_subject@1 = <<"{\"version\":1,\"mode\":\"numeric\",\"comparison\":{\"type\":\"equal\",\"expected\":\"2.00\"},\"tolerance\":{\"type\":\"none\"},\"representation\":{\"type\":\"any\"},\"precision\":{\"type\":\"none\"}}"/utf8>>,
    case _assert_subject =:= _assert_subject@1 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_equality_json_test"/utf8>>,
                function => <<"numeric_expected_values_are_encoded_as_strings_test"/utf8>>,
                line => 76,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject,
                    start => 2258,
                    'end' => 2297
                    },
                right => #{kind => literal,
                    value => _assert_subject@1,
                    start => 2305,
                    'end' => 2507
                    },
                start => 2251,
                'end' => 2507,
                expression_start => 2258})
    end.

-file("test/math_equality_json_test.gleam", 80).
-spec decoder_rejects_malformed_json_test() -> nil.
decoder_rejects_malformed_json_test() ->
    _assert_subject = torus_math:decode_equality_config(<<"{"/utf8>>),
    _assert_subject@1 = {error, {invalid_json, <<"could not parse JSON"/utf8>>}},
    case _assert_subject =:= _assert_subject@1 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_equality_json_test"/utf8>>,
                function => <<"decoder_rejects_malformed_json_test"/utf8>>,
                line => 81,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject,
                    start => 2567,
                    'end' => 2605
                    },
                right => #{kind => literal,
                    value => _assert_subject@1,
                    start => 2613,
                    'end' => 2669
                    },
                start => 2560,
                'end' => 2669,
                expression_start => 2567})
    end.

-file("test/math_equality_json_test.gleam", 85).
-spec decoder_rejects_missing_required_fields_test() -> nil.
decoder_rejects_missing_required_fields_test() ->
    _assert_subject = torus_math:decode_equality_config(
        <<"{\"mode\":\"numeric\"}"/utf8>>
    ),
    _assert_subject@1 = {error, {missing_field, <<"version"/utf8>>}},
    case _assert_subject =:= _assert_subject@1 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_equality_json_test"/utf8>>,
                function => <<"decoder_rejects_missing_required_fields_test"/utf8>>,
                line => 86,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject,
                    start => 2738,
                    'end' => 2797
                    },
                right => #{kind => literal,
                    value => _assert_subject@1,
                    start => 2805,
                    'end' => 2848
                    },
                start => 2731,
                'end' => 2848,
                expression_start => 2738})
    end.

-file("test/math_equality_json_test.gleam", 90).
-spec decoder_rejects_bad_version_test() -> nil.
decoder_rejects_bad_version_test() ->
    _assert_subject = torus_math:decode_equality_config(
        <<"{\"version\":2,\"mode\":\"numeric\"}"/utf8>>
    ),
    _assert_subject@1 = {error, {unsupported_version, 2}},
    case _assert_subject =:= _assert_subject@1 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_equality_json_test"/utf8>>,
                function => <<"decoder_rejects_bad_version_test"/utf8>>,
                line => 91,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject,
                    start => 2905,
                    'end' => 2991
                    },
                right => #{kind => literal,
                    value => _assert_subject@1,
                    start => 2999,
                    'end' => 3042
                    },
                start => 2898,
                'end' => 3042,
                expression_start => 2905})
    end.

-file("test/math_equality_json_test.gleam", 97).
-spec decoder_rejects_unknown_discriminators_test() -> nil.
decoder_rejects_unknown_discriminators_test() ->
    Unknown_mode = <<"{\"version\":1,\"mode\":\"adaptive\"}"/utf8>>,
    Unknown_comparison = <<"{\"version\":1,\"mode\":\"numeric\",\"comparison\":{\"type\":\"adaptive_equal\",\"expected\":\"2\"},\"tolerance\":{\"type\":\"none\"},\"representation\":{\"type\":\"any\"},\"precision\":{\"type\":\"none\"}}"/utf8>>,
    _assert_subject = torus_math:decode_equality_config(Unknown_mode),
    _assert_subject@1 = {error,
        {unknown_discriminator, <<"mode"/utf8>>, <<"adaptive"/utf8>>}},
    case _assert_subject =:= _assert_subject@1 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_equality_json_test"/utf8>>,
                function => <<"decoder_rejects_unknown_discriminators_test"/utf8>>,
                line => 103,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject,
                    start => 3413,
                    'end' => 3460
                    },
                right => #{kind => literal,
                    value => _assert_subject@1,
                    start => 3468,
                    'end' => 3535
                    },
                start => 3406,
                'end' => 3535,
                expression_start => 3413})
    end,
    _assert_subject@2 = torus_math:decode_equality_config(Unknown_comparison),
    _assert_subject@3 = {error,
        {unknown_discriminator,
            <<"comparison.type"/utf8>>,
            <<"adaptive_equal"/utf8>>}},
    case _assert_subject@2 =:= _assert_subject@3 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_equality_json_test"/utf8>>,
                function => <<"decoder_rejects_unknown_discriminators_test"/utf8>>,
                line => 105,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject@2,
                    start => 3545,
                    'end' => 3598
                    },
                right => #{kind => literal,
                    value => _assert_subject@3,
                    start => 3606,
                    'end' => 3709
                    },
                start => 3538,
                'end' => 3709,
                expression_start => 3545})
    end.

-file("test/math_equality_json_test.gleam", 112).
-spec decoder_rejects_invalid_field_types_test() -> nil.
decoder_rejects_invalid_field_types_test() ->
    Invalid_expected = <<"{\"version\":1,\"mode\":\"numeric\",\"comparison\":{\"type\":\"equal\",\"expected\":2},\"tolerance\":{\"type\":\"none\"},\"representation\":{\"type\":\"any\"},\"precision\":{\"type\":\"none\"}}"/utf8>>,
    _assert_subject = torus_math:decode_equality_config(Invalid_expected),
    _assert_subject@1 = {error,
        {invalid_field, <<"expected"/utf8>>, <<"expected string"/utf8>>}},
    case _assert_subject =:= _assert_subject@1 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_equality_json_test"/utf8>>,
                function => <<"decoder_rejects_invalid_field_types_test"/utf8>>,
                line => 116,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject,
                    start => 4000,
                    'end' => 4051
                    },
                right => #{kind => literal,
                    value => _assert_subject@1,
                    start => 4059,
                    'end' => 4130
                    },
                start => 3993,
                'end' => 4130,
                expression_start => 4000})
    end.

-file("test/math_equality_json_test.gleam", 120).
-spec decoder_rejects_invalid_numeric_option_values_test() -> nil.
decoder_rejects_invalid_numeric_option_values_test() ->
    Negative_tolerance = <<"{\"version\":1,\"mode\":\"numeric\",\"comparison\":{\"type\":\"equal\",\"expected\":\"2\"},\"tolerance\":{\"type\":\"absolute\",\"value\":-0.1},\"representation\":{\"type\":\"any\"},\"precision\":{\"type\":\"none\"}}"/utf8>>,
    Zero_significant_figures = <<"{\"version\":1,\"mode\":\"numeric\",\"comparison\":{\"type\":\"equal\",\"expected\":\"2\"},\"tolerance\":{\"type\":\"none\"},\"representation\":{\"type\":\"any\"},\"precision\":{\"type\":\"legacy_significant_figures\",\"count\":0}}"/utf8>>,
    Negative_decimal_places = <<"{\"version\":1,\"mode\":\"numeric\",\"comparison\":{\"type\":\"equal\",\"expected\":\"2\"},\"tolerance\":{\"type\":\"none\"},\"representation\":{\"type\":\"any\"},\"precision\":{\"type\":\"decimal_places\",\"rule\":\"exactly\",\"count\":-1}}"/utf8>>,
    _assert_subject = torus_math:decode_equality_config(Negative_tolerance),
    _assert_subject@1 = {error,
        {invalid_field,
            <<"tolerance.value"/utf8>>,
            <<"expected non-negative float"/utf8>>}},
    case _assert_subject =:= _assert_subject@1 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_equality_json_test"/utf8>>,
                function => <<"decoder_rejects_invalid_numeric_option_values_test"/utf8>>,
                line => 130,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject,
                    start => 5009,
                    'end' => 5062
                    },
                right => #{kind => literal,
                    value => _assert_subject@1,
                    start => 5070,
                    'end' => 5179
                    },
                start => 5002,
                'end' => 5179,
                expression_start => 5009})
    end,
    _assert_subject@2 = torus_math:decode_equality_config(
        Zero_significant_figures
    ),
    _assert_subject@3 = {error,
        {invalid_field,
            <<"precision.count"/utf8>>,
            <<"expected positive integer"/utf8>>}},
    case _assert_subject@2 =:= _assert_subject@3 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_equality_json_test"/utf8>>,
                function => <<"decoder_rejects_invalid_numeric_option_values_test"/utf8>>,
                line => 135,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject@2,
                    start => 5189,
                    'end' => 5248
                    },
                right => #{kind => literal,
                    value => _assert_subject@3,
                    start => 5256,
                    'end' => 5363
                    },
                start => 5182,
                'end' => 5363,
                expression_start => 5189})
    end,
    _assert_subject@4 = torus_math:decode_equality_config(
        Negative_decimal_places
    ),
    _assert_subject@5 = {error,
        {invalid_field,
            <<"precision.count"/utf8>>,
            <<"expected non-negative integer"/utf8>>}},
    case _assert_subject@4 =:= _assert_subject@5 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_equality_json_test"/utf8>>,
                function => <<"decoder_rejects_invalid_numeric_option_values_test"/utf8>>,
                line => 140,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject@4,
                    start => 5373,
                    'end' => 5431
                    },
                right => #{kind => literal,
                    value => _assert_subject@5,
                    start => 5439,
                    'end' => 5550
                    },
                start => 5366,
                'end' => 5550,
                expression_start => 5373})
    end.
