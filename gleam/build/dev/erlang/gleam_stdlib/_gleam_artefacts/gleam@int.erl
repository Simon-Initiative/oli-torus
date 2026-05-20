-module(gleam@int).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/gleam/int.gleam").
-export([absolute_value/1, to_float/1, power/2, square_root/1, parse/1, base_parse/2, to_string/1, to_base_string/2, to_base2/1, to_base8/1, to_base16/1, to_base36/1, max/2, min/2, clamp/3, compare/2, is_even/1, is_odd/1, negate/1, sum/1, product/1, random/1, divide/2, remainder/2, modulo/2, floor_divide/2, add/2, multiply/2, subtract/2, bitwise_and/2, bitwise_not/1, bitwise_or/2, bitwise_exclusive_or/2, bitwise_shift_left/2, bitwise_shift_right/2, range/4]).

-if(?OTP_RELEASE >= 27).
-define(MODULEDOC(Str), -moduledoc(Str)).
-define(DOC(Str), -doc(Str)).
-else.
-define(MODULEDOC(Str), -compile([])).
-define(DOC(Str), -compile([])).
-endif.

?MODULEDOC(
    " Functions for working with integers.\n"
    "\n"
    " ## Division by zero\n"
    "\n"
    " In Erlang division by zero results in a crash, however Gleam does not have\n"
    " partial functions and operators in core so instead division by zero returns\n"
    " zero, a behaviour taken from Pony, Coq, and Lean.\n"
    "\n"
    " This may seem unexpected at first, but it is no less mathematically valid\n"
    " than crashing or returning a special value. Division by zero is undefined\n"
    " in mathematics.\n"
).

-file("src/gleam/int.gleam", 28).
?DOC(
    " Returns the absolute value of the input.\n"
    "\n"
    " ## Examples\n"
    "\n"
    " ```gleam\n"
    " assert absolute_value(-12) == 12\n"
    " ```\n"
    "\n"
    " ```gleam\n"
    " assert absolute_value(10) == 10\n"
    " ```\n"
).
-spec absolute_value(integer()) -> integer().
absolute_value(X) ->
    case X >= 0 of
        true ->
            X;

        false ->
            X * -1
    end.

-file("src/gleam/int.gleam", 251).
?DOC(
    " Takes an int and returns its value as a float.\n"
    "\n"
    " ## Examples\n"
    "\n"
    " ```gleam\n"
    " assert to_float(5) == 5.0\n"
    " ```\n"
    "\n"
    " ```gleam\n"
    " assert to_float(0) == 0.0\n"
    " ```\n"
    "\n"
    " ```gleam\n"
    " assert to_float(-3) == -3.0\n"
    " ```\n"
).
-spec to_float(integer()) -> float().
to_float(X) ->
    erlang:float(X).

-file("src/gleam/int.gleam", 60).
?DOC(
    " Returns the result of the base being raised to the power of the\n"
    " exponent, as a `Float`.\n"
    "\n"
    " ## Examples\n"
    "\n"
    " ```gleam\n"
    " assert power(2, -1.0) == Ok(0.5)\n"
    " ```\n"
    "\n"
    " ```gleam\n"
    " assert power(2, 2.0) == Ok(4.0)\n"
    " ```\n"
    "\n"
    " ```gleam\n"
    " assert power(8, 1.5) == Ok(22.627416997969522)\n"
    " ```\n"
    "\n"
    " ```gleam\n"
    " assert 4 |> power(of: 2.0) == Ok(16.0)\n"
    " ```\n"
    "\n"
    " ```gleam\n"
    " assert power(-1, 0.5) == Error(Nil)\n"
    " ```\n"
).
-spec power(integer(), float()) -> {ok, float()} | {error, nil}.
power(Base, Exponent) ->
    _pipe = Base,
    _pipe@1 = erlang:float(_pipe),
    gleam@float:power(_pipe@1, Exponent).

-file("src/gleam/int.gleam", 78).
?DOC(
    " Returns the square root of the input as a `Float`.\n"
    "\n"
    " ## Examples\n"
    "\n"
    " ```gleam\n"
    " assert square_root(4) == Ok(2.0)\n"
    " ```\n"
    "\n"
    " ```gleam\n"
    " assert square_root(-16) == Error(Nil)\n"
    " ```\n"
).
-spec square_root(integer()) -> {ok, float()} | {error, nil}.
square_root(X) ->
    _pipe = X,
    _pipe@1 = erlang:float(_pipe),
    gleam@float:square_root(_pipe@1).

