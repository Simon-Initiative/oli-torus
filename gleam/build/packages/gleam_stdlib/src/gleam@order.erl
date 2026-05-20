-module(gleam@order).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/gleam/order.gleam").
-export([negate/1, to_int/1, compare/2, reverse/1, break_tie/2, lazy_break_tie/2]).
-export_type([order/0]).

-if(?OTP_RELEASE >= 27).
-define(MODULEDOC(Str), -moduledoc(Str)).
-define(DOC(Str), -doc(Str)).
-else.
-define(MODULEDOC(Str), -compile([])).
-define(DOC(Str), -compile([])).
-endif.

-type order() :: lt | eq | gt.

-file("src/gleam/order.gleam", 32).
?DOC(
    " Inverts an order, so less-than becomes greater-than and greater-than\n"
    " becomes less-than.\n"
    "\n"
    " ## Examples\n"
    "\n"
    " ```gleam\n"
    " assert negate(Lt) == Gt\n"
    " ```\n"
    "\n"
    " ```gleam\n"
    " assert negate(Eq) == Eq\n"
    " ```\n"
    "\n"
    " ```gleam\n"
    " assert negate(Gt) == Lt\n"
    " ```\n"
).
-spec negate(order()) -> order().
negate(Order) ->
    case Order of
        lt ->
            gt;

        eq ->
            eq;

        gt ->
            lt
    end.

-file("src/gleam/order.gleam", 56).
?DOC(
    " Produces a numeric representation of the order.\n"
    "\n"
    " ## Examples\n"
    "\n"
    " ```gleam\n"
    " assert to_int(Lt) == -1\n"
    " ```\n"
    "\n"
    " ```gleam\n"
    " assert to_int(Eq) == 0\n"
    " ```\n"
    "\n"
    " ```gleam\n"
    " assert to_int(Gt) == 1\n"
    " ```\n"
).
-spec to_int(order()) -> integer().
to_int(Order) ->
    case Order of
        lt ->
            -1;

        eq ->
            0;

        gt ->
            1
    end.

-file("src/gleam/order.gleam", 72).
?DOC(
    " Compares two `Order` values to one another, producing a new `Order`.\n"
    "\n"
    " ## Examples\n"
    "\n"
    " ```gleam\n"
    " assert compare(Eq, with: Lt) == Gt\n"
    " ```\n"
).
-spec compare(order(), order()) -> order().
compare(A, B) ->
    case {A, B} of
        {X, Y} when X =:= Y ->
            eq;

        {lt, _} ->
            lt;

        {eq, gt} ->
            lt;

        {_, _} ->
            gt
    end.

-file("src/gleam/order.gleam", 92).
?DOC(
    " Inverts an ordering function, so less-than becomes greater-than and greater-than\n"
    " becomes less-than.\n"
    "\n"
    " ## Examples\n"
    "\n"
    " ```gleam\n"
    " import gleam/int\n"
    " import gleam/list\n"
    "\n"
    " assert list.sort([1, 5, 4], by: reverse(int.compare)) == [5, 4, 1]\n"
    " ```\n"
).
-spec reverse(fun((I, I) -> order())) -> fun((I, I) -> order()).
reverse(Orderer) ->
    fun(A, B) -> Orderer(B, A) end.

-file("src/gleam/order.gleam", 112).
?DOC(
    " Return a fallback `Order` in case the first argument is `Eq`.\n"
    "\n"
    " ## Examples\n"
    "\n"
    " ```gleam\n"
    " import gleam/int\n"
    "\n"
    " assert break_tie(in: int.compare(1, 1), with: Lt) == Lt\n"
    " ```\n"
    "\n"
    " ```gleam\n"
    " import gleam/int\n"
    "\n"
    " assert break_tie(in: int.compare(1, 0), with: Eq) == Gt\n"
    " ```\n"
).
-spec break_tie(order(), order()) -> order().
break_tie(Order, Other) ->
    case Order of
        lt ->
            Order;

        gt ->
            Order;

        eq ->
            Other
    end.

-file("src/gleam/order.gleam", 139).
?DOC(
    " Invokes a fallback function returning an `Order` in case the first argument\n"
    " is `Eq`.\n"
    "\n"
    " This can be useful when the fallback comparison might be expensive and it\n"
    " needs to be delayed until strictly necessary.\n"
    "\n"
    " ## Examples\n"
    "\n"
    " ```gleam\n"
    " import gleam/int\n"
    "\n"
    " assert lazy_break_tie(in: int.compare(1, 1), with: fn() { Lt }) == Lt\n"
    " ```\n"
    "\n"
    " ```gleam\n"
    " import gleam/int\n"
    "\n"
    " assert lazy_break_tie(in: int.compare(1, 0), with: fn() { Eq }) == Gt\n"
    " ```\n"
).
-spec lazy_break_tie(order(), fun(() -> order())) -> order().
lazy_break_tie(Order, Comparison) ->
    case Order of
        lt ->
            Order;

        gt ->
            Order;

        eq ->
            Comparison()
    end.
