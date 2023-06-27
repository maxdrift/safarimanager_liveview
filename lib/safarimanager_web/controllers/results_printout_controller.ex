defmodule SMWeb.ResultsPrintoutController do
  @moduledoc """
  Controller to format competition results for printing
  """
  use SMWeb, :controller

  alias SM.Competitions
  alias SM.Results

  require Logger

  @spec show(Plug.Conn.t(), any()) :: Plug.Conn.t() | {:error, :not_found}
  def show(conn, %{"competition_id" => competition_id}) do
    competition_types = Competitions.list_competition_types()

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
        competition_types: competition_types,
        page_title: "Safari Manager - #{gettext("Overall classification")}"
      )
    end
  end
end
