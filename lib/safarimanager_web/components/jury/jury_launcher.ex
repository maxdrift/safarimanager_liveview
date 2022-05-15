defmodule SMWeb.JuryLauncher do
  @moduledoc """
  Jury launcher live view
  """
  use SMWeb, :surface_view

  alias SM.Competitions
  alias SMWeb.Components.CompetitionHeader
  alias SMWeb.Components.StepsHeader
  alias Surface.Components.Link
  alias Surface.Components.LiveRedirect

  require Logger

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def handle_params(%{"competition_id" => competition_id}, _uri, socket) do
    {:ok, competition} = Competitions.get(competition_id)

    socket =
      socket
      |> assign(:competition_id, competition_id)
      |> assign(:competition, competition)

    {:noreply, socket}
  end
end
