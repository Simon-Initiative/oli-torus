-module(torus_math).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/torus_math.gleam").
-export([parse/1, parse_with_config/2, validate_symbols/2, to_debug_string/1, parse_error_to_debug_string/1, default_parse_config/0, validate_equality_config/1, decode_equality_config/1, encode_equality_config/1, evaluate_equality/2]).

-if(?OTP_RELEASE >= 27).
-define(MODULEDOC(Str), -moduledoc(Str)).
-define(DOC(Str), -doc(Str)).
-else.
-define(MODULEDOC(Str), -compile([])).
-define(DOC(Str), -compile([])).
-endif.

-file("src/torus_math.gleam", 13).
?DOC(
    " This module is named `torus_math` instead of `math` because `math` collides\n"
    " with Erlang's standard `math` module on the BEAM target. It remains the only\n"
    " parser API Torus callers should depend on, so internal lexer/parser modules\n"
    " can evolve without creating server/browser drift.\n"
).
-spec parse(binary()) -> {ok, math@ast:parsed()} |
    {error, math@ast:parse_error()}.
parse(Input) ->
    math@parser:parse(Input).

-file("src/torus_math.gleam", 20).
?DOC(
    " This overload point is reserved for grammar-level parser options. It accepts\n"
    " a config now so later phases can add behavior without changing the public\n"
    " function shape.\n"
).
-spec parse_with_config(binary(), math@ast:parse_config()) -> {ok,
        math@ast:parsed()} |
    {error, math@ast:parse_error()}.
parse_with_config(Input, _) ->
    parse(Input).

-file("src/torus_math.gleam", 29).
?DOC(
    " Validation is exposed beside parsing but remains a separate call so author\n"
    " configuration cannot accidentally alter syntactic parse success.\n"
).
-spec validate_symbols(math@ast:parsed(), math@ast:symbol_config()) -> {ok,
        math@ast:parsed()} |
    {error, math@ast:validation_error()}.
validate_symbols(Parsed, Config) ->
    math@validate:validate_symbols(Parsed, Config).

-file("src/torus_math.gleam", 38).
?DOC(
    " Debug strings are for demos and golden tests. They are intentionally not a\n"
    " JSON or TypeScript contract for browser integration.\n"
).
-spec to_debug_string(math@ast:parsed()) -> binary().
to_debug_string(Parsed) ->
    math@format:to_debug_string(Parsed).

-file("src/torus_math.gleam", 44).
?DOC(
    " Keep parse-error formatting public so dev prototypes can display structured\n"
    " failures without logging or inventing target-specific formatting.\n"
).
-spec parse_error_to_debug_string(math@ast:parse_error()) -> binary().
parse_error_to_debug_string(Error) ->
    math@format:parse_error_to_debug_string(Error).

-file("src/torus_math.gleam", 50).
?DOC(
    " Keep the default config in the public module so Torus callers do not need to\n"
    " depend on internal AST module details for ordinary parsing.\n"
).
-spec default_parse_config() -> math@ast:parse_config().
default_parse_config() ->
    math@ast:default_parse_config().

-file("src/torus_math.gleam", 56).
?DOC(
    " Validate the math equality contract through the public Torus math boundary\n"
    " so Elixir and browser callers do not depend on equality internals directly.\n"
).
-spec validate_equality_config(math@equality@types:equality_spec()) -> {ok,
        math@equality@types:equality_spec()} |
    {error, math@equality@types:equality_config_error()}.
validate_equality_config(Spec) ->
    math@equality@evaluate:validate_spec(Spec).

-file("src/torus_math.gleam", 65).
?DOC(
    " Decode `equalityConfig` JSON through the public Torus math boundary. Keeping\n"
    " JSON here avoids asking Elixir or TypeScript callers to understand Gleam's\n"
    " internal equality modules.\n"
).
-spec decode_equality_config(binary()) -> {ok,
        math@equality@types:equality_spec()} |
    {error, math@equality@types:equality_config_error()}.
decode_equality_config(Source) ->
    math@equality@json:decode_equality_config(Source).

-file("src/torus_math.gleam", 73).
?DOC(
    " Encode `equalityConfig` JSON through the same public boundary used for\n"
    " decoding so golden fixtures and future storage cannot drift by runtime.\n"
).
-spec encode_equality_config(math@equality@types:equality_spec()) -> binary().
encode_equality_config(Spec) ->
    math@equality@json:encode_equality_config(Spec).

-file("src/torus_math.gleam", 80).
?DOC(
    " Evaluate a submitted answer through the equality contract boundary. The\n"
    " public result stays limited to equality outcomes and diagnostics so Torus\n"
    " reducers remain responsible for feedback, scoring, and lifecycle decisions.\n"
).
-spec evaluate_equality(math@equality@types:equality_spec(), binary()) -> math@equality@types:equality_result().
evaluate_equality(Spec, Submitted) ->
    math@equality@evaluate:evaluate(Spec, Submitted).
