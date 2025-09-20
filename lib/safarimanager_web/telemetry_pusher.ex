defmodule SMWeb.TelemetryPusher do
  @moduledoc false
  use GenServer

  alias SMWeb.PrometheusPush

  require Logger

  def start_link(state) do
    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  @impl GenServer
  def init(_state) do
    schedule_work()
    {:ok, %{push_to_remote: true}}
  end

  @impl GenServer
  def handle_info(:push, %{push_to_remote: true} = state) do
    state =
      case do_recurrent_thing() do
        :ok ->
          state

        {:error, reason} ->
          Logger.warning("Unable to push metrics to server: #{inspect(reason)}")
          Logger.error("Disabling further metrics pushes to remote instance")
          %{state | push_to_remote: false}
      end

    :ok = schedule_work()
    {:noreply, state}
  end

  def handle_info(:push, state) do
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
