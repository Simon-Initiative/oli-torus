-module(math@equality@json).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/math/equality/json.gleam").
-export([decode_equality_config/1, encode_equality_config/1]).

-if(?OTP_RELEASE >= 27).
-define(MODULEDOC(Str), -moduledoc(Str)).
-define(DOC(Str), -doc(Str)).
-else.
-define(MODULEDOC(Str), -compile([])).
-define(DOC(Str), -compile([])).
-endif.

-file("src/math/equality/json.gleam", 917).
-spec field_error(binary(), binary(), list(gleam@dynamic@decode:decode_error())) -> math@equality@types:equality_config_error().
field_error(Field, Expected, Errors) ->
    case gleam@list:any(
        Errors,
        fun(Error) -> erlang:element(3, Error) =:= <<"Nothing"/utf8>> end
    ) of
        true ->
            {missing_field, Field};

        false ->
            {invalid_field, Field, <<"expected "/utf8, Expected/binary>>}
    end.

-file("src/math/equality/json.gleam", 905).
?DOC(
    " All field reads go through `gleam/dynamic/decode` so JSON structure handling\n"
    " is delegated to the library while Torus still maps failures into stable\n"
    " equality-config error variants.\n"
).
-spec read_field(
    gleam@dynamic:dynamic_(),
    binary(),
    gleam@dynamic@decode:decoder(AFS),
    binary()
) -> {ok, AFS} | {error, math@equality@types:equality_config_error()}.
read_field(Dynamic, Field, Decoder, Expected) ->
    case gleam@dynamic@decode:run(
        Dynamic,
        gleam@dynamic@decode:field(
            Field,
            Decoder,
            fun gleam@dynamic@decode:success/1
        )
    ) of
        {ok, Value} ->
            {ok, Value};

        {error, Errors} ->
            {error, field_error(Field, Expected, Errors)}
    end.

-file("src/math/equality/json.gleam", 883).
-spec read_string_list(gleam@dynamic:dynamic_(), binary()) -> {ok,
        list(binary())} |
    {error, math@equality@types:equality_config_error()}.
read_string_list(Dynamic, Field) ->
    read_field(
        Dynamic,
        Field,
        gleam@dynamic@decode:list(
            {decoder, fun gleam@dynamic@decode:decode_string/1}
        ),
        <<"string array"/utf8>>
    ).

-file("src/math/equality/json.gleam", 840).
-spec decode_unit_list(
    gleam@dynamic:dynamic_(),
    fun((list(binary())) -> math@equality@types:unit_policy())
) -> {ok, math@equality@types:unit_policy()} |
    {error, math@equality@types:equality_config_error()}.
decode_unit_list(Dynamic, Constructor) ->
    case read_string_list(Dynamic, <<"units"/utf8>>) of
        {ok, Units} ->
            {ok, Constructor(Units)};

        {error, Error} ->
            {error, Error}
    end.

-file("src/math/equality/json.gleam", 857).
-spec read_string(gleam@dynamic:dynamic_(), binary()) -> {ok, binary()} |
    {error, math@equality@types:equality_config_error()}.
read_string(Dynamic, Field) ->
    read_field(
        Dynamic,
        Field,
        {decoder, fun gleam@dynamic@decode:decode_string/1},
        <<"string"/utf8>>
    ).

-file("src/math/equality/json.gleam", 818).
-spec decode_unit_policy(gleam@dynamic:dynamic_()) -> {ok,
        math@equality@types:unit_policy()} |
    {error, math@equality@types:equality_config_error()}.
decode_unit_policy(Dynamic) ->
    case read_string(Dynamic, <<"type"/utf8>>) of
        {error, Error} ->
            {error, Error};

        {ok, Kind} ->
            case Kind of
                <<"ignored"/utf8>> ->
                    {ok, units_ignored};

                <<"required"/utf8>> ->
                    {ok, units_required};

                <<"accepted_units"/utf8>> ->
                    decode_unit_list(
                        Dynamic,
                        fun(Field@0) -> {accepted_units, Field@0} end
                    );

                <<"strict_unit"/utf8>> ->
                    case read_string(Dynamic, <<"unit"/utf8>>) of
                        {ok, Unit} ->
                            {ok, {strict_unit, Unit}};

                        {error, Error@1} ->
                            {error, Error@1}
                    end;

                <<"convertible_units"/utf8>> ->
                    decode_unit_list(
                        Dynamic,
                        fun(Field@0) -> {convertible_units, Field@0} end
                    );

                Other ->
                    {error,
                        {unknown_discriminator, <<"policy.type"/utf8>>, Other}}
            end
    end.

-file("src/math/equality/json.gleam", 850).
-spec read_dynamic(gleam@dynamic:dynamic_(), binary()) -> {ok,
        gleam@dynamic:dynamic_()} |
    {error, math@equality@types:equality_config_error()}.
read_dynamic(Dynamic, Field) ->
    read_field(
        Dynamic,
        Field,
        {decoder, fun gleam@dynamic@decode:decode_dynamic/1},
        <<"value"/utf8>>
    ).

-file("src/math/equality/json.gleam", 776).
-spec decode_unit_comparison(gleam@dynamic:dynamic_()) -> {ok,
        math@equality@types:unit_comparison()} |
    {error, math@equality@types:equality_config_error()}.
decode_unit_comparison(Dynamic) ->
    case read_string(Dynamic, <<"type"/utf8>>) of
        {error, Error} ->
            {error, Error};

        {ok, Kind} ->
            case Kind of
                <<"unit_numeric"/utf8>> ->
                    case read_string(Dynamic, <<"expectedValue"/utf8>>) of
                        {error, Error@1} ->
                            {error, Error@1};

                        {ok, Expected_value} ->
                            case read_string(Dynamic, <<"expectedUnit"/utf8>>) of
                                {ok, Expected_unit} ->
                                    {ok,
                                        {unit_numeric,
                                            math@equality@types:numeric_input(
                                                Expected_value
                                            ),
                                            Expected_unit}};

                                {error, Error@2} ->
                                    {error, Error@2}
                            end
                    end;

                <<"unit_expression"/utf8>> ->
                    case read_string(Dynamic, <<"expectedExpression"/utf8>>) of
                        {error, Error@3} ->
                            {error, Error@3};

                        {ok, Expected_expression} ->
                            case read_string(Dynamic, <<"expectedUnit"/utf8>>) of
                                {ok, Expected_unit@1} ->
                                    {ok,
                                        {unit_expression,
                                            Expected_expression,
                                            Expected_unit@1}};

                                {error, Error@4} ->
                                    {error, Error@4}
                            end
                    end;

                Other ->
                    {error,
                        {unknown_discriminator,
                            <<"comparison.type"/utf8>>,
                            Other}}
            end
    end.

