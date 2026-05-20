-module(math@equality@numeric).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/math/equality/numeric.gleam").
-export([evaluate/2]).

-if(?OTP_RELEASE >= 27).
-define(MODULEDOC(Str), -moduledoc(Str)).
-define(DOC(Str), -doc(Str)).
-else.
-define(MODULEDOC(Str), -compile([])).
-define(DOC(Str), -compile([])).
-endif.

-file("src/math/equality/numeric.gleam", 617).
?DOC(
    " Convert collected diagnostics into the public equality outcome. A successful\n"
    " result carries a stable numeric-match diagnostic so tests and preview tooling\n"
    " can identify the evaluator layer that made the decision.\n"
).
-spec finalize(list(math@equality@types:equality_diagnostic())) -> math@equality@types:equality_result().
finalize(Diagnostics) ->
    case Diagnostics of
        [] ->
            {equality_matched, [numeric_comparison_matched]};

        _ ->
            {equality_not_matched, Diagnostics}
    end.

-file("src/math/equality/numeric.gleam", 444).
?DOC(
    " Scientific precision checks only look at the mantissa, matching the current\n"
    " `#precision` behavior where exponent digits are not significant figures.\n"
).
-spec mantissa_part(binary()) -> binary().
mantissa_part(Submitted) ->
    case gleam@string:split_once(
        gleam@string:replace(Submitted, <<"E"/utf8>>, <<"e"/utf8>>),
        <<"e"/utf8>>
    ) of
        {ok, {Mantissa, _}} ->
            Mantissa;

        {error, nil} ->
            Submitted
    end.

-file("src/math/equality/numeric.gleam", 416).
?DOC(" Count decimal places from the mantissa so `1.20e3` has two decimal places.\n").
-spec decimal_places(binary()) -> integer().
decimal_places(Submitted) ->
    Mantissa = mantissa_part(Submitted),
    case gleam@string:split_once(Mantissa, <<"."/utf8>>) of
        {ok, {_, Fraction}} ->
            string:length(Fraction);

        {error, nil} ->
            0
    end.

-file("src/math/equality/numeric.gleam", 403).
?DOC(
    " Apply the new decimal-place rule family. Integers have zero decimal places,\n"
    " while scientific notation counts places in the mantissa.\n"
).
-spec decimal_place_rule_matches(
    integer(),
    math@equality@types:decimal_place_rule(),
    integer()
) -> boolean().
decimal_place_rule_matches(Actual, Rule, Expected) ->
    case Rule of
        exactly ->
            Actual =:= Expected;

        at_least ->
            Actual >= Expected;

        at_most ->
            Actual =< Expected
    end.

-file("src/math/equality/numeric.gleam", 516).
?DOC(
    " ASCII digit checks are enough here because Number input rule parsing uses\n"
    " ordinary ASCII numeric notation rather than localized digits.\n"
).
-spec is_digit(binary()) -> boolean().
is_digit(Char) ->
    case Char of
        <<"0"/utf8>> ->
            true;

        <<"1"/utf8>> ->
            true;

        <<"2"/utf8>> ->
            true;

        <<"3"/utf8>> ->
            true;

        <<"4"/utf8>> ->
            true;

        <<"5"/utf8>> ->
            true;

        <<"6"/utf8>> ->
            true;

        <<"7"/utf8>> ->
            true;

        <<"8"/utf8>> ->
            true;

        <<"9"/utf8>> ->
            true;

        _ ->
            false
    end.

-file("src/math/equality/numeric.gleam", 524).
?DOC(" Non-zero digits drive placeholder-zero stripping for significant figures.\n").
-spec is_non_zero_digit(binary()) -> boolean().
is_non_zero_digit(Char) ->
    case Char of
        <<"1"/utf8>> ->
            true;

        <<"2"/utf8>> ->
            true;

        <<"3"/utf8>> ->
            true;

        <<"4"/utf8>> ->
            true;

        <<"5"/utf8>> ->
            true;

        <<"6"/utf8>> ->
            true;

        <<"7"/utf8>> ->
            true;

        <<"8"/utf8>> ->
            true;

        <<"9"/utf8>> ->
            true;

        _ ->
            false
    end.

