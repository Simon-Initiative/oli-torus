-module(math@lexer).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/math/lexer.gleam").
-export([lex/1]).

-if(?OTP_RELEASE >= 27).
-define(MODULEDOC(Str), -moduledoc(Str)).
-define(DOC(Str), -doc(Str)).
-else.
-define(MODULEDOC(Str), -compile([])).
-define(DOC(Str), -compile([])).
-endif.

-file("src/math/lexer.gleam", 462).
-spec symbol_for(binary()) -> {ok, math@token:symbol()} | {error, nil}.
symbol_for(Raw) ->
    case Raw of
        <<"+"/utf8>> ->
            {ok, plus};

        <<"-"/utf8>> ->
            {ok, minus};

        <<"*"/utf8>> ->
            {ok, star};

        <<"/"/utf8>> ->
            {ok, slash};

        <<"^"/utf8>> ->
            {ok, caret};

        <<"("/utf8>> ->
            {ok, l_paren};

        <<")"/utf8>> ->
            {ok, r_paren};

        <<"|"/utf8>> ->
            {ok, bar};

        <<"!"/utf8>> ->
            {ok, bang};

        <<","/utf8>> ->
            {ok, comma};

        _ ->
            {error, nil}
    end.

-file("src/math/lexer.gleam", 458).
-spec join_chars(list(binary())) -> binary().
join_chars(Chars) ->
    gleam@string:join(Chars, <<""/utf8>>).

-file("src/math/lexer.gleam", 508).
-spec grapheme_code(binary()) -> integer().
grapheme_code(Raw) ->
    case gleam@string:to_utf_codepoints(Raw) of
        [Codepoint] ->
            gleam_stdlib:identity(Codepoint);

        _ ->
            -1
    end.

-file("src/math/lexer.gleam", 497).
-spec is_digit(binary()) -> boolean().
is_digit(Raw) ->
    case gleam@string:to_graphemes(Raw) of
        [Grapheme] ->
            Code = grapheme_code(Grapheme),
            (Code >= 48) andalso (Code =< 57);

        _ ->
            false
    end.

-file("src/math/lexer.gleam", 486).
-spec is_alpha(binary()) -> boolean().
is_alpha(Raw) ->
    case gleam@string:to_graphemes(Raw) of
        [Grapheme] ->
            Code = grapheme_code(Grapheme),
            ((Code >= 65) andalso (Code =< 90)) orelse ((Code >= 97) andalso (Code
            =< 122));

        _ ->
            false
    end.

-file("src/math/lexer.gleam", 482).
-spec is_word_continue(binary()) -> boolean().
is_word_continue(Raw) ->
    is_alpha(Raw) orelse is_digit(Raw).

-file("src/math/lexer.gleam", 440).
-spec take_while(
    list(binary()),
    integer(),
    fun((binary()) -> boolean()),
    list(binary())
) -> {list(binary()), list(binary()), integer()}.
take_while(Chars, Offset, Predicate, Acc) ->
    case Chars of
        [First | Rest] ->
            case Predicate(First) of
                true ->
                    take_while(Rest, Offset + 1, Predicate, [First | Acc]);

                false ->
                    {lists:reverse(Acc), Chars, Offset}
            end;

        [] ->
            {lists:reverse(Acc), Chars, Offset}
    end.

-file("src/math/lexer.gleam", 404).
-spec read_leading_dot_error(list(binary()), integer()) -> math@ast:parse_error().
read_leading_dot_error(Chars, Start) ->
    case Chars of
        [<<"."/utf8>> | Rest] ->
            {Fraction, _, End_offset} = take_while(
                Rest,
                Start + 1,
                fun is_digit/1,
                []
            ),
            case Fraction of
                [] ->
                    {unsupported_character,
                        {span, Start, Start + 1},
                        <<"."/utf8>>};

                _ ->
                    {invalid_number,
                        {span, Start, End_offset},
                        join_chars([<<"."/utf8>> | Fraction])}
            end;

        _ ->
            {unsupported_character, {span, Start, Start + 1}, <<"."/utf8>>}
    end.