-file("src/math/equality/json.gleam", 747).
-spec decode_unit_spec(gleam@dynamic:dynamic_(), integer()) -> {ok,
        math@equality@types:equality_spec()} |
    {error, math@equality@types:equality_config_error()}.
decode_unit_spec(Dynamic, Version) ->
    case read_dynamic(Dynamic, <<"comparison"/utf8>>) of
        {error, Error} ->
            {error, Error};

        {ok, Comparison_dynamic} ->
            case decode_unit_comparison(Comparison_dynamic) of
                {error, Error@1} ->
                    {error, Error@1};

                {ok, Comparison} ->
                    case read_dynamic(Dynamic, <<"policy"/utf8>>) of
                        {error, Error@2} ->
                            {error, Error@2};

                        {ok, Policy_dynamic} ->
                            case decode_unit_policy(Policy_dynamic) of
                                {ok, Policy} ->
                                    {ok,
                                        {equality_spec,
                                            Version,
                                            {unit_aware,
                                                {unit_spec, Comparison, Policy}}}};

                                {error, Error@3} ->
                                    {error, Error@3}
                            end
                    end
            end
    end.

-file("src/math/equality/json.gleam", 871).
-spec read_float(gleam@dynamic:dynamic_(), binary()) -> {ok, float()} |
    {error, math@equality@types:equality_config_error()}.
read_float(Dynamic, Field) ->
    read_field(
        Dynamic,
        Field,
        gleam@dynamic@decode:one_of(
            {decoder, fun gleam@dynamic@decode:decode_float/1},
            [begin
                    _pipe = {decoder, fun gleam@dynamic@decode:decode_int/1},
                    gleam@dynamic@decode:map(_pipe, fun erlang:float/1)
                end]
        ),
        <<"number"/utf8>>
    ).

-file("src/math/equality/json.gleam", 729).
-spec decode_domain(gleam@dynamic:dynamic_()) -> {ok,
        math@equality@types:variable_domain()} |
    {error, math@equality@types:equality_config_error()}.
decode_domain(Dynamic) ->
    case read_string(Dynamic, <<"name"/utf8>>) of
        {error, Error} ->
            {error, Error};

        {ok, Name} ->
            case read_float(Dynamic, <<"lower"/utf8>>) of
                {error, Error@1} ->
                    {error, Error@1};

                {ok, Lower} ->
                    case read_float(Dynamic, <<"upper"/utf8>>) of
                        {ok, Upper} ->
                            {ok, {variable_domain, Name, Lower, Upper}};

                        {error, Error@2} ->
                            {error, Error@2}
                    end
            end
    end.

-file("src/math/equality/json.gleam", 715).
-spec decode_domains(
    list(gleam@dynamic:dynamic_()),
    list(math@equality@types:variable_domain())
) -> {ok, list(math@equality@types:variable_domain())} |
    {error, math@equality@types:equality_config_error()}.
decode_domains(Values, Acc) ->
    case Values of
        [] ->
            {ok, lists:reverse(Acc)};

        [First | Rest] ->
            case decode_domain(First) of
                {ok, Domain} ->
                    decode_domains(Rest, [Domain | Acc]);

                {error, Error} ->
                    {error, Error}
            end
    end.

-file("src/math/equality/json.gleam", 895).
-spec read_dynamic_list(gleam@dynamic:dynamic_(), binary()) -> {ok,
        list(gleam@dynamic:dynamic_())} |
    {error, math@equality@types:equality_config_error()}.
read_dynamic_list(Dynamic, Field) ->
    read_field(
        Dynamic,
        Field,
        gleam@dynamic@decode:list(
            {decoder, fun gleam@dynamic@decode:decode_dynamic/1}
        ),
        <<"array"/utf8>>
    ).

-file("src/math/equality/json.gleam", 981).
-spec function_from_string(binary()) -> {ok, math@ast:function_name()} |
    {error, math@equality@types:equality_config_error()}.
function_from_string(Raw) ->
    case Raw of
        <<"sin"/utf8>> ->
            {ok, sin};

        <<"cos"/utf8>> ->
            {ok, cos};

        <<"tan"/utf8>> ->
            {ok, tan};

        <<"ln"/utf8>> ->
            {ok, ln};

        <<"log"/utf8>> ->
            {ok, log};

        <<"log10"/utf8>> ->
            {ok, log10};

        <<"log2"/utf8>> ->
            {ok, log2};

        <<"sqrt"/utf8>> ->
            {ok, sqrt};

        <<"abs"/utf8>> ->
            {ok, abs};

        <<"exp"/utf8>> ->
            {ok, exp};

        Other ->
            {error,
                {unknown_discriminator, <<"allowedFunctions[]"/utf8>>, Other}}
    end.

-file("src/math/equality/json.gleam", 701).
-spec decode_functions_loop(list(binary()), list(math@ast:function_name())) -> {ok,
        list(math@ast:function_name())} |
    {error, math@equality@types:equality_config_error()}.
decode_functions_loop(Raw_functions, Acc) ->
    case Raw_functions of
        [] ->
            {ok, lists:reverse(Acc)};

        [First | Rest] ->
            case function_from_string(First) of
                {ok, Name} ->
                    decode_functions_loop(Rest, [Name | Acc]);

                {error, Error} ->
                    {error, Error}
            end
    end.

-file("src/math/equality/json.gleam", 695).
-spec decode_functions(list(binary())) -> {ok, list(math@ast:function_name())} |
    {error, math@equality@types:equality_config_error()}.
