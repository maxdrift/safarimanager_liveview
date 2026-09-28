defmodule SM.Slides.Importer do
  @moduledoc """
  Imports slide image files from host-local paths (direct import / USB dialog).
  """
  alias SM.CompetitionDirectories
  alias SM.CompetitionDirectories.PathSafety
  alias SM.Participants
  alias SM.Slides

  require Logger

  # Parallel image prep/thumbs; DB inserts retry on SQLITE_BUSY (see SM.Repo.with_busy_retry/2).
  # ponytail: no write GenServer yet — short inserts + busy_timeout + retry cover desktop N≈100–200.
  @concurrency 4

  @doc """
  Imports `source_paths`, calling `on_progress.(processed, total)` after every file (failed ones included).
  Returns the number of successfully imported slides.
  """
  @spec import_paths(String.t(), String.t(), [String.t()], keyword()) :: {:ok, non_neg_integer()}
  def import_paths(competition_id, user_id, source_paths, opts \\ []) when is_list(source_paths) do
    on_progress = Keyword.get(opts, :on_progress, fn _processed, _total -> :ok end)
    total = length(source_paths)
    linked_ctx = linked_import_context(competition_id, user_id)

    {_processed, imported} =
      source_paths
      |> Task.async_stream(&import_one(competition_id, user_id, &1, linked_ctx),
        max_concurrency: @concurrency,
        timeout: :infinity
      )
      |> Enum.reduce({0, 0}, fn result, {processed, imported} ->
        on_progress.(processed + 1, total)
        {processed + 1, if(match?({:ok, {:ok, _}}, result), do: imported + 1, else: imported)}
      end)

    {:ok, imported}
  end

  @doc """
  Auto-assigns `cwd` as the participant's originals folder when importing from inside the linked root,
  unless that would re-point slides already linked from another folder.
  """
  @spec prepare_participant_folder(String.t(), String.t() | nil, String.t()) :: :ok
  def prepare_participant_folder(competition_id, user_id, cwd) when is_binary(user_id) do
    with {:ok, directory} <- CompetitionDirectories.get(competition_id),
         {:ok, relative} <- PathSafety.relative_folder(directory.root_path, cwd),
         {:ok, participant} <- Participants.get(user_id, competition_id),
         true <- can_auto_assign_folder?(participant, relative, competition_id, user_id) do
      case CompetitionDirectories.assign_participant_folder(competition_id, user_id, cwd) do
        {:ok, _} ->
          :ok

        {:error, reason} ->
          Logger.warning("Could not assign originals folder #{cwd}: #{inspect(reason)}")
          :ok
      end
    else
      _ -> :ok
    end
  end

  def prepare_participant_folder(_competition_id, _user_id, _cwd), do: :ok

  defp import_one(competition_id, user_id, source_path, linked_ctx) do
    %File.Stat{size: file_size} = File.stat!(source_path)

    storage = if linked_source?(linked_ctx, source_path), do: :linked, else: :internal

    with {:ok, slide} <-
           Slides.create_slide_from_file(
             competition_id,
             user_id,
             Path.basename(source_path),
             file_size,
             MIME.from_path(source_path),
             source_path,
             storage
           ),
         :ok <- Slides.generate_thumbnail_from_source(slide, :small) do
      maybe_schedule_medium(slide)
      {:ok, slide}
    end
  rescue
    error ->
      Logger.error("Failed to import #{source_path}: #{Exception.message(error)}")
      {:error, error}
  end

  defp maybe_schedule_medium(%{storage: :linked} = slide) do
    Task.Supervisor.start_child(SM.TaskSupervisor, fn ->
      Slides.generate_thumbnail_from_source(slide, :medium)
    end)
  end

  defp maybe_schedule_medium(_slide), do: :ok

  defp can_auto_assign_folder?(participant, relative, competition_id, user_id) do
    current = participant.originals_folder && PathSafety.normalize_relative(participant.originals_folder)
    relative = PathSafety.normalize_relative(relative)

    current in [nil, relative] or CompetitionDirectories.count_linked_slides(competition_id, user_id) == 0
  end

  defp linked_import_context(_competition_id, nil), do: nil

  defp linked_import_context(competition_id, user_id) do
    with {:ok, directory} <- CompetitionDirectories.get(competition_id),
         {:ok, participant} <- Participants.get(user_id, competition_id),
         folder when is_binary(folder) <- participant.originals_folder do
      %{root_path: directory.root_path, originals_folder: PathSafety.normalize_relative(folder)}
    else
      _ -> nil
    end
  end

  defp linked_source?(nil, _source_path), do: false

  defp linked_source?(%{root_path: root_path, originals_folder: originals_folder}, source_path) do
    source_dir = Path.dirname(Path.expand(source_path))

    case PathSafety.relative_folder(root_path, source_dir) do
      {:ok, relative} -> PathSafety.normalize_relative(relative) == originals_folder
      _ -> false
    end
  end
end
