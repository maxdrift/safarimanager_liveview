defmodule SMWeb.Live.Participants do
  @moduledoc """
  Participants live view
  """
  use SMWeb, :live_view

  import SMWeb.Components.CompetitionHeader
  import SMWeb.Components.Layout
  import SMWeb.Components.StepsHeader
  import SMWeb.Components.UserForm

  alias SM.Accounts
  alias SM.Accounts.User
  alias SM.Categories
  alias SM.Competitions
  alias SM.Organizations
  alias SM.Participants

  require Logger

  on_mount SMWeb.SidebarHook

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    socket =
      assign(socket,
        organizations: Organizations.list(),
        categories: Categories.list(),
        participants: [],
        entity: %User{},
        form: to_form(Accounts.change_for_competition_registration(%User{}), as: :entity),
        participants_selection: MapSet.new(),
        expand_register_form: false
      )

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
    changeset = Accounts.change_for_competition_registration(socket.assigns.entity, entity)
    form = to_form(changeset, action: :validate, as: :entity)

    {:noreply, assign(socket, :form, form)}
  end

  def handle_event("submit-new-user", %{"entity" => entity}, socket) do
    case Accounts.register_simplified_user(entity) do
      {:ok, _user} ->
        socket =
          socket
          |> assign(:entity, %User{})
          |> assign(
            :form,
            to_form(Accounts.change_for_competition_registration(socket.assigns.entity), as: :entity)
          )
          # Note: remember events pushed from the server via push_event are global
          # and will be dispatched to all active hooks on the client who are handling that event.
          |> push_event("reset_entity_organization_id", %{})

        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  def handle_event("reset-new-user", %{}, socket) do
    fresh_entity = %User{}
    socket =
      socket
      |> assign(:entity, fresh_entity)
      |> assign(
        :form,
        to_form(Accounts.change_for_competition_registration(fresh_entity), as: :entity)
      )

    {:noreply, socket}
  end

  def handle_event("toggle-register-form", _params, socket) do
    {:noreply, assign(socket, :expand_register_form, !socket.assigns.expand_register_form)}
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
    participants = Participants.filter_by_name(socket.assigns.competition_id, value)
    {:noreply, assign(socket, :participants, participants)}
  end

  def handle_event("category-change", %{"category_id" => new_category_id, "user_id" => _user_id}, socket)
      when new_category_id in [nil, ""] do
    {:noreply, socket}
  end

  def handle_event("category-change", %{"category_id" => new_category_id, "user_id" => user_id}, socket) do
    {:ok, participant} = Participants.get(user_id, socket.assigns.competition_id)

    participant
    |> Participants.update(%{"category_id" => new_category_id})
    |> case do
      {:ok, _participant} ->
        # Reload participants list to reflect the change
        participants = Participants.list(socket.assigns.competition_id)

        socket =
          socket
          |> assign(:participants, participants)
          |> put_flash(:info, gettext("Category was changed successfully"))

        {:noreply, socket}

      {:error, reason} ->
        Logger.error("Error changing participant (user ID: #{user_id}) category during enrollment: #{inspect(reason)}")

        socket = put_flash(socket, :error, gettext("Unable to change Category"))

        {:noreply, socket}
    end
  end

  def handle_event(_event, _params, socket) do
    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_params(%{"competition_id" => competition_id}, _uri, socket) do
    _result = if connected?(socket), do: {Participants.subscribe(), Accounts.subscribe()}

    {:ok, competition} = Competitions.get(competition_id)
    users = Accounts.list_enrollable(competition_id)

    socket =
      assign(socket,
        competition_id: competition_id,
        competition: competition,
        participants: Participants.list(competition_id),
        users: users
      )

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_info({Participants, [:participant, _action], _result}, socket) do
    competition_id = socket.assigns.competition_id
    {:ok, competition} = Competitions.get(competition_id)
    users = Accounts.list_enrollable(competition_id)

    socket =
      assign(socket,
        competition: competition,
        participants: Participants.list(competition_id),
        users: users
      )

    {:noreply, socket}
  end

  def handle_info({Accounts, [:user, _action], _result}, socket) do
    users = Accounts.list_enrollable(socket.assigns.competition_id)

    socket = assign(socket, :users, users)

    {:noreply, socket}
  end
end
