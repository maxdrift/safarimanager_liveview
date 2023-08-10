defmodule SMWeb.TelemetryPusher do
  @moduledoc false
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
    :ok =
      case do_recurrent_thing() do
        :ok ->
          :ok

        {:error, reason} ->
          Logger.warning("Unable to push metrics to server: #{inspect(reason)}")
          :ok
      end

    :ok = schedule_work()
    {:noreply, state}
  end

  defp do_recurrent_thing do
    hostname = get_config!(:instance_id)
    PrometheusPush.push(%{job: "push-metrics", grouping_key: [{"instance", hostname}]})
  end

  defp schedule_work(delay_sec \\ 10) do
    _ref = Process.send_after(self(), :push, :timer.seconds(delay_sec))
    :ok
  end

  defp get_config!(key) do
    :safarimanager
    |> Application.fetch_env!(__MODULE__)
    |> Keyword.fetch!(key)
  end
end
