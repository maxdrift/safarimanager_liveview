import Config

# Only in tests, remove the complexity from the password hashing algorithm
config :bcrypt_elixir, :log_rounds, 1

# Configure your database
config :safarimanager, SM.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "safarimanager_test",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :safarimanager, SMWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "LGY+YLBArtMn1SS2N8vx5S0dqSXFusK72PKwcr1RbHJxRxiZWu3HHJQRz2KVmCLk",
  server: false

# In test we don't send emails.
config :safarimanager, SM.Mailer, adapter: Swoosh.Adapters.Test

# Print only warnings and errors during test
config :logger, level: :warn

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime
