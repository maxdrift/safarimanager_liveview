defmodule SM.Slides.Storage do
  @moduledoc """
  Resolves filesystem paths for slide originals and thumbnails.

  See `docs/IMAGE_STORAGE.md`.
  """

  alias SM.CompetitionDirectories
  alias SM.CompetitionDirectories.PathSafety
  alias SM.Participants
  alias SM.Slides
  alias SM.Slides.Slide

  @spec internal_original_path(Slide.t()) :: String.t()
  def internal_original_path(%Slide{} = slide) do
    slide.competition_id
    |> Slides.get_uploads_path(slide.user_id)
    |> Path.join(slide.file_name)
  end

  @spec original_path(Slide.t()) :: String.t() | nil
  def original_path(%Slide{} = slide) do
    if PathSafety.safe_file_name?(slide.file_name), do: resolve_original(slide)
  end

  @spec thumbnail_path(Slide.t(), :small | :medium | :large) :: String.t()
  def thumbnail_path(%Slide{} = slide, size) when size in [:small, :medium, :large] do
    slide.competition_id
    |> Slides.get_thumbnails_path(slide.user_id, size)
    |> Path.join(slide.file_name)
  end

  @spec original_reachable?(Slide.t()) :: boolean()
  def original_reachable?(%Slide{} = slide) do
    path = original_path(slide)
    is_binary(path) and File.regular?(path)
  end

  @doc """
  Best available file for display: original, then medium, then small thumbnail.
  """
  @spec serving_path(Slide.t()) :: {:ok, String.t()} | {:error, :not_found}
  def serving_path(%Slide{} = slide) do
    if PathSafety.safe_file_name?(slide.file_name) do
      [original_path(slide), thumbnail_path(slide, :medium), thumbnail_path(slide, :small)]
      |> Enum.find(&(is_binary(&1) and File.regular?(&1)))
      |> case do
        nil -> {:error, :not_found}
        path -> {:ok, path}
      end
    else
      {:error, :not_found}
    end
  end

  defp resolve_original(%Slide{storage: :internal} = slide), do: internal_original_path(slide)

  defp resolve_original(%Slide{storage: :linked} = slide) do
    with {:ok, directory} <- CompetitionDirectories.get(slide.competition_id),
         {:ok, participant} <- Participants.get(slide.user_id, slide.competition_id),
         folder when is_binary(folder) <- participant.originals_folder,
         {:ok, folder_path} <- PathSafety.participant_folder_path(directory.root_path, folder) do
      Path.join(folder_path, slide.file_name)
    else
      _ -> nil
    end
  end
end