-file("src/math/lexer.gleam", 387).
-spec normalize_scientific_for_parse(binary()) -> binary().
normalize_scientific_for_parse(Raw) ->
    Normalized_marker = gleam@string:replace(Raw, <<"E"/utf8>>, <<"e"/utf8>>),
    case gleam_stdlib:contains_string(Normalized_marker, <<"."/utf8>>) of
        true ->
            Normalized_marker;

        false ->
            case gleam@string:split_once(Normalized_marker, <<"e"/utf8>>) of
                {ok, {Mantissa, Exponent}} ->
                    <<<<Mantissa/binary, ".0e"/utf8>>/binary, Exponent/binary>>;

                {error, nil} ->
                    Normalized_marker
            end
    end.

-file("src/math/lexer.gleam", 368).
-spec parse_number_value(binary(), math@ast:number_notation()) -> {ok, float()} |
    {error, nil}.
parse_number_value(Raw, Notation) ->
    case Notation of
        integer_notation ->
            case gleam_stdlib:parse_int(Raw) of
                {ok, Value} ->
                    {ok, erlang:float(Value)};

                {error, nil} ->
                    {error, nil}
            end;

        decimal_notation ->
            gleam_stdlib:parse_float(Raw);

        scientific_notation ->
            _pipe = normalize_scientific_for_parse(Raw),
            gleam_stdlib:parse_float(_pipe)
    end.

-file("src/math/lexer.gleam", 339).
-spec finish_number(
    binary(),
    list(binary()),
    integer(),
    integer(),
    math@ast:number_notation(),
    gleam@option:option(integer())
) -> {ok, {math@ast:number_literal(), list(binary()), integer()}} |
    {error, math@ast:parse_error()}.
finish_number(Raw, Rest, End_offset, Start, Notation, Decimal_places) ->
    case parse_number_value(Raw, Notation) of
        {ok, Value} ->
            {ok,
                {{number_literal, Raw, Value, Notation, Decimal_places},
                    Rest,
                    End_offset}};

        {error, nil} ->
            {error, {invalid_number, {span, Start, End_offset}, Raw}}
    end.

-file("src/math/lexer.gleam", 323).
-spec invalid_exponent(binary(), binary(), binary(), integer(), integer()) -> {ok,
        {math@ast:number_literal(), list(binary()), integer()}} |
    {error, math@ast:parse_error()}.
invalid_exponent(Prefix, Marker, Sign, Start, End_offset) ->
    {error,
        {invalid_number,
            {span, Start, End_offset},
            <<<<Prefix/binary, Marker/binary>>/binary, Sign/binary>>}}.

-file("src/math/lexer.gleam", 433).
-spec unsupported_comma(integer()) -> math@ast:parse_error().
unsupported_comma(Offset) ->
    {unsupported_character, {span, Offset, Offset + 1}, <<","/utf8>>}.

-file("src/math/lexer.gleam", 280).
-spec read_exponent(
    binary(),
    binary(),
    list(binary()),
    integer(),
    integer(),
    gleam@option:option(integer())
) -> {ok, {math@ast:number_literal(), list(binary()), integer()}} |
    {error, math@ast:parse_error()}.
read_exponent(
    Prefix,
    Marker,
    After_marker,
    Marker_offset,
    Start,
    Decimal_places
) ->
    {Sign, Exponent_chars, Exponent_start} = case After_marker of
        [<<"+"/utf8>> | Rest] ->
            {<<"+"/utf8>>, Rest, Marker_offset + 2};

        [<<"-"/utf8>> | Rest@1] ->
            {<<"-"/utf8>>, Rest@1, Marker_offset + 2};

        _ ->
            {<<""/utf8>>, After_marker, Marker_offset + 1}
    end,
    case Exponent_chars of
        [First_digit | _] ->
            case is_digit(First_digit) of
                true ->
                    {Exponent_digits, Rest@2, End_offset} = take_while(
                        Exponent_chars,
                        Exponent_start,
                        fun is_digit/1,
                        []
                    ),
                    case Rest@2 of
                        [<<","/utf8>> | _] ->
                            {error, unsupported_comma(End_offset)};

                        _ ->
                            finish_number(
                                <<<<<<Prefix/binary, Marker/binary>>/binary,
                                        Sign/binary>>/binary,
                                    (join_chars(Exponent_digits))/binary>>,
                                Rest@2,
                                End_offset,
                                Start,
                                scientific_notation,
                                Decimal_places
                            )
                    end;

                false ->
                    invalid_exponent(
                        Prefix,
                        Marker,
                        Sign,
                        Start,
                        Exponent_start
                    )
            end;

        [] ->
            invalid_exponent(Prefix, Marker, Sign, Start, Exponent_start)
    end.

