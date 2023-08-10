defmodule SMWeb.TelemetryPusherSupervisor do
  @moduledoc false
  use Supervisor

  alias SMWeb.TelemetryPusher

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl Supervisor
  def init(_init_arg) do
    children = [
      {TelemetryPusher, []}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
