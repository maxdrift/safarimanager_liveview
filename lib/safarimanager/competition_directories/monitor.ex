defmodule SM.CompetitionDirectories.Monitor do
  @moduledoc """
  Polls linked competition directories and broadcasts reachability changes.

  See `docs/IMAGE_STORAGE.md`.
  """
  use GenServer

  alias SM.CompetitionDirectories

  @poll_interval to_timeout(second: 5)

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl GenServer
  def init(_opts) do
    schedule_poll()
    {:ok, %{}}
  end

  @impl GenServer
  def handle_info(:poll, state) do
    CompetitionDirectories.list_linked()
    |> Task.async_stream(
      &CompetitionDirectories.check_reachability_with_timeout(&1.competition_id),
      timeout: :infinity,
      max_concurrency: 4
    )
    |> Stream.run()

    schedule_poll()
    {:noreply, state}
  end

  defp schedule_poll do
    Process.send_after(self(), :poll, @poll_interval)
  end
end
