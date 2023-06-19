defmodule SMWeb.CSVExportController do
  use SMWeb, :controller

  alias SM.CSVExport

  require Logger

  @spec create(Plug.Conn.t(), any()) :: Plug.Conn.t()
  def create(conn, %{"entity" => entity}) do
    filename =
      "#{Gettext.gettext(SMWeb.Gettext, entity)}-export-#{DateTime.to_iso8601(DateTime.utc_now())}.csv"

    conn =
      conn
      |> put_resp_content_type("text/csv")
      |> put_resp_header("content-disposition", ~s(attachment; filename="#{filename}"))
      |> send_chunked(200)

    case CSVExport.export(entity, &chunk(conn, &1)) do
      {:ok, conn} ->
        conn

      {:error, reason} ->
        Logger.error("Failed to dump #{entity} to CSV: #{inspect(reason)}")

        conn
    end
  end
end
