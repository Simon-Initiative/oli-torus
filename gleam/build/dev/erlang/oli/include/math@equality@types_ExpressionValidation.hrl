-record(expression_validation, {
    allowed_variables :: list(binary()),
    allowed_functions :: list(math@ast:function_name()),
    domains :: list(math@equality@types:variable_domain())
}).
