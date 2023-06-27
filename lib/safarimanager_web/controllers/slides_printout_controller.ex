defmodule SMWeb.SlidesPrintoutController do
  @moduledoc """
  Controller to format competition participants slides for printing
  """
  use SMWeb, :controller

  alias SM.Competitions
  alias SM.Results

  require Logger

  @spec show(Plug.Conn.t(), any()) :: Plug.Conn.t() | {:error, :not_found}
  def show(conn, %{"competition_id" => competition_id}) do
    config = Results.get_printout_config()

    with {:ok, competition} <- Competitions.get(competition_id),
         {:ok, results} <- Results.list(competition_id) do
      conn
      |> put_root_layout({SMWeb.Layouts, :print})
      |> render(:show,
        header_line: config[:header_line],
        sub_header_line: config[:sub_header_line],
        results: results,
        competition: competition,
        page_title: "Safari Manager - #{gettext("Participants slides report")}"
      )
    end
  end
end
