-module(math@ast).
-compile([no_auto_import, nowarn_unused_vars, nowarn_unused_function, nowarn_nomatch, inline]).
-define(FILEPATH, "src/math/ast.gleam").
-export([default_parse_config/0]).
-export_type([parsed/0, expr/0, expr_kind/0, number_literal/0, number_notation/0, constant/0, prefix_op/0, binary_op/0, multiply_style/0, function_name/0, unit_expr/0, span/0, parse_config/0, parse_error/0, symbol_config/0, validation_error/0]).

-if(?OTP_RELEASE >= 27).
-define(MODULEDOC(Str), -moduledoc(Str)).
-define(DOC(Str), -doc(Str)).
-else.
-define(MODULEDOC(Str), -compile([])).
-define(DOC(Str), -compile([])).
-endif.

-type parsed() :: {expression, expr()} | {quantity, expr(), unit_expr()}.

-type expr() :: {expr, expr_kind(), span()}.

-type expr_kind() :: {num, number_literal()} |
    {var, binary()} |
    {const, constant()} |
    {prefix, prefix_op(), expr()} |
    {binary, binary_op(), expr(), expr()} |
    {call, function_name(), list(expr())} |
    {factorial, expr()}.

-type number_literal() :: {number_literal,
        binary(),
        float(),
        number_notation(),
        gleam@option:option(integer())}.

-type number_notation() :: integer_notation |
    decimal_notation |
    scientific_notation.

-type constant() :: pi | euler.

-type prefix_op() :: negate | positive.

-type binary_op() :: add |
    subtract |
    {multiply, multiply_style()} |
    divide |
    power.

-type multiply_style() :: explicit_multiply | implicit_multiply.

-type function_name() :: sin |
    cos |
    tan |
    ln |
    log |
    log10 |
    log2 |
    sqrt |
    abs |
    exp.

-type unit_expr() :: {unit_atom, binary()} |
    {unit_mul, unit_expr(), unit_expr()} |
    {unit_div, unit_expr(), unit_expr()} |
    {unit_pow, unit_expr(), integer()}.

-type span() :: {span, integer(), integer()}.

-type parse_config() :: parse_config.

-type parse_error() :: {unexpected_token, span(), list(binary()), binary()} |
    {unexpected_end, list(binary())} |
    {invalid_number, span(), binary()} |
    {unsupported_character, span(), binary()} |
    {unsupported_function, span(), binary()} |
    {function_requires_parentheses, span(), binary()} |
    {unclosed_parenthesis, span()} |
    {unclosed_absolute_value, span()} |
    {trailing_input, span()}.

-type symbol_config() :: {symbol_config, list(binary()), list(function_name())}.

-type validation_error() :: {unexpected_variable, span(), binary()} |
    {disallowed_function, span(), function_name()}.

-file("src/math/ast.gleam", 147).
?DOC(
    " The default parse config is centralized so callers do not invent their own\n"
    " defaults before grammar toggles exist.\n"
).
-spec default_parse_config() -> parse_config().
default_parse_config() ->
    parse_config.
