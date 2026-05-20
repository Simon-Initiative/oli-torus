-module(math@validate).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/math/validate.gleam").
-export([validate_symbols/2]).

-if(?OTP_RELEASE >= 27).
-define(MODULEDOC(Str), -moduledoc(Str)).
-define(DOC(Str), -doc(Str)).
-else.
-define(MODULEDOC(Str), -compile([])).
-define(DOC(Str), -compile([])).
-endif.

-file("src/math/validate.gleam", 62).
-spec validate_args(list(math@ast:expr()), math@ast:symbol_config()) -> {ok,
        nil} |
    {error, math@ast:validation_error()}.
validate_args(Args, Config) ->
    case Args of
        [] ->
            {ok, nil};

        [First | Rest] ->
            case validate_expr(First, Config) of
                {ok, nil} ->
                    validate_args(Rest, Config);

                {error, Error} ->
                    {error, Error}
            end
    end.

-file("src/math/validate.gleam", 28).
-spec validate_expr(math@ast:expr(), math@ast:symbol_config()) -> {ok, nil} |
    {error, math@ast:validation_error()}.
validate_expr(Expr, Config) ->
    case erlang:element(2, Expr) of
        {num, _} ->
            {ok, nil};

        {const, _} ->
            {ok, nil};

        {var, Name} ->
            case gleam@list:contains(erlang:element(2, Config), Name) of
                true ->
                    {ok, nil};

                false ->
                    {error,
                        {unexpected_variable, erlang:element(3, Expr), Name}}
            end;

        {prefix, _, Arg} ->
            validate_expr(Arg, Config);

        {binary, _, Left, Right} ->
            case validate_expr(Left, Config) of
                {ok, nil} ->
                    validate_expr(Right, Config);

                {error, Error} ->
                    {error, Error}
            end;

        {call, Name@1, Args} ->
            case gleam@list:contains(erlang:element(3, Config), Name@1) of
                true ->
                    validate_args(Args, Config);

                false ->
                    {error,
                        {disallowed_function, erlang:element(3, Expr), Name@1}}
            end;

        {factorial, Arg@1} ->
            validate_expr(Arg@1, Config)
    end.

-file("src/math/validate.gleam", 7).
?DOC(
    " Validation intentionally accepts an already parsed AST. This keeps syntactic\n"
    " parser success independent from author settings, so activities can decide\n"
    " whether a symbol is allowed without changing what the parser recognizes.\n"
).
-spec validate_symbols(math@ast:parsed(), math@ast:symbol_config()) -> {ok,
        math@ast:parsed()} |
    {error, math@ast:validation_error()}.
validate_symbols(Parsed, Config) ->
    case Parsed of
        {expression, Expr} ->
            case validate_expr(Expr, Config) of
                {ok, nil} ->
                    {ok, Parsed};

                {error, Error} ->
                    {error, Error}
            end;

        {quantity, Value, _} ->
            case validate_expr(Value, Config) of
                {ok, nil} ->
                    {ok, Parsed};

                {error, Error@1} ->
                    {error, Error@1}
            end
    end.
