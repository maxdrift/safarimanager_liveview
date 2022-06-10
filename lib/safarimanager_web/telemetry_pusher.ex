defmodule SMWeb.TelemetryPusher do
  use GenServer

  alias SMWeb.PrometheusPush

  require Logger

  def start_link(state) do
    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  @impl GenServer
  def init(state) do
    schedule_work()
    {:ok, state}
  end

  @impl GenServer
  def handle_info(:push, state) do
    do_recurrent_thing()
    schedule_work()
    {:noreply, state}
  end

  defp do_recurrent_thing() do
    {:ok, hostname} = :inet.gethostname()

    case PrometheusPush.push(%{job: "push-metrics", grouping_key: [{"instance", hostname}]}) do
      :ok ->
        :ok

      {:error, reason} = error ->
        Logger.warning("Unable to push metrics to server: #{inspect(reason)}")
        error
    end
  end

  defp schedule_work(delay_sec \\ 10) do
    Process.send_after(self(), :push, :timer.seconds(delay_sec))
  end
end