-file("src/math/equality/numeric.gleam", 467).
?DOC(
    " Leading zeros before the first non-zero digit are placeholders. If the whole\n"
    " mantissa is zero, keep the zeros so `0.0` still has two significant figures,\n"
    " matching the legacy edge-case behavior.\n"
).
-spec drop_leading_placeholder_zeros(list(binary())) -> list(binary()).
drop_leading_placeholder_zeros(Chars) ->
    case Chars of
        [<<"0"/utf8>> | Rest] ->
            case gleam@list:any(Rest, fun is_non_zero_digit/1) of
                true ->
                    drop_leading_placeholder_zeros(Rest);

                false ->
                    Chars
            end;

        _ ->
            Chars
    end.

-file("src/math/equality/numeric.gleam", 494).
?DOC(
    " Drop zeros from the reversed integer until doing so would remove all\n"
    " significant digits. This preserves `0` as one significant figure.\n"
).
-spec drop_trailing_integer_zeroes(list(binary())) -> list(binary()).
drop_trailing_integer_zeroes(Chars) ->
    case Chars of
        [<<"0"/utf8>> | Rest] ->
            case gleam@list:any(Rest, fun is_non_zero_digit/1) of
                true ->
                    drop_trailing_integer_zeroes(Rest);

                false ->
                    Chars
            end;

        _ ->
            Chars
    end.

-file("src/math/equality/numeric.gleam", 481).
?DOC(
    " Integer trailing zeros after a non-zero digit are placeholders in legacy\n"
    " significant-figure mode, so `1200` has two significant figures.\n"
).
-spec strip_integer_trailing_zeros(binary()) -> binary().
strip_integer_trailing_zeros(Mantissa) ->
    Reversed = begin
        _pipe = Mantissa,
        _pipe@1 = gleam@string:to_graphemes(_pipe),
        _pipe@2 = lists:reverse(_pipe@1),
        _pipe@3 = drop_trailing_integer_zeroes(_pipe@2),
        lists:reverse(_pipe@3)
    end,
    gleam@string:join(Reversed, <<""/utf8>>).

-file("src/math/equality/numeric.gleam", 455).
?DOC(
    " Remove an optional sign before representation or precision checks so signs do\n"
    " not count as digits and do not block leading-zero normalization.\n"
).
-spec strip_sign(binary()) -> binary().
strip_sign(Submitted) ->
    case gleam_stdlib:string_starts_with(Submitted, <<"-"/utf8>>) orelse gleam_stdlib:string_starts_with(
        Submitted,
        <<"+"/utf8>>
    ) of
        true ->
            gleam@string:drop_start(Submitted, 1);

        false ->
            Submitted
    end.

-file("src/math/equality/numeric.gleam", 428).
?DOC(
    " Count significant figures using the legacy Torus intent: ignore exponent,\n"
    " ignore a sign, ignore leading placeholder zeros, and ignore trailing integer\n"
    " zeros unless a decimal point makes them significant.\n"
).
-spec significant_figures(binary()) -> integer().
significant_figures(Submitted) ->
    Mantissa = begin
        _pipe = Submitted,
        _pipe@1 = mantissa_part(_pipe),
        strip_sign(_pipe@1)
    end,
    Normalized = case gleam_stdlib:contains_string(Mantissa, <<"."/utf8>>) of
        true ->
            Mantissa;

        false ->
            strip_integer_trailing_zeros(Mantissa)
    end,
    _pipe@2 = Normalized,
    _pipe@3 = gleam@string:replace(_pipe@2, <<"."/utf8>>, <<""/utf8>>),
    _pipe@4 = gleam@string:to_graphemes(_pipe@3),
    _pipe@5 = drop_leading_placeholder_zeros(_pipe@4),
    gleam@list:count(_pipe@5, fun is_digit/1).

