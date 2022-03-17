defmodule SMWeb.Results do
  @moduledoc """
  Results live view
  """
  use SMWeb, :surface_view

  alias SM.Competitions
  alias SM.Results
  alias SM.Slides
  alias Surface.Components.LiveRedirect

  require Logger

  # data competition, :struct

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    if connected?(socket), do: Slides.subscribe()
    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def handle_event(event_name, params, socket) do
    IO.inspect(event_name)
    IO.inspect(params)

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_params(%{"competition_id" => competition_id}, _uri, socket) do
    {:ok, results} = Results.list(competition_id)
    {:ok, competition} = Competitions.get(competition_id)

    socket =
      socket
      |> assign(:competition_id, competition_id)
      |> assign(:competition, competition)
      |> assign(:results, results)

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_info({Slides, [:slide, _action], _result}, socket) do
    {:ok, results} = Results.list(socket.assigns.competition_id)

    socket = assign(socket, :results, results)

    {:noreply, socket}
  end
end
