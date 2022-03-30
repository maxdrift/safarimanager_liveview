defmodule SM.ImageProcessing do
  @moduledoc """
  Image processing helpers
  """
  import Mogrify

  @spec save_thumbnail(String.t(), non_neg_integer(), non_neg_integer(), String.t()) :: %{
          atom() => any()
        }
  def save_thumbnail(source, height, width, path) do
    source
    |> open()
    |> resize_to_limit("#{height}x#{width}")
    |> save(path: path)
  end

  @spec get_info(String.t()) :: %{atom() => any()}
  def get_info(path) do
    identify(path)
  end
end
