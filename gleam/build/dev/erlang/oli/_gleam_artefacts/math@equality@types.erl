-module(math@equality@types).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/math/equality/types.gleam").
-export([numeric_input/1, default_numeric_options/1]).
-export_type([equality_spec/0, equality_mode/0, numeric_spec/0, numeric_input/0, numeric_comparison/0, range_bounds/0, numeric_tolerance/0, numeric_representation/0, numeric_precision/0, decimal_place_rule/0, expression_spec/0, expression_comparison/0, expression_validation/0, variable_domain/0, sampling_config/0, unit_spec/0, unit_comparison/0, unit_policy/0, equality_config_error/0, equality_result/0, unsupported_evaluation_mode/0, equality_diagnostic/0]).

-if(?OTP_RELEASE >= 27).
-define(MODULEDOC(Str), -moduledoc(Str)).
-define(DOC(Str), -doc(Str)).
-else.
-define(MODULEDOC(Str), -compile([])).
-define(DOC(Str), -compile([])).
-endif.

-type equality_spec() :: {equality_spec, integer(), equality_mode()}.

-type equality_mode() :: {numeric, numeric_spec()} |
    {expression, expression_spec()} |
    {unit_aware, unit_spec()}.

-type numeric_spec() :: {numeric_spec,
        numeric_comparison(),
        numeric_tolerance(),
        numeric_representation(),
        numeric_precision()}.

-type numeric_input() :: {numeric_input, binary()}.

-type numeric_comparison() :: {equal, numeric_input()} |
    {not_equal, numeric_input()} |
    {greater_than, numeric_input()} |
    {greater_than_or_equal, numeric_input()} |
    {less_than, numeric_input()} |
    {less_than_or_equal, numeric_input()} |
    {between, numeric_input(), numeric_input(), range_bounds()} |
    {not_between, numeric_input(), numeric_input(), range_bounds()}.

-type range_bounds() :: inclusive | exclusive.

-type numeric_tolerance() :: no_tolerance |
    {absolute_tolerance, float()} |
    {relative_tolerance, float()} |
    {absolute_or_relative_tolerance, float(), float()}.

-type numeric_representation() :: any_representation |
    integer_representation |
    decimal_representation |
    scientific_representation.

-type numeric_precision() :: no_precision |
    {legacy_significant_figures, integer()} |
    {decimal_places, decimal_place_rule(), integer()}.

-type decimal_place_rule() :: exactly | at_least | at_most.

-type expression_spec() :: {expression_spec,
        expression_comparison(),
        expression_validation()}.

-type expression_comparison() :: {exact_expression, binary()} |
    {algebraic_equivalence, binary(), sampling_config()}.

-type expression_validation() :: {expression_validation,
        list(binary()),
        list(math@ast:function_name()),
        list(variable_domain())}.

-type variable_domain() :: {variable_domain, binary(), float(), float()}.

-type sampling_config() :: {sampling_config, integer(), integer()}.

-type unit_spec() :: {unit_spec, unit_comparison(), unit_policy()}.

-type unit_comparison() :: {unit_numeric, numeric_input(), binary()} |
    {unit_expression, binary(), binary()}.

-type unit_policy() :: units_ignored |
    units_required |
    {accepted_units, list(binary())} |
    {strict_unit, binary()} |
    {convertible_units, list(binary())}.

-type equality_config_error() :: {unsupported_version, integer()} |
    {invalid_json, binary()} |
    {missing_field, binary()} |
    {unknown_discriminator, binary(), binary()} |
    {invalid_field, binary(), binary()}.

-type equality_result() :: {equality_matched, list(equality_diagnostic())} |
    {equality_not_matched, list(equality_diagnostic())} |
    {invalid_config, equality_config_error()} |
    {invalid_submitted_answer, list(equality_diagnostic())} |
    {unsupported_mode, unsupported_evaluation_mode()}.

-type unsupported_evaluation_mode() :: numeric_evaluation |
    expression_evaluation |
    unit_aware_evaluation.

-type equality_diagnostic() :: config_accepted |
    evaluation_not_implemented |
    adaptive_evaluation_excluded |
    numeric_parse_failure |
    numeric_value_mismatch |
    numeric_range_mismatch |
    numeric_tolerance_mismatch |
    numeric_representation_mismatch |
    numeric_precision_mismatch |
    numeric_comparison_matched.

-file("src/math/equality/types.gleam", 222).
?DOC(
    " This helper keeps ordinary numeric string construction concise in tests and\n"
    " future fixtures while preserving the design choice that numeric expected\n"
    " answers stay in raw string form until numeric evaluation parses them.\n"
).
-spec numeric_input(binary()) -> numeric_input().
numeric_input(Raw) ->
    {numeric_input, Raw}.

-file("src/math/equality/types.gleam", 228).
?DOC(
    " The default numeric options encode the authoring intent of \"plain numeric\n"
    " comparison\" without tolerance, representation, or precision constraints.\n"
).
-spec default_numeric_options(numeric_comparison()) -> numeric_spec().
default_numeric_options(Comparison) ->
    {numeric_spec, Comparison, no_tolerance, any_representation, no_precision}.
