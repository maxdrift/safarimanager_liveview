defmodule SMWeb.ParticipantsPrintoutController do
  @moduledoc """
  Controller to format competition participants for printing
  """
  use SMWeb, :controller

  alias SM.Competitions
  alias SM.Participants
  alias SM.Results

  require Logger

  @spec show(Plug.Conn.t(), any()) :: Plug.Conn.t() | {:error, :not_found}
  def show(conn, %{"competition_id" => competition_id}) do
    competition_types = Competitions.list_competition_types()

    config = Results.get_printout_config()

    with {:ok, competition} <- Competitions.get(competition_id),
         participants <- Participants.list(competition_id) do
      conn
      |> put_root_layout({SMWeb.Layouts, :print})
      |> render(:show,
        header_line: config[:header_line],
        sub_header_line: config[:sub_header_line],
        participants: participants,
        competition: competition,
        competition_types: competition_types,
        page_title: "Safari Manager - #{gettext("Participants list")}"
      )
    end
  end
end
