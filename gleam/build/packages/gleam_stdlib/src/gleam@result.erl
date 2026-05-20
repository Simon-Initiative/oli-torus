-module(gleam@result).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/gleam/result.gleam").
-export([is_ok/1, is_error/1, map/2, map_error/2, flatten/1, 'try'/2, unwrap/2, lazy_unwrap/2, unwrap_error/2, 'or'/2, lazy_or/2, all/1, partition/1, replace/2, replace_error/2, values/1, try_recover/2]).

-if(?OTP_RELEASE >= 27).
-define(MODULEDOC(Str), -moduledoc(Str)).
-define(DOC(Str), -doc(Str)).
-else.
-define(MODULEDOC(Str), -compile([])).
-define(DOC(Str), -compile([])).
-endif.

?MODULEDOC(
    " Result represents the result of something that may succeed or not.\n"
    " `Ok` means it was successful, `Error` means it was not successful.\n"
).

-file("src/gleam/result.gleam", 18).
?DOC(
    " Checks whether the result is an `Ok` value.\n"
    "\n"
    " ## Examples\n"
    "\n"
    " ```gleam\n"
    " assert is_ok(Ok(1))\n"
    " ```\n"
    "\n"
    " ```gleam\n"
    " assert !is_ok(Error(Nil))\n"
    " ```\n"
).
-spec is_ok({ok, any()} | {error, any()}) -> boolean().
is_ok(Result) ->
    case Result of
        {error, _} ->
            false;

        {ok, _} ->
            true
    end.

-file("src/gleam/result.gleam", 37).
?DOC(
    " Checks whether the result is an `Error` value.\n"
    "\n"
    " ## Examples\n"
    "\n"
    " ```gleam\n"
    " assert !is_error(Ok(1))\n"
    " ```\n"
    "\n"
    " ```gleam\n"
    " assert is_error(Error(Nil))\n"
    " ```\n"
).
-spec is_error({ok, any()} | {error, any()}) -> boolean().
is_error(Result) ->
    case Result of
        {ok, _} ->
            false;

        {error, _} ->
            true
    end.

-file("src/gleam/result.gleam", 60).
?DOC(
    " Updates a value held within the `Ok` of a result by calling a given function\n"
    " on it.\n"
    "\n"
    " If the result is an `Error` rather than `Ok` the function is not called and the\n"
    " result stays the same.\n"
    "\n"
    " ## Examples\n"
    "\n"
    " ```gleam\n"
    " assert map(over: Ok(1), with: fn(x) { x + 1 }) == Ok(2)\n"
    " ```\n"
    "\n"
    " ```gleam\n"
    " assert map(over: Error(1), with: fn(x) { x + 1 }) == Error(1)\n"
    " ```\n"
).
-spec map({ok, CMV} | {error, CMW}, fun((CMV) -> CMZ)) -> {ok, CMZ} |
    {error, CMW}.
map(Result, Fun) ->
    case Result of
        {ok, X} ->
            {ok, Fun(X)};

        {error, E} ->
            {error, E}
    end.

-file("src/gleam/result.gleam", 83).
?DOC(
    " Updates a value held within the `Error` of a result by calling a given function\n"
    " on it.\n"
    "\n"
    " If the result is `Ok` rather than `Error` the function is not called and the\n"
    " result stays the same.\n"
    "\n"
    " ## Examples\n"
    "\n"
    " ```gleam\n"
    " assert map_error(over: Error(1), with: fn(x) { x + 1 }) == Error(2)\n"
    " ```\n"
    "\n"
    " ```gleam\n"
    " assert map_error(over: Ok(1), with: fn(x) { x + 1 }) == Ok(1)\n"
    " ```\n"
).
-spec map_error({ok, CNC} | {error, CND}, fun((CND) -> CNG)) -> {ok, CNC} |
    {error, CNG}.
map_error(Result, Fun) ->
    case Result of
        {ok, X} ->
            {ok, X};

        {error, Error} ->
            {error, Fun(Error)}
    end.

