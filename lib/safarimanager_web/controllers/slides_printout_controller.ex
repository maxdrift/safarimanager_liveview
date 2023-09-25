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

    with {:ok, competition} <- Competitions.get(competition_id) do
      if competition.for_teams do
        do_show_teams(conn, competition, config)
      else
        do_show_participants(conn, competition, config)
      end
    end
  end

  defp do_show_participants(conn, competition, config) do
    with {:ok, results} <- Results.list(competition.id) do
      conn
      |> put_root_layout(html: :print)
      |> render(:show,
        header_line: config[:header_line],
        sub_header_line: config[:sub_header_line],
        results: results,
        competition: competition,
        page_title: "#{competition.name} - #{gettext("Participants slides report")}"
      )
    end
  end

  defp do_show_teams(conn, competition, config) do
    with {:ok, results} <- Results.list_for_teams(competition.id) do
      conn
      |> put_root_layout(html: :print)
      |> render(:show_teams,
        header_line: config[:header_line],
        sub_header_line: config[:sub_header_line],
        results: results,
        competition: competition,
        page_title: "#{competition.name} - #{gettext("Teams slides report")}"
      )
    end
  end
end
