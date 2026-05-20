-module(gleam@option).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/gleam/option.gleam").
-export([all/1, is_some/1, is_none/1, to_result/2, from_result/1, unwrap/2, lazy_unwrap/2, map/2, flatten/1, then/2, 'or'/2, lazy_or/2, values/1]).
-export_type([option/1]).

-if(?OTP_RELEASE >= 27).
-define(MODULEDOC(Str), -moduledoc(Str)).
-define(DOC(Str), -doc(Str)).
-else.
-define(MODULEDOC(Str), -compile([])).
-define(DOC(Str), -compile([])).
-endif.

-type option(EL) :: {some, EL} | none.

-file("src/gleam/option.gleam", 57).
-spec reverse_and_prepend(list(FA), list(FA)) -> list(FA).
reverse_and_prepend(Prefix, Suffix) ->
    case Prefix of
        [] ->
            Suffix;

        [First | Rest] ->
            reverse_and_prepend(Rest, [First | Suffix])
    end.

-file("src/gleam/option.gleam", 42).
-spec all_loop(list(option(ER)), list(ER)) -> option(list(ER)).
all_loop(List, Acc) ->
    case List of
        [] ->
            {some, lists:reverse(Acc)};

        [none | _] ->
            none;

        [{some, First} | Rest] ->
            all_loop(Rest, [First | Acc])
    end.

-file("src/gleam/option.gleam", 38).
?DOC(
    " Combines a list of `Option`s into a single `Option`.\n"
    " If all elements in the list are `Some` then returns a `Some` holding the list of values.\n"
    " If any element is `None` then returns `None`.\n"
    "\n"
    " ## Examples\n"
    "\n"
    " ```gleam\n"
    " assert all([Some(1), Some(2)]) == Some([1, 2])\n"
    " ```\n"
    "\n"
    " ```gleam\n"
    " assert all([Some(1), None]) == None\n"
    " ```\n"
).
-spec all(list(option(EM))) -> option(list(EM)).
all(List) ->
    all_loop(List, []).

-file("src/gleam/option.gleam", 76).
?DOC(
    " Checks whether the `Option` is a `Some` value.\n"
    "\n"
    " ## Examples\n"
    "\n"
    " ```gleam\n"
    " assert is_some(Some(1))\n"
    " ```\n"
    "\n"
    " ```gleam\n"
    " assert !is_some(None)\n"
    " ```\n"
).
-spec is_some(option(any())) -> boolean().
is_some(Option) ->
    Option /= none.

-file("src/gleam/option.gleam", 92).
?DOC(
    " Checks whether the `Option` is a `None` value.\n"
    "\n"
    " ## Examples\n"
    "\n"
    " ```gleam\n"
    " assert !is_none(Some(1))\n"
    " ```\n"
    "\n"
    " ```gleam\n"
    " assert is_none(None)\n"
    " ```\n"
).
-spec is_none(option(any())) -> boolean().
is_none(Option) ->
    Option =:= none.

-file("src/gleam/option.gleam", 108).
?DOC(
    " Converts an `Option` type to a `Result` type.\n"
    "\n"
    " ## Examples\n"
    "\n"
    " ```gleam\n"
    " assert to_result(Some(1), \"some_error\") == Ok(1)\n"
    " ```\n"
    "\n"
    " ```gleam\n"
    " assert to_result(None, \"some_error\") == Error(\"some_error\")\n"
    " ```\n"
).
-spec to_result(option(FI), FL) -> {ok, FI} | {error, FL}.
to_result(Option, E) ->
    case Option of
        {some, A} ->
            {ok, A};

        none ->
            {error, E}
    end.

-file("src/gleam/option.gleam", 127).
?DOC(
    " Converts a `Result` type to an `Option` type.\n"
    "\n"
    " ## Examples\n"
    "\n"
    " ```gleam\n"
    " assert from_result(Ok(1)) == Some(1)\n"
    " ```\n"
    "\n"
    " ```gleam\n"
    " assert from_result(Error(\"some_error\")) == None\n"
    " ```\n"
).
-spec from_result({ok, FO} | {error, any()}) -> option(FO).
from_result(Result) ->
    case Result of
        {ok, A} ->
            {some, A};

        {error, _} ->
            none
    end.

-file("src/gleam/option.gleam", 146).
?DOC(
    " Extracts the value from an `Option`, returning a default value if there is none.\n"
    "\n"
    " ## Examples\n"
    "\n"
    " ```gleam\n"
    " assert unwrap(Some(1), 0) == 1\n"
    " ```\n"
    "\n"
    " ```gleam\n"
    " assert unwrap(None, 0) == 0\n"
    " ```\n"
).
-spec unwrap(option(FT), FT) -> FT.
unwrap(Option, Default) ->
    case Option of
        {some, X} ->
            X;

        none ->
            Default
    end.

-file("src/gleam/option.gleam", 165).
?DOC(
    " Extracts the value from an `Option`, evaluating the default function if the option is `None`.\n"
    "\n"
    " ## Examples\n"
    "\n"
    " ```gleam\n"
    " assert lazy_unwrap(Some(1), fn() { 0 }) == 1\n"
    " ```\n"
    "\n"
    " ```gleam\n"
    " assert lazy_unwrap(None, fn() { 0 }) == 0\n"
    " ```\n"
).
-spec lazy_unwrap(option(FV), fun(() -> FV)) -> FV.
lazy_unwrap(Option, Default) ->
    case Option of
        {some, X} ->
            X;

        none ->
            Default()
    end.

