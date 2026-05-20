-module(math_test@corpus).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "test/math_test/corpus.gleam").
-export([accepted_parser_inputs/0, rejected_parser_inputs/0, precedence_inputs/0]).

-if(?OTP_RELEASE >= 27).
-define(MODULEDOC(Str), -moduledoc(Str)).
-define(DOC(Str), -doc(Str)).
-else.
-define(MODULEDOC(Str), -compile([])).
-define(DOC(Str), -compile([])).
-endif.

-file("test/math_test/corpus.gleam", 3).
?DOC(
    " The Phase 1 corpus is intentionally data only. Later phases will attach\n"
    " expected ASTs and errors while keeping this shared accepted/rejected shape.\n"
).
-spec accepted_parser_inputs() -> list(binary()).
accepted_parser_inputs() ->
    [<<"2"/utf8>>,
        <<"2.0"/utf8>>,
        <<"1.23e-4"/utf8>>,
        <<"x"/utf8>>,
        <<"2x"/utf8>>,
        <<"xy"/utf8>>,
        <<"2(x+3)"/utf8>>,
        <<"(x+1)(x-1)"/utf8>>,
        <<"2x + 6"/utf8>>,
        <<"sqrt(2)/2"/utf8>>,
        <<"sin(x)"/utf8>>,
        <<"cos(x)"/utf8>>,
        <<"tan(x)"/utf8>>,
        <<"ln(x)"/utf8>>,
        <<"log(x)"/utf8>>,
        <<"log10(x)"/utf8>>,
        <<"log2(x)"/utf8>>,
        <<"abs(x)"/utf8>>,
        <<"exp(x)"/utf8>>,
        <<"pi"/utf8>>,
        <<"e"/utf8>>,
        <<"|x-2|"/utf8>>,
        <<"n!"/utf8>>,
        <<"2^3^4"/utf8>>,
        <<"-x^2"/utf8>>].

-file("test/math_test/corpus.gleam", 36).
?DOC(
    " These cases document unsupported or malformed syntax before behavior exists.\n"
    " Parser implementation phases should replace scaffold assertions with\n"
    " structured error expectations for each input.\n"
).
-spec rejected_parser_inputs() -> list(binary()).
rejected_parser_inputs() ->
    [<<"2^^3"/utf8>>,
        <<"1,000"/utf8>>,
        <<"tan x"/utf8>>,
        <<"sqrt()"/utf8>>,
        <<"(x+1"/utf8>>,
        <<"|x-2"/utf8>>,
        <<"2+"/utf8>>].

-file("test/math_test/corpus.gleam", 42).
?DOC(
    " Precedence cases live separately so binding-power decisions are visible in\n"
    " review before the Pratt parser is implemented.\n"
).
-spec precedence_inputs() -> list(binary()).
precedence_inputs() ->
    [<<"2+3*4"/utf8>>,
        <<"2*3+4"/utf8>>,
        <<"2^3^4"/utf8>>,
        <<"-x^2"/utf8>>,
        <<"(-x)^2"/utf8>>,
        <<"2x^2"/utf8>>,
        <<"1/2x"/utf8>>].
