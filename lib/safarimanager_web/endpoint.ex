defmodule SMWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :safarimanager

  # The session will be stored in the cookie and signed,
  # this means its contents can be read but not tampered with.
  # Set :encryption_salt if you would also like to encrypt it.
  @session_options [
    store: :cookie,
    key: "_safarimanager_key",
    signing_salt: "hkvQEXLl"
  ]

  socket "/live", Phoenix.LiveView.Socket, websocket: [connect_info: [session: @session_options]]

  # Serve at "/" the static files from "priv/static" directory.
  #
  # You should set gzip to true if you are running phx.digest
  # when deploying your static files in production.
  plug Plug.Static,
    at: "/",
    from: :safarimanager,
    gzip: true,
    only: SMWeb.static_paths()

  plug Plug.Static,
    at: "/uploads",
    from: {SM.Slides, :get_uploads_path, []},
    gzip: false

  # Code reloading can be explicitly enabled under the
  # :code_reloader configuration of your endpoint.
  if code_reloading? do
    socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket
    plug Phoenix.LiveReloader
    plug Phoenix.CodeReloader
    plug Phoenix.Ecto.CheckRepoStatus, otp_app: :safarimanager
  end

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options
  plug SMWeb.Router

  @spec access_struct_url :: map()
  def access_struct_url do
    base =
      case struct_url() do
        %URI{scheme: "https", port: 0} = uri ->
          %{uri | port: SM.Utils.get_port(__MODULE__, :https, 433)}

        %URI{scheme: "http", port: 0} = uri ->
          %{uri | port: SM.Utils.get_port(__MODULE__, :http, 80)}

        %URI{} = uri ->
          uri
      end

    update_in(base.path, &(&1 || "/"))
  end

  @spec access_url :: String.t()
  def access_url do
    URI.to_string(access_struct_url())
  end
end
