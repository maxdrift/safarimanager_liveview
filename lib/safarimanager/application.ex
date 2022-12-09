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
        # {Finch, name: SMFinch, pools: %{default: [count: 1, size: 10]}},
        # Start the supervisor for the GenServer pushing metrics
        # to Prometheus
        SMWeb.TelemetryPusherSupervisor,
        # Start the PubSub system
        {Phoenix.PubSub, name: SM.PubSub},
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
        result

      {:error, error} ->
        abort!(Application.format_error(error))
    end
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl Application
  def config_change(changed, _new, removed) do
    SMWeb.Endpoint.config_change(changed, removed)
    :ok
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

  # TODO: Move this to shared module and use it to present startup config errors to the user.
  # Aborts booting due to a configuration error.
  @spec abort!(String.t()) :: no_return()
  defp abort!(message)

  if Mix.target() == :app do
    defp abort!(message) do
      ElixirKit.publish(:abort, message)
      Process.sleep(:infinity)
    end
  else
    defp abort!(message) do
      IO.puts("\nERROR!!! [SafariManager] " <> message)
      System.halt(1)
    end
  end
end
