[
  import_deps: [:ecto, :ecto_sql, :phoenix, :surface],
  plugins: [Phoenix.LiveView.HTMLFormatter],
  surface_inputs: ["{lib,test}/**/*.{ex,exs,sface}"],
  inputs: ["*.{heex,ex,exs}", "priv/*/seeds.exs", "{config,lib,test}/**/*.{heex,ex,exs}"],
  subdirectories: ["priv/*/migrations"]
]
