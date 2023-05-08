defmodule SM.Release do
  @moduledoc """
  Used for executing DB release tasks when run in production without Mix
  installed.
  """
  @app :safarimanager

  @spec create :: :ok
  def create do
    ensure_app_loaded()

    Enum.each(repos(), fn repo ->
      :ok = ensure_repo_created(repo)
    end)
  end

  @spec migrate :: list
  def migrate do
    ensure_app_loaded()

    for repo <- repos() do
      IO.puts("Migrating #{inspect(repo)}...")
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  @spec rollback(atom, any) :: :ok
  def rollback(repo, version) do
    ensure_app_loaded()

    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
    :ok
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp ensure_app_loaded do
    :ok = Application.ensure_loaded(:safarimanager)
  end

  defp ensure_repo_created(repo) do
    case repo.__adapter__.storage_up(repo.config) do
      :ok ->
        IO.puts("Created #{inspect(repo)} database.")
        :ok

      {:error, :already_up} ->
        IO.puts("Failed to create #{inspect(repo)} database: already exists.")
        :ok

      {:error, reason} = error ->
        IO.puts("Failed to create #{inspect(repo)} database: #{inspect(reason)}")
        error
    end
  end
end
