[
  import_deps: [:ecto, :phoenix, :surface],
  inputs: [
    "*.{heex,ex,exs,sface}",
    "priv/*/seeds.exs",
    "{config,lib,test}/**/*.{heex,ex,exs,sface}"
  ],
  subdirectories: ["priv/*/migrations"],
  plugins: [Phoenix.LiveView.HTMLFormatter, Surface.Formatter.Plugin]
]