decode_functions(Raw_functions) ->
    decode_functions_loop(Raw_functions, []).

-file("src/math/equality/json.gleam", 665).
-spec decode_expression_validation(gleam@dynamic:dynamic_()) -> {ok,
        math@equality@types:expression_validation()} |
    {error, math@equality@types:equality_config_error()}.
decode_expression_validation(Dynamic) ->
    case read_string_list(Dynamic, <<"allowedVariables"/utf8>>) of
        {error, Error} ->
            {error, Error};

        {ok, Allowed_variables} ->
            case read_string_list(Dynamic, <<"allowedFunctions"/utf8>>) of
                {error, Error@1} ->
                    {error, Error@1};

                {ok, Raw_functions} ->
                    case decode_functions(Raw_functions) of
                        {error, Error@2} ->
                            {error, Error@2};

                        {ok, Allowed_functions} ->
                            case read_dynamic_list(Dynamic, <<"domains"/utf8>>) of
                                {error, Error@3} ->
                                    {error, Error@3};

                                {ok, Domain_values} ->
                                    case decode_domains(Domain_values, []) of
                                        {ok, Domains} ->
                                            {ok,
                                                {expression_validation,
                                                    Allowed_variables,
                                                    Allowed_functions,
                                                    Domains}};

                                        {error, Error@4} ->
                                            {error, Error@4}
                                    end
                            end
                    end
            end
    end.

-file("src/math/equality/json.gleam", 864).
-spec read_int(gleam@dynamic:dynamic_(), binary()) -> {ok, integer()} |
    {error, math@equality@types:equality_config_error()}.
read_int(Dynamic, Field) ->
    read_field(
        Dynamic,
        Field,
        {decoder, fun gleam@dynamic@decode:decode_int/1},
        <<"integer"/utf8>>
    ).

-file("src/math/equality/json.gleam", 651).
-spec decode_sampling(gleam@dynamic:dynamic_()) -> {ok,
        math@equality@types:sampling_config()} |
    {error, math@equality@types:equality_config_error()}.
decode_sampling(Dynamic) ->
    case read_int(Dynamic, <<"seed"/utf8>>) of
        {error, Error} ->
            {error, Error};

        {ok, Seed} ->
            case read_int(Dynamic, <<"sampleCount"/utf8>>) of
                {ok, Sample_count} ->
                    {ok, {sampling_config, Seed, Sample_count}};

                {error, Error@1} ->
                    {error, Error@1}
            end
    end.

-file("src/math/equality/json.gleam", 613).
-spec decode_expression_comparison(gleam@dynamic:dynamic_()) -> {ok,
        math@equality@types:expression_comparison()} |
    {error, math@equality@types:equality_config_error()}.
decode_expression_comparison(Dynamic) ->
    case read_string(Dynamic, <<"type"/utf8>>) of
        {error, Error} ->
            {error, Error};

        {ok, Kind} ->
            case Kind of
                <<"exact_expression"/utf8>> ->
                    case read_string(Dynamic, <<"expected"/utf8>>) of
                        {ok, Expected} ->
                            {ok, {exact_expression, Expected}};

                        {error, Error@1} ->
                            {error, Error@1}
                    end;

                <<"algebraic_equivalence"/utf8>> ->
                    case read_string(Dynamic, <<"expected"/utf8>>) of
                        {error, Error@2} ->
                            {error, Error@2};

                        {ok, Expected@1} ->
                            case read_dynamic(Dynamic, <<"sampling"/utf8>>) of
                                {error, Error@3} ->
                                    {error, Error@3};

                                {ok, Sampling_dynamic} ->
                                    case decode_sampling(Sampling_dynamic) of
                                        {ok, Sampling} ->
                                            {ok,
                                                {algebraic_equivalence,
                                                    Expected@1,
                                                    Sampling}};

                                        {error, Error@4} ->
                                            {error, Error@4}
                                    end
                            end
                    end;

                Other ->
                    {error,
                        {unknown_discriminator,
                            <<"comparison.type"/utf8>>,
                            Other}}
            end
    end.

-file("src/math/equality/json.gleam", 584).
-spec decode_expression_spec(gleam@dynamic:dynamic_(), integer()) -> {ok,
        math@equality@types:equality_spec()} |
    {error, math@equality@types:equality_config_error()}.
decode_expression_spec(Dynamic, Version) ->
    case read_dynamic(Dynamic, <<"comparison"/utf8>>) of
        {error, Error} ->
            {error, Error};

        {ok, Comparison_dynamic} ->
            case decode_expression_comparison(Comparison_dynamic) of
                {error, Error@1} ->
                    {error, Error@1};

                {ok, Comparison} ->
                    case read_dynamic(Dynamic, <<"validation"/utf8>>) of
                        {error, Error@2} ->
                            {error, Error@2};

                        {ok, Validation_dynamic} ->
                            case decode_expression_validation(
                                Validation_dynamic
                            ) of
                                {ok, Validation} ->
                                    {ok,
                                        {equality_spec,
                                            Version,
                                            {expression,
                                                {expression_spec,
                                                    Comparison,
                                                    Validation}}}};

                                {error, Error@3} ->
                                    {error, Error@3}
                            end
                    end
            end
    end.

-file("src/math/equality/json.gleam", 954).
-spec decimal_rule_from_string(binary()) -> {ok,
        math@equality@types:decimal_place_rule()} |
    {error, math@equality@types:equality_config_error()}.
decimal_rule_from_string(Rule) ->
    case Rule of
        <<"exactly"/utf8>> ->
            {ok, exactly};

        <<"at_least"/utf8>> ->
            {ok, at_least};

        <<"at_most"/utf8>> ->
            {ok, at_most};

        Other ->
            {error, {unknown_discriminator, <<"precision.rule"/utf8>>, Other}}
    end.

-file("src/math/equality/json.gleam", 558).
-spec decode_decimal_places(gleam@dynamic:dynamic_()) -> {ok,
        math@equality@types:numeric_precision()} |
    {error, math@equality@types:equality_config_error()}.
