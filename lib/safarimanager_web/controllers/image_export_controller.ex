defmodule SMWeb.ImageExportController do
  use SMWeb, :controller

  alias SM.Slides

  require Logger

  @spec create(Plug.Conn.t(), any()) :: Plug.Conn.t()
  def create(conn, %{"slide_id" => slide_id}) do
    {:ok, slide} = Slides.get(slide_id)

    file_path =
      slide.competition_id
      |> Slides.get_uploads_path(slide.user_id)
      |> Path.join(slide.file_name)

    send_download(conn, {:file, file_path})
  end
end
