defmodule SM.USBWatcher do
  @moduledoc """
  GenServer watching new volumes insertions/extractions.
  """
  use GenServer, restart: :transient

  require Logger

  @poll_interval :timer.seconds(5)

  @spec start_link(any()) :: GenServer.on_start()
  def start_link(_args) do
    GenServer.start_link(__MODULE__, [])
  end

  @spec ls(String.t()) :: [String.t()]
  def ls(path) do
    GenServer.call(__MODULE__, {:ls, path})
  end

  @impl GenServer
  def init(_state) do
    # Schedule work to be performed on start
    schedule_work()

    {:ok, get_volumes()}
  end

  @impl GenServer
  def handle_info(:poll, state) do
    new_state = get_volumes()

    added_items = new_state -- state
    removed_items = state -- new_state

    cond do
      Enum.count(added_items) > 0 ->
        Logger.info("""
        New volumes were mounted:
          - #{Enum.join(added_items, "\n  - ")}
        """)

      Enum.count(removed_items) > 0 ->
        Logger.info("""
        Some volumes were unmounted:
          - #{Enum.join(removed_items, "\n  - ")}
        """)

      true ->
        Logger.debug("No volumes added/removed...")
    end

    # Reschedule once more
    schedule_work()

    {:noreply, new_state}
  end

  @impl GenServer
  def handle_call({:ls, path}, _from, state) do
    {:reply, ls_volume(path), state}
  end

  @impl GenServer
  def terminate(:normal, _state) do
    :stop
  end

  # Internal

  defp schedule_work do
    Process.send_after(self(), :poll, @poll_interval)
  end

  defp get_volumes do
    "mount"
    |> System.cmd([])
    |> elem(0)
    |> String.split("\n", trim: true)
    |> Enum.map(fn line ->
      mount = Regex.named_captures(~r{^(?<device>.+) on (?<mountpoint>.+) \((?<mode>.+)\)$}, line)
      Map.get(mount, "mountpoint")
    end)
    |> Enum.sort()
  end

  defp ls_volume(path) do
    [_head | tail] =
      "ls"
      |> System.cmd(["-lh", path])
      |> elem(0)
      |> String.split("\n", trim: true)

    tail
  end
end
