-record(symbol_config, {
    allowed_variables :: list(binary()),
    allowed_functions :: list(math@ast:function_name())
}).
