[
  import_deps: [:ecto, :phoenix, :surface],
  surface_inputs: ["{lib,test}/**/*.{ex,exs,sface}"],
  inputs: ["*.{heex,ex,exs}", "priv/*/seeds.exs", "{config,lib,test}/**/*.{heex,ex,exs}"],
  subdirectories: ["priv/*/migrations"],
  plugins: [Phoenix.LiveView.HTMLFormatter]
]
