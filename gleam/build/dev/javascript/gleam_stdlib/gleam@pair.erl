-module(gleam@pair).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/gleam/pair.gleam").
-export([first/1, second/1, swap/1, map_first/2, map_second/2, new/2]).

-if(?OTP_RELEASE >= 27).
-define(MODULEDOC(Str), -moduledoc(Str)).
-define(DOC(Str), -doc(Str)).
-else.
-define(MODULEDOC(Str), -compile([])).
-define(DOC(Str), -compile([])).
-endif.

-file("src/gleam/pair.gleam", 9).
?DOC(
    " Returns the first element in a pair.\n"
    "\n"
    " ## Examples\n"
    "\n"
    " ```gleam\n"
    " assert first(#(1, 2)) == 1\n"
    " ```\n"
).
-spec first({CLY, any()}) -> CLY.
first(Pair) ->
    {A, _} = Pair,
    A.

-file("src/gleam/pair.gleam", 22).
?DOC(
    " Returns the second element in a pair.\n"
    "\n"
    " ## Examples\n"
    "\n"
    " ```gleam\n"
    " assert second(#(1, 2)) == 2\n"
    " ```\n"
).
-spec second({any(), CMB}) -> CMB.
second(Pair) ->
    {_, A} = Pair,
    A.

-file("src/gleam/pair.gleam", 35).
?DOC(
    " Returns a new pair with the elements swapped.\n"
    "\n"
    " ## Examples\n"
    "\n"
    " ```gleam\n"
    " assert swap(#(1, 2)) == #(2, 1)\n"
    " ```\n"
).
-spec swap({CMC, CMD}) -> {CMD, CMC}.
swap(Pair) ->
    {A, B} = Pair,
    {B, A}.

-file("src/gleam/pair.gleam", 49).
?DOC(
    " Returns a new pair with the first element having had `with` applied to\n"
    " it.\n"
    "\n"
    " ## Examples\n"
    "\n"
    " ```gleam\n"
    " assert #(1, 2) |> map_first(fn(n) { n * 2 }) == #(2, 2)\n"
    " ```\n"
).
-spec map_first({CME, CMF}, fun((CME) -> CMG)) -> {CMG, CMF}.
map_first(Pair, Fun) ->
    {A, B} = Pair,
    {Fun(A), B}.

-file("src/gleam/pair.gleam", 63).
?DOC(
    " Returns a new pair with the second element having had `with` applied to\n"
    " it.\n"
    "\n"
    " ## Examples\n"
    "\n"
    " ```gleam\n"
    " assert #(1, 2) |> map_second(fn(n) { n * 2 }) == #(1, 4)\n"
    " ```\n"
).
-spec map_second({CMH, CMI}, fun((CMI) -> CMJ)) -> {CMH, CMJ}.
map_second(Pair, Fun) ->
    {A, B} = Pair,
    {A, Fun(B)}.

-file("src/gleam/pair.gleam", 77).
?DOC(
    " Returns a new pair with the given elements. This can also be done using the dedicated\n"
    " syntax instead: `new(1, 2) == #(1, 2)`.\n"
    "\n"
    " ## Examples\n"
    "\n"
    " ```gleam\n"
    " assert new(1, 2) == #(1, 2)\n"
    " ```\n"
).
-spec new(CMK, CML) -> {CMK, CML}.
new(First, Second) ->
    {First, Second}.