-file("src/math/equality/numeric.gleam", 388).
?DOC(
    " Dispatch precision families without conflating them. This is deliberately\n"
    " not inferred from representation because scientific notation and decimals can\n"
    " both carry either significant figures or decimal-place requirements.\n"
).
-spec precision_matches(binary(), math@equality@types:numeric_precision()) -> boolean().
precision_matches(Submitted, Precision) ->
    case Precision of
        no_precision ->
            true;

        {legacy_significant_figures, Count} ->
            significant_figures(Submitted) =:= Count;

        {decimal_places, Rule, Count@1} ->
            decimal_place_rule_matches(decimal_places(Submitted), Rule, Count@1)
    end.

-file("src/math/equality/numeric.gleam", 375).
?DOC(
    " Precision constraints are submitted-form checks. Significant figures preserve\n"
    " legacy `#precision` intent, while decimal places are the new explicit author\n"
    " control and must remain separate.\n"
).
-spec precision_diagnostics(binary(), math@equality@types:numeric_precision()) -> list(math@equality@types:equality_diagnostic()).
precision_diagnostics(Submitted, Precision) ->
    case precision_matches(gleam@string:trim(Submitted), Precision) of
        true ->
            [];

        false ->
            [numeric_precision_mismatch]
    end.

-file("src/math/equality/numeric.gleam", 367).
?DOC(
    " Scientific representation is intentionally marker-based after parse success:\n"
    " both `e` and `E` are accepted because current Number input parsing accepts\n"
    " both forms.\n"
).
-spec is_scientific_form(binary()) -> boolean().
is_scientific_form(Submitted) ->
    gleam_stdlib:contains_string(Submitted, <<"e"/utf8>>) orelse gleam_stdlib:contains_string(
        Submitted,
        <<"E"/utf8>>
    ).

-file("src/math/equality/numeric.gleam", 358).
?DOC(
    " Decimal representation requires a decimal point in the mantissa and excludes\n"
    " scientific notation so authors can distinguish `42.0` from `4.20e1`.\n"
).
-spec is_decimal_form(binary()) -> boolean().
is_decimal_form(Submitted) ->
    (gleam_stdlib:contains_string(Submitted, <<"."/utf8>>) andalso not gleam_stdlib:contains_string(
        Submitted,
        <<"e"/utf8>>
    ))
    andalso not gleam_stdlib:contains_string(Submitted, <<"E"/utf8>>).

-file("src/math/equality/numeric.gleam", 507).
?DOC(" Check a sign-stripped string for ordinary integer digits.\n").
-spec all_digits(binary()) -> boolean().
all_digits(Value) ->
    case gleam@string:to_graphemes(Value) of
        [] ->
            false;

        Chars ->
            gleam@list:all(Chars, fun is_digit/1)
    end.

-file("src/math/equality/numeric.gleam", 569).
?DOC(
    " Decide whether to parse through the float parser. Scientific notation routes\n"
    " here even when the mantissa is an integer because the BEAM parser needs a\n"
    " lowercase `e` and decimal point normalization before it accepts the value.\n"
).
-spec looks_float_like(binary()) -> boolean().
looks_float_like(Raw) ->
    (gleam_stdlib:contains_string(Raw, <<"."/utf8>>) orelse gleam_stdlib:contains_string(
        Raw,
        <<"e"/utf8>>
    ))
    orelse gleam_stdlib:contains_string(Raw, <<"E"/utf8>>).

