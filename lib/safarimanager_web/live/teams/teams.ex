defmodule SMWeb.Live.Teams do
  @moduledoc """
  Teams live view
  """
  use SMWeb, :surface_view

  alias SM.Accounts
  alias SM.Accounts.User
  alias SM.Competitions
  alias SM.Participants
  alias SM.Teams
  alias SMWeb.Components.CompetitionHeader
  alias SMWeb.Components.FieldsList
  alias SMWeb.Components.FieldsListItem
  alias SMWeb.Components.Layout
  alias SMWeb.Components.SMField
  alias SMWeb.Components.StepsHeader
  alias Surface.Components.Form
  alias Surface.Components.Form.HiddenInput
  alias Surface.Components.Form.Reset
  alias Surface.Components.Form.Submit
  alias Surface.Components.Form.TextInput
  alias Surface.Components.Link
  alias Surface.Components.LiveRedirect

  require Logger

  on_mount SMWeb.SidebarHook

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    socket =
      assign(socket,
        participants: [],
        teams: [],
        entity: %User{},
        changeset: nil,
        participants_selection: MapSet.new()
      )

    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("filter-participants", %{"value" => ""}, socket) do
    participants = Participants.list(socket.assigns.competition_id)
    {:noreply, assign(socket, :participants, participants)}
  end

  def handle_event("filter-participants", %{"value" => value}, socket) do
    participants = Participants.filter_by_name(socket.assigns.competition_id, value)
    {:noreply, assign(socket, :participants, participants)}
  end

  def handle_event(
        "change",
        %{"_target" => ["participants-list-selection"], "participants-list-selection" => selection},
        socket
      ) do
    socket =
      assign(socket, participants_selection: MapSet.new(selection))

    {:noreply, socket}
  end

  def handle_event("create-team", _params, socket) do
    competition_id = socket.assigns.competition.id

    members =
      socket.assigns.participants_selection
      |> MapSet.to_list()
      |> Enum.map(&%{"user_id" => &1})

    next_team_number = Teams.get_next_team_number(competition_id)

    socket =
      case Teams.create(%{"competition_id" => competition_id, "number" => next_team_number, "members" => members}) do
        {:ok, team} ->
          put_flash(
            socket,
            :info,
            "#{gettext("Team created successfully")}: #{Teams.synthesize_team_name(team)}"
          )

        {:error, reason} ->
          Logger.error("Unable to create team from selected participants: #{inspect(reason)}")
          put_flash(socket, :error, gettext("Unable to create team"))
      end

    socket =
      assign(socket, participants_selection: MapSet.new())

    {:noreply, socket}
  end

  def handle_event("edit-team", %{"id" => team_id}, socket) do
    {:ok, team} = Teams.get(team_id)

    form =
      team
      |> Teams.change()
      |> to_form()

    socket = assign(socket, changeset: form)

    {:noreply, socket}
  end

  def handle_event("validate-team", %{"entity" => params}, socket) do
    {:ok, team} = Teams.get(params["id"])

    form =
      team
      |> Teams.change(params)
      |> Map.put(:action, :validate)
      |> to_form()

    socket = assign(socket, changeset: form)

    {:noreply, socket}
  end

  def handle_event("submit-team", %{"entity" => params}, socket) do
    {:ok, team} = Teams.get(params["id"])

    {:ok, _team} = Teams.update(team, params)

    socket = assign(socket, changeset: nil)

    {:noreply, socket}
  end

  def handle_event("stop-editing-team", _params, socket) do
    socket = assign(socket, changeset: nil)

    {:noreply, socket}
  end

  def handle_event("remove-team", %{"id" => team_id}, socket) do
    on_confirm = fn socket ->
      with {:ok, team} <- Teams.get(team_id),
           {:ok, _team} <- Teams.delete(team) do
        put_flash(socket, :info, gettext("Team deleted successfully"))
      else
        {:error, reason} ->
          Logger.error("Unable to delete team '#{team_id}': #{inspect(reason)}")
          put_flash(socket, :error, gettext("Unable to delete team"))
      end
    end

    {:noreply,
     confirm(socket, on_confirm,
       title: gettext("Delete team"),
       description: gettext("Are you sure you want to delete this team?"),
       confirm_text: gettext("Delete"),
       confirm_icon: "trash"
     )}
  end

  def handle_event(event_name, params, socket) do
    Logger.debug("#{inspect({event_name, params})}")

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_params(%{"competition_id" => competition_id}, _uri, socket) do
    _result = if connected?(socket), do: {Participants.subscribe(), Teams.subscribe()}

    {:ok, competition} = Competitions.get(competition_id)
    users = Accounts.list_enrollable(competition_id)

    socket =
      assign(socket,
        competition_id: competition_id,
        competition: competition,
        participants: Participants.list_for_teams(competition_id),
        teams: Teams.list_by_competition(competition_id),
        users: users
      )

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_info({Participants, [:participant, _action], _result}, socket) do
    competition_id = socket.assigns.competition_id
    participants = Participants.list_for_teams(competition_id)
    teams = Teams.list_by_competition(competition_id)

    socket =
      assign(socket,
        participants: participants,
        teams: teams
      )

    {:noreply, socket}
  end

  def handle_info({Teams, [:team, _action], _result}, socket) do
    competition_id = socket.assigns.competition_id
    participants = Participants.list_for_teams(competition_id)
    teams = Teams.list_by_competition(competition_id)

    socket =
      assign(socket,
        participants: participants,
        teams: teams
      )

    {:noreply, socket}
  end

  def handle_info(_message, socket) do
    {:noreply, socket}
  end
end