-file("src/gleam/int.gleam", 98).
?DOC(
    " Parses a given string as an int if possible.\n"
    "\n"
    " ## Examples\n"
    "\n"
    " ```gleam\n"
    " assert parse(\"2\") == Ok(2)\n"
    " ```\n"
    "\n"
    " ```gleam\n"
    " assert parse(\"ABC\") == Error(Nil)\n"
    " ```\n"
).
-spec parse(binary()) -> {ok, integer()} | {error, nil}.
parse(String) ->
    gleam_stdlib:parse_int(String).

-file("src/gleam/int.gleam", 125).
?DOC(
    " Parses a given string as an int in a given base if possible.\n"
    " Supports only bases 2 to 36, for values outside of which this function returns an `Error(Nil)`.\n"
    "\n"
    " ## Examples\n"
    "\n"
    " ```gleam\n"
    " assert base_parse(\"10\", 2) == Ok(2)\n"
    " ```\n"
    "\n"
    " ```gleam\n"
    " assert base_parse(\"30\", 16) == Ok(48)\n"
    " ```\n"
    "\n"
    " ```gleam\n"
    " assert base_parse(\"1C\", 36) == Ok(48)\n"
    " ```\n"
    "\n"
    " ```gleam\n"
    " assert base_parse(\"48\", 1) == Error(Nil)\n"
    " ```\n"
    "\n"
    " ```gleam\n"
    " assert base_parse(\"48\", 37) == Error(Nil)\n"
    " ```\n"
).
-spec base_parse(binary(), integer()) -> {ok, integer()} | {error, nil}.
base_parse(String, Base) ->
    case (Base >= 2) andalso (Base =< 36) of
        true ->
            gleam_stdlib:int_from_base_string(String, Base);

        false ->
            {error, nil}
    end.

-file("src/gleam/int.gleam", 146).
?DOC(
    " Prints a given int to a string.\n"
    "\n"
    " ## Examples\n"
    "\n"
    " ```gleam\n"
    " assert to_string(2) == \"2\"\n"
    " ```\n"
).
-spec to_string(integer()) -> binary().
to_string(X) ->
    erlang:integer_to_binary(X).

-file("src/gleam/int.gleam", 174).
?DOC(
    " Prints a given int to a string using the base number provided.\n"
    " Supports only bases 2 to 36, for values outside of which this function returns an `Error(Nil)`.\n"
    " For common bases (2, 8, 16, 36), use the `to_baseN` functions.\n"
    "\n"
    " ## Examples\n"
    "\n"
    " ```gleam\n"
    " assert to_base_string(2, 2) == Ok(\"10\")\n"
    " ```\n"
    "\n"
    " ```gleam\n"
    " assert to_base_string(48, 16) == Ok(\"30\")\n"
    " ```\n"
    "\n"
    " ```gleam\n"
    " assert to_base_string(48, 36) == Ok(\"1C\")\n"
    " ```\n"
    "\n"
    " ```gleam\n"
    " assert to_base_string(48, 1) == Error(Nil)\n"
    " ```\n"
    "\n"
    " ```gleam\n"
    " assert to_base_string(48, 37) == Error(Nil)\n"
    " ```\n"
).
-spec to_base_string(integer(), integer()) -> {ok, binary()} | {error, nil}.
to_base_string(X, Base) ->
    case (Base >= 2) andalso (Base =< 36) of
        true ->
            {ok, erlang:integer_to_binary(X, Base)};

        false ->
            {error, nil}
    end.

-file("src/gleam/int.gleam", 193).
?DOC(
    " Prints a given int to a string using base-2.\n"
    "\n"
    " ## Examples\n"
    "\n"
    " ```gleam\n"
    " assert to_base2(2) == \"10\"\n"
    " ```\n"
).
-spec to_base2(integer()) -> binary().
to_base2(X) ->
    erlang:integer_to_binary(X, 2).

-file("src/gleam/int.gleam", 205).
?DOC(
    " Prints a given int to a string using base-8.\n"
    "\n"
    " ## Examples\n"
    "\n"
    " ```gleam\n"
    " assert to_base8(15) == \"17\"\n"
    " ```\n"
).
-spec to_base8(integer()) -> binary().
to_base8(X) ->
    erlang:integer_to_binary(X, 8).

