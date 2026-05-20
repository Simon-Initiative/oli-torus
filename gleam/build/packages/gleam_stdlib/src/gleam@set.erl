-module(gleam@set).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/gleam/set.gleam").
-export([new/0, size/1, is_empty/1, insert/2, contains/2, delete/2, to_list/1, from_list/1, fold/3, filter/2, map/2, drop/2, take/2, union/2, intersection/2, difference/2, is_subset/2, is_disjoint/2, symmetric_difference/2, each/2]).
-export_type([set/1]).

-if(?OTP_RELEASE >= 27).
-define(MODULEDOC(Str), -moduledoc(Str)).
-define(DOC(Str), -doc(Str)).
-else.
-define(MODULEDOC(Str), -compile([])).
-define(DOC(Str), -compile([])).
-endif.

-opaque set(CVK) :: {set, gleam@dict:dict(CVK, list(nil))}.

-file("src/gleam/set.gleam", 32).
?DOC(" Creates a new empty set.\n").
-spec new() -> set(any()).
new() ->
    {set, maps:new()}.

-file("src/gleam/set.gleam", 50).
?DOC(
    " Gets the number of members in a set.\n"
    "\n"
    " This function runs in constant time.\n"
    "\n"
    " ## Examples\n"
    "\n"
    " ```gleam\n"
    " assert new()\n"
    "   |> insert(1)\n"
    "   |> insert(2)\n"
    "   |> size\n"
    "   == 2\n"
    " ```\n"
).
-spec size(set(any())) -> integer().
size(Set) ->
    maps:size(erlang:element(2, Set)).

-file("src/gleam/set.gleam", 66).
?DOC(
    " Determines whether or not the set is empty.\n"
    "\n"
    " ## Examples\n"
    "\n"
    " ```gleam\n"
    " assert new() |> is_empty\n"
    " ```\n"
    "\n"
    " ```gleam\n"
    " assert !{ new() |> insert(1) |> is_empty }\n"
    " ```\n"
).
-spec is_empty(set(any())) -> boolean().
is_empty(Set) ->
    Set =:= new().

-file("src/gleam/set.gleam", 84).
?DOC(
    " Inserts a member into the set.\n"
    "\n"
    " This function runs in logarithmic time.\n"
    "\n"
    " ## Examples\n"
    "\n"
    " ```gleam\n"
    " assert new()\n"
    "   |> insert(1)\n"
    "   |> insert(2)\n"
    "   |> size\n"
    "   == 2\n"
    " ```\n"
).
-spec insert(set(CVS), CVS) -> set(CVS).
insert(Set, Member) ->
    {set, gleam@dict:insert(erlang:element(2, Set), Member, [])}.

-file("src/gleam/set.gleam", 108).
?DOC(
    " Checks whether a set contains a given member.\n"
    "\n"
    " This function runs in logarithmic time.\n"
    "\n"
    " ## Examples\n"
    "\n"
    " ```gleam\n"
    " assert new()\n"
    "   |> insert(2)\n"
    "   |> contains(2)\n"
    " ```\n"
    "\n"
    " ```gleam\n"
    " assert !{\n"
    "   new()\n"
    "   |> insert(2)\n"
    "   |> contains(1)\n"
    " }\n"
    " ```\n"
).
-spec contains(set(CVV), CVV) -> boolean().
contains(Set, Member) ->
    _pipe = erlang:element(2, Set),
    _pipe@1 = gleam_stdlib:map_get(_pipe, Member),
    gleam@result:is_ok(_pipe@1).

-file("src/gleam/set.gleam", 130).
?DOC(
    " Removes a member from a set. If the set does not contain the member then\n"
    " the set is returned unchanged.\n"
    "\n"
    " This function runs in logarithmic time.\n"
    "\n"
    " ## Examples\n"
    "\n"
    " ```gleam\n"
    " assert !{\n"
    "   new()\n"
    "   |> insert(2)\n"
    "   |> delete(2)\n"
    "   |> contains(2)\n"
    " }\n"
    " ```\n"
).
-spec delete(set(CVX), CVX) -> set(CVX).
delete(Set, Member) ->
    {set, gleam@dict:delete(erlang:element(2, Set), Member)}.

-file("src/gleam/set.gleam", 147).
?DOC(
    " Converts the set into a list of the contained members.\n"
    "\n"
    " The list has no specific ordering, any unintentional ordering may change in\n"
    " future versions of Gleam or Erlang.\n"
    "\n"
    " This function runs in linear time.\n"
    "\n"
    " ## Examples\n"
    "\n"
    " ```gleam\n"
    " assert new() |> insert(2) |> to_list == [2]\n"
    " ```\n"
).
-spec to_list(set(CWA)) -> list(CWA).
to_list(Set) ->
    maps:keys(erlang:element(2, Set)).

