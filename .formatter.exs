[
  import_deps: [:ecto, :ecto_sql, :phoenix, :tesla],
  inputs: [
    "*.{ex,exs,heex}",
    "priv/*/seeds.exs",
    "{lib,test}/**/*.{ex,exs,heex}"
  ],
  subdirectories: ["priv/*/migrations", "config"],
  plugins: [Phoenix.LiveView.HTMLFormatter, Styler]
]