-file("src/gleam/result.gleam", 109).
?DOC(
    " Merges a nested `Result` into a single layer.\n"
    "\n"
    " ## Examples\n"
    "\n"
    " ```gleam\n"
    " assert flatten(Ok(Ok(1))) == Ok(1)\n"
    " ```\n"
    "\n"
    " ```gleam\n"
    " assert flatten(Ok(Error(\"\"))) == Error(\"\")\n"
    " ```\n"
    "\n"
    " ```gleam\n"
    " assert flatten(Error(Nil)) == Error(Nil)\n"
    " ```\n"
).
-spec flatten({ok, {ok, CNJ} | {error, CNK}} | {error, CNK}) -> {ok, CNJ} |
    {error, CNK}.
flatten(Result) ->
    case Result of
        {ok, X} ->
            X;

        {error, Error} ->
            {error, Error}
    end.

-file("src/gleam/result.gleam", 143).
?DOC(
    " \"Updates\" an `Ok` result by passing its value to a function that yields a result,\n"
    " and returning the yielded result. (This may \"replace\" the `Ok` with an `Error`.)\n"
    "\n"
    " If the input is an `Error` rather than an `Ok`, the function is not called and\n"
    " the original `Error` is returned.\n"
    "\n"
    " This function is the equivalent of calling `map` followed by `flatten`, and\n"
    " it is useful for chaining together multiple functions that may fail.\n"
    "\n"
    " ## Examples\n"
    "\n"
    " ```gleam\n"
    " assert try(Ok(1), fn(x) { Ok(x + 1) }) == Ok(2)\n"
    " ```\n"
    "\n"
    " ```gleam\n"
    " assert try(Ok(1), fn(x) { Ok(#(\"a\", x)) }) == Ok(#(\"a\", 1))\n"
    " ```\n"
    "\n"
    " ```gleam\n"
    " assert try(Ok(1), fn(_) { Error(\"Oh no\") }) == Error(\"Oh no\")\n"
    " ```\n"
    "\n"
    " ```gleam\n"
    " assert try(Error(Nil), fn(x) { Ok(x + 1) }) == Error(Nil)\n"
    " ```\n"
).
-spec 'try'({ok, CNR} | {error, CNS}, fun((CNR) -> {ok, CNV} | {error, CNS})) -> {ok,
        CNV} |
    {error, CNS}.
'try'(Result, Fun) ->
    case Result of
        {ok, X} ->
            Fun(X);

        {error, E} ->
            {error, E}
    end.

-file("src/gleam/result.gleam", 166).
?DOC(
    " Extracts the `Ok` value from a result, returning a default value if the result\n"
    " is an `Error`.\n"
    "\n"
    " ## Examples\n"
    "\n"
    " ```gleam\n"
    " assert unwrap(Ok(1), 0) == 1\n"
    " ```\n"
    "\n"
    " ```gleam\n"
    " assert unwrap(Error(\"\"), 0) == 0\n"
    " ```\n"
).
-spec unwrap({ok, COA} | {error, any()}, COA) -> COA.
unwrap(Result, Default) ->
    case Result of
        {ok, V} ->
            V;

        {error, _} ->
            Default
    end.

-file("src/gleam/result.gleam", 186).
?DOC(
    " Extracts the `Ok` value from a result, evaluating the default function if the result\n"
    " is an `Error`.\n"
    "\n"
    " ## Examples\n"
    "\n"
    " ```gleam\n"
    " assert lazy_unwrap(Ok(1), fn() { 0 }) == 1\n"
    " ```\n"
    "\n"
    " ```gleam\n"
    " assert lazy_unwrap(Error(\"\"), fn() { 0 }) == 0\n"
    " ```\n"
).
-spec lazy_unwrap({ok, COE} | {error, any()}, fun(() -> COE)) -> COE.
lazy_unwrap(Result, Default) ->
    case Result of
        {ok, V} ->
            V;

        {error, _} ->
            Default()
    end.

-file("src/gleam/result.gleam", 206).
?DOC(
    " Extracts the `Error` value from a result, returning a default value if the result\n"
    " is an `Ok`.\n"
    "\n"
    " ## Examples\n"
    "\n"
    " ```gleam\n"
    " assert unwrap_error(Error(1), 0) == 1\n"
    " ```\n"
    "\n"
    " ```gleam\n"
    " assert unwrap_error(Ok(\"\"), 0) == 0\n"
    " ```\n"
).
-spec unwrap_error({ok, any()} | {error, COJ}, COJ) -> COJ.
unwrap_error(Result, Default) ->
    case Result of
        {ok, _} ->
            Default;

        {error, E} ->
            E
    end.

