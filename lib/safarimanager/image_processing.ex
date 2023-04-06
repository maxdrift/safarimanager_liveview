defmodule SM.ImageProcessing do
  @moduledoc """
  Image processing helpers
  """
  require Logger

  @spec save_thumbnail(String.t(), non_neg_integer(), non_neg_integer(), String.t()) ::
          :ok | {:error, any()}
  def save_thumbnail(source, height, width, path) do
    with {:ok, image} <- Image.thumbnail(source, "#{height}x#{width}", crop: :attention),
         {:ok, _image} <- Image.write(image, path),
         do: :ok
  end

  @spec get_metadata(String.t()) :: {:ok, pos_integer(), pos_integer(), map()} | {:error, any()}
  def get_metadata(path) do
    # When :sequential, Image (via Vix) is able to support streaming transformations
    # and optimise memory usage more effectively. However :sequential also means that
    # some operations cannot be completed because they would require non-sequential
    # access to the image. In these cases, :random access is required.
    with {:ok, image} <- Image.open(path, access: :sequential),
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

      {:error, _reason} ->
        Logger.warning("Image missing metadata")
        %{}
    end
  rescue
    e in ArgumentError ->
      Logger.error("Unable to process EXIF metadata: #{inspect(e)}")
      %{}
  end
end