-file("src/math/equality/numeric.gleam", 352).
?DOC(
    " Integer representation means ordinary signed digits with no decimal point or\n"
    " exponent marker. A value like `42.0` can parse to the same number but remains\n"
    " a decimal form for authoring purposes.\n"
).
-spec is_integer_form(binary()) -> boolean().
is_integer_form(Submitted) ->
    not looks_float_like(Submitted) andalso all_digits(strip_sign(Submitted)).

-file("src/math/equality/numeric.gleam", 337).
?DOC(
    " Match only broad Number-input forms here. Parser-level syntax rules stay in\n"
    " the parser; this function answers the authoring question \"what form did the\n"
    " learner use for this scalar value?\"\n"
).
-spec representation_matches(
    binary(),
    math@equality@types:numeric_representation()
) -> boolean().
representation_matches(Submitted, Representation) ->
    case Representation of
        any_representation ->
            true;

        integer_representation ->
            is_integer_form(Submitted);

        decimal_representation ->
            is_decimal_form(Submitted);

        scientific_representation ->
            is_scientific_form(Submitted)
    end.

-file("src/math/equality/numeric.gleam", 322).
?DOC(
    " Representation constraints check the submitted text form after numeric parse\n"
    " succeeds. They are intentionally independent from value comparison so `42.0`\n"
    " can be a right value but wrong integer representation.\n"
).
-spec representation_diagnostics(
    binary(),
    math@equality@types:numeric_representation()
) -> list(math@equality@types:equality_diagnostic()).
representation_diagnostics(Submitted, Representation) ->
    Normalized = gleam@string:trim(Submitted),
    case representation_matches(Normalized, Representation) of
        true ->
            [];

        false ->
            [numeric_representation_mismatch]
    end.

-file("src/math/equality/numeric.gleam", 247).
?DOC(
    " Keep inversion explicit so `not between` remains the exact complement of the\n"
    " configured range, including boundary behavior chosen by the author.\n"
).
-spec apply_range_inversion(boolean(), boolean()) -> boolean().
apply_range_inversion(Inside, Inverted) ->
    case Inverted of
        true ->
            case Inside of
                true ->
                    false;

                false ->
                    true
            end;

        false ->
            Inside
    end.

-file("src/math/equality/numeric.gleam", 262).
?DOC(
    " Apply the author-selected boundary policy. Inclusive and exclusive are typed\n"
    " because the legacy rule string encoded this with brackets, which would be too\n"
    " easy to lose in a free-form string config.\n"
).
-spec within_bounds(
    float(),
    float(),
    float(),
    math@equality@types:range_bounds()
) -> boolean().
within_bounds(Value, Lower, Upper, Bounds) ->
    case Bounds of
        inclusive ->
            (Lower =< Value) andalso (Value =< Upper);

        exclusive ->
            (Lower < Value) andalso (Value < Upper)
    end.

-file("src/math/equality/numeric.gleam", 578).
?DOC(
    " Normalize only the parse input for runtime compatibility. Raw authored and\n"
    " submitted strings stay internal to representation and precision checks rather\n"
    " than being emitted in public diagnostics.\n"
).
-spec normalize_scientific(binary()) -> binary().
normalize_scientific(Raw) ->
    Normalized_marker = gleam@string:replace(Raw, <<"E"/utf8>>, <<"e"/utf8>>),
    case gleam_stdlib:contains_string(Normalized_marker, <<"e"/utf8>>) of
        false ->
            Normalized_marker;

        true ->
            case gleam_stdlib:contains_string(Normalized_marker, <<"."/utf8>>) of
                true ->
                    Normalized_marker;

                false ->
                    case gleam@string:split_once(
                        Normalized_marker,
                        <<"e"/utf8>>
                    ) of
                        {ok, {Mantissa, Exponent}} ->
                            <<<<Mantissa/binary, ".0e"/utf8>>/binary,
                                Exponent/binary>>;

                        {error, nil} ->
                            Normalized_marker
                    end
            end
    end.

