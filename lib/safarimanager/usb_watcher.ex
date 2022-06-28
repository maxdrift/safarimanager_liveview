defmodule SM.USBWatcher do
  @moduledoc """
  GenServer watching new volumes insertions/extractions.
  """
  use GenServer, restart: :transient

  require Logger

  @poll_interval :timer.seconds(5)

  @spec start_link(any()) :: GenServer.on_start()
  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  @spec ls(pid(), String.t()) :: [String.t()]
  def ls(pid, path) do
    GenServer.call(pid, {:ls, path})
  end

  @impl GenServer
  def init([caller_pid]) do
    volumes = get_volumes()
    # Schedule work to be performed on start
    schedule_work(caller_pid)

    {:ok, volumes}
  end

  @impl GenServer
  def handle_info({:poll, caller_pid}, state) do
    new_state = get_volumes()

    added_items = new_state -- state
    removed_items = state -- new_state

    cond do
      Enum.count(added_items) > 0 ->
        Logger.info("""
        New volumes were mounted:
          - #{Enum.join(added_items, "\n  - ")}
        """)

        {:new_volumes, ^added_items} = send(caller_pid, {:new_volumes, added_items})

      Enum.count(removed_items) > 0 ->
        Logger.info("""
        Some volumes were unmounted:
          - #{Enum.join(removed_items, "\n  - ")}
        """)

        :volumes_removed = send(caller_pid, :volumes_removed)

      true ->
        Logger.debug("No volumes added/removed...")
    end

    # Reschedule once more
    schedule_work(caller_pid)

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

  defp schedule_work(caller_pid) do
    Process.send_after(self(), {:poll, caller_pid}, @poll_interval)
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
