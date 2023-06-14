defmodule SM.Cache do
  use Nebulex.Cache,
    otp_app: :safarimanager,
    adapter: Nebulex.Adapters.Local
end
