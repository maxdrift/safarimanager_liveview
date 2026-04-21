defmodule SM.ImageProcessing do
  @moduledoc """
  Image processing helpers backed by `ex_image_resizer` (Rust NIF).
  """

  require Logger

  @spec save_thumbnail(String.t(), non_neg_integer(), non_neg_integer(), String.t()) ::
          :ok | {:error, any()}
  def save_thumbnail(source, width, height, path) do
    ExImageResizer.resize_file_fill(source, path, width, height)
  end

  @spec get_metadata(String.t()) :: {:ok, pos_integer(), pos_integer(), map()} | {:error, any()}
  def get_metadata(path) do
    with {:ok, bin} <- File.read(path),
         {:ok, %{width: width, height: height}} <- ExImageResizer.info(bin) do
      {:ok, width, height, read_exif(bin)}
    end
  end

  defp read_exif(bin) do
    case ExImageResizer.exif(bin) do
      {:ok, meta} ->
        gps = Map.get(meta, :gps) || %{}
        Map.put(meta, :gps, gps)

      {:error, reason} ->
        Logger.warning("Image missing metadata: #{inspect(reason)}")
        %{}
    end
  end
end
