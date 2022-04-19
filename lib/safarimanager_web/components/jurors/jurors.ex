defmodule SMWeb.Jurors do
  @moduledoc """
  Jurors live view
  """
  use SMWeb, :surface_view

  alias SM.Accounts
  alias SM.Competitions
  alias SM.Jurors
  alias SMWeb.Components.CompetitionHeader
  alias SMWeb.Components.StepsHeader
  alias Surface.Components.LiveRedirect

  require Logger

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("enroll", %{"user-id" => user_id}, socket) do
    competition_id = socket.assigns.competition_id
    max_jurors_count = socket.assigns.competition.req_jurors_count

    :ok =
      if Enum.count(socket.assigns.competition.jurors) < max_jurors_count do
        {:ok, _juror} = Jurors.create(%{user_id: user_id, competition_id: competition_id})
        :ok
      else
        Logger.warn("Reached max of #{max_jurors_count} Jurors for Competition #{competition_id}")
      end

    {:noreply, socket}
  end

  def handle_event("remove", %{"user-id" => user_id}, socket) do
    {:ok, _juror} = Jurors.delete(user_id, socket.assigns.competition_id)

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_params(%{"competition_id" => competition_id}, _uri, socket) do
    if connected?(socket), do: Jurors.subscribe()

    {:ok, competition} = Competitions.get(competition_id)
    users = Accounts.list_enrollable(competition_id)

    socket =
      socket
      |> assign(:competition_id, competition_id)
      |> assign(:competition, competition)
      |> assign(:users, users)

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_info({Jurors, [:competition, :updated], _result}, socket) do
    {:ok, competition} = Competitions.get(socket.assigns.competition_id)

    socket = assign(socket, :competition, competition)

    {:noreply, socket}
  end

  def handle_info({Jurors, [:user, :updated], _result}, socket) do
    users = Accounts.list_enrollable(socket.assigns.competition_id)

    socket = assign(socket, :users, users)

    {:noreply, socket}
  end
end
