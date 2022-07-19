# Server-side coding standard

## Code Formatting

This project uses the default Elixir code formatting rules through running `mix format`. To enable auto-format on save, install the _ElixirLS_ plugin for your code editor and add a configuration option. For Visual Studio Code, you can do this by opening the config file with `cmd+p`, typing `> Open Settings`, and adding this line:

- `"editor.formatOnSave": true`

## UI Code

User interface code can be implemented using either traditional, stateless controller rendered templated views or with stateful Phoenix LiveView implementations. For Phoenix LiveView implemented user interfaces, all new views and components should be implemented using the Surface library.
