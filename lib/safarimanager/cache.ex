defmodule SM.Cache do
  @moduledoc false
  use Nebulex.Cache,
    otp_app: :safarimanager,
    adapter: Nebulex.Adapters.Local
end
