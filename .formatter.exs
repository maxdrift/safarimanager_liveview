[
  import_deps: [:ecto, :ecto_sql, :phoenix, :surface, :tesla],
  inputs: [
    "*.{ex,exs,sface,heex}",
    "priv/*/seeds.exs",
    "{lib,test}/**/*.{ex,exs,sface,heex}"
  ],
  subdirectories: ["priv/*/migrations", "config"],
  plugins: [Surface.Formatter.Plugin, Phoenix.LiveView.HTMLFormatter, Styler]
]
