-module(math_equality_parity_test).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "test/math_equality_parity_test.gleam").
-export([main/0, standard_numeric_operator_corpus_matches_legacy_rule_shapes_test/0, standard_numeric_operator_corpus_evaluates_positive_and_negative_cases_test/0, parity_corpus_covers_every_standard_numeric_operator_test/0, parity_edge_cases_cover_ranges_scientific_parse_and_precision_test/0, parity_corpus_excludes_adaptive_numeric_forms_test/0]).
-export_type([parity_case/0]).

-if(?OTP_RELEASE >= 27).
-define(MODULEDOC(Str), -moduledoc(Str)).
-define(DOC(Str), -doc(Str)).
-else.
-define(MODULEDOC(Str), -compile([])).
-define(DOC(Str), -compile([])).
-endif.

-type parity_case() :: {parity_case,
        binary(),
        binary(),
        math@equality@types:equality_spec(),
        binary(),
        binary(),
        math@equality@types:equality_diagnostic(),
        binary()}.

-file("test/math_equality_parity_test.gleam", 7).
-spec main() -> nil.
main() ->
    gleeunit:main().

-file("test/math_equality_parity_test.gleam", 228).
?DOC(
    " Construct numeric configs with explicit option layers. This keeps parity\n"
    " examples honest about when legacy behavior is encoded as tolerance or\n"
    " significant-figure config instead of being implicit evaluator behavior.\n"
).
-spec numeric_spec_with_options(
    math@equality@types:numeric_comparison(),
    math@equality@types:numeric_tolerance(),
    math@equality@types:numeric_representation(),
    math@equality@types:numeric_precision()
) -> math@equality@types:equality_spec().
numeric_spec_with_options(Comparison, Tolerance, Representation, Precision) ->
    {equality_spec,
        1,
        {numeric,
            {numeric_spec, Comparison, Tolerance, Representation, Precision}}}.

-file("test/math_equality_parity_test.gleam", 216).
?DOC(
    " Construct the common no-option numeric config used by legacy scalar and range\n"
    " rule cases. Legacy precision and float-tolerance cases use the explicit\n"
    " option helper so the compatibility choice is visible in the test.\n"
).
-spec numeric_spec(math@equality@types:numeric_comparison()) -> math@equality@types:equality_spec().
numeric_spec(Comparison) ->
    numeric_spec_with_options(
        Comparison,
        no_tolerance,
        any_representation,
        no_precision
    ).