-file("src/gleam/result.gleam", 233).
?DOC(
    " Returns the first value if it is `Ok`, otherwise returns the second value.\n"
    "\n"
    " ## Examples\n"
    "\n"
    " ```gleam\n"
    " assert or(Ok(1), Ok(2)) == Ok(1)\n"
    " ```\n"
    "\n"
    " ```gleam\n"
    " assert or(Ok(1), Error(\"Error 2\")) == Ok(1)\n"
    " ```\n"
    "\n"
    " ```gleam\n"
    " assert or(Error(\"Error 1\"), Ok(2)) == Ok(2)\n"
    " ```\n"
    "\n"
    " ```gleam\n"
    " assert or(Error(\"Error 1\"), Error(\"Error 2\")) == Error(\"Error 2\")\n"
    " ```\n"
).
-spec 'or'({ok, COM} | {error, CON}, {ok, COM} | {error, CON}) -> {ok, COM} |
    {error, CON}.
'or'(First, Second) ->
    case First of
        {ok, _} ->
            First;

        {error, _} ->
            Second
    end.

-file("src/gleam/result.gleam", 263).
?DOC(
    " Returns the first value if it is `Ok`, otherwise evaluates the given function for a fallback value.\n"
    "\n"
    " If you need access to the initial error value, use `result.try_recover`.\n"
    "\n"
    " ## Examples\n"
    "\n"
    " ```gleam\n"
    " assert lazy_or(Ok(1), fn() { Ok(2) }) == Ok(1)\n"
    " ```\n"
    "\n"
    " ```gleam\n"
    " assert lazy_or(Ok(1), fn() { Error(\"Error 2\") }) == Ok(1)\n"
    " ```\n"
    "\n"
    " ```gleam\n"
    " assert lazy_or(Error(\"Error 1\"), fn() { Ok(2) }) == Ok(2)\n"
    " ```\n"
    "\n"
    " ```gleam\n"
    " assert lazy_or(Error(\"Error 1\"), fn() { Error(\"Error 2\") })\n"
    "   == Error(\"Error 2\")\n"
    " ```\n"
).
-spec lazy_or({ok, COU} | {error, COV}, fun(() -> {ok, COU} | {error, COV})) -> {ok,
        COU} |
    {error, COV}.
lazy_or(First, Second) ->
    case First of
        {ok, _} ->
            First;

        {error, _} ->
            Second()
    end.

-file("src/gleam/result.gleam", 287).
?DOC(
    " Combines a list of results into a single result.\n"
    " If all elements in the list are `Ok` then returns an `Ok` holding the list of values.\n"
    " If any element is `Error` then returns the first error.\n"
    "\n"
    " ## Examples\n"
    "\n"
    " ```gleam\n"
    " assert all([Ok(1), Ok(2)]) == Ok([1, 2])\n"
    " ```\n"
    "\n"
    " ```gleam\n"
    " assert all([Ok(1), Error(\"e\")]) == Error(\"e\")\n"
    " ```\n"
).
-spec all(list({ok, CPC} | {error, CPD})) -> {ok, list(CPC)} | {error, CPD}.
all(Results) ->
    gleam@list:try_map(Results, fun(Result) -> Result end).

-file("src/gleam/result.gleam", 307).
-spec partition_loop(list({ok, CPR} | {error, CPS}), list(CPR), list(CPS)) -> {list(CPR),
    list(CPS)}.
partition_loop(Results, Oks, Errors) ->
    case Results of
        [] ->
            {Oks, Errors};

        [{ok, A} | Rest] ->
            partition_loop(Rest, [A | Oks], Errors);

        [{error, E} | Rest@1] ->
            partition_loop(Rest@1, Oks, [E | Errors])
    end.

