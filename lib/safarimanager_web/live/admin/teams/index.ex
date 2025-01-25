defmodule SMWeb.Live.Admin.Teams.Index do
  @moduledoc """
  Teams live view
  """
  use SMWeb, :surface_view

  import SMWeb.Components.DateTimeString
  import SMWeb.Components.FieldsList
  import SMWeb.Components.Layout
  import SMWeb.Components.ShortUUID
  import SMWeb.Components.SMField

  alias SM.Competitions
  alias SM.Participants
  alias SM.Teams
  alias SM.Teams.Team
  alias SM.Teams.TeamMember
  alias SMWeb.Components.Column
  alias SMWeb.Components.Grid
  alias Surface.Components.Context
  alias Surface.Components.Form
  alias Surface.Components.Form.ErrorTag
  alias Surface.Components.Form.Field
  alias Surface.Components.Form.HiddenInput
  alias Surface.Components.Form.Inputs
  alias Surface.Components.Form.Label
  alias Surface.Components.Form.NumberInput
  alias Surface.Components.Form.Reset
  alias Surface.Components.Form.Select
  alias Surface.Components.Form.Submit
  alias Surface.Components.Form.TextInput

  require Logger

  on_mount SMWeb.SidebarHook

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    _result = subscribe(socket)

    changeset_action = SMWeb.live_action_to_changeset_action(socket.assigns.live_action)

    socket =
      socket
      |> load_entities()
      |> reset_current_editing()
      |> assign(
        action: changeset_action,
        competitions: Competitions.list(),
        participants: []
      )

    {:ok, socket}
  end

  @impl Phoenix.LiveView
  # Create/Edit dialog validate callback
  def handle_event("validate", %{"entity" => params}, socket) do
    competition_id = params["competition_id"]

    changeset =
      change(socket.assigns.record, params)

    user_ids = unique_member_users(changeset, competition_id)

    # TODO: Use `to_form/1` instead!
    changeset =
      changeset
      |> assign_form()
      |> Map.put(:action, :validate)

    socket =
      if competition_id == "" do
        socket
      else
        assign(socket,
          participants: get_participants_options(competition_id, user_ids),
          competition_id: competition_id
        )
      end

    socket = assign(socket, :changeset, changeset)
    {:noreply, socket}
  end

  # Create/Edit dialog submit callback
  def handle_event("submit", %{"entity" => %{"_action" => "create"} = params}, socket) do
    case Teams.create(params) do
      {:ok, _entity} ->
        socket =
          socket
          |> reset_current_editing()
          |> push_patch(to: "/admin/teams")

        socket = put_flash(socket, :info, gettext("Team created successfully"))
        {:noreply, socket}

      {:error, changeset} ->
        Logger.error("Error creating team: #{inspect(changeset)}")

        socket =
          socket
          |> assign(:changeset, changeset)
          |> put_flash(:error, gettext("Unable to create the team"))

        {:noreply, socket}
    end
  end

  def handle_event("submit", %{"entity" => %{"_action" => "edit"} = params}, socket) do
    case Teams.update(socket.assigns.record, params) do
      {:ok, entity} ->
        socket =
          socket
          |> reset_current_editing()
          |> push_patch(to: "/admin/teams")

        socket =
          put_flash(
            socket,
            :info,
            ~s(#{gettext("Edited team")} "#{Teams.synthesize_team_name(entity)}")
          )

        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  @impl Phoenix.LiveView
  def handle_params(%{"id" => id}, _url, socket) do
    case Teams.get(id) do
      {:ok, team} ->
        case socket.assigns.live_action do
          :show ->
            {:noreply, assign(socket, record: team)}

          :edit ->
            changeset = change(team, %{})
            competition_id = team.competition_id
            user_ids = unique_member_users(changeset, competition_id)

            socket =
              assign(socket,
                record: team,
                changeset: changeset,
                participants: get_participants_options(competition_id, user_ids),
                action: :edit
              )

            {:noreply, socket}
        end

      {:error, reason} ->
        socket = put_flash(socket, :error, gettext("Unable to retrieve this Team"))
        Logger.error("Error retrieving Team #{id}: #{inspect(reason)}")
        {:noreply, socket}
    end
  end

  def handle_params(_params, _url, socket) do
    case socket.assigns.live_action do
      :index ->
        {:noreply, socket}

      :new ->
        socket =
          socket
          |> reset_current_editing()
          |> assign(action: :create, participants: [])

        {:noreply, socket}
    end
  end

  @impl Phoenix.LiveView
  def handle_info({"delete-one", id}, socket) do
    socket =
      case delete(id) do
        :ok -> put_flash(socket, :info, gettext("Team deleted successfully"))
        :error -> put_flash(socket, :error, gettext("Unable to delete Team"))
      end

    {:noreply, socket}
  end

  def handle_info({"delete-selected", selection}, socket) do
    socket =
      case delete(selection) do
        :ok ->
          put_flash(socket, :info, gettext("Teams deleted successfully"))

        :error ->
          put_flash(socket, :error, gettext("Unable to delete Teams"))
      end

    {:noreply, socket}
  end

  def handle_info("delete-all", socket) do
    {:ok, _result} = Teams.delete_all()

    {:noreply, put_flash(socket, :info, gettext("All teams deleted successfully"))}
  end

  def handle_info({Teams, [:team, :deleted], deleted_ids}, socket) when is_list(deleted_ids) do
    socket =
      deleted_ids
      |> Stream.map(fn id -> "items-#{id}" end)
      |> Stream.scan(socket, fn dom_id, socket ->
        stream_delete_by_dom_id(socket, :items, dom_id)
      end)
      |> Enum.reverse()
      |> hd()

    {:noreply, socket}
  end

  def handle_info({Teams, [:team, :deleted], deleted_count}, socket) when is_integer(deleted_count) do
    {:noreply, push_navigate(socket, to: "/admin/teams")}
  end

  def handle_info({Teams, [:team, :deleted], deleted_item}, socket) do
    {:noreply, stream_delete(socket, :items, deleted_item)}
  end

  def handle_info({Teams, [:team, :updated], updated_item}, socket) do
    {:ok, updated_item} = Teams.get(updated_item.id)
    {:noreply, stream_insert(socket, :items, updated_item)}
  end

  def handle_info({Teams, [:team, :created], inserted_item}, socket) do
    _socket =
      if is_nil(Map.get(socket.assigns, :last_id)) do
        {:noreply, stream_insert(socket, :items, inserted_item)}
      else
        {:noreply, socket}
      end
  end

  def handle_info(_any, socket), do: {:noreply, socket}

  # Internal

  defp change(team, params) do
    Teams.change(team, params)
  end

  defp delete(ids) when is_list(ids) do
    case Teams.delete_many(ids) do
      {:ok, deleted} ->
        Logger.debug("Deleted #{deleted} entities")
        :ok

      :error ->
        Logger.error("""
        Error deleting multiple Teams:
          - #{Enum.join(ids, "\n  - ")}
        """)

        :error
    end
  end

  defp delete(id) do
    with {:ok, team} <- Teams.get(id),
         {:ok, _result} <- Teams.delete(team) do
      :ok
    else
      {:error, reason} ->
        Logger.error("Error deleting Team #{inspect(id)}: #{inspect(reason)}")
        :error
    end
  end

  defp subscribe(socket) do
    if connected?(socket) do
      case Teams.subscribe() do
        :ok ->
          :ok

        {:error, reason} = error ->
          Logger.error("Unable to subscribe to Teams updates: #{inspect(reason)}")
          error
      end
    end
  end

  defp load_entities(socket) do
    items = Teams.list()

    stream(socket, :items, items)
  end

  defp reset_current_editing(socket) do
    entity = %Team{}
    changeset = change(entity, %{})
    changeset = assign_form(changeset)

    socket
    |> assign(:record, entity)
    |> assign(:changeset, changeset)
  end

  defp assign_form(%Ecto.Changeset{} = changeset) do
    if Ecto.Changeset.get_field(changeset, :members) == [] do
      Ecto.Changeset.put_change(changeset, :members, [%TeamMember{}])
      # |> to_form()
    else
      # to_form(changeset)
      changeset
    end
  end

  defp unique_member_users(_changeset, nil), do: []
  defp unique_member_users(_changeset, ""), do: []

  defp unique_member_users(changeset, competition_id) do
    changeset
    |> Ecto.Changeset.fetch_field!(:members)
    |> Enum.map(&Map.get(&1, :user_id))
    |> Enum.concat(Teams.list_member_users(competition_id))
    |> Enum.reject(&is_nil(&1))
    |> Enum.uniq()
  end

  defp get_participants_options(competition_id, member_user_ids) do
    competition_id
    |> Participants.list()
    |> Enum.sort_by(& &1.user.last_name)
    |> Enum.map(
      &[
        key: "#{&1.user.last_name} #{&1.user.first_name}",
        value: &1.user.id,
        hidden: &1.user.id in member_user_ids
      ]
    )
  end
end
