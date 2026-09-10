import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

alias SM.Slides.Slide

priv_dir = :safarimanager |> :code.priv_dir() |> to_string()
priv_dir_uploads = Path.join(priv_dir, "/uploads")

uploads_path =
  "UPLOADS_PATH"
  |> System.get_env(priv_dir_uploads)
  |> Path.expand()

config :safarimanager,
  shutdown_callback: {System, :stop, []}

if config_env() != :test do
  if !File.exists?(uploads_path) do
    File.mkdir_p!(uploads_path)
  end

  config :safarimanager, Slide, uploads_base_path: uploads_path
end

db_path =
  "DATABASE_PATH"
  |> System.get_env(priv_dir)
  |> Path.expand()
  |> Path.join("safarimanager.db")

config :safarimanager, Slide,
  direct_file_upload: System.get_env("DIRECT_FILE_UPLOAD", "true") == "true"

if config_env() != :test do
  if !File.exists?(db_path) do
    File.mkdir_p!(Path.dirname(db_path))
    File.touch!(db_path)
  end

  config :safarimanager, SM.Repo, database: db_path
end

secret_key_base =
  System.get_env("SECRET_KEY_BASE") ||
    raise """
    environment variable SECRET_KEY_BASE is missing.
    You can generate one by calling: mix phx.gen.secret
    """

lv_signing_salt =
  System.get_env("LV_SIGNING_SALT") ||
    raise """
    environment variable LV_SIGNING_SALT is missing.
    You can generate one by calling: mix phx.gen.secret 32
    """

http_ip = {0, 0, 0, 0}
http_port = "SAFARIMANAGER_PORT" |> System.get_env("4000") |> String.to_integer()
url_host = System.get_env("SAFARIMANAGER_HOST", "localhost")

allowed_origins =
  "ALLOWED_ORIGINS"
  |> System.get_env("")
  |> String.split(",", trim: true)

{:ok, hostname} = :inet.gethostname()

env =
  if config_env() == :prod and config_target() == :app do
    "app"
  else
    to_string(config_env())
  end

config :logger, :svadilfari,
  labels: [
    {"service", "safarimanager"},
    {"env", env},
    {"hostname", System.get_env("INSTANCE_ID", to_string(hostname))}
  ]

config :logger, level: String.to_atom(System.get_env("LOG_LEVEL", "info"))

config :safarimanager, SMWeb.Endpoint,
  url: [host: url_host],
  http: [
    # Enable IPv6 and bind on all interfaces.
    # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
    # See the documentation on https://hexdocs.pm/plug_cowboy/Plug.Cowboy.html
    # for details about using IPv6 vs IPv4 and loopback vs public addresses.
    ip: http_ip,
    port: http_port
  ],
  http: [
    ip: http_ip,
    port: http_port,
    http_1_options: [max_header_length: 32_768],
    # if Mix.target() == :app do
    #   config :safarimanager, SMWeb.Endpoint, check_origin: false
    # else
    #   config :safarimanager, SMWeb.Endpoint,
    #     check_origin: ["http://#{url_host}:#{url_port}" | allowed_origins]
    # end
    http_2_options: [max_header_value_length: 32_768]
  ],
  check_origin: false,
  secret_key_base: secret_key_base,
  live_view: [signing_salt: lv_signing_salt]

config :safarimanager, SMWeb.PrometheusPush,
  url: System.get_env("PROMETHEUS_PUSH_GW_HOST", "https://prometheus.maxdrift.org"),
  # ## Configuring the mailer
  #
  # In production you need to configure the mailer to use a different adapter.
  # Also, you may need to configure the Swoosh API client of your choice if you
  # are not using SMTP. Here is an example of the configuration:
  #
  #     config :safarimanager, SM.Mailer,
  #       adapter: Swoosh.Adapters.Mailgun,
  #       api_key: System.get_env("MAILGUN_API_KEY"),
  #       domain: System.get_env("MAILGUN_DOMAIN")
  #
  # For this example you need include a HTTP client required by Swoosh API client.
  # Swoosh supports Hackney and Finch out of the box:
  #
  #     config :swoosh, :api_client, Swoosh.ApiClient.Hackney
  #
  # See https://hexdocs.pm/swoosh/Swoosh.html#module-installation for details.
  basic_auth: [
    username: System.get_env("PROMETHEUS_PUSH_GW_USER", "safarimanager"),
    password: System.get_env("PROMETHEUS_PUSH_GW_PASSWORD")
  ]

config :safarimanager, SMWeb.TelemetryPusher,
  instance_id: System.get_env("INSTANCE_ID", to_string(hostname)),
  push_interval: System.get_env("TELEMETRY_PUSH_INTERVAL", "10000") |> String.to_integer()

# end

if config_env() != :test do
  config :gettext, :default_locale, System.get_env("SM_LOCALE", "en")
end
