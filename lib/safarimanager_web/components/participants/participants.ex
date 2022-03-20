defmodule SMWeb.Participants do
  @moduledoc """
  Participants live view
  """
  use SMWeb, :surface_view

  alias SM.Accounts
  alias SM.Accounts.User
  alias SM.Competitions
  alias SM.Participants
  alias SMWeb.Components.FormActions
  alias SMWeb.Components.Users.Form
  alias Surface.Components.LiveRedirect

  require Logger

  # data competition, :struct

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:entity, %User{})
      |> assign(:changeset, Accounts.change_user_name_and_email(%User{}))

    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("enroll", %{"user-id" => user_id}, socket) do
    {:ok, _participant} =
      Participants.create(%{user_id: user_id, competition_id: socket.assigns.competition_id})

    {:noreply, socket}
  end

  def handle_event("remove", %{"user-id" => user_id}, socket) do
    {:ok, _participant} = Participants.delete(user_id, socket.assigns.competition_id)

    {:noreply, socket}
  end

  def handle_event("validate-new-user", %{"entity" => entity}, socket) do
    changeset =
      socket.assigns.entity
      |> Accounts.change_user_name_and_email(entity)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  def handle_event("submit-new-user", %{"entity" => entity}, socket) do
    case Accounts.register_simplified_user(entity) do
      {:ok, _user} ->
        socket =
          socket
          |> assign(:entity, %User{})
          |> assign(:changeset, Accounts.change_user_name_and_email(socket.assigns.entity))

        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  def handle_event("reset-new-user", %{}, socket) do
    socket =
      socket
      |> assign(:entity, %User{})
      |> assign(:changeset, Accounts.change_user_name_and_email(socket.assigns.entity))

    {:noreply, socket}
  end

  def handle_event(event_name, params, socket) do
    IO.inspect(event_name)
    IO.inspect(params)

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_params(%{"competition_id" => competition_id}, _uri, socket) do
    if connected?(socket), do: Participants.subscribe()

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
  def handle_info({Participants, [:competition, :updated], _result}, socket) do
    {:ok, competition} = Competitions.get(socket.assigns.competition_id)

    socket = assign(socket, :competition, competition)

    {:noreply, socket}
  end

  def handle_info({Participants, [:user, :updated], _result}, socket) do
    users = Accounts.list_enrollable(socket.assigns.competition_id)

    socket = assign(socket, :users, users)

    {:noreply, socket}
  end
end