decode_decimal_places(Dynamic) ->
    case read_string(Dynamic, <<"rule"/utf8>>) of
        {error, Error} ->
            {error, Error};

        {ok, Rule} ->
            case decimal_rule_from_string(Rule) of
                {error, Error@1} ->
                    {error, Error@1};

                {ok, Decoded_rule} ->
                    case read_int(Dynamic, <<"count"/utf8>>) of
                        {ok, Count} ->
                            case Count >= 0 of
                                true ->
                                    {ok, {decimal_places, Decoded_rule, Count}};

                                false ->
                                    {error,
                                        {invalid_field,
                                            <<"precision.count"/utf8>>,
                                            <<"expected non-negative integer"/utf8>>}}
                            end;

                        {error, Error@2} ->
                            {error, Error@2}
                    end
            end
    end.

-file("src/math/equality/json.gleam", 523).
-spec decode_precision(gleam@dynamic:dynamic_()) -> {ok,
        math@equality@types:numeric_precision()} |
    {error, math@equality@types:equality_config_error()}.
decode_precision(Dynamic) ->
    case read_dynamic(Dynamic, <<"precision"/utf8>>) of
        {error, Error} ->
            {error, Error};

        {ok, Precision_dynamic} ->
            case read_string(Precision_dynamic, <<"type"/utf8>>) of
                {error, Error@1} ->
                    {error, Error@1};

                {ok, Kind} ->
                    case Kind of
                        <<"none"/utf8>> ->
                            {ok, no_precision};

                        <<"legacy_significant_figures"/utf8>> ->
                            case read_int(Precision_dynamic, <<"count"/utf8>>) of
                                {ok, Count} ->
                                    case Count > 0 of
                                        true ->
                                            {ok,
                                                {legacy_significant_figures,
                                                    Count}};

                                        false ->
                                            {error,
                                                {invalid_field,
                                                    <<"precision.count"/utf8>>,
                                                    <<"expected positive integer"/utf8>>}}
                                    end;

                                {error, Error@2} ->
                                    {error, Error@2}
                            end;

                        <<"decimal_places"/utf8>> ->
                            decode_decimal_places(Precision_dynamic);

                        Other ->
                            {error,
                                {unknown_discriminator,
                                    <<"precision.type"/utf8>>,
                                    Other}}
                    end
            end
    end.

-file("src/math/equality/json.gleam", 499).
-spec decode_representation(gleam@dynamic:dynamic_()) -> {ok,
        math@equality@types:numeric_representation()} |
    {error, math@equality@types:equality_config_error()}.
decode_representation(Dynamic) ->
    case read_dynamic(Dynamic, <<"representation"/utf8>>) of
        {error, Error} ->
            {error, Error};

        {ok, Representation_dynamic} ->
            case read_string(Representation_dynamic, <<"type"/utf8>>) of
                {error, Error@1} ->
                    {error, Error@1};

                {ok, Kind} ->
                    case Kind of
                        <<"any"/utf8>> ->
                            {ok, any_representation};

                        <<"integer"/utf8>> ->
                            {ok, integer_representation};

                        <<"decimal"/utf8>> ->
                            {ok, decimal_representation};

                        <<"scientific"/utf8>> ->
                            {ok, scientific_representation};

                        Other ->
                            {error,
                                {unknown_discriminator,
                                    <<"representation.type"/utf8>>,
                                    Other}}
                    end
            end
    end.

-file("src/math/equality/json.gleam", 455).
-spec decode_absolute_or_relative(gleam@dynamic:dynamic_()) -> {ok,
        math@equality@types:numeric_tolerance()} |
    {error, math@equality@types:equality_config_error()}.
decode_absolute_or_relative(Dynamic) ->
    case read_float(Dynamic, <<"absolute"/utf8>>) of
        {error, Error} ->
            {error, Error};

        {ok, Absolute} ->
            case read_float(Dynamic, <<"relative"/utf8>>) of
                {ok, Relative} ->
                    case (Absolute >= +0.0) andalso (Relative >= +0.0) of
                        true ->
                            {ok,
                                {absolute_or_relative_tolerance,
                                    Absolute,
                                    Relative}};

                        false ->
                            {error,
                                {invalid_field,
                                    <<"tolerance"/utf8>>,
                                    <<"expected non-negative float values"/utf8>>}}
                    end;

                {error, Error@1} ->
                    {error, Error@1}
            end
    end.

-file("src/math/equality/json.gleam", 480).
-spec decode_float_field(
    gleam@dynamic:dynamic_(),
    binary(),
    fun((float()) -> math@equality@types:numeric_tolerance())
) -> {ok, math@equality@types:numeric_tolerance()} |
    {error, math@equality@types:equality_config_error()}.
decode_float_field(Dynamic, Field, Constructor) ->
    case read_float(Dynamic, Field) of
        {ok, Value} ->
            case Value >= +0.0 of
                true ->
                    {ok, Constructor(Value)};

                false ->
                    {error,
                        {invalid_field,
                            <<"tolerance."/utf8, Field/binary>>,
                            <<"expected non-negative float"/utf8>>}}
            end;

        {error, Error} ->
            {error, Error}
    end.

-file("src/math/equality/json.gleam", 420).
-spec decode_tolerance(gleam@dynamic:dynamic_()) -> {ok,
        math@equality@types:numeric_tolerance()} |
    {error, math@equality@types:equality_config_error()}.
decode_tolerance(Dynamic) ->
    case read_dynamic(Dynamic, <<"tolerance"/utf8>>) of
        {error, Error} ->
            {error, Error};

        {ok, Tolerance_dynamic} ->
            case read_string(Tolerance_dynamic, <<"type"/utf8>>) of
                {error, Error@1} ->
                    {error, Error@1};

                {ok, Kind} ->
                    case Kind of
                        <<"none"/utf8>> ->
                            {ok, no_tolerance};

                        <<"absolute"/utf8>> ->
                            decode_float_field(
                                Tolerance_dynamic,
                                <<"value"/utf8>>,
                                fun(Field@0) -> {absolute_tolerance, Field@0} end
                            );

                        <<"relative"/utf8>> ->
                            decode_float_field(
                                Tolerance_dynamic,
                                <<"value"/utf8>>,
                                fun(Field@0) -> {relative_tolerance, Field@0} end
                            );

                        <<"absolute_or_relative"/utf8>> ->
                            decode_absolute_or_relative(Tolerance_dynamic);

                        Other ->
                            {error,
                                {unknown_discriminator,
                                    <<"tolerance.type"/utf8>>,
                                    Other}}
                    end
            end
    end.

