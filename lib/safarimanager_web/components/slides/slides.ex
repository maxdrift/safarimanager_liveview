defmodule SMWeb.Slides do
  @moduledoc """
  Slides live view
  """
  use SMWeb, :surface_view

  alias SM.Accounts
  alias SM.Competitions
  alias SM.Slides
  alias Surface.Components.LiveFileInput
  alias Surface.Components.Form
  alias Surface.Components.Form.ErrorTag
  alias Surface.Components.Form.Field
  alias Surface.Components.Form.Label
  alias Surface.Components.Form.Reset
  alias Surface.Components.Form.Submit
  alias Surface.Components.LiveRedirect
  alias Surface.Components.LivePatch

  require Logger

  # data user, :struct

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:user, nil)
      |> assign(:slides, [])
      |> allow_upload(:images, accept: ~w(.jpg .jpeg .png), max_entries: 150)

    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("select", %{"id" => user_id}, socket) do
    socket =
      socket
      |> assign(:user, Accounts.get_user!(user_id))

    {:noreply, socket}
  end

  def handle_event("submit", %{}, socket) do
    assigns = socket.assigns

    Enum.each(socket.assigns.uploads.images.entries, fn entry ->
      Slides.create(%{
        user_id: assigns.user.id,
        competition_id: assigns.competition_id,
        file_name: entry.client_name,
        file_size: entry.client_size,
        file_type: entry.client_type
      })
    end)

    {:noreply, socket}
  end

  def handle_event(event_name, params, socket) do
    IO.inspect(event_name)
    IO.inspect(params)
    IO.inspect(socket.assigns.uploads)

    {:noreply, socket}
  end

  @impl Phoenix.LiveView

  def handle_params(%{"competition_id" => competition_id} = params, _uri, socket) do
    if connected?(socket), do: {Competitions.subscribe(), Accounts.subscribe()}

    user_id = params["user_id"]

    {:ok, competition} = Competitions.get(competition_id)

    socket =
      socket
      |> assign(:competition_id, competition_id)
      |> assign(:competition, competition)
      # FIXME: this way of selecting the user forces a re-query of Competition
      |> assign(:user, user_id && Accounts.get_user!(user_id))
      |> assign(:slides, user_id && Slides.list(user_id, competition_id))

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_info({Slides, [:competition, :updated], _result}, socket) do
    {:ok, competition} = Competitions.get(socket.assigns.competition_id)

    socket = assign(socket, :competition, competition)

    {:noreply, socket}
  end

  def handle_info({Slides, [:user, :updated], _result}, socket) do
    users = Accounts.list_enrollable(socket.assigns.competition_id)

    socket = assign(socket, :users, users)

    {:noreply, socket}
  end
end