-file("src/math/equality/numeric.gleam", 551).
?DOC(
    " Leading decimals such as `.5` and `-.5` are accepted by current Number input\n"
    " comparison rules even though the expression lexer rejects them today. Keep\n"
    " that compatibility at the numeric evaluator boundary.\n"
).
-spec normalize_leading_decimal(binary()) -> binary().
normalize_leading_decimal(Raw) ->
    case gleam_stdlib:string_starts_with(Raw, <<"."/utf8>>) of
        true ->
            <<"0"/utf8, Raw/binary>>;

        false ->
            case gleam_stdlib:string_starts_with(Raw, <<"-."/utf8>>) of
                true ->
                    <<"-0."/utf8, (gleam@string:drop_start(Raw, 2))/binary>>;

                false ->
                    case gleam_stdlib:string_starts_with(Raw, <<"+."/utf8>>) of
                        true ->
                            <<"+0."/utf8,
                                (gleam@string:drop_start(Raw, 2))/binary>>;

                        false ->
                            Raw
                    end
            end
    end.

-file("src/math/equality/numeric.gleam", 535).
?DOC(
    " Parse numeric strings in the same scalar family as Number input response\n"
    " rules: integers, decimals, leading-decimal values, negatives, and scientific\n"
    " notation. This intentionally does not call the expression parser, because\n"
    " `2+2` should not become a Number input scalar.\n"
).
-spec parse_number(binary()) -> {ok, float()} | {error, nil}.
parse_number(Raw) ->
    Normalized = begin
        _pipe = Raw,
        _pipe@1 = gleam@string:trim(_pipe),
        normalize_leading_decimal(_pipe@1)
    end,
    case looks_float_like(Normalized) of
        true ->
            _pipe@2 = Normalized,
            _pipe@3 = normalize_scientific(_pipe@2),
            gleam_stdlib:parse_float(_pipe@3);

        false ->
            case gleam_stdlib:parse_int(Normalized) of
                {ok, Value} ->
                    {ok, erlang:float(Value)};

                {error, nil} ->
                    {error, nil}
            end
    end.

-file("src/math/equality/numeric.gleam", 597).
?DOC(
    " Parse configured numeric values with field-specific errors so JSON configs\n"
    " can point authors and migration tooling at the exact invalid parameter.\n"
).
-spec parse_config_number(math@equality@types:numeric_input(), binary()) -> {ok,
        float()} |
    {error, math@equality@types:equality_config_error()}.
parse_config_number(Input, Field) ->
    case Input of
        {numeric_input, Raw} ->
            case parse_number(Raw) of
                {ok, Value} ->
                    {ok, Value};

                {error, nil} ->
                    {error,
                        {invalid_field,
                            Field,
                            <<"expected numeric string"/utf8>>}}
            end
    end.

-file("src/math/equality/numeric.gleam", 218).
?DOC(
    " Evaluate inclusive or exclusive ranges after normalizing bound order. Current\n"
    " standard numeric rules allow dynamic values to arrive in either order, so the\n"
    " new contract preserves that min/max behavior instead of making authors sort\n"
    " bounds themselves.\n"
).
-spec evaluate_range(
    float(),
    math@equality@types:numeric_input(),
    math@equality@types:numeric_input(),
    math@equality@types:range_bounds(),
    boolean()
) -> {ok, list(math@equality@types:equality_diagnostic())} |
    {error, math@equality@types:equality_config_error()}.
evaluate_range(Submitted_value, Lower_input, Upper_input, Bounds, Inverted) ->
    case parse_config_number(Lower_input, <<"comparison.lower"/utf8>>) of
        {error, Error} ->
            {error, Error};

        {ok, Lower} ->
            case parse_config_number(Upper_input, <<"comparison.upper"/utf8>>) of
                {error, Error@1} ->
                    {error, Error@1};

                {ok, Upper} ->
                    Lower_bound = gleam@float:min(Lower, Upper),
                    Upper_bound = gleam@float:max(Lower, Upper),
                    Inside = within_bounds(
                        Submitted_value,
                        Lower_bound,
                        Upper_bound,
                        Bounds
                    ),
                    case apply_range_inversion(Inside, Inverted) of
                        true ->
                            {ok, []};

                        false ->
                            {ok, [numeric_range_mismatch]}
                    end
            end
    end.