-file("src/math/equality/json.gleam", 935).
-spec bounds_from_string(binary()) -> {ok, math@equality@types:range_bounds()} |
    {error, math@equality@types:equality_config_error()}.
bounds_from_string(Bounds) ->
    case Bounds of
        <<"inclusive"/utf8>> ->
            {ok, inclusive};

        <<"exclusive"/utf8>> ->
            {ok, exclusive};

        Other ->
            {error,
                {unknown_discriminator, <<"comparison.bounds"/utf8>>, Other}}
    end.

-file("src/math/equality/json.gleam", 392).
-spec decode_range(
    gleam@dynamic:dynamic_(),
    fun((math@equality@types:numeric_input(), math@equality@types:numeric_input(), math@equality@types:range_bounds()) -> math@equality@types:numeric_comparison())
) -> {ok, math@equality@types:numeric_comparison()} |
    {error, math@equality@types:equality_config_error()}.
decode_range(Dynamic, Constructor) ->
    case read_string(Dynamic, <<"lower"/utf8>>) of
        {error, Error} ->
            {error, Error};

        {ok, Lower} ->
            case read_string(Dynamic, <<"upper"/utf8>>) of
                {error, Error@1} ->
                    {error, Error@1};

                {ok, Upper} ->
                    case read_string(Dynamic, <<"bounds"/utf8>>) of
                        {error, Error@2} ->
                            {error, Error@2};

                        {ok, Bounds} ->
                            case bounds_from_string(Bounds) of
                                {ok, Decoded_bounds} ->
                                    {ok,
                                        Constructor(
                                            math@equality@types:numeric_input(
                                                Lower
                                            ),
                                            math@equality@types:numeric_input(
                                                Upper
                                            ),
                                            Decoded_bounds
                                        )};

                                {error, Error@3} ->
                                    {error, Error@3}
                            end
                    end
            end
    end.

-file("src/math/equality/json.gleam", 382).
-spec decode_threshold(
    gleam@dynamic:dynamic_(),
    fun((math@equality@types:numeric_input()) -> math@equality@types:numeric_comparison())
) -> {ok, math@equality@types:numeric_comparison()} |
    {error, math@equality@types:equality_config_error()}.
decode_threshold(Dynamic, Constructor) ->
    case read_string(Dynamic, <<"threshold"/utf8>>) of
        {ok, Raw} ->
            {ok, Constructor(math@equality@types:numeric_input(Raw))};

        {error, Error} ->
            {error, Error}
    end.

-file("src/math/equality/json.gleam", 372).
-spec decode_expected(
    gleam@dynamic:dynamic_(),
    fun((math@equality@types:numeric_input()) -> math@equality@types:numeric_comparison())
) -> {ok, math@equality@types:numeric_comparison()} |
    {error, math@equality@types:equality_config_error()}.
decode_expected(Dynamic, Constructor) ->
    case read_string(Dynamic, <<"expected"/utf8>>) of
        {ok, Raw} ->
            {ok, Constructor(math@equality@types:numeric_input(Raw))};

        {error, Error} ->
            {error, Error}
    end.

-file("src/math/equality/json.gleam", 347).
-spec decode_numeric_comparison(gleam@dynamic:dynamic_()) -> {ok,
        math@equality@types:numeric_comparison()} |
    {error, math@equality@types:equality_config_error()}.
decode_numeric_comparison(Dynamic) ->
    case read_string(Dynamic, <<"type"/utf8>>) of
        {error, Error} ->
            {error, Error};

        {ok, Kind} ->
            case Kind of
                <<"equal"/utf8>> ->
                    decode_expected(
                        Dynamic,
                        fun(Field@0) -> {equal, Field@0} end
                    );

                <<"not_equal"/utf8>> ->
                    decode_expected(
                        Dynamic,
                        fun(Field@0) -> {not_equal, Field@0} end
                    );

                <<"greater_than"/utf8>> ->
                    decode_threshold(
                        Dynamic,
                        fun(Field@0) -> {greater_than, Field@0} end
                    );

                <<"greater_than_or_equal"/utf8>> ->
                    decode_threshold(
                        Dynamic,
                        fun(Field@0) -> {greater_than_or_equal, Field@0} end
                    );

                <<"less_than"/utf8>> ->
                    decode_threshold(
                        Dynamic,
                        fun(Field@0) -> {less_than, Field@0} end
                    );

                <<"less_than_or_equal"/utf8>> ->
                    decode_threshold(
                        Dynamic,
                        fun(Field@0) -> {less_than_or_equal, Field@0} end
                    );

                <<"between"/utf8>> ->
                    decode_range(
                        Dynamic,
                        fun(Field@0, Field@1, Field@2) -> {between, Field@0, Field@1, Field@2} end
                    );

                <<"not_between"/utf8>> ->
                    decode_range(
                        Dynamic,
                        fun(Field@0, Field@1, Field@2) -> {not_between, Field@0, Field@1, Field@2} end
                    );

                Other ->
                    {error,
                        {unknown_discriminator,
                            <<"comparison.type"/utf8>>,
                            Other}}
            end
    end.

-file("src/math/equality/json.gleam", 312).
-spec decode_numeric_spec(gleam@dynamic:dynamic_(), integer()) -> {ok,
        math@equality@types:equality_spec()} |
    {error, math@equality@types:equality_config_error()}.