-file("src/gleam/int.gleam", 217).
?DOC(
    " Prints a given int to a string using base-16.\n"
    "\n"
    " ## Examples\n"
    "\n"
    " ```gleam\n"
    " assert to_base16(48) == \"30\"\n"
    " ```\n"
).
-spec to_base16(integer()) -> binary().
to_base16(X) ->
    erlang:integer_to_binary(X, 16).

-file("src/gleam/int.gleam", 229).
?DOC(
    " Prints a given int to a string using base-36.\n"
    "\n"
    " ## Examples\n"
    "\n"
    " ```gleam\n"
    " assert to_base36(48) == \"1C\"\n"
    " ```\n"
).
-spec to_base36(integer()) -> binary().
to_base36(X) ->
    erlang:integer_to_binary(X, 36).

-file("src/gleam/int.gleam", 326).
?DOC(
    " Compares two ints, returning the larger of the two.\n"
    "\n"
    " ## Examples\n"
    "\n"
    " ```gleam\n"
    " assert max(2, 3) == 3\n"
    " ```\n"
).
-spec max(integer(), integer()) -> integer().
max(A, B) ->
    case A > B of
        true ->
            A;

        false ->
            B
    end.

-file("src/gleam/int.gleam", 311).
?DOC(
    " Compares two ints, returning the smaller of the two.\n"
    "\n"
    " ## Examples\n"
    "\n"
    " ```gleam\n"
    " assert min(2, 3) == 2\n"
    " ```\n"
).
-spec min(integer(), integer()) -> integer().
min(A, B) ->
    case A < B of
        true ->
            A;

        false ->
            B
    end.

-file("src/gleam/int.gleam", 269).
?DOC(
    " Restricts an int between two bounds.\n"
    "\n"
    " Note: If the `min` argument is larger than the `max` argument then they\n"
    " will be swapped, so the minimum bound is always lower than the maximum\n"
    " bound.\n"
    "\n"
    " ## Examples\n"
    "\n"
    " ```gleam\n"
    " assert clamp(40, min: 50, max: 60) == 50\n"
    " ```\n"
    "\n"
    " ```gleam\n"
    " assert clamp(40, min: 50, max: 30) == 40\n"
    " ```\n"
).
-spec clamp(integer(), integer(), integer()) -> integer().
clamp(X, Min_bound, Max_bound) ->
    case Min_bound >= Max_bound of
        true ->
            _pipe = X,
            _pipe@1 = min(_pipe, Min_bound),
            max(_pipe@1, Max_bound);

        false ->
            _pipe@2 = X,
            _pipe@3 = min(_pipe@2, Max_bound),
            max(_pipe@3, Min_bound)
    end.

-file("src/gleam/int.gleam", 292).
?DOC(
    " Compares two ints, returning an order.\n"
    "\n"
    " ## Examples\n"
    "\n"
    " ```gleam\n"
    " assert compare(2, 3) == Lt\n"
    " ```\n"
    "\n"
    " ```gleam\n"
    " assert compare(4, 3) == Gt\n"
    " ```\n"
    "\n"
    " ```gleam\n"
    " assert compare(3, 3) == Eq\n"
    " ```\n"
).
-spec compare(integer(), integer()) -> gleam@order:order().
compare(A, B) ->
    case A =:= B of
        true ->
            eq;

        false ->
            case A < B of
                true ->
                    lt;

                false ->
                    gt
            end
    end.

-file("src/gleam/int.gleam", 345).
?DOC(
    " Returns whether the value provided is even.\n"
    "\n"
    " ## Examples\n"
    "\n"
    " ```gleam\n"
    " assert is_even(2)\n"
    " ```\n"
    "\n"
    " ```gleam\n"
    " assert !is_even(3)\n"
    " ```\n"
).
-spec is_even(integer()) -> boolean().
is_even(X) ->
    (X rem 2) =:= 0.

-file("src/gleam/int.gleam", 361).
?DOC(
    " Returns whether the value provided is odd.\n"
    "\n"
    " ## Examples\n"
    "\n"
    " ```gleam\n"
    " assert is_odd(3)\n"
    " ```\n"
    "\n"
    " ```gleam\n"
    " assert !is_odd(2)\n"
    " ```\n"
).
-spec is_odd(integer()) -> boolean().
is_odd(X) ->
    (X rem 2) /= 0.