-file("src/gleam/set.gleam", 168).
?DOC(
    " Creates a new set of the members in a given list.\n"
    "\n"
    " This function runs in loglinear time.\n"
    "\n"
    " ## Examples\n"
    "\n"
    " ```gleam\n"
    " import gleam/int\n"
    " import gleam/list\n"
    "\n"
    " assert [1, 1, 2, 4, 3, 2]\n"
    "   |> from_list\n"
    "   |> to_list\n"
    "   |> list.sort(by: int.compare)\n"
    "   == [1, 2, 3, 4]\n"
    " ```\n"
).
-spec from_list(list(CWD)) -> set(CWD).
from_list(Members) ->
    Dict = gleam@list:fold(
        Members,
        maps:new(),
        fun(M, K) -> gleam@dict:insert(M, K, []) end
    ),
    {set, Dict}.

-file("src/gleam/set.gleam", 191).
?DOC(
    " Combines all entries into a single value by calling a given function on each\n"
    " one.\n"
    "\n"
    " Sets are not ordered so the values are not returned in any specific order.\n"
    " Do not write code that relies on the order entries are used by this\n"
    " function as it may change in later versions of Gleam or Erlang.\n"
    "\n"
    " ## Examples\n"
    "\n"
    " ```gleam\n"
    " assert from_list([1, 3, 9])\n"
    "   |> fold(0, fn(accumulator, member) { accumulator + member })\n"
    "   == 13\n"
    " ```\n"
).
-spec fold(set(CWG), CWI, fun((CWI, CWG) -> CWI)) -> CWI.
fold(Set, Initial, Reducer) ->
    gleam@dict:fold(
        erlang:element(2, Set),
        Initial,
        fun(A, K, _) -> Reducer(A, K) end
    ).

-file("src/gleam/set.gleam", 215).
?DOC(
    " Creates a new set from an existing set, minus any members that a given\n"
    " function returns `False` for.\n"
    "\n"
    " This function runs in loglinear time.\n"
    "\n"
    " ## Examples\n"
    "\n"
    " ```gleam\n"
    " import gleam/int\n"
    "\n"
    " assert from_list([1, 4, 6, 3, 675, 44, 67])\n"
    "   |> filter(keeping: int.is_even)\n"
    "   |> to_list\n"
    "   == [4, 6, 44]\n"
    " ```\n"
).
-spec filter(set(CWJ), fun((CWJ) -> boolean())) -> set(CWJ).
filter(Set, Predicate) ->
    {set,
        gleam@dict:filter(erlang:element(2, Set), fun(M, _) -> Predicate(M) end)}.

-file("src/gleam/set.gleam", 234).
?DOC(
    " Creates a new set from a given set with the result of applying the given\n"
    " function to each member.\n"
    "\n"
    " ## Examples\n"
    "\n"
    " ```gleam\n"
    " assert from_list([1, 2, 3, 4])\n"
    "   |> map(with: fn(x) { x * 2 })\n"
    "   |> to_list\n"
    "   == [2, 4, 6, 8]\n"
    " ```\n"
).
-spec map(set(CWM), fun((CWM) -> CWO)) -> set(CWO).
map(Set, Fun) ->
    fold(Set, new(), fun(Acc, Member) -> insert(Acc, Fun(Member)) end).

-file("src/gleam/set.gleam", 252).
?DOC(
    " Creates a new set from a given set with all the same entries except any\n"
    " entry found on the given list.\n"
    "\n"
    " ## Examples\n"
    "\n"
    " ```gleam\n"
    " assert from_list([1, 2, 3, 4])\n"
    "   |> drop([1, 3])\n"
    "   |> to_list\n"
    "   == [2, 4]\n"
    " ```\n"
).
-spec drop(set(CWQ), list(CWQ)) -> set(CWQ).
drop(Set, Disallowed) ->
    gleam@list:fold(Disallowed, Set, fun delete/2).

-file("src/gleam/set.gleam", 270).
?DOC(
    " Creates a new set from a given set, only including any members which are in\n"
    " a given list.\n"
    "\n"
    " This function runs in loglinear time.\n"
    "\n"
    " ## Examples\n"
    "\n"
    " ```gleam\n"
    " assert from_list([1, 2, 3])\n"
    "   |> take([1, 3, 5])\n"
    "   |> to_list\n"
    "   == [1, 3]\n"
    " ```\n"
).
-spec take(set(CWU), list(CWU)) -> set(CWU).
take(Set, Desired) ->
    {set, gleam@dict:take(erlang:element(2, Set), Desired)}.