decode_numeric_spec(Dynamic, Version) ->
    case read_dynamic(Dynamic, <<"comparison"/utf8>>) of
        {error, Error} ->
            {error, Error};

        {ok, Comparison_dynamic} ->
            case decode_numeric_comparison(Comparison_dynamic) of
                {error, Error@1} ->
                    {error, Error@1};

                {ok, Comparison} ->
                    case decode_tolerance(Dynamic) of
                        {error, Error@2} ->
                            {error, Error@2};

                        {ok, Tolerance} ->
                            case decode_representation(Dynamic) of
                                {error, Error@3} ->
                                    {error, Error@3};

                                {ok, Representation} ->
                                    case decode_precision(Dynamic) of
                                        {error, Error@4} ->
                                            {error, Error@4};

                                        {ok, Precision} ->
                                            {ok,
                                                {equality_spec,
                                                    Version,
                                                    {numeric,
                                                        {numeric_spec,
                                                            Comparison,
                                                            Tolerance,
                                                            Representation,
                                                            Precision}}}}
                                    end
                            end
                    end
            end
    end.

-file("src/math/equality/json.gleam", 296).
-spec decode_supported_spec(gleam@dynamic:dynamic_(), integer()) -> {ok,
        math@equality@types:equality_spec()} |
    {error, math@equality@types:equality_config_error()}.
decode_supported_spec(Dynamic, Version) ->
    case read_string(Dynamic, <<"mode"/utf8>>) of
        {error, Error} ->
            {error, Error};

        {ok, Mode} ->
            case Mode of
                <<"numeric"/utf8>> ->
                    decode_numeric_spec(Dynamic, Version);

                <<"expression"/utf8>> ->
                    decode_expression_spec(Dynamic, Version);

                <<"unit_aware"/utf8>> ->
                    decode_unit_spec(Dynamic, Version);

                Other ->
                    {error, {unknown_discriminator, <<"mode"/utf8>>, Other}}
            end
    end.

-file("src/math/equality/json.gleam", 287).
-spec default_version_probe(integer()) -> math@equality@types:equality_spec().
default_version_probe(Version) ->
    {equality_spec,
        Version,
        {numeric,
            math@equality@types:default_numeric_options(
                {equal, math@equality@types:numeric_input(<<"0"/utf8>>)}
            )}}.

-file("src/math/equality/json.gleam", 274).
-spec decode_spec(gleam@dynamic:dynamic_()) -> {ok,
        math@equality@types:equality_spec()} |
    {error, math@equality@types:equality_config_error()}.
decode_spec(Dynamic) ->
    case read_int(Dynamic, <<"version"/utf8>>) of
        {error, Error} ->
            {error, Error};

        {ok, Version} ->
            case math@equality@evaluate:validate_spec(
                default_version_probe(Version)
            ) of
                {error, Error@1} ->
                    {error, Error@1};

                {ok, _} ->
                    decode_supported_spec(Dynamic, Version)
            end
    end.

-file("src/math/equality/json.gleam", 13).
?DOC(
    " Decode the future `equalityConfig` JSON shape into the typed contract.\n"
    " `gleam_json` owns JSON parsing here; this module owns only the Torus\n"
    " equality-config semantics layered on top of that package.\n"
).
-spec decode_equality_config(binary()) -> {ok,
        math@equality@types:equality_spec()} |
    {error, math@equality@types:equality_config_error()}.
decode_equality_config(Source) ->
    case gleam@json:parse(
        Source,
        {decoder, fun gleam@dynamic@decode:decode_dynamic/1}
    ) of
        {ok, Dynamic} ->
            decode_spec(Dynamic);

        {error, _} ->
            {error, {invalid_json, <<"could not parse JSON"/utf8>>}}
    end.

-file("src/math/equality/json.gleam", 263).
-spec string_array(list(binary())) -> gleam@json:json().
string_array(Values) ->
    gleam@json:array(Values, fun gleam@json:string/1).

-file("src/math/equality/json.gleam", 235).
-spec unit_policy_to_json(math@equality@types:unit_policy()) -> gleam@json:json().
unit_policy_to_json(Policy) ->
    case Policy of
        units_ignored ->
            gleam@json:object(
                [{<<"type"/utf8>>, gleam@json:string(<<"ignored"/utf8>>)}]
            );

        units_required ->
            gleam@json:object(
                [{<<"type"/utf8>>, gleam@json:string(<<"required"/utf8>>)}]
            );

        {accepted_units, Units} ->
            gleam@json:object(
                [{<<"type"/utf8>>, gleam@json:string(<<"accepted_units"/utf8>>)},
                    {<<"units"/utf8>>, string_array(Units)}]
            );

        {strict_unit, Unit} ->
            gleam@json:object(
                [{<<"type"/utf8>>, gleam@json:string(<<"strict_unit"/utf8>>)},
                    {<<"unit"/utf8>>, gleam@json:string(Unit)}]
            );

        {convertible_units, Units@1} ->
            gleam@json:object(
                [{<<"type"/utf8>>,
                        gleam@json:string(<<"convertible_units"/utf8>>)},
                    {<<"units"/utf8>>, string_array(Units@1)}]
            )
    end.

-file("src/math/equality/json.gleam", 259).
-spec numeric_to_json(math@equality@types:numeric_input()) -> gleam@json:json().
numeric_to_json(Input) ->
    gleam@json:string(erlang:element(2, Input)).

-file("src/math/equality/json.gleam", 216).
-spec unit_comparison_to_json(math@equality@types:unit_comparison()) -> gleam@json:json().
unit_comparison_to_json(Comparison) ->
    case Comparison of
        {unit_numeric, Expected_value, Expected_unit} ->
            gleam@json:object(
                [{<<"type"/utf8>>, gleam@json:string(<<"unit_numeric"/utf8>>)},
                    {<<"expectedValue"/utf8>>, numeric_to_json(Expected_value)},
                    {<<"expectedUnit"/utf8>>, gleam@json:string(Expected_unit)}]
            );

        {unit_expression, Expected_expression, Expected_unit@1} ->
            gleam@json:object(
                [{<<"type"/utf8>>,
                        gleam@json:string(<<"unit_expression"/utf8>>)},
                    {<<"expectedExpression"/utf8>>,
                        gleam@json:string(Expected_expression)},
                    {<<"expectedUnit"/utf8>>,
                        gleam@json:string(Expected_unit@1)}]
            )
    end.

