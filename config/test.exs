import Config

database_path = Path.join(System.tmp_dir!(), "safarimanager/#{System.unique_integer()}-test-database.db")

uploads_path =
  Path.join(System.tmp_dir!(), "safarimanager/uploads")

# Only in tests, remove the complexity from the password hashing algorithm
config :bcrypt_elixir, :log_rounds, 1

# Print only warnings and errors during test
config :logger, level: :warn

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# In test we don't send emails.
config :safarimanager, SM.Mailer, adapter: Swoosh.Adapters.Test

# Configure your database
config :safarimanager, SM.Repo,
  database: database_path,
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 5

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :safarimanager, SM.Slides.Slide, uploads_base_path: uploads_path

config :safarimanager, SMWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "LGY+YLBArtMn1SS2N8vx5S0dqSXFusK72PKwcr1RbHJxRxiZWu3HHJQRz2KVmCLk",
  server: false