-file("src/math/lexer.gleam", 226).
-spec invalid_decimal(list(binary()), integer(), integer()) -> {ok,
        {math@ast:number_literal(), list(binary()), integer()}} |
    {error, math@ast:parse_error()}.
invalid_decimal(Whole, Start, End_offset) ->
    {error,
        {invalid_number,
            {span, Start, End_offset},
            join_chars(lists:append(Whole, [<<"."/utf8>>]))}}.

-file("src/math/lexer.gleam", 237).
-spec read_number_after_mantissa(
    binary(),
    list(binary()),
    integer(),
    integer(),
    math@ast:number_notation(),
    gleam@option:option(integer())
) -> {ok, {math@ast:number_literal(), list(binary()), integer()}} |
    {error, math@ast:parse_error()}.
read_number_after_mantissa(
    Raw_prefix,
    Rest,
    Current_offset,
    Start,
    Notation,
    Decimal_places
) ->
    case Rest of
        [<<","/utf8>> | _] ->
            {error, unsupported_comma(Current_offset)};

        [<<"e"/utf8>> | After_marker] ->
            read_exponent(
                Raw_prefix,
                <<"e"/utf8>>,
                After_marker,
                Current_offset,
                Start,
                Decimal_places
            );

        [<<"E"/utf8>> | After_marker@1] ->
            read_exponent(
                Raw_prefix,
                <<"E"/utf8>>,
                After_marker@1,
                Current_offset,
                Start,
                Decimal_places
            );

        _ ->
            finish_number(
                Raw_prefix,
                Rest,
                Current_offset,
                Start,
                Notation,
                Decimal_places
            )
    end.

-file("src/math/lexer.gleam", 190).
-spec read_decimal(list(binary()), list(binary()), integer(), integer()) -> {ok,
        {math@ast:number_literal(), list(binary()), integer()}} |
    {error, math@ast:parse_error()}.
read_decimal(Whole, After_dot, Start, Dot_offset) ->
    Fraction_start = Dot_offset + 1,
    case After_dot of
        [First_fraction | _] ->
            case is_digit(First_fraction) of
                true ->
                    {Fraction, Rest_after_fraction, After_fraction} = take_while(
                        After_dot,
                        Fraction_start,
                        fun is_digit/1,
                        []
                    ),
                    Raw_prefix = join_chars(
                        lists:append(
                            lists:append(Whole, [<<"."/utf8>>]),
                            Fraction
                        )
                    ),
                    read_number_after_mantissa(
                        Raw_prefix,
                        Rest_after_fraction,
                        After_fraction,
                        Start,
                        decimal_notation,
                        {some, erlang:length(Fraction)}
                    );

                false ->
                    invalid_decimal(Whole, Start, Fraction_start)
            end;

        [] ->
            invalid_decimal(Whole, Start, Fraction_start)
    end.

-file("src/math/lexer.gleam", 147).
-spec read_number(list(binary()), integer()) -> {ok,
        {math@ast:number_literal(), list(binary()), integer()}} |
    {error, math@ast:parse_error()}.
read_number(Chars, Start) ->
    {Whole, Rest, After_whole} = take_while(Chars, Start, fun is_digit/1, []),
    case Rest of
        [<<","/utf8>> | _] ->
            {error, unsupported_comma(After_whole)};

        [<<"."/utf8>> | After_dot] ->
            read_decimal(Whole, After_dot, Start, After_whole);

        [<<"e"/utf8>> | After_marker] ->
            read_exponent(
                join_chars(Whole),
                <<"e"/utf8>>,
                After_marker,
                After_whole,
                Start,
                {some, 0}
            );

        [<<"E"/utf8>> | After_marker@1] ->
            read_exponent(
                join_chars(Whole),
                <<"E"/utf8>>,
                After_marker@1,
                After_whole,
                Start,
                {some, 0}
            );

        _ ->
            finish_number(
                join_chars(Whole),
                Rest,
                After_whole,
                Start,
                integer_notation,
                none
            )
    end.

