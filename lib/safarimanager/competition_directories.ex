defmodule SM.CompetitionDirectories do
  @moduledoc """
  Links competitions to host-local directories for linked slide originals.

  Product scope: `docs/LINKED_ORIGINALS.md`. On-disk contract: `docs/IMAGE_STORAGE.md`.
  """
  use SM, :context

  alias SM.CompetitionDirectories.CompetitionDirectory
  alias SM.CompetitionDirectories.Manifest
  alias SM.CompetitionDirectories.PathSafety
  alias SM.CompetitionDirectories.Volumes
  alias SM.Competitions
  alias SM.Participants
  alias SM.Participants.Participant
  alias SM.Slides.Slide

  @reachability_cache_prefix "originals_reachability:"
  @check_timeout to_timeout(second: 3)

  @type reachability :: :reachable | :unreachable | :unknown

  @spec get(String.t()) :: {:ok, CompetitionDirectory.t()} | {:error, :not_linked}
  def get(competition_id) do
    case Repo.get(CompetitionDirectory, competition_id) do
      nil -> {:error, :not_linked}
      directory -> {:ok, directory}
    end
  end

  @spec count_linked_slides(String.t()) :: non_neg_integer()
  def count_linked_slides(competition_id) do
    Repo.one!(from(s in Slide, where: s.competition_id == ^competition_id and s.storage == ^:linked, select: count(s.id)))
  end

  @spec count_linked_slides(String.t(), String.t()) :: non_neg_integer()
  def count_linked_slides(competition_id, user_id) do
    Repo.one!(
      from(s in Slide,
        where: s.competition_id == ^competition_id and s.user_id == ^user_id and s.storage == ^:linked,
        select: count(s.id)
      )
    )
  end

  @doc """
  Links (or re-links) the competition to `root_path`. Re-linking is how a moved root is located manually.
  """
  @spec link_root(String.t(), String.t()) :: {:ok, CompetitionDirectory.t()} | {:error, term()}
  def link_root(competition_id, root_path) do
    with {:ok, root_path} <- PathSafety.expand_root(root_path),
         {:ok, competition} <- Competitions.get(competition_id),
         {:ok, library_id} <- ensure_root_manifest(root_path, competition),
         {:ok, directory} <- upsert_directory(competition_id, library_id, root_path) do
      _ = check_reachability(competition_id)
      {:ok, directory}
    end
  end

  @spec unlink_root(String.t()) :: :ok | {:error, term()}
  def unlink_root(competition_id) do
    fn ->
      with {:ok, directory} <- get(competition_id),
           0 <- count_linked_slides(competition_id),
           {:ok, _} <- Repo.delete(directory) do
        {:ok, directory}
      else
        count when is_integer(count) -> {:error, :linked_slides_remain}
        error -> error
      end
    end
    |> Repo.transact()
    |> case do
      {:ok, directory} ->
        _ = remove_from_root_manifest(directory)
        set_reachability(competition_id, :unknown)

      error ->
        error
    end
  end

  @doc """
  Assigns `folder_path` (absolute, inside the root) as the participant's originals folder.

  The marker write is best-effort (read-only media); the DB assignment is authoritative for serving.
  """
  @spec assign_participant_folder(String.t(), String.t(), String.t()) ::
          {:ok, Participant.t()} | {:error, term()}
  def assign_participant_folder(competition_id, user_id, folder_path) do
    with {:ok, directory} <- get(competition_id),
         {:ok, participant} <- Participants.get(user_id, competition_id),
         {:ok, relative} <- PathSafety.relative_folder(directory.root_path, folder_path),
         {:ok, absolute} <- PathSafety.participant_folder_path(directory.root_path, relative),
         true <- File.dir?(absolute) || {:error, :enoent} do
      write_participant_marker(directory, participant, absolute)

      participant
      |> Participant.folder_changeset(PathSafety.normalize_relative(relative))
      |> Repo.update()
    end
  end

  @spec reconcile_participant_folders(String.t()) :: {:ok, non_neg_integer()} | {:error, term()}
  def reconcile_participant_folders(competition_id) do
    with {:ok, directory} <- get(competition_id) do
      updated =
        competition_id
        |> Participants.list()
        |> Enum.count(fn participant ->
          case Manifest.scan_participant_folders(directory.root_path, competition_id, participant.user_id) do
            {:ok, relative} when relative != participant.originals_folder ->
              {:ok, _} = participant |> Participant.folder_changeset(relative) |> Repo.update()
              true

            _ ->
              false
          end
        end)

      {:ok, updated}
    end
  end

  @doc """
  Makes sure the root is reachable, relocating it by `library_id` across mounted volumes if needed.
  """
  @spec reconcile_root_path(String.t()) :: {:ok, CompetitionDirectory.t()} | {:error, term()}
  def reconcile_root_path(competition_id) do
    with {:ok, directory} <- get(competition_id) do
      if root_reachable?(directory.root_path), do: {:ok, directory}, else: relocate_root(directory)
    end
  end

  @doc """
  Removes the competition from the on-disk markers. Must run before the competition row is deleted,
  since the directory row cascades with it.
  """
  @spec remove_competition_from_manifests(String.t()) :: :ok
  def remove_competition_from_manifests(competition_id) do
    case get(competition_id) do
      {:ok, directory} ->
        _ = remove_from_root_manifest(directory)
        remove_participant_links(competition_id, directory.root_path)

      {:error, :not_linked} ->
        :ok
    end
  end

  @spec check_reachability(String.t()) :: reachability()
  def check_reachability(competition_id) do
    status =
      case reconcile_root_path(competition_id) do
        {:ok, _directory} -> :reachable
        {:error, :not_linked} -> :unknown
        {:error, _} -> :unreachable
      end

    set_reachability(competition_id, status)
    status
  end

  @doc """
  Like `check_reachability/1`, but a hung volume counts as unreachable instead of blocking the caller.
  """
  @spec check_reachability_with_timeout(String.t(), timeout()) :: reachability()
  def check_reachability_with_timeout(competition_id, timeout \\ @check_timeout) do
    task = Task.Supervisor.async_nolink(SM.TaskSupervisor, fn -> check_reachability(competition_id) end)

    case Task.yield(task, timeout) || Task.shutdown(task, :brutal_kill) do
      {:ok, status} ->
        status

      _ ->
        set_reachability(competition_id, :unreachable)
        :unreachable
    end
  end

  @spec get_reachability(String.t()) :: reachability()
  def get_reachability(competition_id) do
    case SM.Cache.get(reachability_cache_key(competition_id)) do
      status when status in [:reachable, :unreachable] -> status
      _ -> :unknown
    end
  end

  @spec list_linked() :: [CompetitionDirectory.t()]
  def list_linked do
    Repo.all(CompetitionDirectory)
  end

  # Internal

  defp set_reachability(competition_id, status) do
    previous = get_reachability(competition_id)
    :ok = SM.Cache.put(reachability_cache_key(competition_id), status)

    if previous != status do
      _ = notify_subscribers({:ok, status}, [:originals_reachability, competition_id])
    end

    :ok
  end

  defp root_reachable?(root_path) do
    File.dir?(root_path) and File.exists?(Manifest.root_path(root_path))
  end

  defp relocate_root(%CompetitionDirectory{} = directory) do
    search_roots = Volumes.search_roots_for_relocate(directory.root_path)

    case Manifest.find_roots_with_library_id(directory.library_id, search_roots) do
      [new_root | _] ->
        directory
        |> CompetitionDirectory.changeset(%{root_path: new_root})
        |> Repo.update()

      [] ->
        {:error, :not_found}
    end
  end

  defp reachability_cache_key(competition_id), do: @reachability_cache_prefix <> competition_id

  defp upsert_directory(competition_id, library_id, root_path) do
    %CompetitionDirectory{competition_id: competition_id}
    |> CompetitionDirectory.changeset(%{library_id: library_id, root_path: root_path})
    |> Repo.insert(
      on_conflict: [set: [library_id: library_id, root_path: root_path, updated_at: DateTime.utc_now()]],
      conflict_target: :competition_id
    )
  end

  # The root manifest is what makes a root reachable and relocatable, so it must be writable.
  # An unreadable manifest is never overwritten: it may belong to other competitions.
  defp ensure_root_manifest(root_path, competition) do
    root =
      case Manifest.read_root(root_path) do
        {:ok, root} -> {:ok, Manifest.add_competition_to_root(root, competition.id, competition.name)}
        {:error, :missing} -> {:ok, Manifest.new_root(Ecto.UUID.generate(), competition.id, competition.name)}
        {:error, :invalid} -> {:error, :invalid_manifest}
      end

    with {:ok, root} <- root,
         :ok <- Manifest.write_root(root_path, root) do
      {:ok, root.library_id}
    else
      {:error, :invalid_manifest} = error ->
        error

      {:error, reason} ->
        Logger.warning("Root manifest write failed for #{root_path}: #{inspect(reason)}")
        {:error, :manifest_not_writable}
    end
  end

  defp remove_from_root_manifest(%CompetitionDirectory{} = directory) do
    case Manifest.read_root(directory.root_path) do
      {:ok, root} ->
        updated = Manifest.remove_competition_from_root(root, directory.competition_id)
        Manifest.write_root(directory.root_path, updated)

      _ ->
        :ok
    end
  end

  defp write_participant_marker(directory, participant, folder_path) do
    link = %{
      competition_id: participant.competition_id,
      user_id: participant.user_id,
      number: participant.number,
      name: participant_display_name(participant)
    }

    marker =
      case Manifest.read_participant(folder_path) do
        {:ok, existing} -> Manifest.upsert_participant_link(existing, link)
        {:error, _} -> %{version: 1, library_id: directory.library_id, links: [link]}
      end

    case Manifest.write_participant(folder_path, marker) do
      :ok -> :ok
      {:error, reason} -> Logger.warning("Participant marker write failed: #{inspect(reason)}")
    end
  end

  defp remove_participant_links(competition_id, root_path) do
    competition_id
    |> Participants.list()
    |> Enum.filter(&is_binary(&1.originals_folder))
    |> Enum.each(fn participant ->
      with {:ok, folder_path} <- PathSafety.participant_folder_path(root_path, participant.originals_folder),
           {:ok, marker} <- Manifest.read_participant(folder_path) do
        updated = Manifest.remove_participant_link(marker, competition_id, participant.user_id)
        Manifest.write_participant(folder_path, updated)
      end
    end)
  end

  defp participant_display_name(%Participant{} = participant) do
    case Repo.preload(participant, :user).user do
      %{first_name: first_name, last_name: last_name} -> "#{first_name} #{last_name}"
      _ -> "Participant #{participant.number}"
    end
  end
end
