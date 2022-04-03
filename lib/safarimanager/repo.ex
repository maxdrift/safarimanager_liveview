defmodule SM.Repo do
  use Ecto.Repo,
    otp_app: :safarimanager,
    # adapter: Ecto.Adapters.Postgres
    adapter: Ecto.Adapters.SQLite3
end
