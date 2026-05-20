-record(number_literal, {
    raw :: binary(),
    value :: float(),
    notation :: math@ast:number_notation(),
    decimal_places :: gleam@option:option(integer())
}).
