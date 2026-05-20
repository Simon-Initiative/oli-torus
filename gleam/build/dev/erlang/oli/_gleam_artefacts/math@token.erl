-module(math@token).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/math/token.gleam").
-export([span/1, has_leading_space/1]).
-export_type([token/0, symbol/0]).

-if(?OTP_RELEASE >= 27).
-define(MODULEDOC(Str), -moduledoc(Str)).
-define(DOC(Str), -doc(Str)).
-else.
-define(MODULEDOC(Str), -compile([])).
-define(DOC(Str), -compile([])).
-endif.

-type token() :: {number_token,
        math@ast:number_literal(),
        math@ast:span(),
        boolean()} |
    {word_token, binary(), math@ast:span(), boolean()} |
    {symbol_token, symbol(), math@ast:span(), boolean()}.

-type symbol() :: plus |
    minus |
    star |
    slash |
    caret |
    l_paren |
    r_paren |
    bar |
    bang |
    comma.

-file("src/math/token.gleam", 31).
?DOC(
    " Parser code should use this helper rather than duplicating token pattern\n"
    " matches when it only needs a source span.\n"
).
-spec span(token()) -> math@ast:span().
span(Token) ->
    case Token of
        {number_token, _, Span, _} ->
            Span;

        {word_token, _, Span@1, _} ->
            Span@1;

        {symbol_token, _, Span@2, _} ->
            Span@2
    end.

-file("src/math/token.gleam", 41).
?DOC(
    " Parser and future unit logic should ask this helper for whitespace boundary\n"
    " information so the token representation can evolve behind one function.\n"
).
-spec has_leading_space(token()) -> boolean().
has_leading_space(Token) ->
    case Token of
        {number_token, _, _, Leading_space} ->
            Leading_space;

        {word_token, _, _, Leading_space@1} ->
            Leading_space@1;

        {symbol_token, _, _, Leading_space@2} ->
            Leading_space@2
    end.
