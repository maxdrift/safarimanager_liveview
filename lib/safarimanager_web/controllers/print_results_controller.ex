defmodule SMWeb.PrintResultsController do
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

    with {:ok, competition} <- Competitions.get(competition_id),
         {:ok, results} <- Results.list(competition_id) do
      conn
      |> put_root_layout({SMWeb.Layouts, :print})
      |> render(:show,
        results: results,
        competition: competition,
        competition_types: competition_types,
        page_title: "Safari Manager - #{gettext("General Classification")}"
      )
    end
  end
end