-file("test/math_equality_parity_test.gleam", 124).
?DOC(
    " Build the executable parity corpus from the standard rule builders in\n"
    " `rules.ts`. `gte`, `lte`, `neq`, and `nbtw` have direct typed variants here\n"
    " even though legacy rule strings express them as OR or negation wrappers.\n"
).
-spec operator_corpus() -> list(parity_case()).
operator_corpus() ->
    [{parity_case,
            <<"eq"/utf8>>,
            <<"input = {2}"/utf8>>,
            numeric_spec(
                {equal, math@equality@types:numeric_input(<<"2"/utf8>>)}
            ),
            <<"2"/utf8>>,
            <<"3"/utf8>>,
            numeric_value_mismatch,
            <<"{\"version\":1,\"mode\":\"numeric\",\"comparison\":{\"type\":\"equal\",\"expected\":\"2\"},\"tolerance\":{\"type\":\"none\"},\"representation\":{\"type\":\"any\"},\"precision\":{\"type\":\"none\"}}"/utf8>>},
        {parity_case,
            <<"neq"/utf8>>,
            <<"(!(input = {2}))"/utf8>>,
            numeric_spec(
                {not_equal, math@equality@types:numeric_input(<<"2"/utf8>>)}
            ),
            <<"3"/utf8>>,
            <<"2"/utf8>>,
            numeric_value_mismatch,
            <<"{\"version\":1,\"mode\":\"numeric\",\"comparison\":{\"type\":\"not_equal\",\"expected\":\"2\"},\"tolerance\":{\"type\":\"none\"},\"representation\":{\"type\":\"any\"},\"precision\":{\"type\":\"none\"}}"/utf8>>},
        {parity_case,
            <<"gt"/utf8>>,
            <<"input > {2}"/utf8>>,
            numeric_spec(
                {greater_than, math@equality@types:numeric_input(<<"2"/utf8>>)}
            ),
            <<"3"/utf8>>,
            <<"2"/utf8>>,
            numeric_value_mismatch,
            <<"{\"version\":1,\"mode\":\"numeric\",\"comparison\":{\"type\":\"greater_than\",\"threshold\":\"2\"},\"tolerance\":{\"type\":\"none\"},\"representation\":{\"type\":\"any\"},\"precision\":{\"type\":\"none\"}}"/utf8>>},
        {parity_case,
            <<"gte"/utf8>>,
            <<"input = {2} || (input > {2})"/utf8>>,
            numeric_spec(
                {greater_than_or_equal,
                    math@equality@types:numeric_input(<<"2"/utf8>>)}
            ),
            <<"2"/utf8>>,
            <<"1"/utf8>>,
            numeric_value_mismatch,
            <<"{\"version\":1,\"mode\":\"numeric\",\"comparison\":{\"type\":\"greater_than_or_equal\",\"threshold\":\"2\"},\"tolerance\":{\"type\":\"none\"},\"representation\":{\"type\":\"any\"},\"precision\":{\"type\":\"none\"}}"/utf8>>},
        {parity_case,
            <<"lt"/utf8>>,
            <<"input < {2}"/utf8>>,
            numeric_spec(
                {less_than, math@equality@types:numeric_input(<<"2"/utf8>>)}
            ),
            <<"1"/utf8>>,
            <<"2"/utf8>>,
            numeric_value_mismatch,
            <<"{\"version\":1,\"mode\":\"numeric\",\"comparison\":{\"type\":\"less_than\",\"threshold\":\"2\"},\"tolerance\":{\"type\":\"none\"},\"representation\":{\"type\":\"any\"},\"precision\":{\"type\":\"none\"}}"/utf8>>},
        {parity_case,
            <<"lte"/utf8>>,
            <<"input = {2} || (input < {2})"/utf8>>,
            numeric_spec(
                {less_than_or_equal,
                    math@equality@types:numeric_input(<<"2"/utf8>>)}
            ),
            <<"2"/utf8>>,
            <<"3"/utf8>>,
            numeric_value_mismatch,
            <<"{\"version\":1,\"mode\":\"numeric\",\"comparison\":{\"type\":\"less_than_or_equal\",\"threshold\":\"2\"},\"tolerance\":{\"type\":\"none\"},\"representation\":{\"type\":\"any\"},\"precision\":{\"type\":\"none\"}}"/utf8>>},
        {parity_case,
            <<"btw"/utf8>>,
            <<"input = {[1,3]}"/utf8>>,
            numeric_spec(
                {between,
                    math@equality@types:numeric_input(<<"1"/utf8>>),
                    math@equality@types:numeric_input(<<"3"/utf8>>),
                    inclusive}
            ),
            <<"2"/utf8>>,
            <<"4"/utf8>>,
            numeric_range_mismatch,
            <<"{\"version\":1,\"mode\":\"numeric\",\"comparison\":{\"type\":\"between\",\"lower\":\"1\",\"upper\":\"3\",\"bounds\":\"inclusive\"},\"tolerance\":{\"type\":\"none\"},\"representation\":{\"type\":\"any\"},\"precision\":{\"type\":\"none\"}}"/utf8>>},
        {parity_case,
            <<"nbtw"/utf8>>,
            <<"(!(input = {[1,3]}))"/utf8>>,
            numeric_spec(
                {not_between,
                    math@equality@types:numeric_input(<<"1"/utf8>>),
                    math@equality@types:numeric_input(<<"3"/utf8>>),
                    inclusive}
            ),
            <<"4"/utf8>>,
            <<"2"/utf8>>,
            numeric_range_mismatch,
            <<"{\"version\":1,\"mode\":\"numeric\",\"comparison\":{\"type\":\"not_between\",\"lower\":\"1\",\"upper\":\"3\",\"bounds\":\"inclusive\"},\"tolerance\":{\"type\":\"none\"},\"representation\":{\"type\":\"any\"},\"precision\":{\"type\":\"none\"}}"/utf8>>}].

