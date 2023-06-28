defmodule SMWeb.SelectionPrintoutController do
  @moduledoc """
  Controller to format competition slides selection for printing
  """
  use SMWeb, :controller

  alias SM.Competitions
  alias SM.Participants
  alias SM.Results
  alias SM.Slides

  require Logger

  @spec show(Plug.Conn.t(), any()) :: Plug.Conn.t() | {:error, :not_found}
  def show(conn, %{"competition_id" => competition_id, "user_id" => user_id}) do
    config = Results.get_printout_config()

    with {:ok, competition} <- Competitions.get(competition_id),
         {:ok, participant} <- Participants.get(user_id, competition_id) do
      slides = Slides.list_for_printout(user_id, competition_id)

      conn
      |> put_root_layout(html: :print)
      |> render(:show_single,
        header_line: config[:header_line],
        sub_header_line: config[:sub_header_line],
        participant: participant,
        slides: slides,
        competition: competition,
        page_title: "Safari Manager - #{gettext("Slides selection report")}"
      )
    end
  end

  def show(conn, %{"competition_id" => competition_id}) do
    config = Results.get_printout_config()

    with {:ok, competition} <- Competitions.get(competition_id) do
      participants = Participants.list_with_slides(competition_id)

      conn
      |> put_root_layout(html: :print)
      |> render(:show_multi,
        header_line: config[:header_line],
        sub_header_line: config[:sub_header_line],
        participants: participants,
        competition: competition,
        page_title: "Safari Manager - #{gettext("Slides selection report")}"
      )
    end
  end
end
