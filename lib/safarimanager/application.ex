defmodule SM.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  require Logger

  @impl Application
  def start(_type, _args) do
    :ok = set_libvips_concurrency()

    children =
      [
        SM.PromEx,
        {Task.Supervisor, name: SM.TaskSupervisor},
        # Start the Ecto repository
        SM.Repo,
        # Finch init for Tesla
        {Finch, name: SMFinch, pools: %{default: [count: 1, size: 10]}},
        # Start the supervisor for the GenServer pushing metrics
        # to Prometheus
        SMWeb.TelemetryPusherSupervisor,
        # Start the PubSub system
        {Phoenix.PubSub, name: SM.PubSub},
        # Nebulex caching system
        SM.Cache,
        # Start the Endpoint (http/https)
        SMWeb.Endpoint,
        # Start a worker by calling: SM.Worker.start_link(arg)
        # {SM.Worker, arg}
        {SM.USBWatcherSupervisor, []}
      ] ++ app_specs()

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: SM.Supervisor]

    case Supervisor.start_link(children, opts) do
      {:ok, _} = result ->
        # TODO: Move migrations execution to ElixirKit pre-start action
        _repos = SM.Release.migrate()
        display_startup_info()

        result

      {:error, error} ->
        SM.Config.abort!(Application.format_error(error))
    end
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl Application
  def config_change(changed, _new, removed) do
    SMWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  # Internal

  defp display_startup_info do
    if Phoenix.Endpoint.server?(:safarimanager, SMWeb.Endpoint) do
      Logger.info("[Safari Manager] Application running at #{SMWeb.Endpoint.access_url()}")
    end

    db_path = Application.get_env(:safarimanager, SM.Repo)[:database]
    Logger.info("[Safari Manager] Database path set to: #{db_path}")

    uploads_path = Application.get_env(:safarimanager, SM.Slides.Slide)[:uploads_base_path]
    Logger.info("[Safari Manager] Uploads path set to #{uploads_path}")
  end

  defp set_libvips_concurrency do
    concurrency =
      System.schedulers_online()
      |> determine_concurrency()
      |> Image.put_concurrency()

    Logger.info("VIPS concurrency set to #{concurrency}")

    :ok
  end

  defp determine_concurrency(1) do
    1
  end

  defp determine_concurrency(number_of_schedulers)
       when number_of_schedulers > 0 and rem(number_of_schedulers, 2) == 0 do
    div(number_of_schedulers, 2)
  end

  defp determine_concurrency(number_of_schedulers) when number_of_schedulers > 0 do
    determine_concurrency(number_of_schedulers - 1)
  end

  if Mix.target() == :app do
    defp app_specs, do: [SMApp]
  else
    defp app_specs, do: []
  end
end