-file("src/gleam/set.gleam", 290).
-spec order(set(CXC), set(CXC)) -> {set(CXC), set(CXC)}.
order(First, Second) ->
    case maps:size(erlang:element(2, First)) > maps:size(
        erlang:element(2, Second)
    ) of
        true ->
            {First, Second};

        false ->
            {Second, First}
    end.

-file("src/gleam/set.gleam", 285).
?DOC(
    " Creates a new set that contains all members of both given sets.\n"
    "\n"
    " This function runs in loglinear time.\n"
    "\n"
    " ## Examples\n"
    "\n"
    " ```gleam\n"
    " assert union(from_list([1, 2]), from_list([2, 3])) |> to_list\n"
    "   == [1, 2, 3]\n"
    " ```\n"
).
-spec union(set(CWY), set(CWY)) -> set(CWY).
union(First, Second) ->
    {Larger, Smaller} = order(First, Second),
    fold(Smaller, Larger, fun insert/2).

-file("src/gleam/set.gleam", 308).
?DOC(
    " Creates a new set that contains members that are present in both given sets.\n"
    "\n"
    " This function runs in loglinear time.\n"
    "\n"
    " ## Examples\n"
    "\n"
    " ```gleam\n"
    " assert intersection(from_list([1, 2]), from_list([2, 3])) |> to_list\n"
    "   == [2]\n"
    " ```\n"
).
-spec intersection(set(CXH), set(CXH)) -> set(CXH).
intersection(First, Second) ->
    {Larger, Smaller} = order(First, Second),
    take(Larger, to_list(Smaller)).

-file("src/gleam/set.gleam", 326).
?DOC(
    " Creates a new set that contains members that are present in the first set\n"
    " but not the second.\n"
    "\n"
    " ## Examples\n"
    "\n"
    " ```gleam\n"
    " assert difference(from_list([1, 2]), from_list([2, 3, 4])) |> to_list\n"
    "   == [1]\n"
    " ```\n"
).
-spec difference(set(CXL), set(CXL)) -> set(CXL).
difference(First, Second) ->
    drop(First, to_list(Second)).

-file("src/gleam/set.gleam", 345).
?DOC(
    " Determines if a set is fully contained by another.\n"
    "\n"
    " ## Examples\n"
    "\n"
    " ```gleam\n"
    " assert is_subset(from_list([1]), from_list([1, 2]))\n"
    " ```\n"
    "\n"
    " ```gleam\n"
    " assert !is_subset(from_list([1, 2, 3]), from_list([3, 4, 5]))\n"
    " ```\n"
).
-spec is_subset(set(CXP), set(CXP)) -> boolean().
is_subset(First, Second) ->
    intersection(First, Second) =:= First.

-file("src/gleam/set.gleam", 361).
?DOC(
    " Determines if two sets contain no common members\n"
    "\n"
    " ## Examples\n"
    "\n"
    " ```gleam\n"
    " assert is_disjoint(from_list([1, 2, 3]), from_list([4, 5, 6]))\n"
    " ```\n"
    "\n"
    " ```gleam\n"
    " assert !is_disjoint(from_list([1, 2, 3]), from_list([3, 4, 5]))\n"
    " ```\n"
).
-spec is_disjoint(set(CXS), set(CXS)) -> boolean().
is_disjoint(First, Second) ->
    intersection(First, Second) =:= new().

-file("src/gleam/set.gleam", 376).
?DOC(
    " Creates a new set that contains members that are present in either set, but\n"
    " not both.\n"
    "\n"
    " ## Examples\n"
    "\n"
    " ```gleam\n"
    " assert symmetric_difference(from_list([1, 2, 3]), from_list([3, 4]))\n"
    "   |> to_list\n"
    "   == [1, 2, 4]\n"
    " ```\n"
).
-spec symmetric_difference(set(CXV), set(CXV)) -> set(CXV).
symmetric_difference(First, Second) ->
    difference(union(First, Second), intersection(First, Second)).

-file("src/gleam/set.gleam", 405).
?DOC(
    " Calls a function for each member in a set, discarding the return\n"
    " value.\n"
    "\n"
    " Useful for producing a side effect for every item of a set.\n"
    "\n"
    " The order of elements in the iteration is an implementation detail that\n"
    " should not be relied upon.\n"
    "\n"
    " ## Examples\n"
    "\n"
    " ```gleam\n"
    " let set = from_list([\"apple\", \"banana\", \"cherry\"])\n"
    "\n"
    " assert each(set, io.println) == Nil\n"
    " // apple\n"
    " // banana\n"
    " // cherry\n"
    " ```\n"
).
-spec each(set(CXZ), fun((CXZ) -> any())) -> nil.
each(Set, Fun) ->
    fold(
        Set,
        nil,
        fun(Nil, Member) ->
            Fun(Member),
            Nil
        end
    ).