-file("src/gleam/result.gleam", 303).
?DOC(
    " Given a list of results, returns a pair where the first element is a list\n"
    " of all the values inside `Ok` and the second element is a list with all the\n"
    " values inside `Error`. The values in both lists appear in reverse order with\n"
    " respect to their position in the original list of results.\n"
    "\n"
    " ## Examples\n"
    "\n"
    " ```gleam\n"
    " assert partition([Ok(1), Error(\"a\"), Error(\"b\"), Ok(2)])\n"
    "   == #([2, 1], [\"b\", \"a\"])\n"
    " ```\n"
).
-spec partition(list({ok, CPK} | {error, CPL})) -> {list(CPK), list(CPL)}.
partition(Results) ->
    partition_loop(Results, [], []).

-file("src/gleam/result.gleam", 327).
?DOC(
    " Replace the value within a result\n"
    "\n"
    " ## Examples\n"
    "\n"
    " ```gleam\n"
    " assert replace(Ok(1), Nil) == Ok(Nil)\n"
    " ```\n"
    "\n"
    " ```gleam\n"
    " assert replace(Error(1), Nil) == Error(1)\n"
    " ```\n"
).
-spec replace({ok, any()} | {error, CQA}, CQD) -> {ok, CQD} | {error, CQA}.
replace(Result, Value) ->
    case Result of
        {ok, _} ->
            {ok, Value};

        {error, Error} ->
            {error, Error}
    end.

-file("src/gleam/result.gleam", 346).
?DOC(
    " Replace the error within a result\n"
    "\n"
    " ## Examples\n"
    "\n"
    " ```gleam\n"
    " assert replace_error(Error(1), Nil) == Error(Nil)\n"
    " ```\n"
    "\n"
    " ```gleam\n"
    " assert replace_error(Ok(1), Nil) == Ok(1)\n"
    " ```\n"
).
-spec replace_error({ok, CQG} | {error, any()}, CQK) -> {ok, CQG} | {error, CQK}.
replace_error(Result, Error) ->
    case Result of
        {ok, X} ->
            {ok, X};

        {error, _} ->
            {error, Error}
    end.

-file("src/gleam/result.gleam", 361).
?DOC(
    " Given a list of results, returns only the values inside `Ok`.\n"
    "\n"
    " ## Examples\n"
    "\n"
    " ```gleam\n"
    " assert values([Ok(1), Error(\"a\"), Ok(3)]) == [1, 3]\n"
    " ```\n"
).
-spec values(list({ok, CQN} | {error, any()})) -> list(CQN).
values(Results) ->
    gleam@list:filter_map(Results, fun(Result) -> Result end).

-file("src/gleam/result.gleam", 397).
?DOC(
    " Updates a value held within the `Error` of a result by calling a given function\n"
    " on it, where the given function also returns a result. The two results are\n"
    " then merged together into one result.\n"
    "\n"
    " If the result is an `Ok` rather than `Error` the function is not called and the\n"
    " result stays the same.\n"
    "\n"
    " This function is useful for chaining together computations that may fail\n"
    " and trying to recover from possible errors.\n"
    "\n"
    " If you do not need access to the initial error value, use `result.lazy_or`.\n"
    "\n"
    " ## Examples\n"
    "\n"
    " ```gleam\n"
    " assert Ok(1)\n"
    "   |> try_recover(with: fn(_) { Error(\"failed to recover\") })\n"
    "   == Ok(1)\n"
    " ```\n"
    "\n"
    " ```gleam\n"
    " assert Error(1)\n"
    "   |> try_recover(with: fn(error) { Ok(error + 1) })\n"
    "   == Ok(2)\n"
    " ```\n"
    "\n"
    " ```gleam\n"
    " assert Error(1)\n"
    "   |> try_recover(with: fn(error) { Error(\"failed to recover\") })\n"
    "   == Error(\"failed to recover\")\n"
    " ```\n"
).
-spec try_recover(
    {ok, CQT} | {error, CQU},
    fun((CQU) -> {ok, CQT} | {error, CQX})
) -> {ok, CQT} | {error, CQX}.
try_recover(Result, Fun) ->
    case Result of
        {ok, Value} ->
            {ok, Value};

        {error, Error} ->
            Fun(Error)
    end.