-file("src/gleam/option.gleam", 188).
?DOC(
    " Updates a value held within the `Some` of an `Option` by calling a given function\n"
    " on it.\n"
    "\n"
    " If the `Option` is a `None` rather than `Some`, the function is not called and the\n"
    " `Option` stays the same.\n"
    "\n"
    " ## Examples\n"
    "\n"
    " ```gleam\n"
    " assert map(over: Some(1), with: fn(x) { x + 1 }) == Some(2)\n"
    " ```\n"
    "\n"
    " ```gleam\n"
    " assert map(over: None, with: fn(x) { x + 1 }) == None\n"
    " ```\n"
).
-spec map(option(FX), fun((FX) -> FZ)) -> option(FZ).
map(Option, Fun) ->
    case Option of
        {some, X} ->
            {some, Fun(X)};

        none ->
            none
    end.

-file("src/gleam/option.gleam", 211).
?DOC(
    " Merges a nested `Option` into a single layer.\n"
    "\n"
    " ## Examples\n"
    "\n"
    " ```gleam\n"
    " assert flatten(Some(Some(1))) == Some(1)\n"
    " ```\n"
    "\n"
    " ```gleam\n"
    " assert flatten(Some(None)) == None\n"
    " ```\n"
    "\n"
    " ```gleam\n"
    " assert flatten(None) == None\n"
    " ```\n"
).
-spec flatten(option(option(GB))) -> option(GB).
flatten(Option) ->
    case Option of
        {some, X} ->
            X;

        none ->
            none
    end.

-file("src/gleam/option.gleam", 246).
?DOC(
    " Updates a value held within the `Some` of an `Option` by calling a given function\n"
    " on it, where the given function also returns an `Option`. The two options are\n"
    " then merged together into one `Option`.\n"
    "\n"
    " If the `Option` is a `None` rather than `Some` the function is not called and the\n"
    " option stays the same.\n"
    "\n"
    " This function is the equivalent of calling `map` followed by `flatten`, and\n"
    " it is useful for chaining together multiple functions that return `Option`.\n"
    "\n"
    " ## Examples\n"
    "\n"
    " ```gleam\n"
    " assert then(Some(1), fn(x) { Some(x + 1) }) == Some(2)\n"
    " ```\n"
    "\n"
    " ```gleam\n"
    " assert then(Some(1), fn(x) { Some(#(\"a\", x)) }) == Some(#(\"a\", 1))\n"
    " ```\n"
    "\n"
    " ```gleam\n"
    " assert then(Some(1), fn(_) { None }) == None\n"
    " ```\n"
    "\n"
    " ```gleam\n"
    " assert then(None, fn(x) { Some(x + 1) }) == None\n"
    " ```\n"
).
-spec then(option(GF), fun((GF) -> option(GH))) -> option(GH).
then(Option, Fun) ->
    case Option of
        {some, X} ->
            Fun(X);

        none ->
            none
    end.

-file("src/gleam/option.gleam", 273).
?DOC(
    " Returns the first value if it is `Some`, otherwise returns the second value.\n"
    "\n"
    " ## Examples\n"
    "\n"
    " ```gleam\n"
    " assert or(Some(1), Some(2)) == Some(1)\n"
    " ```\n"
    "\n"
    " ```gleam\n"
    " assert or(Some(1), None) == Some(1)\n"
    " ```\n"
    "\n"
    " ```gleam\n"
    " assert or(None, Some(2)) == Some(2)\n"
    " ```\n"
    "\n"
    " ```gleam\n"
    " assert or(None, None) == None\n"
    " ```\n"
).
-spec 'or'(option(GK), option(GK)) -> option(GK).
'or'(First, Second) ->
    case First of
        {some, _} ->
            First;

        none ->
            Second
    end.

-file("src/gleam/option.gleam", 300).
?DOC(
    " Returns the first value if it is `Some`, otherwise evaluates the given function for a fallback value.\n"
    "\n"
    " ## Examples\n"
    "\n"
    " ```gleam\n"
    " assert lazy_or(Some(1), fn() { Some(2) }) == Some(1)\n"
    " ```\n"
    "\n"
    " ```gleam\n"
    " assert lazy_or(Some(1), fn() { None }) == Some(1)\n"
    " ```\n"
    "\n"
    " ```gleam\n"
    " assert lazy_or(None, fn() { Some(2) }) == Some(2)\n"
    " ```\n"
    "\n"
    " ```gleam\n"
    " assert lazy_or(None, fn() { None }) == None\n"
    " ```\n"
).
-spec lazy_or(option(GO), fun(() -> option(GO))) -> option(GO).
lazy_or(First, Second) ->
    case First of
        {some, _} ->
            First;

        none ->
            Second()
    end.

-file("src/gleam/option.gleam", 320).
-spec values_loop(list(option(GW)), list(GW)) -> list(GW).
values_loop(List, Acc) ->
    case List of
        [] ->
            lists:reverse(Acc);

        [none | Rest] ->
            values_loop(Rest, Acc);

        [{some, First} | Rest@1] ->
            values_loop(Rest@1, [First | Acc])
    end.

-file("src/gleam/option.gleam", 316).
?DOC(
    " Given a list of `Option`s,\n"
    " returns only the values inside `Some`.\n"
    "\n"
    " ## Examples\n"
    "\n"
    " ```gleam\n"
    " assert values([Some(1), None, Some(3)]) == [1, 3]\n"
    " ```\n"
).
-spec values(list(option(GS))) -> list(GS).
values(Options) ->
    values_loop(Options, []).