-file("src/math/equality/numeric.gleam", 199).
?DOC(
    " Ordered comparisons parse their configured threshold and return scalar value\n"
    " mismatch diagnostics. Tolerance is intentionally not read here because there\n"
    " is no legacy standard-rule meaning for \"greater than within tolerance\".\n"
).
-spec evaluate_ordered_scalar(
    float(),
    math@equality@types:numeric_input(),
    fun((float(), float()) -> boolean())
) -> {ok, list(math@equality@types:equality_diagnostic())} |
    {error, math@equality@types:equality_config_error()}.
evaluate_ordered_scalar(Submitted_value, Threshold_input, Predicate) ->
    case parse_config_number(Threshold_input, <<"comparison.threshold"/utf8>>) of
        {error, Error} ->
            {error, Error};

        {ok, Threshold_value} ->
            case Predicate(Submitted_value, Threshold_value) of
                true ->
                    {ok, []};

                false ->
                    {ok, [numeric_value_mismatch]}
            end
    end.

-file("src/math/equality/numeric.gleam", 298).
?DOC(
    " Use the tolerance diagnostic only when a tolerance was part of the author\n"
    " config; otherwise a failed equality is an ordinary value mismatch.\n"
).
-spec equality_mismatch_diagnostic(math@equality@types:numeric_tolerance()) -> math@equality@types:equality_diagnostic().
equality_mismatch_diagnostic(Tolerance) ->
    case Tolerance of
        no_tolerance ->
            numeric_value_mismatch;

        _ ->
            numeric_tolerance_mismatch
    end.

-file("src/math/equality/numeric.gleam", 315).
?DOC(
    " Relative tolerance uses the larger magnitude as the reference, matching the\n"
    " current Elixir rule behavior for standard Number input equality.\n"
).
-spec relative_window(float(), float(), float()) -> float().
relative_window(Left, Right, Relative) ->
    Relative * gleam@float:max(
        gleam@float:absolute_value(Left),
        gleam@float:absolute_value(Right)
    ).

-file("src/math/equality/numeric.gleam", 309).
?DOC(
    " Keep absolute-difference math in one helper so future target-specific float\n"
    " decisions have one place to change.\n"
).
-spec absolute_difference(float(), float()) -> float().
absolute_difference(Left, Right) ->
    gleam@float:absolute_value(Left - Right).

-file("src/math/equality/numeric.gleam", 277).
?DOC(
    " Apply the configured equality tolerance. Relative tolerance follows the\n"
    " legacy Torus rule of scaling by the larger magnitude so near-zero values do\n"
    " not get a large implicit window.\n"
).
-spec values_equal(float(), float(), math@equality@types:numeric_tolerance()) -> boolean().
values_equal(Submitted_value, Expected_value, Tolerance) ->
    case Tolerance of
        no_tolerance ->
            Submitted_value =:= Expected_value;

        {absolute_tolerance, Value} ->
            absolute_difference(Submitted_value, Expected_value) =< Value;

        {relative_tolerance, Value@1} ->
            absolute_difference(Submitted_value, Expected_value) =< relative_window(
                Submitted_value,
                Expected_value,
                Value@1
            );

        {absolute_or_relative_tolerance, Absolute, Relative} ->
            (absolute_difference(Submitted_value, Expected_value) =< Absolute)
            orelse (absolute_difference(Submitted_value, Expected_value) =< relative_window(
                Submitted_value,
                Expected_value,
                Relative
            ))
    end.

