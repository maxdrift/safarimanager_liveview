defmodule SMWeb.TeamsPrintoutController do
  @moduledoc """
  Controller to format competition teams for printing
  """
  use SMWeb, :controller

  alias SM.Competitions
  alias SM.Results
  alias SM.Teams

  require Logger

  @spec show(Plug.Conn.t(), any()) :: Plug.Conn.t() | {:error, :not_found}
  def show(conn, %{"competition_id" => competition_id}) do
    competition_types = Competitions.list_competition_types()

    config = Results.get_printout_config()

    with {:ok, competition} <- Competitions.get(competition_id),
         teams <- Teams.list_by_competition(competition_id) do
      conn
      |> put_root_layout(html: :print)
      |> render(:show,
        header_line: config[:header_line],
        sub_header_line: config[:sub_header_line],
        teams: teams,
        competition: competition,
        competition_types: competition_types,
        page_title: "#{competition.name} - #{gettext("Teams list")}"
      )
    end
  end
end
