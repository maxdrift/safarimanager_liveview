defmodule SM.ImageProcessing do
  @moduledoc """
  Image processing helpers
  """

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

  # @spec get_info(String.t()) :: %{atom() => any()}
  # def get_info(path) do
  #   identify(path)
  # end

  @spec get_metadata(String.t()) :: {:ok, %{(atom() | String.t()) => any()}} | {:error, any()}
  def get_metadata(path) do
    Exexif.exif_from_jpeg_file(path)
  end

  defp determine_concurrency(1) do
    1
  end

  defp determine_concurrency(number_of_schedulers) when rem(number_of_schedulers, 2) == 0 do
    number_of_schedulers / 2
  end

  defp determine_concurrency(number_of_schedulers) do
    determine_concurrency(number_of_schedulers - 1)
  end
end
