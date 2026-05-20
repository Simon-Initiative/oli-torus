-module(gleam@dynamic).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/gleam/dynamic.gleam").
-export([classify/1, bool/1, string/1, float/1, int/1, bit_array/1, list/1, array/1, properties/1, nil/0]).
-export_type([dynamic_/0]).

-if(?OTP_RELEASE >= 27).
-define(MODULEDOC(Str), -moduledoc(Str)).
-define(DOC(Str), -doc(Str)).
-else.
-define(MODULEDOC(Str), -compile([])).
-define(DOC(Str), -compile([])).
-endif.

-type dynamic_() :: any().

-file("src/gleam/dynamic.gleam", 29).
?DOC(
    " Return a string indicating the type of the dynamic value.\n"
    "\n"
    " This function may be useful for constructing error messages or logs. If you\n"
    " want to turn dynamic data into well typed data then you want the\n"
    " `gleam/dynamic/decode` module.\n"
    "\n"
    " ```gleam\n"
    " assert classify(string(\"Hello\")) == \"String\"\n"
    " ```\n"
).
-spec classify(dynamic_()) -> binary().
classify(Data) ->
    gleam_stdlib:classify_dynamic(Data).

-file("src/gleam/dynamic.gleam", 35).
?DOC(" Create a dynamic value from a bool.\n").
-spec bool(boolean()) -> dynamic_().
bool(A) ->
    gleam_stdlib:identity(A).

-file("src/gleam/dynamic.gleam", 43).
?DOC(
    " Create a dynamic value from a string.\n"
    "\n"
    " On Erlang this will be a binary string rather than a character list.\n"
).
-spec string(binary()) -> dynamic_().
string(A) ->
    gleam_stdlib:identity(A).

-file("src/gleam/dynamic.gleam", 49).
?DOC(" Create a dynamic value from a float.\n").
-spec float(float()) -> dynamic_().
float(A) ->
    gleam_stdlib:identity(A).

-file("src/gleam/dynamic.gleam", 55).
?DOC(" Create a dynamic value from an int.\n").
-spec int(integer()) -> dynamic_().
int(A) ->
    gleam_stdlib:identity(A).

-file("src/gleam/dynamic.gleam", 61).
?DOC(" Create a dynamic value from a bit array.\n").
-spec bit_array(bitstring()) -> dynamic_().
bit_array(A) ->
    gleam_stdlib:identity(A).

-file("src/gleam/dynamic.gleam", 67).
?DOC(" Create a dynamic value from a list.\n").
-spec list(list(dynamic_())) -> dynamic_().
list(A) ->
    gleam_stdlib:identity(A).

-file("src/gleam/dynamic.gleam", 76).
?DOC(
    " Create a dynamic value from a list, converting it to a sequential runtime\n"
    " format rather than the regular list format.\n"
    "\n"
    " On Erlang this will be a tuple, on JavaScript this will be an array.\n"
).
-spec array(list(dynamic_())) -> dynamic_().
array(A) ->
    erlang:list_to_tuple(A).

-file("src/gleam/dynamic.gleam", 84).
?DOC(
    " Create a dynamic value made of an unordered series of keys and values, where\n"
    " the keys are unique.\n"
    "\n"
    " On Erlang this will be a map, on JavaScript this will be a Gleam dict\n"
    " object.\n"
).
-spec properties(list({dynamic_(), dynamic_()})) -> dynamic_().
properties(Entries) ->
    gleam_stdlib:identity(maps:from_list(Entries)).

-file("src/gleam/dynamic.gleam", 93).
?DOC(
    " A dynamic value representing nothing.\n"
    "\n"
    " On Erlang this will be the atom `nil`, on JavaScript this will be\n"
    " `undefined`.\n"
).
-spec nil() -> dynamic_().
nil() ->
    gleam_stdlib:identity(nil).
