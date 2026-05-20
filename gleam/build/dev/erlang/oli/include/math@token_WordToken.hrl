-record(word_token, {
    raw :: binary(),
    span :: math@ast:span(),
    leading_space :: boolean()
}).
