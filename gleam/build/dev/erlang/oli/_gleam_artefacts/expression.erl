-module(expression).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/expression.gleam").
-export([hello/1, parse/1]).

-file("src/expression.gleam", 1).
-spec hello(binary()) -> binary().
hello(Name) ->
    <<<<"Hello from Gleam, "/utf8, Name/binary>>/binary, "!"/utf8>>.

-file("src/expression.gleam", 5).
-spec parse(binary()) -> {ok, binary()} | {error, binary()}.
parse(Expression) ->
    {ok, <<"parsed: "/utf8, Expression/binary>>}.
