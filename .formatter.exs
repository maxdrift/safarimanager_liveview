[
  import_deps: [:ecto, :phoenix, :surface, :tesla],
  inputs: [
    "*.{ex,exs,sface,heex}",
    "priv/*/seeds.exs",
    "{config,lib,test}/**/*.{ex,exs,sface,heex}"
  ],
  subdirectories: ["priv/*/migrations"],
  plugins: [Surface.Formatter.Plugin, Phoenix.LiveView.HTMLFormatter, Styler]
]
