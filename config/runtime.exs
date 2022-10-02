import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

priv_dir = :code.priv_dir(:safarimanager) |> to_string()

priv_dir_uploads = Path.join(priv_dir, "/uploads")

uploads_path = System.get_env("UPLOADS_PATH", priv_dir_uploads)

unless File.exists?(uploads_path) do
  File.mkdir_p!(uploads_path)
end

config :safarimanager, SM.Slides.Slide, uploads_base_path: uploads_path

db_path =
  "DATABASE_PATH"
  |> System.get_env(priv_dir)
  |> Path.join("safarimanager.db")

unless File.exists?(db_path) do
  File.mkdir_p!(Path.dirname(db_path))
  File.touch!(db_path)
end

config :safarimanager, SM.Repo, database: db_path

config :logger, level: String.to_atom(System.get_env("LOG_LEVEL", "info"))

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

url_host = System.get_env("URL_HOST", "localhost")
url_port = "URL_PORT" |> System.get_env("443") |> String.to_integer()

http_ip = {0, 0, 0, 0, 0, 0, 0, 0}
http_port = "HTTP_PORT" |> System.get_env("4000") |> String.to_integer()

allowed_origins =
  "ALLOWED_ORIGINS"
  |> System.get_env("")
  |> String.split(",", trim: true)

config :safarimanager, SMWeb.Endpoint,
  url: [host: url_host, port: 443],
  http: [
    # Enable IPv6 and bind on all interfaces.
    # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
    # See the documentation on https://hexdocs.pm/plug_cowboy/Plug.Cowboy.html
    # for details about using IPv6 vs IPv4 and loopback vs public addresses.
    ip: http_ip,
    port: http_port
  ],
  check_origin: [
    "http://#{url_host}:#{url_port}",
    "http://#{url_host}:#{http_port}" | allowed_origins
  ],
  secret_key_base: secret_key_base,
  live_view: [signing_salt: lv_signing_salt]

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

# end

{:ok, hostname} = :inet.gethostname()

config :safarimanager, SMWeb.TelemetryPusher,
  instance_id: System.get_env("INSTANCE_ID", to_string(hostname))

config :safarimanager, SMWeb.PrometheusPush,
  url: System.get_env("PROMETHEUS_PUSH_GW_HOST", "https://prometheus.maxdrift.org"),
  basic_auth: [
    username: System.get_env("PROMETHEUS_PUSH_GW_USER", "safarimanager"),
    password: System.get_env("PROMETHEUS_PUSH_GW_PASSWORD")
  ]
