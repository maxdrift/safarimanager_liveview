import Config

# Build ex_image_resizer from source until precompiled NIFs + checksum-Elixir.ExImageResizer.exs are published for your targets.
config :rustler_precompiled, :force_build, ex_image_resizer: true

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n"

# Initialize plugs at runtime for faster development compilation
config :phoenix, :plug_init_mode, :runtime

# Set a higher stacktrace during development. Avoid configuring such
# in production as building large stacktraces may be expensive.
config :phoenix, :stacktrace_depth, 20

config :safarimanager, SMWeb.Endpoint,
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  watchers: [
    npx: [
      "tailwindcss",
      "--input=css/app.css",
      "--output=../priv/static/assets/app.css",
      "--postcss",
      "--watch",
      cd: Path.expand("../assets", __DIR__)
    ],
    # Start the esbuild watcher by calling Esbuild.install_and_run(:default, args)
    esbuild: {Esbuild, :install_and_run, [:default, ~w(--sourcemap=inline --watch)]}
  ],
  # Watch static and templates for browser reloading.
  reloadable_compilers: [:gettext, :elixir],
  web_console_logger: true,
  live_reload: [
    patterns: [
      ~r"priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"priv/gettext/.*(po)$",
      ~r"lib/safarimanager_web/(live|views|components)/.*(ex|heex|js)$",
      ~r"lib/safarimanager_web/templates/.*(eex)$"
    ]
  ]
