defmodule SM.USBWatcherSupervisor do
  @moduledoc """
  USBWatcher GenServer Dynamic Supervisor
  """
  use DynamicSupervisor

  require Logger

  @spec start_link(any()) :: Supervisor.on_start()
  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @spec start_poller(pid()) :: :ok
  def start_poller(caller_pid) do
    spec = {SM.USBWatcher, [caller_pid]}
    {:ok, pid} = DynamicSupervisor.start_child(__MODULE__, spec)
    Logger.info("Started child: #{inspect(pid)}")
    :ok
  end

  @spec get_poller_pid :: {:ok, pid()} | {:error, :no_active_pollers | :poller_restarting}
  def get_poller_pid do
    case DynamicSupervisor.which_children(__MODULE__) do
      [{:undefined, :restarting, :worker, _modules}] ->
        Logger.warning("Child is restarting")
        {:error, :poller_restarting}

      [{:undefined, child, :worker, _modules}] ->
        {:ok, child}

      [] ->
        {:error, :no_active_pollers}
    end
  end

  @spec stop_poller :: :ok
  def stop_poller do
    case DynamicSupervisor.which_children(__MODULE__) do
      [{:undefined, :restarting, :worker, _modules}] ->
        Logger.warning("Child is restarting")
        :ok

      [{:undefined, child, :worker, _modules}] ->
        :ok = GenServer.stop(child, :normal, :timer.seconds(60))
        Logger.info("Stopped child: #{inspect(child)}")

      [] ->
        Logger.info("All children already stopped.")
        :ok
    end
  end

  @spec active? :: boolean()
  def active? do
    not (DynamicSupervisor.which_children(__MODULE__) == [])
  end

  @impl DynamicSupervisor
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one, max_children: 1)
  end
end
