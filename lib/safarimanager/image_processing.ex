defmodule SM.ImageProcessing do
  @moduledoc """
  Image processing helpers
  """
  import Mogrify

  @spec save_thumbnail(String.t(), non_neg_integer(), non_neg_integer(), String.t()) ::
          {:ok, String.t()} | {:error, any()}
  def save_thumbnail(source, height, width, path) do
    source
    |> open()
    |> resize_to_limit("#{height}x#{width}")
    |> save(path: path)
  rescue
    File.Error -> {:error, :invalid_src_path}
    error -> {:error, error}
  else
    _image -> {:ok, path}
  end

  @spec get_info(String.t()) :: %{atom() => any()}
  def get_info(path) do
    identify(path)
  end

  @spec get_metadata(String.t()) :: {:ok, %{(atom() | String.t()) => any()}} | {:error, any()}
  def get_metadata(path) do
    Exexif.exif_from_jpeg_file(path)
  end
end
