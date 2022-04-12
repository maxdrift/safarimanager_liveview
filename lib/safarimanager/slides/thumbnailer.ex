defmodule Thumbnailer do
  @moduledoc """
  GenServer to asynchronously generate thumbnails
  """
  use GenServer

  require Logger

  # Client

  @spec start_link() :: :ignore | {:error, any()} | {:ok, pid()}
  def start_link() do
    GenServer.start_link(__MODULE__, [])
  end

  # def push(pid, element) do
  #   GenServer.cast(pid, {:push, element})
  # end

  def create_thumbnails(competition_id, user_id, file_name) do
    GenServer.call(:thumbnailer, {:create_thumbnails, {competition_id, user_id, file_name}})
  end

  # Server (callbacks)

  @impl GenServer
  def init(stack) do
    {:ok, stack}
  end

  @impl GenServer
  def handle_call({:create_thumbnails, {competition_id, user_id, file_name}}, from, state) do
    {:reply, :ok, [from | state]}
  end

  # Internal

  defp generate_thumbnails(competition_id, user_id, file_name) do
    with {:ok, _pid} <-
           Task.Supervisor.start_child(SM.TaskSupervisor, fn ->
             generate_thumbnail(competition_id, user_id, file_name, :small)
           end),
         {:ok, _pid} <-
           Task.Supervisor.start_child(SM.TaskSupervisor, fn ->
             generate_thumbnail(competition_id, user_id, file_name, :medium)
           end),
         {:ok, _pid} <-
           Task.Supervisor.start_child(SM.TaskSupervisor, fn ->
             generate_thumbnail(competition_id, user_id, file_name, :large)
           end),
         do: {:ok, :thumbnail_generated}
  end

  defp generate_thumbnail(competition_id, user_id, file_name, size_type) do
    case SM.Slides.generate_thumbnail(competition_id, user_id, file_name, size_type) do
      :ok ->
        :ok

      {:error, reason} = error ->
        Logger.error(
          "Unable to generate #{size_type} thumbnail for image #{file_name}: #{inspect(reason)}"
        )

        error
    end
  end
end