-file("src/math/equality/json.gleam", 208).
-spec domain_to_json(math@equality@types:variable_domain()) -> gleam@json:json().
domain_to_json(Domain) ->
    gleam@json:object(
        [{<<"name"/utf8>>, gleam@json:string(erlang:element(2, Domain))},
            {<<"lower"/utf8>>, gleam@json:float(erlang:element(3, Domain))},
            {<<"upper"/utf8>>, gleam@json:float(erlang:element(4, Domain))}]
    ).

-file("src/math/equality/json.gleam", 267).
-spec json_array(list(ACV), fun((ACV) -> gleam@json:json())) -> gleam@json:json().
json_array(Values, Encoder) ->
    gleam@json:preprocessed_array(gleam@list:map(Values, Encoder)).

-file("src/math/equality/json.gleam", 966).
-spec function_to_string(math@ast:function_name()) -> binary().
function_to_string(Name) ->
    case Name of
        sin ->
            <<"sin"/utf8>>;

        cos ->
            <<"cos"/utf8>>;

        tan ->
            <<"tan"/utf8>>;

        ln ->
            <<"ln"/utf8>>;

        log ->
            <<"log"/utf8>>;

        log10 ->
            <<"log10"/utf8>>;

        log2 ->
            <<"log2"/utf8>>;

        sqrt ->
            <<"sqrt"/utf8>>;

        abs ->
            <<"abs"/utf8>>;

        exp ->
            <<"exp"/utf8>>
    end.

-file("src/math/equality/json.gleam", 195).
-spec expression_validation_to_json(math@equality@types:expression_validation()) -> gleam@json:json().
expression_validation_to_json(Validation) ->
    gleam@json:object(
        [{<<"allowedVariables"/utf8>>,
                string_array(erlang:element(2, Validation))},
            {<<"allowedFunctions"/utf8>>,
                string_array(
                    gleam@list:map(
                        erlang:element(3, Validation),
                        fun function_to_string/1
                    )
                )},
            {<<"domains"/utf8>>,
                json_array(erlang:element(4, Validation), fun domain_to_json/1)}]
    ).

-file("src/math/equality/json.gleam", 188).
-spec sampling_to_json(math@equality@types:sampling_config()) -> gleam@json:json().
sampling_to_json(Sampling) ->
    gleam@json:object(
        [{<<"seed"/utf8>>, gleam@json:int(erlang:element(2, Sampling))},
            {<<"sampleCount"/utf8>>,
                gleam@json:int(erlang:element(3, Sampling))}]
    ).

-file("src/math/equality/json.gleam", 170).
-spec expression_comparison_to_json(math@equality@types:expression_comparison()) -> gleam@json:json().
expression_comparison_to_json(Comparison) ->
    case Comparison of
        {exact_expression, Expected} ->
            gleam@json:object(
                [{<<"type"/utf8>>,
                        gleam@json:string(<<"exact_expression"/utf8>>)},
                    {<<"expected"/utf8>>, gleam@json:string(Expected)}]
            );

        {algebraic_equivalence, Expected@1, Sampling} ->
            gleam@json:object(
                [{<<"type"/utf8>>,
                        gleam@json:string(<<"algebraic_equivalence"/utf8>>)},
                    {<<"expected"/utf8>>, gleam@json:string(Expected@1)},
                    {<<"sampling"/utf8>>, sampling_to_json(Sampling)}]
            )
    end.

-file("src/math/equality/json.gleam", 946).
-spec decimal_rule_to_string(math@equality@types:decimal_place_rule()) -> binary().
decimal_rule_to_string(Rule) ->
    case Rule of
        exactly ->
            <<"exactly"/utf8>>;

        at_least ->
            <<"at_least"/utf8>>;

        at_most ->
            <<"at_most"/utf8>>
    end.

-file("src/math/equality/json.gleam", 152).
-spec precision_to_json(math@equality@types:numeric_precision()) -> gleam@json:json().
precision_to_json(Precision) ->
    case Precision of
        no_precision ->
            gleam@json:object(
                [{<<"type"/utf8>>, gleam@json:string(<<"none"/utf8>>)}]
            );

        {legacy_significant_figures, Count} ->
            gleam@json:object(
                [{<<"type"/utf8>>,
                        gleam@json:string(<<"legacy_significant_figures"/utf8>>)},
                    {<<"count"/utf8>>, gleam@json:int(Count)}]
            );

        {decimal_places, Rule, Count@1} ->
            gleam@json:object(
                [{<<"type"/utf8>>, gleam@json:string(<<"decimal_places"/utf8>>)},
                    {<<"rule"/utf8>>,
                        gleam@json:string(decimal_rule_to_string(Rule))},
                    {<<"count"/utf8>>, gleam@json:int(Count@1)}]
            )
    end.

-file("src/math/equality/json.gleam", 137).
-spec representation_to_json(math@equality@types:numeric_representation()) -> gleam@json:json().
representation_to_json(Representation) ->
    case Representation of
        any_representation ->
            gleam@json:object(
                [{<<"type"/utf8>>, gleam@json:string(<<"any"/utf8>>)}]
            );

        integer_representation ->
            gleam@json:object(
                [{<<"type"/utf8>>, gleam@json:string(<<"integer"/utf8>>)}]
            );

        decimal_representation ->
            gleam@json:object(
                [{<<"type"/utf8>>, gleam@json:string(<<"decimal"/utf8>>)}]
            );

        scientific_representation ->
            gleam@json:object(
                [{<<"type"/utf8>>, gleam@json:string(<<"scientific"/utf8>>)}]
            )
    end.