-file("src/gleam/int.gleam", 373).
?DOC(
    " Returns the negative of the value provided.\n"
    "\n"
    " ## Examples\n"
    "\n"
    " ```gleam\n"
    " assert negate(1) == -1\n"
    " ```\n"
).
-spec negate(integer()) -> integer().
negate(X) ->
    -1 * X.

-file("src/gleam/int.gleam", 389).
-spec sum_loop(list(integer()), integer()) -> integer().
sum_loop(Numbers, Initial) ->
    case Numbers of
        [First | Rest] ->
            sum_loop(Rest, First + Initial);

        [] ->
            Initial
    end.

-file("src/gleam/int.gleam", 385).
?DOC(
    " Sums a list of ints.\n"
    "\n"
    " ## Example\n"
    "\n"
    " ```gleam\n"
    " assert sum([1, 2, 3]) == 6\n"
    " ```\n"
).
-spec sum(list(integer())) -> integer().
sum(Numbers) ->
    sum_loop(Numbers, 0).

-file("src/gleam/int.gleam", 408).
-spec product_loop(list(integer()), integer()) -> integer().
product_loop(Numbers, Initial) ->
    case Numbers of
        [First | Rest] ->
            product_loop(Rest, First * Initial);

        [] ->
            Initial
    end.

-file("src/gleam/int.gleam", 404).
?DOC(
    " Multiplies a list of ints and returns the product.\n"
    "\n"
    " ## Example\n"
    "\n"
    " ```gleam\n"
    " assert product([2, 3, 4]) == 24\n"
    " ```\n"
).
-spec product(list(integer())) -> integer().
product(Numbers) ->
    product_loop(Numbers, 1).

-file("src/gleam/int.gleam", 436).
?DOC(
    " Generates a random int between zero and the given maximum.\n"
    "\n"
    " The lower number is inclusive, the upper number is exclusive.\n"
    "\n"
    " ## Examples\n"
    "\n"
    " ```gleam\n"
    " random(10)\n"
    " // -> 4\n"
    " ```\n"
    "\n"
    " ```gleam\n"
    " random(1)\n"
    " // -> 0\n"
    " ```\n"
    "\n"
    " ```gleam\n"
    " random(-1)\n"
    " // -> -1\n"
    " ```\n"
).
-spec random(integer()) -> integer().
random(Max) ->
    _pipe = (rand:uniform() * erlang:float(Max)),
    _pipe@1 = math:floor(_pipe),
    erlang:round(_pipe@1).

-file("src/gleam/int.gleam", 465).
?DOC(
    " Performs a truncated integer division.\n"
    "\n"
    " Returns division of the inputs as a `Result`: If the given divisor equals\n"
    " `0`, this function returns an `Error`.\n"
    "\n"
    " ## Examples\n"
    "\n"
    " ```gleam\n"
    " assert divide(0, 1) == Ok(0)\n"
    " ```\n"
    "\n"
    " ```gleam\n"
    " assert divide(1, 0) == Error(Nil)\n"
    " ```\n"
    "\n"
    " ```gleam\n"
    " assert divide(5, 2) == Ok(2)\n"
    " ```\n"
    "\n"
    " ```gleam\n"
    " assert divide(-99, 2) == Ok(-49)\n"
    " ```\n"
).
-spec divide(integer(), integer()) -> {ok, integer()} | {error, nil}.
divide(Dividend, Divisor) ->
    case Divisor of
        0 ->
            {error, nil};

        Divisor@1 ->
            {ok, case Divisor@1 of
                    0 -> 0;
                    Gleam@denominator -> Dividend div Gleam@denominator
                end}
    end.

-file("src/gleam/int.gleam", 510).
?DOC(
    " Computes the remainder of an integer division of inputs as a `Result`.\n"
    "\n"
    " Returns division of the inputs as a `Result`: If the given divisor equals\n"
    " `0`, this function returns an `Error`.\n"
    "\n"
    " Most of the time you will want to use the `%` operator instead of this\n"
    " function.\n"
    "\n"
    " ## Examples\n"
    "\n"
    " ```gleam\n"
    " assert remainder(3, 2) == Ok(1)\n"
    " ```\n"
    "\n"
    " ```gleam\n"
    " assert remainder(1, 0) == Error(Nil)\n"
    " ```\n"
    "\n"
    " ```gleam\n"
    " assert remainder(10, -1) == Ok(0)\n"
    " ```\n"
    "\n"
    " ```gleam\n"
    " assert remainder(13, by: 3) == Ok(1)\n"
    " ```\n"
    "\n"
    " ```gleam\n"
    " assert remainder(-13, by: 3) == Ok(-1)\n"
    " ```\n"
    "\n"
    " ```gleam\n"
    " assert remainder(13, by: -3) == Ok(1)\n"
    " ```\n"
    "\n"
    " ```gleam\n"
    " assert remainder(-13, by: -3) == Ok(-1)\n"
    " ```\n"
).
-spec remainder(integer(), integer()) -> {ok, integer()} | {error, nil}.
remainder(Dividend, Divisor) ->
    case Divisor of
        0 ->
            {error, nil};

        Divisor@1 ->
            {ok, case Divisor@1 of
                    0 -> 0;
                    Gleam@denominator -> Dividend rem Gleam@denominator
                end}
    end.

