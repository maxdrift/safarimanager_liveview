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
  migration_timestamps: [type: :utc_datetime_usec],
  show_sensitive_data_on_connection_error: true

# Configures the endpoint
config :safarimanager, SMWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [
    formats: [
      html: SMWeb.ErrorHTML
    ],
    layout: false,
    log: :debug
  ],
  pubsub_server: SM.PubSub,
  server: true

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

config :safarimanager, SM.Evaluations.Evaluation, types: [:numeric]

config :safarimanager, SM.Slides.Slide,
  statuses: [:discarded, :submitted_jury, :submitted_fixed],
  uploads_base_path: "/uploads",
  thumbnails: [
    small: {100, 100},
    medium: {1280, 1280},
    large: {2560, 2560}
  ]

config :safarimanager, SM.Competitions.CompetitionSettings,
  defaults: [
    evaluations_per_juror: 1,
    number_of_jurors: 3,
    max_jury_slides: 15,
    max_submitted_slides: 99,
    proportional_submission: true,
    submission_ratio: "0.25",
    fixed_points_multiplier: "5.0",
    penalty_amount: "-100",
    dynamic_coefficients: [
      %{name: "max", from: "0", to: "0.33", value: "1"},
      %{name: "mid", from: "0.33", to: "0.66", value: "1"},
      %{name: "min", from: "0.66", to: "1.0", value: "1"}
    ]
  ]

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

# config :tesla, :adapter, {Tesla.Adapter.Finch, name: SMFinch}

config :surface, :components, [
  {Surface.Components.Form.ErrorTag,
   default_translator: {SMWeb.ErrorHelpers, :translate_error}, default_class: "label-text-al"},
  {SMWeb.Components.Admin.Users.Form, propagate_context_to_slots: false},
  {SMWeb.Components.Admin.Competitions.Form, propagate_context_to_slots: false}
]

config :safarimanager, SM.PromEx,
  disabled: false,
  manual_metrics_start_delay: :no_delay,
  drop_metrics_groups: [],
  grafana: :disabled,
  metrics_server: :disabled

config :gettext, :default_locale, "it"

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