-file("test/math_equality_parity_test.gleam", 23).
-spec standard_numeric_operator_corpus_matches_legacy_rule_shapes_test() -> nil.
standard_numeric_operator_corpus_matches_legacy_rule_shapes_test() ->
    gleam@list:each(
        operator_corpus(),
        fun(Parity_case) ->
            _assert_subject = erlang:element(3, Parity_case),
            _assert_subject@1 = <<""/utf8>>,
            case _assert_subject /= _assert_subject@1 of
                true -> nil;
                false -> erlang:error(#{gleam_error => assert,
                        message => <<"Assertion failed."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"math_equality_parity_test"/utf8>>,
                        function => <<"standard_numeric_operator_corpus_matches_legacy_rule_shapes_test"/utf8>>,
                        line => 28,
                        kind => binary_operator,
                        operator => '!=',
                        left => #{kind => expression,
                            value => _assert_subject,
                            start => 728,
                            'end' => 751
                            },
                        right => #{kind => literal,
                            value => _assert_subject@1,
                            start => 755,
                            'end' => 757
                            },
                        start => 721,
                        'end' => 757,
                        expression_start => 728})
            end,
            _assert_subject@2 = begin
                _pipe = erlang:element(4, Parity_case),
                torus_math:encode_equality_config(_pipe)
            end,
            _assert_subject@3 = erlang:element(8, Parity_case),
            case _assert_subject@2 =:= _assert_subject@3 of
                true -> nil;
                false -> erlang:error(#{gleam_error => assert,
                        message => <<"Assertion failed."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"math_equality_parity_test"/utf8>>,
                        function => <<"standard_numeric_operator_corpus_matches_legacy_rule_shapes_test"/utf8>>,
                        line => 29,
                        kind => binary_operator,
                        operator => '==',
                        left => #{kind => expression,
                            value => _assert_subject@2,
                            start => 769,
                            'end' => 828
                            },
                        right => #{kind => expression,
                            value => _assert_subject@3,
                            start => 838,
                            'end' => 854
                            },
                        start => 762,
                        'end' => 854,
                        expression_start => 769})
            end
        end
    ).

-file("test/math_equality_parity_test.gleam", 245).
-spec matched() -> math@equality@types:equality_result().
matched() ->
    {equality_matched, [numeric_comparison_matched]}.

-file("test/math_equality_parity_test.gleam", 35).
-spec standard_numeric_operator_corpus_evaluates_positive_and_negative_cases_test(
    
) -> nil.
standard_numeric_operator_corpus_evaluates_positive_and_negative_cases_test() ->
    gleam@list:each(
        operator_corpus(),
        fun(Parity_case) ->
            _assert_subject = torus_math:evaluate_equality(
                erlang:element(4, Parity_case),
                erlang:element(5, Parity_case)
            ),
            _assert_subject@1 = matched(),
            case _assert_subject =:= _assert_subject@1 of
                true -> nil;
                false -> erlang:error(#{gleam_error => assert,
                        message => <<"Assertion failed."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"math_equality_parity_test"/utf8>>,
                        function => <<"standard_numeric_operator_corpus_evaluates_positive_and_negative_cases_test"/utf8>>,
                        line => 37,
                        kind => binary_operator,
                        operator => '==',
                        left => #{kind => expression,
                            value => _assert_subject,
                            start => 1010,
                            'end' => 1078
                            },
                        right => #{kind => expression,
                            value => _assert_subject@1,
                            start => 1088,
                            'end' => 1097
                            },
                        start => 1003,
                        'end' => 1097,
                        expression_start => 1010})
            end,
            _assert_subject@2 = torus_math:evaluate_equality(
                erlang:element(4, Parity_case),
                erlang:element(6, Parity_case)
            ),
            _assert_subject@3 = {equality_not_matched,
                [erlang:element(7, Parity_case)]},
            case _assert_subject@2 =:= _assert_subject@3 of
                true -> nil;
                false -> erlang:error(#{gleam_error => assert,
                        message => <<"Assertion failed."/utf8>>,
                        file => <<?FILEPATH/utf8>>,
                        module => <<"math_equality_parity_test"/utf8>>,
                        function => <<"standard_numeric_operator_corpus_evaluates_positive_and_negative_cases_test"/utf8>>,
                        line => 39,
                        kind => binary_operator,
                        operator => '==',
                        left => #{kind => expression,
                            value => _assert_subject@2,
                            start => 1109,
                            'end' => 1205
                            },
                        right => #{kind => expression,
                            value => _assert_subject@3,
                            start => 1215,
                            'end' => 1276
                            },
                        start => 1102,
                        'end' => 1276,
                        expression_start => 1109})
            end
        end
    ).