-file("src/math/lexer.gleam", 478).
-spec is_whitespace(binary()) -> boolean().
is_whitespace(Raw) ->
    (((Raw =:= <<" "/utf8>>) orelse (Raw =:= <<"\n"/utf8>>)) orelse (Raw =:= <<"\t"/utf8>>))
    orelse (Raw =:= <<"\r"/utf8>>).

-file("src/math/lexer.gleam", 83).
-spec lex_symbol(
    list(binary()),
    binary(),
    integer(),
    boolean(),
    list(math@token:token())
) -> {ok, list(math@token:token())} | {error, math@ast:parse_error()}.
lex_symbol(Chars, First, Offset, Leading_space, Acc) ->
    case Chars of
        [_ | Rest] ->
            case symbol_for(First) of
                {ok, Symbol} ->
                    Span = {span, Offset, Offset + 1},
                    Next = {symbol_token, Symbol, Span, Leading_space},
                    do_lex(Rest, Offset + 1, false, [Next | Acc]);

                {error, nil} ->
                    {error,
                        {unsupported_character,
                            {span, Offset, Offset + 1},
                            First}}
            end;

        [] ->
            {error, {unsupported_character, {span, Offset, Offset + 1}, First}}
    end.

-file("src/math/lexer.gleam", 56).
-spec lex_word_or_symbol(
    list(binary()),
    binary(),
    integer(),
    boolean(),
    list(math@token:token())
) -> {ok, list(math@token:token())} | {error, math@ast:parse_error()}.
lex_word_or_symbol(Chars, First, Offset, Leading_space, Acc) ->
    case is_alpha(First) of
        true ->
            {Raw_chars, Rest, Next_offset} = take_while(
                Chars,
                Offset,
                fun is_word_continue/1,
                []
            ),
            Span = {span, Offset, Next_offset},
            Next = {word_token, join_chars(Raw_chars), Span, Leading_space},
            do_lex(Rest, Next_offset, false, [Next | Acc]);

        false ->
            lex_symbol(Chars, First, Offset, Leading_space, Acc)
    end.

-file("src/math/lexer.gleam", 124).
-spec lex_number(list(binary()), integer(), boolean(), list(math@token:token())) -> {ok,
        list(math@token:token())} |
    {error, math@ast:parse_error()}.
lex_number(Chars, Offset, Leading_space, Acc) ->
    case read_number(Chars, Offset) of
        {ok, {Literal, Rest, Next_offset}} ->
            Span = {span, Offset, Next_offset},
            Next = {number_token, Literal, Span, Leading_space},
            do_lex(Rest, Next_offset, false, [Next | Acc]);

        {error, Error} ->
            {error, Error}
    end.

-file("src/math/lexer.gleam", 38).
-spec lex_non_whitespace(
    list(binary()),
    binary(),
    integer(),
    boolean(),
    list(math@token:token())
) -> {ok, list(math@token:token())} | {error, math@ast:parse_error()}.
lex_non_whitespace(Chars, First, Offset, Leading_space, Acc) ->
    case is_digit(First) of
        true ->
            lex_number(Chars, Offset, Leading_space, Acc);

        false ->
            case First of
                <<"."/utf8>> ->
                    {error, read_leading_dot_error(Chars, Offset)};

                _ ->
                    lex_word_or_symbol(Chars, First, Offset, Leading_space, Acc)
            end
    end.

-file("src/math/lexer.gleam", 16).
-spec do_lex(list(binary()), integer(), boolean(), list(math@token:token())) -> {ok,
        list(math@token:token())} |
    {error, math@ast:parse_error()}.
do_lex(Chars, Offset, Leading_space, Acc) ->
    case Chars of
        [] ->
            {ok, lists:reverse(Acc)};

        [First | Rest] ->
            case is_whitespace(First) of
                true ->
                    do_lex(Rest, Offset + 1, true, Acc);

                false ->
                    lex_non_whitespace(Chars, First, Offset, Leading_space, Acc)
            end
    end.

-file("src/math/lexer.gleam", 12).
?DOC(
    " Lexing is the first place we make syntax commitments, so it keeps the rules\n"
    " strict and explicit. Later parser phases can depend on tokens having stable\n"
    " spans, number metadata, and whitespace-boundary information.\n"
).
-spec lex(binary()) -> {ok, list(math@token:token())} |
    {error, math@ast:parse_error()}.
lex(Input) ->
    do_lex(gleam@string:to_graphemes(Input), 0, false, []).