-file("src/math/equality/numeric.gleam", 177).
?DOC(
    " Equality-style scalar comparisons are the only Phase 4 operators where\n"
    " tolerance changes value equality. Ordered and range comparisons keep their\n"
    " threshold semantics while still allowing representation and precision checks.\n"
).
-spec evaluate_equality_scalar(
    float(),
    math@equality@types:numeric_input(),
    math@equality@types:numeric_tolerance(),
    boolean()
) -> {ok, list(math@equality@types:equality_diagnostic())} |
    {error, math@equality@types:equality_config_error()}.
evaluate_equality_scalar(Submitted_value, Expected_input, Tolerance, Inverted) ->
    case parse_config_number(Expected_input, <<"comparison.expected"/utf8>>) of
        {error, Error} ->
            {error, Error};

        {ok, Expected_value} ->
            Equal = values_equal(Submitted_value, Expected_value, Tolerance),
            case apply_range_inversion(Equal, Inverted) of
                true ->
                    {ok, []};

                false ->
                    {ok, [equality_mismatch_diagnostic(Tolerance)]}
            end
    end.

-file("src/math/equality/numeric.gleam", 124).
?DOC(
    " Dispatch each standard numeric operator to a small comparison helper. The\n"
    " variants mirror the current response-rule operators and deliberately exclude\n"
    " adaptive-page numeric cases, which continue through AdaptivePartEvaluation.\n"
).
-spec comparison_diagnostics(
    math@equality@types:numeric_comparison(),
    float(),
    math@equality@types:numeric_tolerance()
) -> {ok, list(math@equality@types:equality_diagnostic())} |
    {error, math@equality@types:equality_config_error()}.
comparison_diagnostics(Comparison, Submitted_value, Tolerance) ->
    case Comparison of
        {equal, Expected} ->
            evaluate_equality_scalar(
                Submitted_value,
                Expected,
                Tolerance,
                false
            );

        {not_equal, Expected@1} ->
            evaluate_equality_scalar(
                Submitted_value,
                Expected@1,
                Tolerance,
                true
            );

        {greater_than, Threshold} ->
            evaluate_ordered_scalar(
                Submitted_value,
                Threshold,
                fun(Value, Threshold@1) -> Value > Threshold@1 end
            );

        {greater_than_or_equal, Threshold@2} ->
            evaluate_ordered_scalar(
                Submitted_value,
                Threshold@2,
                fun(Value@1, Threshold@3) -> Value@1 >= Threshold@3 end
            );

        {less_than, Threshold@4} ->
            evaluate_ordered_scalar(
                Submitted_value,
                Threshold@4,
                fun(Value@2, Threshold@5) -> Value@2 < Threshold@5 end
            );

        {less_than_or_equal, Threshold@6} ->
            evaluate_ordered_scalar(
                Submitted_value,
                Threshold@6,
                fun(Value@3, Threshold@7) -> Value@3 =< Threshold@7 end
            );

        {between, Lower, Upper, Bounds} ->
            evaluate_range(Submitted_value, Lower, Upper, Bounds, false);

        {not_between, Lower@1, Upper@1, Bounds@1} ->
            evaluate_range(Submitted_value, Lower@1, Upper@1, Bounds@1, true)
    end.

-file("src/math/equality/numeric.gleam", 101).
?DOC(
    " Evaluate the operator layer and the independent form constraints, preserving\n"
    " separate diagnostics so callers can distinguish \"wrong value\" from \"right\n"
    " value, wrong form\" without involving feedback selection.\n"
).
-spec evaluate_supported_spec(
    math@equality@types:numeric_spec(),
    binary(),
    float()
) -> math@equality@types:equality_result().
evaluate_supported_spec(Spec, Submitted, Submitted_value) ->
    case comparison_diagnostics(
        erlang:element(2, Spec),
        Submitted_value,
        erlang:element(3, Spec)
    ) of
        {error, Error} ->
            {invalid_config, Error};

        {ok, Comparison_diagnostics} ->
            Constraint_diagnostics = begin
                _pipe = Submitted,
                _pipe@1 = representation_diagnostics(
                    _pipe,
                    erlang:element(4, Spec)
                ),
                lists:append(
                    _pipe@1,
                    precision_diagnostics(Submitted, erlang:element(5, Spec))
                )
            end,
            finalize(
                lists:append(Comparison_diagnostics, Constraint_diagnostics)
            )
    end.

