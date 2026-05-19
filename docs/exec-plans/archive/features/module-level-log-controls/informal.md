# Informal Ticket Description

Torus provides the capability for an admin to set a log level but setting to useful levels like DEBUG and INFO when necessary can overwhelm the entire system and make logs difficult to parse.

We want to add the ability for a torus admin to set the log level at the elixir module level using the already capable Logger library.

Reference:
- https://hexdocs.pm/logger/Logger.html#put_module_level/2

By using the function `put_module_level(mod, level)` we can set the desired lower log level only for a given module to do issue investigations and debugging in production without overwhelming the system or having to use the iex shell directly to do so.

Nice to have:
- Also add support for `put_process_level(pid, level)` in case we ever want a particular log level at the process level as well.

This work is necessary to help to continue to debug some of the production LTI issues we have been experiencing, but will also be operationally useful for a bunch of other cases as well.
