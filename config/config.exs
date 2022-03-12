# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :safarimanager,
  namespace: SM,
  ecto_repos: [SM.Repo]

config :safarimanager, SM.Repo,
  migration_primary_key: [name: :id, type: :binary_id],
  migration_foreign_key: [column: :id, type: :binary_id],
  migration_timestamps: [type: :utc_datetime_usec]

# Configures the endpoint
config :safarimanager, SMWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [view: SMWeb.ErrorView, accepts: ~w(json), layout: false],
  pubsub_server: SM.PubSub,
  live_view: [signing_salt: "pCkmwrnY"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :safarimanager, SM.Mailer, adapter: Swoosh.Adapters.Local

config :safarimanager, SM.Subjects.Subject,
  types: [:fish, :macro, :fish_macro, :ambient],
  coefficients: [2, 4, 6]

config :safarimanager, SM.Slides.Slide,
  statuses: [:discarded, :submitted_jury, :submitted_fixed],
  uploads_path: fn competition_id, user_id -> "/uploads/#{competition_id}/#{user_id}" end

config :safarimanager, :generators,
  binary_id: true,
  sample_binary_id: "11111111-1111-1111-1111-111111111111"

# Swoosh API client is needed for adapters other than SMTP.
config :swoosh, :api_client, false

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.14.0",
  default: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :surface, :components, [
  {Surface.Components.Form.ErrorTag,
   default_translator: {SMWeb.ErrorHelpers, :translate_error}, default_class: "label-text-al"}
]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
