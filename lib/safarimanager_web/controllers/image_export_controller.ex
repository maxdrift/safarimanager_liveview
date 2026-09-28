defmodule SMWeb.ImageExportController do
  use SMWeb, :controller

  alias SM.Slides
  alias SM.Slides.Storage

  require Logger

  @spec create(Plug.Conn.t(), any()) :: Plug.Conn.t()
  def create(conn, %{"slide_id" => slide_id}) do
    {:ok, slide} = Slides.get(slide_id)

    case Storage.serving_path(slide) do
      {:ok, file_path} -> send_download(conn, {:file, file_path})
      {:error, :not_found} -> conn |> put_status(:not_found) |> text("Not found")
    end
  end
end
