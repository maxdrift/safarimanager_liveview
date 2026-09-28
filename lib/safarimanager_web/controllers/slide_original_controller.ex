defmodule SMWeb.SlideOriginalController do
  use SMWeb, :controller

  alias SM.Slides
  alias SM.Slides.Storage

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, %{"id" => slide_id}) do
    with {:ok, slide} <- Slides.get(slide_id),
         {:ok, file_path} <- Storage.serving_path(slide) do
      conn
      |> put_resp_content_type(MIME.from_path(file_path), nil)
      |> send_file(200, file_path)
    else
      _ -> conn |> put_status(:not_found) |> text("Not found")
    end
  end
end