-file("src/gleam/int.gleam", 551).
?DOC(
    " Computes the modulo of an integer division of inputs as a `Result`.\n"
    "\n"
    " Returns division of the inputs as a `Result`: If the given divisor equals\n"
    " `0`, this function returns an `Error`.\n"
    "\n"
    " Note that this is different from `int.remainder` and `%` in that the\n"
    " computed value will always have the same sign as the `divisor`.\n"
    "\n"
    " ## Examples\n"
    "\n"
    " ```gleam\n"
    " assert modulo(3, 2) == Ok(1)\n"
    " ```\n"
    "\n"
    " ```gleam\n"
    " assert modulo(1, 0) == Error(Nil)\n"
    " ```\n"
    "\n"
    " ```gleam\n"
    " assert modulo(10, -1) == Ok(0)\n"
    " ```\n"
    "\n"
    " ```gleam\n"
    " assert modulo(13, by: 3) == Ok(1)\n"
    " ```\n"
    "\n"
    " ```gleam\n"
    " assert modulo(-13, by: 3) == Ok(2)\n"
    " ```\n"
    "\n"
    " ```gleam\n"
    " assert modulo(13, by: -3) == Ok(-2)\n"
    " ```\n"
).
-spec modulo(integer(), integer()) -> {ok, integer()} | {error, nil}.
modulo(Dividend, Divisor) ->
    case Divisor of
        0 ->
            {error, nil};

        _ ->
            Remainder = case Divisor of
                0 -> 0;
                Gleam@denominator -> Dividend rem Gleam@denominator
            end,
            case (Remainder * Divisor) < 0 of
                true ->
                    {ok, Remainder + Divisor};

                false ->
                    {ok, Remainder}
            end
    end.

-file("src/gleam/int.gleam", 591).
?DOC(
    " Performs a *floored* integer division, which means that the result will\n"
    " always be rounded towards negative infinity.\n"
    "\n"
    " If you want to perform truncated integer division (rounding towards zero),\n"
    " use `int.divide()` or the `/` operator instead.\n"
    "\n"
    " Returns division of the inputs as a `Result`: If the given divisor equals\n"
    " `0`, this function returns an `Error`.\n"
    "\n"
    " ## Examples\n"
    "\n"
    " ```gleam\n"
    " assert floor_divide(1, 0) == Error(Nil)\n"
    " ```\n"
    "\n"
    " ```gleam\n"
    " assert floor_divide(5, 2) == Ok(2)\n"
    " ```\n"
    "\n"
    " ```gleam\n"
    " assert floor_divide(6, -4) == Ok(-2)\n"
    " ```\n"
    "\n"
    " ```gleam\n"
    " assert floor_divide(-99, 2) == Ok(-50)\n"
    " ```\n"
).
-spec floor_divide(integer(), integer()) -> {ok, integer()} | {error, nil}.
floor_divide(Dividend, Divisor) ->
    case Divisor of
        0 ->
            {error, nil};

        Divisor@1 ->
            case ((Dividend * Divisor@1) < 0) andalso ((case Divisor@1 of
                0 -> 0;
                Gleam@denominator -> Dividend rem Gleam@denominator
            end) /= 0) of
                true ->
                    {ok, (case Divisor@1 of
                            0 -> 0;
                            Gleam@denominator@1 -> Dividend div Gleam@denominator@1
                        end) - 1};

                false ->
                    {ok, case Divisor@1 of
                            0 -> 0;
                            Gleam@denominator@2 -> Dividend div Gleam@denominator@2
                        end}
            end
    end.