-file("src/math/equality/json.gleam", 114).
-spec tolerance_to_json(math@equality@types:numeric_tolerance()) -> gleam@json:json().
tolerance_to_json(Tolerance) ->
    case Tolerance of
        no_tolerance ->
            gleam@json:object(
                [{<<"type"/utf8>>, gleam@json:string(<<"none"/utf8>>)}]
            );

        {absolute_tolerance, Value} ->
            gleam@json:object(
                [{<<"type"/utf8>>, gleam@json:string(<<"absolute"/utf8>>)},
                    {<<"value"/utf8>>, gleam@json:float(Value)}]
            );

        {relative_tolerance, Value@1} ->
            gleam@json:object(
                [{<<"type"/utf8>>, gleam@json:string(<<"relative"/utf8>>)},
                    {<<"value"/utf8>>, gleam@json:float(Value@1)}]
            );

        {absolute_or_relative_tolerance, Absolute, Relative} ->
            gleam@json:object(
                [{<<"type"/utf8>>,
                        gleam@json:string(<<"absolute_or_relative"/utf8>>)},
                    {<<"absolute"/utf8>>, gleam@json:float(Absolute)},
                    {<<"relative"/utf8>>, gleam@json:float(Relative)}]
            )
    end.

-file("src/math/equality/json.gleam", 928).
-spec bounds_to_string(math@equality@types:range_bounds()) -> binary().
bounds_to_string(Bounds) ->
    case Bounds of
        inclusive ->
            <<"inclusive"/utf8>>;

        exclusive ->
            <<"exclusive"/utf8>>
    end.

-file("src/math/equality/json.gleam", 100).
-spec range_json(
    binary(),
    math@equality@types:numeric_input(),
    math@equality@types:numeric_input(),
    math@equality@types:range_bounds()
) -> gleam@json:json().
range_json(Kind, Lower, Upper, Bounds) ->
    gleam@json:object(
        [{<<"type"/utf8>>, gleam@json:string(Kind)},
            {<<"lower"/utf8>>, numeric_to_json(Lower)},
            {<<"upper"/utf8>>, numeric_to_json(Upper)},
            {<<"bounds"/utf8>>, gleam@json:string(bounds_to_string(Bounds))}]
    ).

-file("src/math/equality/json.gleam", 59).
-spec numeric_comparison_to_json(math@equality@types:numeric_comparison()) -> gleam@json:json().
numeric_comparison_to_json(Comparison) ->
    case Comparison of
        {equal, Expected} ->
            gleam@json:object(
                [{<<"type"/utf8>>, gleam@json:string(<<"equal"/utf8>>)},
                    {<<"expected"/utf8>>, numeric_to_json(Expected)}]
            );

        {not_equal, Expected@1} ->
            gleam@json:object(
                [{<<"type"/utf8>>, gleam@json:string(<<"not_equal"/utf8>>)},
                    {<<"expected"/utf8>>, numeric_to_json(Expected@1)}]
            );

        {greater_than, Threshold} ->
            gleam@json:object(
                [{<<"type"/utf8>>, gleam@json:string(<<"greater_than"/utf8>>)},
                    {<<"threshold"/utf8>>, numeric_to_json(Threshold)}]
            );

        {greater_than_or_equal, Threshold@1} ->
            gleam@json:object(
                [{<<"type"/utf8>>,
                        gleam@json:string(<<"greater_than_or_equal"/utf8>>)},
                    {<<"threshold"/utf8>>, numeric_to_json(Threshold@1)}]
            );

        {less_than, Threshold@2} ->
            gleam@json:object(
                [{<<"type"/utf8>>, gleam@json:string(<<"less_than"/utf8>>)},
                    {<<"threshold"/utf8>>, numeric_to_json(Threshold@2)}]
            );

        {less_than_or_equal, Threshold@3} ->
            gleam@json:object(
                [{<<"type"/utf8>>,
                        gleam@json:string(<<"less_than_or_equal"/utf8>>)},
                    {<<"threshold"/utf8>>, numeric_to_json(Threshold@3)}]
            );

        {between, Lower, Upper, Bounds} ->
            range_json(<<"between"/utf8>>, Lower, Upper, Bounds);

        {not_between, Lower@1, Upper@1, Bounds@1} ->
            range_json(<<"not_between"/utf8>>, Lower@1, Upper@1, Bounds@1)
    end.

-file("src/math/equality/json.gleam", 29).
-spec spec_to_json(math@equality@types:equality_spec()) -> gleam@json:json().
spec_to_json(Spec) ->
    case erlang:element(3, Spec) of
        {numeric, Numeric} ->
            gleam@json:object(
                [{<<"version"/utf8>>, gleam@json:int(erlang:element(2, Spec))},
                    {<<"mode"/utf8>>, gleam@json:string(<<"numeric"/utf8>>)},
                    {<<"comparison"/utf8>>,
                        numeric_comparison_to_json(erlang:element(2, Numeric))},
                    {<<"tolerance"/utf8>>,
                        tolerance_to_json(erlang:element(3, Numeric))},
                    {<<"representation"/utf8>>,
                        representation_to_json(erlang:element(4, Numeric))},
                    {<<"precision"/utf8>>,
                        precision_to_json(erlang:element(5, Numeric))}]
            );

        {expression, Expression} ->
            gleam@json:object(
                [{<<"version"/utf8>>, gleam@json:int(erlang:element(2, Spec))},
                    {<<"mode"/utf8>>, gleam@json:string(<<"expression"/utf8>>)},
                    {<<"comparison"/utf8>>,
                        expression_comparison_to_json(
                            erlang:element(2, Expression)
                        )},
                    {<<"validation"/utf8>>,
                        expression_validation_to_json(
                            erlang:element(3, Expression)
                        )}]
            );

        {unit_aware, Unit} ->
            gleam@json:object(
                [{<<"version"/utf8>>, gleam@json:int(erlang:element(2, Spec))},
                    {<<"mode"/utf8>>, gleam@json:string(<<"unit_aware"/utf8>>)},
                    {<<"comparison"/utf8>>,
                        unit_comparison_to_json(erlang:element(2, Unit))},
                    {<<"policy"/utf8>>,
                        unit_policy_to_json(erlang:element(3, Unit))}]
            )
    end.

-file("src/math/equality/json.gleam", 24).
?DOC(
    " Encode the typed equality config into the stable JSON field names that later\n"
    " Response storage and cross-target fixtures will treat as the public contract.\n"
).
-spec encode_equality_config(math@equality@types:equality_spec()) -> binary().
encode_equality_config(Spec) ->
    _pipe = spec_to_json(Spec),
    gleam@json:to_string(_pipe).
