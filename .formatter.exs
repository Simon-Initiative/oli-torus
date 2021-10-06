[
  import_deps: [:ecto, :phoenix, :surface],
  surface_inputs: ["{lib,test}/**/*.{ex,exs,sface}"],
  inputs: ["*.{ex,exs}", "priv/*/seeds.exs", "{config,lib,test}/**/*.{ex,exs}"],
  subdirectories: ["priv/*/migrations"]
]
