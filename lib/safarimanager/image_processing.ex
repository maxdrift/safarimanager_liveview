defmodule SM.ImageProcessing do
  @moduledoc """
  Image processing helpers
  """
  require Logger

  @spec save_thumbnail(String.t(), non_neg_integer(), non_neg_integer(), String.t()) ::
          :ok | {:error, any()}
  def save_thumbnail(source, height, width, path) do
    System.schedulers_online()
    |> determine_concurrency()
    |> Image.put_concurrency()

    with {:ok, image} <- Image.thumbnail(source, "#{height}x#{width}", crop: :attention),
         {:ok, _image} <- Image.write(image, path),
         do: :ok
  end

  @spec get_metadata(String.t()) :: {:ok, pos_integer(), pos_integer(), map()} | {:error, any()}
  def get_metadata(path) do
    with {:ok, image} <- Image.open(path),
         width <- Image.width(image),
         height <- Image.height(image),
         metadata <- maybe_get_exif(image),
         do: {:ok, width, height, metadata}
  end

  # Internal

  defp maybe_get_exif(image) do
    case Image.exif(image) do
      {:ok, metadata} ->
        gps = Map.get(metadata, :gps)
        Map.put(metadata, :gps, (gps && Map.from_struct(gps)) || %{})

      # TODO: Make PR in Image library to fix specs
      {:error, _reason} ->
        Logger.warning("Image missing metadata")
        %{}
    end
  end

  defp determine_concurrency(1) do
    1
  end

  defp determine_concurrency(number_of_schedulers) when rem(number_of_schedulers, 2) == 0 do
    Integer.floor_div(number_of_schedulers, 2)
  end

  defp determine_concurrency(number_of_schedulers) do
    determine_concurrency(number_of_schedulers - 1)
  end
end