-file("src/math/equality/numeric.gleam", 72).
?DOC(
    " Precision counts are authored parameters. Significant figures cannot be zero,\n"
    " while decimal-place rules can validly require exactly zero places.\n"
).
-spec validate_precision(math@equality@types:numeric_precision()) -> {ok, nil} |
    {error, math@equality@types:equality_config_error()}.
validate_precision(Precision) ->
    case Precision of
        no_precision ->
            {ok, nil};

        {legacy_significant_figures, Count} ->
            case Count > 0 of
                true ->
                    {ok, nil};

                false ->
                    {error,
                        {invalid_field,
                            <<"precision.count"/utf8>>,
                            <<"expected positive integer"/utf8>>}}
            end;

        {decimal_places, _, Count@1} ->
            case Count@1 >= 0 of
                true ->
                    {ok, nil};

                false ->
                    {error,
                        {invalid_field,
                            <<"precision.count"/utf8>>,
                            <<"expected non-negative integer"/utf8>>}}
            end
    end.

-file("src/math/equality/numeric.gleam", 32).
?DOC(
    " Validate option parameters before reading the submitted answer so malformed\n"
    " author configuration always reports as config failure, not learner failure.\n"
    " JSON decoding catches shape errors; this protects hand-built Gleam specs too.\n"
).
-spec validate_numeric_options(math@equality@types:numeric_spec()) -> {ok, nil} |
    {error, math@equality@types:equality_config_error()}.
validate_numeric_options(Spec) ->
    case erlang:element(3, Spec) of
        no_tolerance ->
            validate_precision(erlang:element(5, Spec));

        {absolute_tolerance, Value} ->
            case Value >= +0.0 of
                true ->
                    validate_precision(erlang:element(5, Spec));

                false ->
                    {error,
                        {invalid_field,
                            <<"tolerance.value"/utf8>>,
                            <<"expected non-negative float"/utf8>>}}
            end;

        {relative_tolerance, Value@1} ->
            case Value@1 >= +0.0 of
                true ->
                    validate_precision(erlang:element(5, Spec));

                false ->
                    {error,
                        {invalid_field,
                            <<"tolerance.value"/utf8>>,
                            <<"expected non-negative float"/utf8>>}}
            end;

        {absolute_or_relative_tolerance, Absolute, Relative} ->
            case (Absolute >= +0.0) andalso (Relative >= +0.0) of
                true ->
                    validate_precision(erlang:element(5, Spec));

                false ->
                    {error,
                        {invalid_field,
                            <<"tolerance"/utf8>>,
                            <<"expected non-negative float values"/utf8>>}}
            end
    end.

-file("src/math/equality/numeric.gleam", 10).
?DOC(
    " Evaluate the standard/basic page numeric comparison family. This is kept out\n"
    " of the expression parser because Number inputs historically accept scalar\n"
    " numeric answers, not full math expressions with variables or operators.\n"
).
-spec evaluate(math@equality@types:numeric_spec(), binary()) -> math@equality@types:equality_result().
evaluate(Spec, Submitted) ->
    case validate_numeric_options(Spec) of
        {error, Error} ->
            {invalid_config, Error};

        {ok, nil} ->
            case parse_number(Submitted) of
                {error, nil} ->
                    {invalid_submitted_answer, [numeric_parse_failure]};

                {ok, Submitted_value} ->
                    evaluate_supported_spec(Spec, Submitted, Submitted_value)
            end
    end.
