defmodule SM.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl Application
  def start(_type, _args) do
    children = [
      {Task.Supervisor, name: SM.TaskSupervisor},
      # Start the Ecto repository
      SM.Repo,
      # Start the Telemetry supervisor
      SMWeb.Telemetry,
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
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: SM.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl Application
  def config_change(changed, _new, removed) do
    SMWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
