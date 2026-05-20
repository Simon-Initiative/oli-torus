-module(math@equality@evaluate).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/math/equality/evaluate.gleam").
-export([validate_spec/1, evaluate/2]).

-if(?OTP_RELEASE >= 27).
-define(MODULEDOC(Str), -moduledoc(Str)).
-define(DOC(Str), -doc(Str)).
-else.
-define(MODULEDOC(Str), -compile([])).
-define(DOC(Str), -compile([])).
-endif.

-file("src/math/equality/evaluate.gleam", 7).
?DOC(
    " Validate only the root contract invariants that Phase 1 owns. Deeper JSON\n"
    " and numeric validation are intentionally deferred to later phases so this\n"
    " function stays aligned with the current type-contract milestone.\n"
).
-spec validate_spec(math@equality@types:equality_spec()) -> {ok,
        math@equality@types:equality_spec()} |
    {error, math@equality@types:equality_config_error()}.
validate_spec(Spec) ->
    case erlang:element(2, Spec) of
        1 ->
            {ok, Spec};

        Version ->
            {error, {unsupported_version, Version}}
    end.

-file("src/math/equality/evaluate.gleam", 32).
?DOC(
    " Keep mode dispatch in one place so unsupported future families and supported\n"
    " numeric behavior are visible at the public equality boundary.\n"
).
-spec evaluate_mode(math@equality@types:equality_mode(), binary()) -> math@equality@types:equality_result().
evaluate_mode(Mode, Submitted) ->
    case Mode of
        {numeric, Spec} ->
            math@equality@numeric:evaluate(Spec, Submitted);

        {expression, _} ->
            {unsupported_mode, expression_evaluation};

        {unit_aware, _} ->
            {unsupported_mode, unit_aware_evaluation}
    end.

-file("src/math/equality/evaluate.gleam", 20).
?DOC(
    " Evaluate keeps the root-version guard in front of all executable behavior so\n"
    " callers get config failures before mode failures. Numeric mode now delegates\n"
    " to the standard/basic page scalar evaluator; future expression and unit-aware\n"
    " modes remain explicit unsupported results.\n"
).
-spec evaluate(math@equality@types:equality_spec(), binary()) -> math@equality@types:equality_result().
evaluate(Spec, Submitted) ->
    case validate_spec(Spec) of
        {error, Error} ->
            {invalid_config, Error};

        {ok, Valid_spec} ->
            evaluate_mode(erlang:element(3, Valid_spec), Submitted)
    end.