-file("src/gleam/int.gleam", 622).
?DOC(
    " Adds two integers together.\n"
    "\n"
    " It's the function equivalent of the `+` operator.\n"
    " This function is useful in higher order functions or pipes.\n"
    "\n"
    " ## Examples\n"
    "\n"
    " ```gleam\n"
    " assert add(1, 2) == 3\n"
    " ```\n"
    "\n"
    " ```gleam\n"
    " import gleam/list\n"
    " assert list.fold([1, 2, 3], 0, add) == 6\n"
    " ```\n"
    "\n"
    " ```gleam\n"
    " assert 3 |> add(2) == 5\n"
    " ```\n"
).
-spec add(integer(), integer()) -> integer().
add(A, B) ->
    A + B.

-file("src/gleam/int.gleam", 647).
?DOC(
    " Multiplies two integers together.\n"
    "\n"
    " It's the function equivalent of the `*` operator.\n"
    " This function is useful in higher order functions or pipes.\n"
    "\n"
    " ## Examples\n"
    "\n"
    " ```gleam\n"
    " assert multiply(2, 4) == 8\n"
    " ```\n"
    "\n"
    " ```gleam\n"
    " import gleam/list\n"
    "\n"
    " assert list.fold([2, 3, 4], 1, multiply) == 24\n"
    " ```\n"
    "\n"
    " ```gleam\n"
    " assert 3 |> multiply(2) == 6\n"
    " ```\n"
).
-spec multiply(integer(), integer()) -> integer().
multiply(A, B) ->
    A * B.

-file("src/gleam/int.gleam", 676).
?DOC(
    " Subtracts one int from another.\n"
    "\n"
    " It's the function equivalent of the `-` operator.\n"
    " This function is useful in higher order functions or pipes.\n"
    "\n"
    " ## Examples\n"
    "\n"
    " ```gleam\n"
    " assert subtract(3, 1) == 2\n"
    " ```\n"
    "\n"
    " ```gleam\n"
    " import gleam/list\n"
    "\n"
    " assert list.fold([1, 2, 3], 10, subtract) == 4\n"
    " ```\n"
    "\n"
    " ```gleam\n"
    " assert 3 |> subtract(2) == 1\n"
    " ```\n"
    "\n"
    " ```gleam\n"
    " assert 3 |> subtract(2, _) == -1\n"
    " ```\n"
).
-spec subtract(integer(), integer()) -> integer().
subtract(A, B) ->
    A - B.

-file("src/gleam/int.gleam", 695).
?DOC(
    " Calculates the bitwise AND of its arguments.\n"
    "\n"
    " Most the time you should use the bit array syntaxes instead of manipulating\n"
    " bits as ints with bitwise functions.\n"
    "\n"
    " ## Target specific behaviour\n"
    "\n"
    " The exact behaviour of this function depends on the target platform.\n"
    " On Erlang it is equivalent to bitwise operations on ints, on JavaScript it\n"
    " is equivalent to bitwise operations on big-ints. If you need to avoid the\n"
    " overhead of big-ints on JavaScript use bit arrays or another package that\n"
    " provides faster bitwise operations.\n"
).
-spec bitwise_and(integer(), integer()) -> integer().
bitwise_and(X, Y) ->
    erlang:'band'(X, Y).

-file("src/gleam/int.gleam", 712).
?DOC(
    " Calculates the bitwise NOT of its argument.\n"
    "\n"
    " Most the time you should use the bit array syntaxes instead of manipulating\n"
    " bits as ints with bitwise functions.\n"
    "\n"
    " ## Target specific behaviour\n"
    "\n"
    " The exact behaviour of this function depends on the target platform.\n"
    " On Erlang it is equivalent to bitwise operations on ints, on JavaScript it\n"
    " is equivalent to bitwise operations on big-ints. If you need to avoid the\n"
    " overhead of big-ints on JavaScript use bit arrays or another package that\n"
    " provides faster bitwise operations.\n"
).
-spec bitwise_not(integer()) -> integer().
bitwise_not(X) ->
    erlang:'bnot'(X).

-file("src/gleam/int.gleam", 729).
?DOC(
    " Calculates the bitwise OR of its arguments.\n"
    "\n"
    " Most the time you should use the bit array syntaxes instead of manipulating\n"
    " bits as ints with bitwise functions.\n"
    "\n"
    " ## Target specific behaviour\n"
    "\n"
    " The exact behaviour of this function depends on the target platform.\n"
    " On Erlang it is equivalent to bitwise operations on ints, on JavaScript it\n"
    " is equivalent to bitwise operations on big-ints. If you need to avoid the\n"
    " overhead of big-ints on JavaScript use bit arrays or another package that\n"
    " provides faster bitwise operations.\n"
).
-spec bitwise_or(integer(), integer()) -> integer().
bitwise_or(X, Y) ->
    erlang:'bor'(X, Y).

