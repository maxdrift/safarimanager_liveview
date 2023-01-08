defmodule SMWeb.Participants do
  @moduledoc """
  Participants live view
  """
  use SMWeb, :surface_view

  alias SM.Accounts
  alias SM.Accounts.User
  alias SM.Categories
  alias SM.Competitions
  alias SM.Organizations
  alias SM.Participants
  alias SMWeb.Components.Admin.Users.Form, as: UsersForm
  alias SMWeb.Components.CompetitionHeader
  alias SMWeb.Components.FormActions
  alias SMWeb.Components.Layout
  alias SMWeb.Components.StepsHeader
  alias Surface.Components.Form
  alias Surface.Components.Form.TextInput
  alias Surface.Components.LiveRedirect

  require Logger

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:organizations, Organizations.list())
      |> assign(:categories, Categories.list())
      |> assign(:participants, [])
      |> assign(:entity, %User{})
      |> assign(:changeset, Accounts.change_for_competition_registration(%User{}))

    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("enroll", %{"user-id" => user_id}, socket) do
    competition_id = socket.assigns.competition_id
    number = Participants.get_next_participant_number(competition_id)
    user = Accounts.get_user!(user_id)
    category_id = user.category_id

    {:ok, _participant} =
      Participants.create(%{
        user_id: user_id,
        competition_id: competition_id,
        category_id: category_id,
        number: number
      })

    {:noreply, socket}
  end

  def handle_event("remove", %{"user-id" => user_id}, socket) do
    {:ok, _participant} = Participants.delete(user_id, socket.assigns.competition_id)

    {:noreply, socket}
  end

  def handle_event("validate-new-user", %{"entity" => entity}, socket) do
    changeset =
      socket.assigns.entity
      |> Accounts.change_for_competition_registration(entity)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  def handle_event("submit-new-user", %{"entity" => entity}, socket) do
    case Accounts.register_simplified_user(entity) do
      {:ok, _user} ->
        socket =
          socket
          |> assign(:entity, %User{})
          |> assign(
            :changeset,
            Accounts.change_for_competition_registration(socket.assigns.entity)
          )
          # Note: remember events pushed from the server via push_event are global
          # and will be dispatched to all active hooks on the client who are handling that event.
          |> push_event("reset_entity_organization_id", %{})

        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  def handle_event("reset-new-user", %{}, socket) do
    socket =
      socket
      |> assign(:entity, %User{})
      |> assign(:changeset, Accounts.change_for_competition_registration(socket.assigns.entity))

    {:noreply, socket}
  end

  def handle_event("filter-users", %{"value" => ""}, socket) do
    users = Accounts.list_enrollable(socket.assigns.competition_id)
    {:noreply, assign(socket, :users, users)}
  end

  def handle_event("filter-users", %{"value" => value}, socket) do
    users = Accounts.list_enrollable(socket.assigns.competition_id, value)
    {:noreply, assign(socket, :users, users)}
  end

  def handle_event("filter-participants", %{"value" => ""}, socket) do
    participants = Participants.list(socket.assigns.competition_id)
    {:noreply, assign(socket, :participants, participants)}
  end

  def handle_event("filter-participants", %{"value" => value}, socket) do
    participants = Participants.list(socket.assigns.competition_id, value)
    {:noreply, assign(socket, :participants, participants)}
  end

  @impl Phoenix.LiveView
  def handle_params(%{"competition_id" => competition_id}, _uri, socket) do
    _result = if connected?(socket), do: {Participants.subscribe(), Accounts.subscribe()}

    {:ok, competition} = Competitions.get(competition_id)
    users = Accounts.list_enrollable(competition_id)

    socket =
      socket
      |> assign(:competition_id, competition_id)
      |> assign(:competition, competition)
      |> assign(:participants, Participants.list(competition_id))
      |> assign(:users, users)

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_info({Participants, [:competition, :updated], _result}, socket) do
    competition_id = socket.assigns.competition_id
    {:ok, competition} = Competitions.get(competition_id)

    socket =
      socket
      |> assign(:competition, competition)
      |> assign(:participants, Participants.list(competition_id))

    {:noreply, socket}
  end

  def handle_info({Participants, [:user, :updated], _result}, socket) do
    users = Accounts.list_enrollable(socket.assigns.competition_id)

    socket = assign(socket, :users, users)

    {:noreply, socket}
  end

  def handle_info({Accounts, [:user, _action], _result}, socket) do
    users = Accounts.list_enrollable(socket.assigns.competition_id)

    socket = assign(socket, :users, users)

    {:noreply, socket}
  end
end
