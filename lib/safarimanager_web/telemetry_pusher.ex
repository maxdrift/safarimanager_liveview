defmodule SMWeb.TelemetryPusher do
  use GenServer

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
    case Prometheus.Push.push(%{job: "push-metrics", instance: "some-instance"}) do
      {:ok, {{_protocol, 200, 'OK'}, _headers, _body}} ->
        :ok

      {:ok, {{_protocol, 401, 'Unauthorized'}, _headers, _body}} ->
        Logger.warning("Unable to push metrics to server: unauthorized")
        {:error, :unauthorized}

      {:ok, {{_protocol, status_code, status_str}, _headers, _body}} ->
        Logger.warning("Unable to push metrics to server: #{status_str}")
        {:error, {status_code, to_string(status_str)}}

      {:error, reason} ->
        Logger.warning("Unable to push metrics to server: #{inspect(reason)}")
        {:error, {:unexpected, reason}}
    end
  end

  defp schedule_work(delay_sec \\ 10) do
    Process.send_after(self(), :push, :timer.seconds(delay_sec))
  end
end
