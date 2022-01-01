defmodule SM.Repo do
  use Ecto.Repo,
    otp_app: :safarimanager,
    adapter: Ecto.Adapters.Postgres
end
