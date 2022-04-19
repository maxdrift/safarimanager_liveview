defmodule SM.Repo do
  use Ecto.Repo,
    otp_app: :safarimanager,
    adapter: if(Mix.env() == :prod, do: Ecto.Adapters.Postgres, else: Ecto.Adapters.SQLite3)
end
