[
  import_deps: [:ecto, :phoenix, :surface],
  inputs: [
    "lib/**/*.{ex,sface}",
    "*.{ex,exs}",
    "priv/*/seeds.exs",
    "{config,lib,test}/**/*.{ex,exs}"
  ],
  subdirectories: ["priv/*/migrations"],
  plugins: [Surface.Formatter.Plugin]
]