-file("src/gleam/int.gleam", 746).
?DOC(
    " Calculates the bitwise XOR of its arguments.\n"
    "\n"
    " Most the time you should use the bit array syntaxes instead of manipulating\n"
    " bits as ints with bitwise functions.\n"
    "\n"
    " ## Target specific behaviour\n"
    "\n"
    " The exact behaviour of this function depends on the target platform.\n"
    " On Erlang it is equivalent to bitwise operations on ints, on JavaScript it\n"
    " is equivalent to bitwise operations on big-ints. If you need to avoid the\n"
    " overhead of big-ints on JavaScript use bit arrays or another package that\n"
    " provides faster bitwise operations.\n"
).
-spec bitwise_exclusive_or(integer(), integer()) -> integer().
bitwise_exclusive_or(X, Y) ->
    erlang:'bxor'(X, Y).

-file("src/gleam/int.gleam", 763).
?DOC(
    " Calculates the result of an arithmetic left bitshift.\n"
    "\n"
    " Most the time you should use the bit array syntaxes instead of manipulating\n"
    " bits as ints with bitwise functions.\n"
    "\n"
    " ## Target specific behaviour\n"
    "\n"
    " The exact behaviour of this function depends on the target platform.\n"
    " On Erlang it is equivalent to bitwise operations on ints, on JavaScript it\n"
    " is equivalent to bitwise operations on big-ints. If you need to avoid the\n"
    " overhead of big-ints on JavaScript use bit arrays or another package that\n"
    " provides faster bitwise operations.\n"
).
-spec bitwise_shift_left(integer(), integer()) -> integer().
bitwise_shift_left(X, Y) ->
    erlang:'bsl'(X, Y).

-file("src/gleam/int.gleam", 780).
?DOC(
    " Calculates the result of an arithmetic right bitshift.\n"
    "\n"
    " Most the time you should use the bit array syntaxes instead of manipulating\n"
    " bits as ints with bitwise functions.\n"
    "\n"
    " ## Target specific behaviour\n"
    "\n"
    " The exact behaviour of this function depends on the target platform.\n"
    " On Erlang it is equivalent to bitwise operations on ints, on JavaScript it\n"
    " is equivalent to bitwise operations on big-ints. If you need to avoid the\n"
    " overhead of big-ints on JavaScript use bit arrays or another package that\n"
    " provides faster bitwise operations.\n"
).
-spec bitwise_shift_right(integer(), integer()) -> integer().
bitwise_shift_right(X, Y) ->
    erlang:'bsr'(X, Y).

-file("src/gleam/int.gleam", 813).
-spec range_loop(
    integer(),
    integer(),
    integer(),
    CM,
    fun((CM, integer()) -> CM)
) -> CM.
range_loop(Current, Stop, Increment, Acc, Reducer) ->
    case Current =:= Stop of
        true ->
            Acc;

        false ->
            Acc@1 = Reducer(Acc, Current),
            Current@1 = Current + Increment,
            range_loop(Current@1, Stop, Increment, Acc@1, Reducer)
    end.

-file("src/gleam/int.gleam", 800).
?DOC(
    " Run a function for each int between ints `from` and `to`.\n"
    "\n"
    " `from` is inclusive, and `to` is exclusive.\n"
    "\n"
    " ## Examples\n"
    "\n"
    " ```gleam\n"
    " assert\n"
    "   range(from: 0, to: 3, with: \"\", run: fn(acc, i) {\n"
    "     acc <> to_string(i)\n"
    "   })\n"
    "   == \"012\"\n"
    " ```\n"
    "\n"
    " ```gleam\n"
    " assert range(from: 1, to: -2, with: [], run: list.prepend) == [-1, 0, 1]\n"
    " ```\n"
).
-spec range(integer(), integer(), CL, fun((CL, integer()) -> CL)) -> CL.
range(Start, Stop, Acc, Reducer) ->
    Increment = case Start < Stop of
        true ->
            1;

        false ->
            -1
    end,
    range_loop(Start, Stop, Increment, Acc, Reducer).