-file("test/math_equality_parity_test.gleam", 47).
-spec parity_corpus_covers_every_standard_numeric_operator_test() -> nil.
parity_corpus_covers_every_standard_numeric_operator_test() ->
    Operators = begin
        _pipe = operator_corpus(),
        gleam@list:map(
            _pipe,
            fun(Parity_case) -> erlang:element(2, Parity_case) end
        )
    end,
    _assert_subject = [<<"eq"/utf8>>,
        <<"neq"/utf8>>,
        <<"gt"/utf8>>,
        <<"gte"/utf8>>,
        <<"lt"/utf8>>,
        <<"lte"/utf8>>,
        <<"btw"/utf8>>,
        <<"nbtw"/utf8>>],
    case Operators =:= _assert_subject of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_equality_parity_test"/utf8>>,
                function => <<"parity_corpus_covers_every_standard_numeric_operator_test"/utf8>>,
                line => 51,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => Operators,
                    start => 1458,
                    'end' => 1467
                    },
                right => #{kind => literal,
                    value => _assert_subject,
                    start => 1471,
                    'end' => 1525
                    },
                start => 1451,
                'end' => 1525,
                expression_start => 1458})
    end.

-file("test/math_equality_parity_test.gleam", 54).
-spec parity_edge_cases_cover_ranges_scientific_parse_and_precision_test() -> nil.
parity_edge_cases_cover_ranges_scientific_parse_and_precision_test() ->
    Inclusive_range = numeric_spec(
        {between,
            math@equality@types:numeric_input(<<"1"/utf8>>),
            math@equality@types:numeric_input(<<"3"/utf8>>),
            inclusive}
    ),
    Exclusive_reversed_range = numeric_spec(
        {between,
            math@equality@types:numeric_input(<<"3"/utf8>>),
            math@equality@types:numeric_input(<<"1"/utf8>>),
            exclusive}
    ),
    Scientific_legacy_float_equality = numeric_spec_with_options(
        {equal, math@equality@types:numeric_input(<<"1.0e3"/utf8>>)},
        {relative_tolerance, 0.0000000001},
        any_representation,
        no_precision
    ),
    Legacy_precision = numeric_spec_with_options(
        {equal, math@equality@types:numeric_input(<<"1.20e3"/utf8>>)},
        no_tolerance,
        any_representation,
        {legacy_significant_figures, 3}
    ),
    _assert_subject = torus_math:evaluate_equality(
        Inclusive_range,
        <<"1"/utf8>>
    ),
    _assert_subject@1 = matched(),
    case _assert_subject =:= _assert_subject@1 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_equality_parity_test"/utf8>>,
                function => <<"parity_edge_cases_cover_ranges_scientific_parse_and_precision_test"/utf8>>,
                line => 85,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject,
                    start => 2444,
                    'end' => 2494
                    },
                right => #{kind => expression,
                    value => _assert_subject@1,
                    start => 2498,
                    'end' => 2507
                    },
                start => 2437,
                'end' => 2507,
                expression_start => 2444})
    end,
    _assert_subject@2 = torus_math:evaluate_equality(
        Exclusive_reversed_range,
        <<"2"/utf8>>
    ),
    _assert_subject@3 = matched(),
    case _assert_subject@2 =:= _assert_subject@3 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_equality_parity_test"/utf8>>,
                function => <<"parity_edge_cases_cover_ranges_scientific_parse_and_precision_test"/utf8>>,
                line => 86,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject@2,
                    start => 2517,
                    'end' => 2576
                    },
                right => #{kind => expression,
                    value => _assert_subject@3,
                    start => 2584,
                    'end' => 2593
                    },
                start => 2510,
                'end' => 2593,
                expression_start => 2517})
    end,
    _assert_subject@4 = torus_math:evaluate_equality(
        Exclusive_reversed_range,
        <<"1"/utf8>>
    ),
    _assert_subject@5 = {equality_not_matched, [numeric_range_mismatch]},
    case _assert_subject@4 =:= _assert_subject@5 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_equality_parity_test"/utf8>>,
                function => <<"parity_edge_cases_cover_ranges_scientific_parse_and_precision_test"/utf8>>,
                line => 88,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject@4,
                    start => 2603,
                    'end' => 2662
                    },
                right => #{kind => expression,
                    value => _assert_subject@5,
                    start => 2670,
                    'end' => 2737
                    },
                start => 2596,
                'end' => 2737,
                expression_start => 2603})
    end,
    _assert_subject@6 = torus_math:evaluate_equality(
        Scientific_legacy_float_equality,
        <<"1000"/utf8>>
    ),
    _assert_subject@7 = matched(),
    case _assert_subject@6 =:= _assert_subject@7 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_equality_parity_test"/utf8>>,
                function => <<"parity_edge_cases_cover_ranges_scientific_parse_and_precision_test"/utf8>>,
                line => 95,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject@6,
                    start => 3032,
                    'end' => 3102
                    },
                right => #{kind => expression,
                    value => _assert_subject@7,
                    start => 3110,
                    'end' => 3119
                    },
                start => 3025,
                'end' => 3119,
                expression_start => 3032})
    end,
    _assert_subject@8 = torus_math:evaluate_equality(
        Legacy_precision,
        <<"1.20e3"/utf8>>
    ),
    _assert_subject@9 = matched(),
    case _assert_subject@8 =:= _assert_subject@9 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_equality_parity_test"/utf8>>,
                function => <<"parity_edge_cases_cover_ranges_scientific_parse_and_precision_test"/utf8>>,
                line => 98,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject@8,
                    start => 3130,
                    'end' => 3186
                    },
                right => #{kind => expression,
                    value => _assert_subject@9,
                    start => 3190,
                    'end' => 3199
                    },
                start => 3123,
                'end' => 3199,
                expression_start => 3130})
    end,
    _assert_subject@10 = torus_math:evaluate_equality(
        Legacy_precision,
        <<"1.200e3"/utf8>>
    ),
    _assert_subject@11 = {equality_not_matched, [numeric_precision_mismatch]},
    case _assert_subject@10 =:= _assert_subject@11 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_equality_parity_test"/utf8>>,
                function => <<"parity_edge_cases_cover_ranges_scientific_parse_and_precision_test"/utf8>>,
                line => 99,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject@10,
                    start => 3209,
                    'end' => 3266
                    },
                right => #{kind => expression,
                    value => _assert_subject@11,
                    start => 3274,
                    'end' => 3345
                    },
                start => 3202,
                'end' => 3345,
                expression_start => 3209})
    end,
    _assert_subject@12 = torus_math:evaluate_equality(
        numeric_spec({equal, math@equality@types:numeric_input(<<"2"/utf8>>)}),
        <<"not numeric"/utf8>>
    ),
    _assert_subject@13 = {invalid_submitted_answer, [numeric_parse_failure]},
    case _assert_subject@12 =:= _assert_subject@13 of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_equality_parity_test"/utf8>>,
                function => <<"parity_edge_cases_cover_ranges_scientific_parse_and_precision_test"/utf8>>,
                line => 102,
                kind => binary_operator,
                operator => '==',
                left => #{kind => expression,
                    value => _assert_subject@12,
                    start => 3356,
                    'end' => 3481
                    },
                right => #{kind => expression,
                    value => _assert_subject@13,
                    start => 3489,
                    'end' => 3559
                    },
                start => 3349,
                'end' => 3559,
                expression_start => 3356})
    end.

-file("test/math_equality_parity_test.gleam", 109).
-spec parity_corpus_excludes_adaptive_numeric_forms_test() -> nil.
parity_corpus_excludes_adaptive_numeric_forms_test() ->
    Operator_names = begin
        _pipe = operator_corpus(),
        gleam@list:map(
            _pipe,
            fun(Parity_case) -> erlang:element(2, Parity_case) end
        )
    end,
    case not gleam@list:any(
        Operator_names,
        fun(Operator) ->
            gleam_stdlib:string_starts_with(Operator, <<"adaptive"/utf8>>)
        end
    ) of
        true -> nil;
        false -> erlang:error(#{gleam_error => assert,
                message => <<"Assertion failed."/utf8>>,
                file => <<?FILEPATH/utf8>>,
                module => <<"math_equality_parity_test"/utf8>>,
                function => <<"parity_corpus_excludes_adaptive_numeric_forms_test"/utf8>>,
                line => 116,
                kind => expression,
                expression => #{kind => expression,
                    value => false,
                    start => 3988,
                    'end' => 4094
                    },
                start => 3981,
                'end' => 4094,
                expression_start => 3988})
    end.
