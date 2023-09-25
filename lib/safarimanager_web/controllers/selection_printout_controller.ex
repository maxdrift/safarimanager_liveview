defmodule SMWeb.SelectionPrintoutController do
  @moduledoc """
  Controller to format competition slides selection for printing
  """
  use SMWeb, :controller

  alias SM.Competitions
  alias SM.Participants
  alias SM.Results
  alias SM.Slides
  alias SM.Teams

  require Logger

  @spec show(Plug.Conn.t(), any()) :: Plug.Conn.t() | {:error, :not_found}
  def show(conn, %{"competition_id" => competition_id, "user_id" => user_id}) do
    config = Results.get_printout_config()

    with {:ok, competition} <- Competitions.get(competition_id),
         {:ok, participant} <- Participants.get(user_id, competition_id) do
      slides = Slides.list_for_printout(user_id, competition_id)
      full_name = "#{participant.user.last_name} #{participant.user.first_name}"

      conn
      |> put_root_layout(html: :print)
      |> render(:show_single,
        header_line: config[:header_line],
        sub_header_line: config[:sub_header_line],
        participant: participant,
        slides: slides,
        competition: competition,
        page_title: "#{competition.name} - #{gettext("Slides selection report")} - #{full_name}"
      )
    end
  end

  def show(conn, %{"competition_id" => competition_id, "team_id" => team_id}) do
    config = Results.get_printout_config()

    with {:ok, competition} <- Competitions.get(competition_id),
         {:ok, team} <- Teams.get(team_id) do
      slides = Slides.list_for_teams_printout(team_id, competition_id)
      team_name = Teams.synthesize_team_name(team)

      conn
      |> put_root_layout(html: :print)
      |> render(:show_single_team,
        header_line: config[:header_line],
        sub_header_line: config[:sub_header_line],
        team: team,
        slides: slides,
        competition: competition,
        page_title: "#{competition.name} - #{gettext("Slides selection report")} - #{team_name}"
      )
    end
  end

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
    participants = Participants.list_with_slides(competition.id)

    conn
    |> put_root_layout(html: :print)
    |> render(:show_multi,
      header_line: config[:header_line],
      sub_header_line: config[:sub_header_line],
      participants: participants,
      competition: competition,
      page_title: "#{competition.name} - #{gettext("Slides selection report")}"
    )
  end

  defp do_show_teams(conn, competition, config) do
    teams = Teams.list_by_competition(competition.id)

    slides =
      competition.id
      |> Slides.list_for_teams_printout()
      |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))

    teams = Enum.reject(teams, fn team -> is_nil(Map.get(slides, team.id)) end)

    conn
    |> put_root_layout(html: :print)
    |> render(:show_multi_teams,
      header_line: config[:header_line],
      sub_header_line: config[:sub_header_line],
      teams: teams,
      slides: slides,
      competition: competition,
      page_title: "#{competition.name} - #{gettext("Slides selection report")}"
    )
  end
end
