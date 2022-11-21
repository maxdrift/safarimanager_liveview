defmodule SM.ImageProcessing do
  @moduledoc """
  Image processing helpers
  """

  @spec save_thumbnail(String.t(), non_neg_integer(), non_neg_integer(), String.t()) ::
          :ok | {:error, any()}
  def save_thumbnail(source, height, width, path) do
    # Consider calling put_concurrency/1 to avoid CPU starvation on RPi.
    # Image.put_concurrency(concurrency)
    with {:ok, image} <- Image.thumbnail(source, "#{height}x#{width}"),
         {:ok, _image} <- Image.write(image, path),
         do: :ok
  end

  # @spec get_info(String.t()) :: %{atom() => any()}
  # def get_info(path) do
  #   identify(path)
  # end

  @spec get_metadata(String.t()) :: {:ok, %{(atom() | String.t()) => any()}} | {:error, any()}
  def get_metadata(path) do
    Exexif.exif_from_jpeg_file(path)
  end
end
