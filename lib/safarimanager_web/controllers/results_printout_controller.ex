defmodule SMWeb.ResultsPrintoutController do
  @moduledoc """
  Controller to format competition results for printing
  """
  use SMWeb, :controller

  alias SM.Categories
  alias SM.Competitions
  alias SM.Results

  require Logger

  @spec show(Plug.Conn.t(), any()) :: Plug.Conn.t() | {:error, :not_found}
  def show(conn, %{"competition_id" => competition_id} = params) do
    category_id = Map.get(params, "category_id")
    config = Results.get_printout_config()

    with {:ok, competition} <- Competitions.get(competition_id) do
      if competition.for_teams do
        do_show_teams(conn, competition, nil, config)
      else
        do_show_participants(conn, competition, category_id, config)
      end
    end
  end

  defp do_show_participants(conn, competition, category_id, config) do
    category_label =
      case category_id do
        nil ->
          gettext("Overall classification")

        category_id ->
          {:ok, category} = Categories.get(category_id)
          "#{String.capitalize(gettext("classification"))}: #{String.capitalize(category.name)}"
      end

    competition_types = Competitions.list_competition_types()

    with {:ok, results} <- Results.list(competition.id, category_id) do
      conn
      |> put_root_layout(html: :print)
      |> render(:show,
        header_line: config[:header_line],
        sub_header_line: config[:sub_header_line],
        category_label: category_label,
        results: results,
        competition: competition,
        competition_types: competition_types,
        page_title: "#{competition.name} - #{gettext("Results")} - #{category_label}"
      )
    end
  end

  defp do_show_teams(conn, competition, nil, config) do
    competition_types = Competitions.list_competition_types()

    with {:ok, results} <- Results.list_for_teams(competition.id) do
      conn
      |> put_root_layout(html: :print)
      |> render(:show_teams,
        header_line: config[:header_line],
        sub_header_line: config[:sub_header_line],
        results: results,
        competition: competition,
        competition_types: competition_types,
        page_title: "#{competition.name} - #{gettext("Results")}"
      )
    end
  end
end
