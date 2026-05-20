-record(unexpected_token, {
    span :: math@ast:span(),
    expected :: list(binary()),
    found :: binary()
}).
